import SwiftUI
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI

struct ChatView: View {
    let chatPartner: User
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var listener: ListenerRegistration? = nil
    @State private var typingListener: ListenerRegistration? = nil
    @State private var showingRateUserView = false
    @State private var showingProfile = false
    @State private var isPartnerTyping: Bool = false
    @State private var typingText: String = ""

    // Throttle typing-status writes so we don't hammer Firestore on every keystroke.
    // One write when the user starts typing, one when they stop — not one per character.
    @State private var typingDebounceTask: DispatchWorkItem? = nil
    @State private var currentlyReportedTyping: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.senderID == Auth.auth().currentUser?.uid {
                                    Spacer()
                                    Text(message.text)
                                        .padding()
                                        .background(Color.blue.opacity(0.7))
                                        .cornerRadius(15)
                                        .foregroundColor(.white)
                                        .shadow(color: Color.blue.opacity(0.5), radius: 3)
                                } else {
                                    Text(message.text)
                                        .padding()
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(15)
                                        .foregroundColor(.black)
                                        .shadow(color: Color.gray.opacity(0.5), radius: 3)
                                    Spacer()
                                }
                            }
                        }

                        if isPartnerTyping {
                            HStack {
                                Spacer()
                                Text(typingText)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(15)
                                    .foregroundColor(.black)
                                    .shadow(color: Color.gray.opacity(0.5), radius: 3)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }

                HStack {
                    TextField("Type a message...", text: $newMessage)
                        .padding()
                        .background(Color.black.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(radius: 3)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
                .padding()

                Button(action: {
                    showingRateUserView = true
                }) {
                    Text("Rate \(chatPartner.name)")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .padding()
                .fullScreenCover(isPresented: $showingRateUserView) {
                    RateUserView(chatPartner: chatPartner)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: { showingProfile = true }) {
                    HStack(spacing: 8) {
                        WebImage(url: URL(string: chatPartner.imageURLs.first ?? ""))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))

                        Text(chatPartner.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingProfile) {
            MatchProfileCover(user: chatPartner, onClose: { showingProfile = false })
        }
        .onAppear {
            fetchMessages()
            listenForTyping()
            markLatestMessageRead()
        }
        .onDisappear {
            listener?.remove()
            typingListener?.remove()
            // Make sure we clear the typing flag when leaving
            if currentlyReportedTyping {
                writeTypingStatus(isTyping: false)
            }
        }
        .onChange(of: newMessage) { value in
            handleTypingChange(hasText: !value.isEmpty)
        }
    }

    // MARK: - Typing throttle

    /// Debounced typing status: write "typing=true" immediately when the user starts,
    /// then write "typing=false" 2 seconds after they stop. This turns O(N keystrokes)
    /// Firestore writes into at most 2 writes per burst of typing.
    private func handleTypingChange(hasText: Bool) {
        typingDebounceTask?.cancel()

        if hasText && !currentlyReportedTyping {
            currentlyReportedTyping = true
            writeTypingStatus(isTyping: true)
        }

        if hasText {
            // Schedule a "stopped typing" write 2s after the last keystroke
            let task = DispatchWorkItem {
                currentlyReportedTyping = false
                writeTypingStatus(isTyping: false)
            }
            typingDebounceTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
        } else if currentlyReportedTyping {
            currentlyReportedTyping = false
            writeTypingStatus(isTyping: false)
        }
    }

    private func writeTypingStatus(isTyping: Bool) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let chatID = generateChatID(user1: currentUserID, user2: chatPartner.id)
        Firestore.firestore().collection("chats").document(chatID).setData([
            "typing": isTyping ? currentUserID : ""
        ], merge: true)
    }

    private func listenForTyping() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let chatID = generateChatID(user1: uid, user2: chatPartner.id)

        typingListener = Firestore.firestore().collection("chats").document(chatID)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let typingUserID = data["typing"] as? String else { return }

                let partnerIsTyping = typingUserID == chatPartner.id
                withAnimation {
                    isPartnerTyping = partnerIsTyping
                    if partnerIsTyping {
                        startTypingAnimation()
                    } else {
                        typingText = ""
                    }
                }
            }
    }

    private func startTypingAnimation() {
        let typingMessages = ["", ".", "..", "..."]
        var counter = 0
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if isPartnerTyping {
                typingText = typingMessages[counter % 4]
                counter += 1
            } else {
                timer.invalidate()
                typingText = ""
            }
        }
    }

    private func fetchMessages() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let chatID = generateChatID(user1: currentUserID, user2: chatPartner.id)

        listener = Firestore.firestore().collection("chats")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥 Error fetching messages: \(error.localizedDescription)")
                    return
                }

                if let documents = snapshot?.documents {
                    messages = documents.compactMap { doc -> Message? in
                        let data = doc.data()
                        return Message(id: doc.documentID, data: data)
                    }
                }
            }
    }

    private func sendMessage() {
        guard let currentUserID = Auth.auth().currentUser?.uid, !newMessage.isEmpty else { return }
        let chatID = generateChatID(user1: currentUserID, user2: chatPartner.id)
        let text = newMessage
        newMessage = ""

        // Cancel the debounce — sending the message clears the typing state
        typingDebounceTask?.cancel()
        if currentlyReportedTyping {
            currentlyReportedTyping = false
            writeTypingStatus(isTyping: false)
        }

        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "receiverID": chatPartner.id,
            "text": text,
            "timestamp": Timestamp(),
            "readBy": [currentUserID]
        ]

        Firestore.firestore().collection("chats")
            .document(chatID)
            .collection("messages")
            .addDocument(data: messageData)
    }

    private func markLatestMessageRead() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let chatID = generateChatID(user1: currentUserID, user2: chatPartner.id)

        Firestore.firestore()
            .collection("chats")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snap, _ in
                guard let doc = snap?.documents.first,
                      let senderID = doc.data()["senderID"] as? String,
                      senderID != currentUserID else { return }
                doc.reference.updateData(["readBy": FieldValue.arrayUnion([currentUserID])])
            }
    }

    private func generateChatID(user1: String, user2: String) -> String {
        return [user1, user2].sorted().joined(separator: "_")
    }
}

struct Message: Identifiable {
    let id: String
    let senderID: String
    let receiverID: String
    let text: String
    let timestamp: Timestamp

    init?(id: String, data: [String: Any]) {
        guard let senderID = data["senderID"] as? String,
              let receiverID = data["receiverID"] as? String,
              let text = data["text"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else { return nil }

        self.id = id
        self.senderID = senderID
        self.receiverID = receiverID
        self.text = text
        self.timestamp = timestamp
    }
}
