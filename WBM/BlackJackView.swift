//
//  BlackJackView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/29/25.
//
//  Rewritten to implement real casino blackjack rules:
//  - Multiple simultaneous hands via splitting (up to 4 hands)
//  - Independent bet per hand (so doubling/splitting tracks diamonds correctly)
//  - Re-splitting supported, with split-aces restricted to one card each (standard rule)
//  - Blackjack (natural 21) only pays out on the original first two cards,
//    not after a hit or after a split
//  - Dealer only plays after every player hand is finished (stood / busted / blackjack)
//  - Each hand is settled independently against the final dealer hand
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Card model

/// Ranks are 1...13 where 1 = Ace, 11 = Jack, 12 = Queen, 13 = King.
/// (Kept identical to the original encoding so your card image assets still work.)
enum HandStatus: Equatable {
    case playing
    case stood
    case busted
    case blackjack   // natural 21 on first two cards
    case surrendered // not used yet, reserved if you want to add surrender later
}

struct PlayerHand: Identifiable, Equatable {
    let id = UUID()
    var cards: [Int] = []
    var bet: Int
    var status: HandStatus = .playing
    /// Split aces only get exactly one extra card and can never hit/double again.
    var isSplitAces: Bool = false
    /// True once this hand has already been doubled (can't double twice).
    var hasDoubled: Bool = false

