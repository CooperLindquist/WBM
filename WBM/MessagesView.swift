import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct MessagesView: View {
    @Binding var unreadCount: Int
    @State private var matchedUsers: [User] = []
    @State private var isLoading = true
    @State private var selectedUser: User? = nil
    @State private var recentMessages: [String: String] = [:]
    @State private var unreadChats: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Matches...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.white)
                } else if matchedUsers.isEmpty {
                    Text("No matches yet!")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(matchedUsers) { user in
                                NavigationLink(value: user) {
                                    HStack(spacing: 15) {
                                        WebImage(url: URL(string: user.imageURLs.first ?? ""))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(user.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                // Bold name if there's an unread message
                                                .fontWeight(unreadChats.contains(user.id) ? .bold : .regular)

                                            Text(recentMessages[user.id] ?? "Tap to chat")
                                                .font(.subheadline)
                                                .foregroundColor(unreadChats.contains(user.id) ? .white : .white.opacity(0.8))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        // Unread dot indicator
                                        if unreadChats.contains(user.id) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 12, height: 12)
                                        }

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(
                                        unreadChats.contains(user.id)
                                            ? Color.white.opacity(0.3)
                                            : Color.white.opacity(0.2)
                                    )
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                fetchMatchedUsers()
                unreadCount = 0 // Clear badge when this view appears
                NotificationManager.shared.clearBadge()
            }
            .navigationDestination(for: User.self) { user in
                ChatView(chatPartner: user)
                    .onAppear { markAsRead(userID: user.id) }
            }
            .navigationTitle("Messages")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Mark as Read

    private func markAsRead(userID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let chatID = [uid, userID].sorted().joined(separator: "_")

        // Get the latest message and add current user to its readBy array
        Firestore.firestore()
            .collection("chats")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snap, _ in
                guard let doc = snap?.documents.first else { return }
                doc.reference.updateData([
                    "readBy": FieldValue.arrayUnion([uid])
                ])
                DispatchQueue.main.async {
                    unreadChats.remove(userID)
                }
            }
    }

    // MARK: - Fetch

    private func fetchMatchedUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        let userDoc = Firestore.firestore().collection("users").document(currentUserID)
        userDoc.getDocument { document, error in
            if let error = error {
                print("Error fetching matches: \(error.localizedDescription)")
                isLoading = false
                return
            }

            guard let data = document?.data(),
                  let matchIDs = data["matches"] as? [String],
                  !matchIDs.isEmpty else {
                matchedUsers = []
                isLoading = false
                return
            }

            Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: matchIDs)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching matched users: \(error.localizedDescription)")
                    } else if let documents = snapshot?.documents {
                        matchedUsers = documents.compactMap { doc -> User? in
                            return User(id: doc.documentID, data: doc.data())
                        }
                        fetchRecentMessages(for: matchIDs, currentUserID: currentUserID)
                    }
                    isLoading = false
                }
        }
    }

    private func fetchRecentMessages(for matchIDs: [String], currentUserID: String) {
        for matchID in matchIDs {
            let chatID = [currentUserID, matchID].sorted().joined(separator: "_")
            Firestore.firestore().collection("chats")
                .document(chatID)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments { snapshot, _ in
                    guard let doc = snapshot?.documents.first else { return }
                    let data = doc.data()
                    let text       = data["text"]     as? String   ?? ""
                    let senderID   = data["senderID"] as? String   ?? ""
                    let readBy     = data["readBy"]   as? [String] ?? []

                    DispatchQueue.main.async {
                        recentMessages[matchID] = text

                        // Mark as unread if the last message is from the other person and we haven't read it
                        if senderID != currentUserID && !readBy.contains(currentUserID) {
                            unreadChats.insert(matchID)
                        }
                    }
                }
        }
    }
}

#Preview {
    MessagesView(unreadCount: .constant(0))
}
