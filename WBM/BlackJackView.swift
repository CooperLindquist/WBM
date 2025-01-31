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
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Diamonds Display
                Text("Diamonds: \(diamonds)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                
                // Play Button
                Button(action: {
                    isGameActive = true
                }) {
                    Text("Play Blackjack")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .onDisappear {
            // Reset state when leaving view
            hasFetchedHands = false
            handsPlayedToday = 0
        }
        .onAppear {
            fetchDiamonds()
            fetchHandsPlayedToday()
        }
        .fullScreenCover(isPresented: $isGameActive) {
            GameView(
                isGameActive: $isGameActive,
                diamonds: $diamonds,
                handsPlayedToday: $handsPlayedToday,
                hasFetchedHands: $hasFetchedHands,
                db: db
            )
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
                    if !gameStarted {
                        if let canPlay = canPlay, !canPlay {
                            if !isPremiumUser() { // Only show timer for non-premium
                                if timeRemaining > 0 {
                                    Text("Time until next game: \(timeFormatted(timeRemaining))")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                } else {
                                    Text("Daily limit reached. Upgrade to premium!")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                        } else {
                            // In GameView.swift
                            if !isPremiumUser() {
                                if hasFetchedHands {
                                    Text("Games left today: \(3 - handsPlayedToday)")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                } else {
                                    ProgressView()
                                        .padding()
                                        .onAppear {
                                            // Final safety check
                                            if !hasFetchedHands {
                                                fetchHandsPlayedToday()
                                            }
                                        }
                                }
                            }
                        }
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
                                    Image("\(dealerHand[index])")
                                        .resizable()
                                        .frame(width: 60, height: 90)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            Text("Score: \(dealerScore)")
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        VStack {
                            Text("Your Hand")
                                .font(.title2)
                                .foregroundColor(.white)
                            HStack {
                                ForEach(playerHand.indices, id: \.self) { index in
                                    Image("\(playerHand[index])")
                                        .resizable()
                                        .frame(width: 60, height: 90)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            Text("Score: \(playerScore)")
                                .foregroundColor(.white)
                                .padding(.top, 5)
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
                        fetchHandsPlayedToday() // Always fetch fresh data
                        canPlayHand { result in
                            canPlay = result
                            if !result && !isPremiumUser() {
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
        
        
        private func checkBlackjack() {
            if playerScore == 21 {
                if dealerScore == 21 {
                    gameStatus = "Push! It's a Tie 🤝"
                    diamonds += betAmount
                } else {
                    gameStatus = "Blackjack! You Win 🎉"
                    diamonds += Int(Double(betAmount) * 2.5) // 3:2 payout
                }
                updateDiamondsInFirebase()
                showEndScreen = true
            }
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
                        // Check if hands played today >= 3
                        if handsPlayedToday >= 3 {
                            // Start the countdown if not already running
                            if self.timeRemaining <= 0 {
                                self.startCountdown()
                            }
                            completion(false)
                        } else {
                            completion(true)
                        }
                    }
                } else {
                    completion(false)
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
            saveTimerState() // Save immediately
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    saveTimerState() // Save on every tick
                } else {
                    timer?.invalidate()
                    // Reset handsPlayedToday at midnight
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
        private func isPremiumUser() -> Bool {
            guard let userId = Auth.auth().currentUser?.uid else { return false }
            var isPremium = false
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    isPremium = data["premium"] as? Bool ?? false
                }
            }
            return isPremium
        }
        // Save the timer state
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
            
            // If timeRemaining is 0 but handsPlayedToday >= 3, restart the timer
            if timeRemaining <= 0 && handsPlayedToday >= 3 {
                startCountdown()
            } else if timeRemaining > 0 {
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
                
                playerHand = [drawCard(), drawCard()]
                dealerHand = [drawCard(), drawCard()]
                updateScores()
                
                // Only update handsPlayedToday for NON-premium users
                guard let userId = Auth.auth().currentUser?.uid else { return }
                db.collection("users").document(userId).getDocument { snapshot, error in
                    if let data = snapshot?.data(), let isPremium = data["premium"] as? Bool, !isPremium {
                        // Update Firebase ONLY if not premium
                        db.collection("users").document(userId).updateData([
                            "handsPlayedToday": FieldValue.increment(Int64(1)),
                            "lastPlayedDate": Timestamp(date: Date())
                        ]) { error in
                            if error == nil {
                                // Update local state
                                handsPlayedToday += 1
                            }
                        }
                    }
                }
                
                if playerHand.contains(1) {
                    DispatchQueue.main.async {
                        isAcePromptActive = true
                    }
                    return
                }
                
                checkBlackjack()
            }
        }
        
        
        private func hit() {
            withAnimation {
                playerHand.append(drawCard())
                updateScores()
            }
            if playerScore > 21 {
                gameStatus = "Bust! You Lose ❌"
                showEndScreen = true
                updateDiamondsInFirebase()
            }
        }
        
        
        private func stand() {
            guard !gameEnded else { return }
            
            withAnimation {
                gameEnded = true
                while dealerScore < 17 {
                    dealerHand.append(drawCard())
                    updateScores()
                }
                checkWinner()
            }
        }
        
        
        
        private func drawCard() -> Int {
            return Int.random(in: 1...13)
        }
        private func canSplit() -> Bool {
            let canSplit = playerHand.count == 2 && playerHand[0] == playerHand[1] && diamonds >= betAmount
            print("Checking split: \(playerHand), Result: \(canSplit)")
            return canSplit
        }
        
        
        
        private func performSplit() {
            if canSplit() {
                diamonds -= betAmount
                updateDiamondsInFirebase()
                
                // Move second card to a new hand
                splitHands = [playerHand.removeLast()]
                playerHand.append(drawCard()) // Replace removed card
                splitHands.append(drawCard()) // Add new card to second hand
                
                isSplitActive = true
            }
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
            dealerScore = calculateHand(dealerHand, isDealer: true) // Dealer auto-picks
        }
        
        
        private func promptForAceValue() -> Int {
            DispatchQueue.main.async {
                isAcePromptActive = true
            }
            return aceChoice ?? 11 // Default to 11 if no input
        }
        
        
        private func calculateHand(_ hand: [Int], isDealer: Bool = false) -> Int {
            var total = 0
            var aceCount = 0
            var aceValues: [Int] = []
            
            for card in hand {
                if card == 1 {
                    aceCount += 1
                } else if card > 10 {
                    total += 10
                } else {
                    total += card
                }
            }
            
            if isDealer {
                // Auto-select Ace value for the dealer
                for _ in 0..<aceCount {
                    total += (total + 11 <= 21) ? 11 : 1
                }
            } else {
                // Ask the player for Ace value choice
                for _ in 0..<aceCount {
                    if aceChoice == nil {
                        DispatchQueue.main.async {
                            isAcePromptActive = true // Trigger alert only for player
                        }
                        return total // Wait for selection
                    }
                    aceValues.append(aceChoice!)
                }
                total += aceValues.reduce(0, +) // Add chosen Ace values
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
            if diamonds >= betAmount {
                diamonds -= betAmount
                betAmount *= 2
                playerHand.append(drawCard()) // One final card
                updateScores()
                updateDiamondsInFirebase()
                stand() // Player must stand after doubling down
            }
        }
        
        
        
        
        private func checkWinner() {
            if playerScore > 21 {
                gameStatus = "Bust! You Lose ❌"
            } else if dealerScore > 21 || playerScore > dealerScore {
                gameStatus = "You Win! 🎉"
                diamonds += betAmount * 2
            } else if playerScore < dealerScore {
                gameStatus = "Dealer Wins 😞"
            } else {
                gameStatus = "It's a Tie! 🤝"
                diamonds += betAmount
            }
            
            updateDiamondsInFirebase() // Update Firebase after game result
            
            withAnimation {
                showEndScreen = true
            }
        }
        
        
        private func restartGame() {
            withAnimation {
                showEndScreen = false
                gameStarted = false
                gameEnded = false // Add this
                playerHand = []
                splitHands = []
                dealerHand = []
                isSplitActive = false
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