    var isResolved: Bool {
        status != .playing
    }
}

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
                .ignoresSafeArea()
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
            fetchUserData()
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

    private func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data() else {
                self.hasFetchedHands = true
                return
            }
            self.diamonds = data["diamonds"] as? Int ?? 0
            let lastPlayedDate = (data["lastPlayedDate"] as? Timestamp)?.dateValue() ?? Date()
            let currentHandsPlayed = data["handsPlayedToday"] as? Int ?? 0
            if !Calendar.current.isDate(lastPlayedDate, inSameDayAs: Date()) {
                self.db.collection("users").document(userId).updateData([
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
        }
    }

    // MARK: - GameView

    struct GameView: View {
        private let db: Firestore

        // Multi-hand state (replaces playerHand / splitHands / isSplitActive)
        @State private var hands: [PlayerHand] = []
        @State private var currentHandIndex: Int = 0

        @State private var dealerHand: [Int] = []
        @State private var dealerRevealed = false

        @State private var gameStatus: String = "Place Your Bet"
        @State private var betAmount: Int = 10
        @State private var showEndScreen: Bool = false
        @State private var gameStarted: Bool = false
        @State private var gameEnded: Bool = false
        @State private var roundResults: [String] = [] // one result line per hand, shown on end screen

        @State private var canPlay: Bool? = nil
        @State private var timeRemaining: Int = 0
        @State private var timer: Timer? = nil

        @Binding var isGameActive: Bool
        @Binding var diamonds: Int
        @Binding var handsPlayedToday: Int
        @Binding var hasFetchedHands: Bool

        @State private var isPremium = false
        @State private var showPremiumAlert = false

        private let maxHands = 4 // standard casino cap on splits (3 splits -> 4 hands)

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
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
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
                        // MARK: Active game table
                        VStack {
                            Text("Dealer's Hand")
                                .font(.title2)
                                .foregroundColor(.white)
                            HStack {
                                ForEach(dealerHand.indices, id: \.self) { index in
                                    if index == 0 || dealerRevealed {
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
                            Text("Score: \(dealerRevealed ? calculateHand(dealerHand) : (dealerHand.count > 0 ? calculateHand([dealerHand[0]]) : 0))")
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                        .padding(.top, 20)

                        Spacer()

                        // All player hands, with the active one highlighted
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(hands.indices, id: \.self) { index in
                                    handView(for: index)
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text(gameStatus)
                            .font(.title2)
                            .foregroundColor(.yellow)
                            .padding()
                            .animation(.easeInOut, value: gameStatus)

                        if !showEndScreen, currentHandIndex < hands.count {
                            actionButtons
                        }
                    }
                }
                .padding(.bottom, 30)
                .onAppear {
                    checkPremiumStatus()
                    if !isPremium {
                        loadTimerState()
                    }
                }

                // End Screen
                if showEndScreen {
                    VStack(spacing: 8) {
                        Text("Round Over")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom, 4)

                        ForEach(roundResults.indices, id: \.self) { i in
                            Text(roundResults[i])
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Text("New Balance: \(diamonds) 💎")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.top, 8)

                        Button(action: restartGame) {
                            Text("Play Again")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)

                        Button(action: { isGameActive = false }) {
                            Text("Exit")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(width: 320)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .transition(.scale)
                    .onAppear {
                        fetchHandsPlayedToday()
                        canPlayHand { result in
                            canPlay = result
                            if !result && !isPremium {
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

        // MARK: - Subviews

        @ViewBuilder
        private func handView(for index: Int) -> some View {
            let hand = hands[index]
            VStack {
                Text(hands.count > 1 ? "Hand \(index + 1)" : "Your Hand")
                    .font(.title3)
                    .foregroundColor(index == currentHandIndex && !showEndScreen ? .yellow : .white)

                HStack {
                    ForEach(hand.cards.indices, id: \.self) { cardIndex in
                        Image("\(hand.cards[cardIndex])")
                            .resizable()
                            .frame(width: 60, height: 90)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(index == currentHandIndex && !showEndScreen ? Color.yellow : Color.clear, lineWidth: 3)
                )

                Text("Score: \(calculateHand(hand.cards))  •  \(hand.bet) 💎")
                    .foregroundColor(.white)
                    .padding(.top, 4)

                statusLabel(for: hand.status)
            }
        }

        @ViewBuilder
        private func statusLabel(for status: HandStatus) -> some View {
            switch status {
            case .busted:
                Text("Bust").foregroundColor(.red).bold()
            case .blackjack:
                Text("Blackjack!").foregroundColor(.green).bold()
            case .stood:
                Text("Stood").foregroundColor(.gray)
            case .surrendered:
                Text("Surrendered").foregroundColor(.orange)
            case .playing:
                EmptyView()
            }
        }

        private var actionButtons: some View {
            let activeHand = hands[currentHandIndex]
            return HStack {
                Button(action: hit) {
                    Text("Hit")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(activeHand.isResolved)

                Button(action: stand) {
                    Text("Stand")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(activeHand.isResolved)

                if canDouble() {
                    Button(action: doubleDown) {
                        Text("Double")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
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
                }
            }
            .padding(.horizontal)
        }

        // MARK: - Premium / daily limit plumbing (unchanged behavior)

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

        private func startCountdownTimer() {
            let calendar = Calendar.current
            let now = Date()
            guard let nextMidnight = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) else { return }
            timeRemaining = Int(nextMidnight.timeIntervalSince(now))
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

        private func fetchHandsPlayedToday() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let lastPlayedDate = (data["lastPlayedDate"] as? Timestamp)?.dateValue() ?? Date()
                    let currentHandsPlayed = data["handsPlayedToday"] as? Int ?? 0
                    if !Calendar.current.isDate(lastPlayedDate, inSameDayAs: Date()) {
                        db.collection("users").document(userId).updateData([
                            "handsPlayedToday": 0,
                            "lastPlayedDate": Timestamp(date: Date())
                        ]) { error in
                            handsPlayedToday = (error == nil) ? 0 : currentHandsPlayed
                            hasFetchedHands = true
                        }
                    } else {
                        handsPlayedToday = currentHandsPlayed
                        hasFetchedHands = true
                    }
                } else {
                    hasFetchedHands = true
                }
            }
        }

        private func saveTimerState() {
            UserDefaults.standard.set(timeRemaining, forKey: "timeRemaining")
            UserDefaults.standard.set(Date(), forKey: "lastTimerUpdate")
        }

        private func loadTimerState() {
            let lastTimerUpdate = UserDefaults.standard.object(forKey: "lastTimerUpdate") as? Date ?? Date()
            let savedTimeRemaining = UserDefaults.standard.integer(forKey: "timeRemaining")
            let elapsedTime = Int(Date().timeIntervalSince(lastTimerUpdate))
            timeRemaining = max(0, savedTimeRemaining - elapsedTime)
            if timeRemaining > 0 && handsPlayedToday >= 3 && !isPremium {
                startCountdown()
            }
        }

        // MARK: - Core game flow

        private func startGame() {
            canPlayHand { canPlay in
                guard canPlay else {
                    gameStatus = "Daily limit reached. Upgrade to premium!"
                    return
                }

                gameStarted = true
                gameEnded = false
                showEndScreen = false
                roundResults = []
                dealerRevealed = false

                diamonds -= betAmount
                updateDiamondsInFirebase()

                let starterHand = PlayerHand(cards: [drawCard(), drawCard()], bet: betAmount)
                hands = [starterHand]
                currentHandIndex = 0

                dealerHand = [drawCard(), drawCard()]
                gameStatus = "Your turn"

                guard let userId = Auth.auth().currentUser?.uid else { return }
                db.collection("users").document(userId).updateData([
                    "handsPlayedToday": FieldValue.increment(Int64(1)),
                    "lastPlayedDate": Timestamp(date: Date())
                ]) { error in
                    if error == nil {
                        self.handsPlayedToday += 1
                    }
                }

                // Resolve a natural blackjack on the opening deal.
                evaluateForBlackjack(at: 0)

                // Dealer blackjack check (peek): if dealer shows ace/10 and has blackjack,
                // round ends immediately for everyone once all hands are dealt.
                if calculateHand(dealerHand) == 21 && dealerHand.count == 2 {
                    dealerRevealed = true
                    finishRoundIfAllHandsDone(forceDealerBlackjack: true)
                } else {
                    advanceToNextPlayableHandOrDealer()
                }
            }
        }

        /// Marks a hand blackjack if it qualifies (exactly 2 cards, value 21, not from a split,
        /// and not split aces). Casino rule: a 21 made after a split does NOT count as blackjack.
        private func evaluateForBlackjack(at index: Int) {
            guard index < hands.count else { return }
            var hand = hands[index]
            guard hand.cards.count == 2, !hand.isSplitAces else {
                return
            }
            // Only the original opening deal (before any split has happened) can be a natural
            // blackjack. Split-derived hands are never passed through this function, so checking
            // hands.count == 1 here correctly means "this is still the single hand from the
            // initial deal," matching the standard casino rule that 21-after-split isn't a natural.
            if hands.count == 1, calculateHand(hand.cards) == 21 {
                hand.status = .blackjack
                hands[index] = hand
            }
        }

        private func canDouble() -> Bool {
            guard currentHandIndex < hands.count else { return false }
            let hand = hands[currentHandIndex]
            return hand.cards.count == 2
                && !hand.hasDoubled
                && !hand.isSplitAces
                && !hand.isResolved
                && diamonds >= hand.bet
        }

        private func canSplit() -> Bool {
            guard currentHandIndex < hands.count else { return false }
            let hand = hands[currentHandIndex]
            guard hand.cards.count == 2, !hand.isResolved, hands.count < maxHands else { return false }
            let rankA = cardRankValue(hand.cards[0])
            let rankB = cardRankValue(hand.cards[1])
            return rankA == rankB && diamonds >= hand.bet
        }

        /// Maps a card to its blackjack rank value for split-eligibility comparison
        /// (so a King and Queen both count as "10" and can be split together, matching
        /// most casino rules; tighten this to `==` raw card if you want exact-rank-only splits).
        private func cardRankValue(_ card: Int) -> Int {
            min(card, 10)
        }

        private func hit() {
            guard currentHandIndex < hands.count, !hands[currentHandIndex].isResolved else { return }
            hands[currentHandIndex].cards.append(drawCard())

            let total = calculateHand(hands[currentHandIndex].cards)
            if total > 21 {
                hands[currentHandIndex].status = .busted
                advanceToNextPlayableHandOrDealer()
            } else if hands[currentHandIndex].isSplitAces {
                // Split aces only ever get one card.
                hands[currentHandIndex].status = .stood
                advanceToNextPlayableHandOrDealer()
            }
            // Note: reaching 21 here is NOT an automatic blackjack/stand —
            // real casino rules let the player choose to stand manually,
            // and a post-hit 21 is just a 21, not a natural blackjack.
        }

        private func stand() {
            guard currentHandIndex < hands.count, !hands[currentHandIndex].isResolved else { return }
            hands[currentHandIndex].status = .stood
            advanceToNextPlayableHandOrDealer()
        }

        private func doubleDown() {
            guard canDouble() else { return }
            let bet = hands[currentHandIndex].bet

            diamonds -= bet
            updateDiamondsInFirebase()

            hands[currentHandIndex].bet += bet
            hands[currentHandIndex].hasDoubled = true
            hands[currentHandIndex].cards.append(drawCard())

            let total = calculateHand(hands[currentHandIndex].cards)
            hands[currentHandIndex].status = total > 21 ? .busted : .stood

            advanceToNextPlayableHandOrDealer()
        }

        private func performSplit() {
            guard canSplit() else { return }

            let original = hands[currentHandIndex]
            let isSplittingAces = cardRankValue(original.cards[0]) == 1

            diamonds -= original.bet
            updateDiamondsInFirebase()

            var hand1 = PlayerHand(cards: [original.cards[0], drawCard()], bet: original.bet)
            var hand2 = PlayerHand(cards: [original.cards[1], drawCard()], bet: original.bet)

            if isSplittingAces {
                // Standard rule: split aces get exactly one card each, then stand automatically.
                hand1.isSplitAces = true
                hand2.isSplitAces = true
                hand1.status = .stood
                hand2.status = .stood
            }

            hands[currentHandIndex] = hand1
            hands.insert(hand2, at: currentHandIndex + 1)

            advanceToNextPlayableHandOrDealer()
        }

        /// Moves currentHandIndex forward to the next hand that still needs player input.
        /// If every hand is resolved, reveals the dealer and plays out the dealer's hand.
        private func advanceToNextPlayableHandOrDealer() {
            var idx = currentHandIndex
            // If the current hand just got resolved, look forward; otherwise stay put
            // (this function is only called right after a hand becomes resolved or
            // immediately after dealing, so always search from currentHandIndex).
            while idx < hands.count && hands[idx].isResolved {
                idx += 1
            }

            if idx < hands.count {
                currentHandIndex = idx
                gameStatus = hands.count > 1 ? "Hand \(idx + 1): your turn" : "Your turn"
                return
            }

            // All hands resolved — dealer plays only if at least one hand can still win
            // (i.e. isn't every hand busted); casino tables still reveal the hole card either way.
            currentHandIndex = hands.count // park past the end so action buttons hide
            dealerRevealed = true

            let anyHandStillIn = hands.contains { $0.status != .busted }
            if anyHandStillIn {
                playDealerHand()
            } else {
                finishRoundIfAllHandsDone()
            }
        }

        private func playDealerHand() {
            gameStatus = "Dealer's turn"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                drawDealerCardStep()
            }
        }

        /// Draws one dealer card at a time with a short delay between draws so the UI animates,
        /// instead of looping synchronously (avoids freezing the UI and is easy to read).
        private func drawDealerCardStep() {
            let total = calculateHand(dealerHand)
            if total < 17 {
                dealerHand.append(drawCard())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    drawDealerCardStep()
                }
            } else {
                finishRoundIfAllHandsDone()
            }
        }

        /// Settles every player hand against the final dealer hand and updates diamonds once.
        private func finishRoundIfAllHandsDone(forceDealerBlackjack: Bool = false) {
            gameEnded = true
            let dealerTotal = calculateHand(dealerHand)
            let dealerHasBlackjack = forceDealerBlackjack || (dealerHand.count == 2 && dealerTotal == 21)
            let dealerBusted = dealerTotal > 21

            var totalPayout = 0
            var results: [String] = []

            for (i, hand) in hands.enumerated() {
                let playerTotal = calculateHand(hand.cards)
                let label = hands.count > 1 ? "Hand \(i + 1): " : ""

                if hand.status == .busted {
                    results.append("\(label)Bust ❌  (-\(hand.bet))")
                    continue // no payout, bet already deducted
                }

                if hand.status == .blackjack {
                    if dealerHasBlackjack {
                        totalPayout += hand.bet
                        results.append("\(label)Push (both Blackjack) 🤝")
                    } else {
                        let payout = Int(Double(hand.bet) * 2.5)
                        totalPayout += payout
                        results.append("\(label)Blackjack! 🎉  (+\(payout - hand.bet))")
                    }
                    continue
                }

                if dealerHasBlackjack {
                    results.append("\(label)Dealer Blackjack 😞  (-\(hand.bet))")
                    continue
                }

                if dealerBusted {
                    let payout = hand.bet * 2
                    totalPayout += payout
                    results.append("\(label)Dealer Bust! 🎉  (+\(hand.bet))")
                } else if playerTotal > dealerTotal {
                    let payout = hand.bet * 2
                    totalPayout += payout
                    results.append("\(label)Win! 🎉  (+\(hand.bet))")
                } else if playerTotal < dealerTotal {
                    results.append("\(label)Lose 😞  (-\(hand.bet))")
                } else {
                    totalPayout += hand.bet
                    results.append("\(label)Push 🤝")
                }
            }

            diamonds += totalPayout
            updateDiamondsInFirebase()

            roundResults = results
            gameStatus = "Round Over"
            withAnimation {
                showEndScreen = true
            }
        }

        // MARK: - Helpers

        private func drawCard() -> Int {
            Int.random(in: 1...13)
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
            for _ in 0..<aceCount {
                total += (total + 11 <= 21) ? 11 : 1
            }
            return total
        }

        private func updateDiamondsInFirebase() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            db.collection("users").document(userId).updateData(["diamonds": diamonds]) { error in
                if let error = error {
                    print("Error updating diamonds: \(error.localizedDescription)")
                }
            }
        }

        private func restartGame() {
            withAnimation {
                showEndScreen = false
                gameStarted = false
                gameEnded = false
                hands = []
                currentHandIndex = 0
                dealerHand = []
                dealerRevealed = false
                roundResults = []
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
