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
    @State private var diamonds: Int = 0
    @State private var isGameActive: Bool = false
    private let db = Firestore.firestore()
    
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
        .onAppear {
            fetchDiamonds()
        }
        .fullScreenCover(isPresented: $isGameActive) {
            GameView(isGameActive: $isGameActive, diamonds: $diamonds)
        }
    }
    
    private func fetchDiamonds() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(), let userDiamonds = data["diamonds"] as? Int {
                diamonds = userDiamonds
            }
        }
    }
}


struct GameView: View {
    @State private var aceChoice: Int? = nil // Track user's choice
    @State private var isAcePromptActive: Bool = false
    @Binding var isGameActive: Bool
    @Binding var diamonds: Int
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


            

                // Bet Selection
                if !gameStarted {
                    Text("Select Your Bet")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()

                    HStack {
                        Button(action: { changeBet(by: -10) }) {
                            Text("-10")
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Text("\(betAmount) 💎")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        Button(action: { changeBet(by: 10) }) {
                            Text("+10")
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()

                    Button(action: startGame) {
                        Text("Start Game")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(diamonds >= betAmount ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(diamonds < betAmount)
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

                        Button(action: stand) {
                            Text("Stand")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
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


    private func startGame() {
        gameStarted = true
        aceChoice = nil // Reset Ace choice
        diamonds -= betAmount
        updateDiamondsInFirebase()

        playerHand = [drawCard(), drawCard()]
        dealerHand = [drawCard(), drawCard()]
        updateScores()

        // Wait for Ace choice if necessary
        if playerHand.contains(1) {
            DispatchQueue.main.async {
                isAcePromptActive = true // Prompt for Ace choice before checking Blackjack
            }
            return
        }

        checkBlackjack()
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
        withAnimation {
            while dealerScore < 17 {
                dealerHand.append(drawCard())
                updateScores()
            }
        }
        checkWinner()
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


#Preview {
    BlackJackView()
}
