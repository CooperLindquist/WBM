//
//  ChatView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/5/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ChatView: View {
    let chatPartner: User
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var listener: ListenerRegistration? = nil
    @State private var showingRateUserView = false


    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

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
        .navigationTitle(chatPartner.name)
        .onAppear(perform: fetchMessages)
        .onDisappear {
            listener?.remove()
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

        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "receiverID": chatPartner.id,
            "text": newMessage,
            "timestamp": Timestamp()
        ]

        Firestore.firestore().collection("chats")
            .document(chatID)
            .collection("messages")
            .addDocument(data: messageData)

        newMessage = ""
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
