//
//  BlackJackView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/29/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BlackJackView: View {
    @State private var handsPlayedToday: Int = 0
    @State private var diamonds: Int = 0
    @State private var isGameActive: Bool = false
    private let db = Firestore.firestore()
    @State private var hasFetchedHands = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text("Diamonds: \(diamonds)")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    .padding()

                Button(action: { isGameActive = true }) {
                    Text("Play Blackjack")
                        .font(.title).fontWeight(.bold)
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.green).foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .onAppear {
            fetchDiamonds()
            fetchHandsPlayedToday()
        }
        .onDisappear {
            hasFetchedHands = false
            handsPlayedToday = 0
        }
        .fullScreenCover(isPresented: $isGameActive) {
            GameView(isGameActive: $isGameActive,
                     diamonds: $diamonds,
                     handsPlayedToday: $handsPlayedToday,
                     hasFetchedHands: $hasFetchedHands,
                     db: db)
        }
    }
    private func fetchHandsPlayedToday() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let lastPlayedDate = (data["lastPlayedDate"] as? Timestamp)?.dateValue() ?? Date()
                    let currentHandsPlayed = data["handsPlayedToday"] as? Int ?? 0
                    
                    if !Calendar.current.isDate(lastPlayedDate, inSameDayAs: Date()) {
                        // Reset in Firebase
                        db.collection("users").document(userId).updateData([
                            "handsPlayedToday": 0,
                            "lastPlayedDate": Timestamp(date: Date())
                        ]) { error in
                            self.handsPlayedToday = (error == nil) ? 0 : currentHandsPlayed
                            self.hasFetchedHands = true
                        }
                    } else {
                        self.handsPlayedToday = currentHandsPlayed
                        self.hasFetchedHands = true
                    }
                } else {
                    self.hasFetchedHands = true
                }
            }
        }
    
    
    
   
    private func fetchDiamonds() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                diamonds = data["diamonds"] as? Int ?? 0
            }
        }
    }
    
    
    struct GameView: View {
        private let db: Firestore
        
        @State private var aceChoice: Int? = nil // Track user's choice
        @State private var isAcePromptActive: Bool = false
        @State private var splitHands: [Int] = []
        @State private var playerHands: [[Int]] = []
        @State private var currentHandIndex = 0
        @State private var splitBet: Int = 0
        @State private var isSplitActive: Bool = false
        @State private var playerHand: [Int] = []
        @State private var dealerHand: [Int] = []
        @State private var playerScore: Int = 0
        @State private var dealerScore: Int = 0
        @State private var gameStatus: String = "Place Your Bet"
        @State private var betAmount: Int = 10
        @State private var showEndScreen: Bool = false
        @State private var gameStarted: Bool = false
        @State private var canPlay: Bool? = nil
        @State private var timeRemaining: Int = 0
        @State private var timer: Timer? = nil
        @State private var gameEnded: Bool = false
        @Binding var isGameActive: Bool
        @Binding var diamonds: Int
        @Binding var handsPlayedToday: Int // Receive from parent
        @Binding var hasFetchedHands: Bool
        @State private var isPremium = false
        @State private var showPremiumAlert = false
        @State private var dealerRevealed = false
        @State private var dealerVisibleScore = 0

        
        
        
        init(isGameActive: Binding<Bool>,
                 diamonds: Binding<Int>,
                 handsPlayedToday: Binding<Int>,
                 hasFetchedHands: Binding<Bool>,
                 db: Firestore) {
                self._isGameActive = isGameActive
                self._diamonds = diamonds
                self._handsPlayedToday = handsPlayedToday
                self._hasFetchedHands = hasFetchedHands
                self.db = db
            }
        
        var body: some View {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Diamonds & Exit
                    HStack {
                        Text("💎 Diamonds: \(diamonds)")
                            .font(.title2)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isGameActive = false }) {
                            Text("Exit")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .alert("Choose Ace Value", isPresented: $isAcePromptActive) {
                        Button("1") {
                            aceChoice = 1
                            updateScores() // Recalculate after choice
                        }
                        Button("11") {
                            aceChoice = 11
                            updateScores() // Recalculate after choice
                        }
                        
                    }
                    if !gameStarted && !isPremium {
                        VStack {
                            if hasFetchedHands {
                                if handsPlayedToday >= 3 {
                                    VStack {
                                        if timeRemaining > 0 {
                                            Text("Next game in: \(timeFormatted(timeRemaining))")
                                                .font(.title2)
                                                .foregroundColor(.orange)
                                        } else {
                                            Button("Upgrade to Premium") {
                                                showPremiumAlert = true
                                            }
                                            .font(.title2)
                                            .foregroundColor(.yellow)
                                        }
                                    }
                                } else {
                                    Text("Games left: \(3 - handsPlayedToday)")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                            } else {
                                ProgressView()
                                    .padding()
                            }
                        }
                    
                        .alert("Go Premium", isPresented: $showPremiumAlert) {
                            Button("Cancel", role: .cancel) {}
                            Button("Upgrade") {
                                // Handle premium upgrade
                            }
                        } message: {
                            Text("Get unlimited games with WBM+!")
                        }
                    }
                    if !isPremium && handsPlayedToday >= 3 {
                        VStack {
                            if timeRemaining > 0 {
                                Text("Next free game in: \(timeFormatted(timeRemaining))")
                                    .foregroundColor(.orange)
                            } else {
                                Button("Upgrade to Premium") {
                                    showPremiumAlert = true
                                }
                                .foregroundColor(.yellow)
                            }
                        }
                        .padding()
                    }
                    
                    // Bet Selection
                    if !gameStarted {
                        VStack(spacing: 20) {
                            Text("Select Your Bet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack {
                                Button(action: { changeBet(by: -10) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.red)
                                }
                                .disabled(betAmount <= 10)
                                
                                Text("\(betAmount) 💎")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(10)
                                
                                Button(action: { changeBet(by: 10) }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.green)
                                }
                                .disabled(betAmount >= diamonds)
                            }
                            
                            Button(action: {
                                canPlayHand { canPlay in
                                    if canPlay {
                                        startGame()
                                    } else {
                                        gameStatus = "Daily limit reached. Upgrade to premium!"
                                    }
                                }
                            }) {
                                Text("Start Game")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(diamonds >= betAmount ? Color.blue : Color.gray)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .disabled(diamonds < betAmount || (canPlay == false && timeRemaining > 0))
                            .padding(.top, 10)
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .padding(.horizontal)
                    } else {
                        // Game View
                        VStack {
                            Text("Dealer's Hand")
                                .font(.title2)
                                .foregroundColor(.white)
                            HStack {
                                ForEach(dealerHand.indices, id: \.self) { index in
                                    if gameStarted && (index == 0 || dealerRevealed) {
                                        Image("\(dealerHand[index])")
                                            .resizable()
                                            .frame(width: 60, height: 90)
                                    } else {
                                        Image("card_back")
                                            .resizable()
                                            .frame(width: 60, height: 90)
                                    }
                                }
                            }
                            Text("Score: \(dealerRevealed ? dealerScore : (dealerHand.count > 0 ? calculateHand([dealerHand[0]]) : 0))")
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        if !playerHands.isEmpty && currentHandIndex < playerHands.count {
                            VStack {
                                Text("Your Hand")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                HStack {
                                    ForEach(playerHands[currentHandIndex], id: \.self) { card in
                                        Image("\(card)")
                                            .resizable()
                                            .frame(width: 60, height: 90)
                                    }
                                }
                                Text("Score: \(calculateHand(playerHands[currentHandIndex]))")
                                    .foregroundColor(.white)
                                    .padding(.top, 5)
                            }
                        } else {
                            Text("Loading hand...")
                                .foregroundColor(.white)
                        }
                        if isSplitActive {
                            VStack {
                                Text("Split Hand")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                HStack {
                                    ForEach(splitHands, id: \.self) { card in
                                        Image("\(card)")
                                            .resizable()
                                            .frame(width: 60, height: 90)
                                    }
                                }
                            }
                        }
                        
                        
                        Text(gameStatus)
                            .font(.title2)
                            .foregroundColor(.yellow)
                            .padding()
                            .animation(.easeInOut, value: gameStatus)
                        
                        HStack {
                            Button(action: hit) {
                                Text("Hit")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(showEndScreen)
                            
                            Button(action: stand) {
                                Text("Stand")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(showEndScreen)
                            if playerHand.count == 2 && diamonds >= betAmount {
                                Button(action: doubleDown) {
                                    Text("Double")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(showEndScreen)
                            }
                            if canSplit() {
                                Button(action: performSplit) {
                                    Text("Split")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(showEndScreen)
                            }
                            
                            
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
                .onAppear {
                    // Add this modifier right after the VStack declaration
                    checkPremiumStatus()
                    if !isPremium {
                        loadTimerState()
                    }
                }
                
                // End Screen
                if showEndScreen {
                    VStack {
                        Text(gameStatus)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                        
                        Text("New Balance: \(diamonds) 💎")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Button(action: restartGame) {
                            Text("Play Again")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                        
                        Button(action: { isGameActive = false }) {
                            Text("Exit")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    
                    .frame(width: 300, height: 300)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .transition(.scale)
                    .onAppear {
                        fetchHandsPlayedToday()
                        canPlayHand { result in
                            canPlay = result
                            if !result && !isPremium { // Use the isPremium state variable
                                loadTimerState()
                            }
                        }
                    }
                    .onDisappear {
                        timer?.invalidate()
                        saveTimerState()
                    }
                    
                }
            }
        }
        
        private func checkPremiumStatus() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).getDocument { snapshot, _ in
                if let data = snapshot?.data() {
                    let premiumStatus = data["premium"] as? Bool ?? false
                    DispatchQueue.main.async {
                        isPremium = premiumStatus
                    }
                }
            }
        }
        private func checkBlackjack() -> Bool {
            let playerTotal = calculateHand(playerHands[currentHandIndex])
            let dealerTotal = calculateHand(dealerHand)
            
            if playerTotal == 21 && playerHands[currentHandIndex].count == 2 {
                if dealerTotal == 21 && dealerHand.count == 2 {
                    gameStatus = "Push! Both Blackjack 🤝"
                    diamonds += betAmount
                } else {
                    gameStatus = "Blackjack! You Win 🎉"
                    diamonds += Int(Double(betAmount) * 2.5)
                }
                updateDiamondsInFirebase()
                showEndScreen = true
                return true // Game should end
            }
            return false // Continue game
        }
        
        private func refreshHandsPlayed() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    handsPlayedToday = data["handsPlayedToday"] as? Int ?? 0
                }
            }
        }

        
        private func canPlayHand(completion: @escaping (Bool) -> Void) {
            guard let userId = Auth.auth().currentUser?.uid else {
                completion(false)
                return
            }
            
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let isPremium = data["premium"] as? Bool ?? false
                    let handsPlayedToday = data["handsPlayedToday"] as? Int ?? 0
                    
                    if isPremium {
                        completion(true)
                    } else {
                        let lastPlayedDate = (data["lastPlayedDate"] as? Timestamp)?.dateValue() ?? Date()
                        if !Calendar.current.isDate(lastPlayedDate, inSameDayAs: Date()) {
                            completion(true)
                        } else {
                            completion(handsPlayedToday < 3)
                        }
                    }
                } else {
                    completion(false)
                }
            }
        }
        private func updateHandsPlayed() {
            handsPlayedToday += 1
            UserDefaults.standard.set(handsPlayedToday, forKey: "handsPlayedToday")
            UserDefaults.standard.set(Date(), forKey: "lastPlayedDate")
            
            if handsPlayedToday >= 3 && !isPremium {
                startCountdownTimer()
            }
        }
        private func startCountdownTimer() {
            let calendar = Calendar.current
            let now = Date()
            
            // 1. Get the next midnight date
            guard let nextMidnight = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) else { return }
            
            // 2. Calculate seconds remaining and convert to Int
            timeRemaining = Int(nextMidnight.timeIntervalSince(now))
            
            // 3. Start the timer
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    handsPlayedToday = 0
                }
            }
        }
        
        private func timeFormatted(_ totalSeconds: Int) -> String {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        
        // Start the countdown timer
        private func startCountdown() {
            let calendar = Calendar.current
            let now = Date()
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            let secondsUntilTomorrow = Int(tomorrow.timeIntervalSince(now))
            
            timeRemaining = secondsUntilTomorrow
            saveTimerState()
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    saveTimerState()
                } else {
                    timer?.invalidate()
                    fetchHandsPlayedToday()
                }
            }
        }
        
        // Fetch handsPlayedToday from Firebase
        private func fetchHandsPlayedToday() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let lastPlayedDate = (data["lastPlayedDate"] as? Timestamp)?.dateValue() ?? Date()
                    let currentHandsPlayed = data["handsPlayedToday"] as? Int ?? 0
                    
                    if !Calendar.current.isDate(lastPlayedDate, inSameDayAs: Date()) {
                        // Reset in Firebase
                        db.collection("users").document(userId).updateData([
                            "handsPlayedToday": 0,
                            "lastPlayedDate": Timestamp(date: Date())
                        ]) { error in
                            handsPlayedToday = (error == nil) ? 0 : currentHandsPlayed
                            hasFetchedHands = true // Update fetch status
                        }
                    } else {
                        handsPlayedToday = currentHandsPlayed
                        hasFetchedHands = true // Update fetch status
                    }
                } else {
                    hasFetchedHands = true // Ensure fetch status updates even on error
                }
            }
        }
       
        
        private func saveTimerState() {
            UserDefaults.standard.set(timeRemaining, forKey: "timeRemaining")
            UserDefaults.standard.set(Date(), forKey: "lastTimerUpdate")
        }

        // Load the timer state
        private func loadTimerState() {
            let lastTimerUpdate = UserDefaults.standard.object(forKey: "lastTimerUpdate") as? Date ?? Date()
            let savedTimeRemaining = UserDefaults.standard.integer(forKey: "timeRemaining")
            
            let elapsedTime = Int(Date().timeIntervalSince(lastTimerUpdate))
            timeRemaining = max(0, savedTimeRemaining - elapsedTime)
            
            // Always restart timer if needed
            if timeRemaining > 0 && handsPlayedToday >= 3 && !isPremium {
                startCountdown()
            }
        }
        
        private func startGame() {
            canPlayHand { canPlay in
                guard canPlay else {
                    gameStatus = "Daily limit reached. Upgrade to premium!"
                    return
                }
                
                gameStarted = true
                aceChoice = nil
                diamonds -= betAmount
                updateDiamondsInFirebase()
                
                playerHands = [[drawCard(), drawCard()]] // Start with single hand
                currentHandIndex = 0 // Reset to first hand
                dealerRevealed = false
                dealerHand = [drawCard(), drawCard()]
                updateScores()
                
                // Update hands played in Firebase
                guard let userId = Auth.auth().currentUser?.uid else { return }
                db.collection("users").document(userId).updateData([
                    "handsPlayedToday": FieldValue.increment(Int64(1)),
                    "lastPlayedDate": Timestamp(date: Date())
                ]) { error in
                    if error == nil {
                        self.handsPlayedToday += 1
                    }
                }
                
                if playerHand.contains(1) {
                    isAcePromptActive = true
                    return
                }
                
                checkBlackjack()
            }
        }
        
        
        private func hit() {
            playerHands[currentHandIndex].append(drawCard())
            updateScores()
            
            let currentTotal = calculateHand(playerHands[currentHandIndex])
            
            if currentTotal > 21 {
                checkWinner() // End immediately on bust
            } else if checkBlackjack() {
                // Game already ended in checkBlackjack
                return
            }
        }
        
        
        private func stand() {
            guard !checkBlackjack() else { return } // Don't proceed if blackjack
            
            if currentHandIndex < playerHands.count - 1 {
                currentHandIndex += 1
                updateScores()
            } else {
                dealerRevealed = true
                startDealerDrawing()
            }
        }
        private func startDealerDrawing() {
            // Don't draw if player already busted
            guard !gameEnded else { return }
            
            dealerRevealed = true
            updateScores()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                var dealerTotal = calculateHand(dealerHand)
                
                // Only draw if player hasn't busted
                while dealerTotal < 17 && !gameEnded {
                    dealerHand.append(drawCard())
                    dealerTotal = calculateHand(dealerHand)
                    updateScores()
                }
                checkWinner()
            }
        }
        
        
        
        private func drawCard() -> Int {
            return Int.random(in: 1...13)
        }
        private func canSplit() -> Bool {
            guard !playerHands.isEmpty else { return false }
            let hand = playerHands[currentHandIndex]
            return hand.count == 2 &&
                   hand[0] == hand[1] &&
                   diamonds >= betAmount
        }
        
        
        
        private func performSplit() {
            guard canSplit() else { return }
            
            // Get current hand
            let originalHand = playerHands[currentHandIndex]
            
            // Create new hands
            let newHand1 = [originalHand[0], drawCard()]
            let newHand2 = [originalHand[1], drawCard()]
            
            // Replace current hand and add new hand
            playerHands[currentHandIndex] = newHand1
            playerHands.append(newHand2)
            
            // Deduct bet and update UI
            diamonds -= betAmount
            updateDiamondsInFirebase()
            updateScores()
        }
        
        private func dealerTurn() {
            if dealerScore < 17 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay for UI update
                    dealerHand.append(drawCard())
                    updateScores()
                    dealerTurn() // Recursive call to continue drawing
                }
            } else {
                checkWinner() // Proceed once dealer stops hitting
            }
        }
        
        
        
        private func updateScores() {
            playerScore = calculateHand(playerHand) // Player still chooses Ace
            dealerScore = calculateHand(dealerHand)
            dealerVisibleScore = dealerHand.count > 0 ? calculateHand([dealerHand[0]]) : 0
        }
        
        
        private func promptForAceValue() -> Int {
            DispatchQueue.main.async {
                isAcePromptActive = true
            }
            return aceChoice ?? 11 // Default to 11 if no input
        }
        
        
        private func calculateHand(_ hand: [Int]) -> Int {
            var total = 0
            var aceCount = 0
            
            for card in hand {
                if card == 1 {
                    aceCount += 1
                } else {
                    total += min(card, 10)
                }
            }
            
            // Handle aces optimally
            for _ in 0..<aceCount {
                total += (total + 11 <= 21) ? 11 : 1
            }
            
            return total
        }
        
        
        private func updateDiamondsInFirebase() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let userRef = Firestore.firestore().collection("users").document(userId)
            
            userRef.updateData(["diamonds": diamonds]) { error in
                if let error = error {
                    print("Error updating diamonds: \(error.localizedDescription)")
                } else {
                    print("Diamonds successfully updated in Firebase!")
                }
            }
        }
        private func doubleDown() {
            guard playerHands[currentHandIndex].count == 2 else { return }
            
            diamonds -= betAmount
            splitBet += betAmount
            updateDiamondsInFirebase()
            
            playerHands[currentHandIndex].append(drawCard())
            updateScores()
            stand()
        }
        
        
        
        
        private func checkWinner() {
            gameEnded = true // Add this flag
            let playerTotal = calculateHand(playerHands[currentHandIndex])
            let dealerTotal = calculateHand(dealerHand)
            print("Final Scores - Player: \(playerTotal), Dealer: \(dealerTotal)")
            
            // Reset diamonds change
            var diamondsChange = 0
            var resultMessage = ""
            
            // Check player bust first
            if playerTotal > 21 {
                resultMessage = "Bust! You Lose ❌"
            }
            // Check dealer bust
            else if dealerTotal > 21 {
                resultMessage = "Dealer Bust! You Win 🎉"
                diamondsChange = betAmount * 2
            }
            // Compare scores
            else {
                if playerTotal > dealerTotal {
                    resultMessage = "You Win! 🎉"
                    diamondsChange = betAmount * 2
                } else if playerTotal < dealerTotal {
                    resultMessage = "Dealer Wins 😞"
                } else {
                    resultMessage = "Push! It's a Tie 🤝"
                    diamondsChange = betAmount
                }
            }
            
            // Check for natural blackjack (only applies to initial 2 cards)
            if playerHands[currentHandIndex].count == 2
               && playerTotal == 21
               && dealerTotal != 21 {
                resultMessage = "Blackjack! You Win 🎉"
                diamondsChange = Int(Double(betAmount) * 2.5)
            }
            
            // Update game state
            gameStatus = resultMessage
            diamonds += diamondsChange
            updateDiamondsInFirebase()
            showEndScreen = true
        }
        
        
        private func restartGame() {
            withAnimation {
                showEndScreen = false
                gameStarted = false
                gameEnded = false
                playerHand = []
                splitHands = []
                dealerHand = []
                isSplitActive = false
                dealerRevealed = false // Add this line
                gameStatus = "Place Your Bet"
            }
        }
        
        private func changeBet(by amount: Int) {
            let newBet = betAmount + amount
            if newBet >= 10 && newBet <= diamonds {
                betAmount = newBet
            }
        }
    }
}
