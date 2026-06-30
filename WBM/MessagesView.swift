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

        // COST OPTIMIZATION: the chat doc now carries an `unreadBy` array directly,
        // so marking as read is one write to a field we already have — no more
        // querying the messages subcollection just to find the latest message.
        Firestore.firestore().collection("chats").document(chatID).updateData([
            "unreadBy": FieldValue.arrayRemove([uid])
        ])
        unreadChats.remove(userID)
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

            // Firestore's `in` operator caps at 30 values, so chunk for users with
            // a large number of matches rather than silently dropping the overflow.
            let chunks = stride(from: 0, to: matchIDs.count, by: 30).map {
                Array(matchIDs[$0..<min($0 + 30, matchIDs.count)])
            }
            let group = DispatchGroup()
            var allUsers: [User] = []
            let lock = NSLock()

            for chunk in chunks {
                group.enter()
                Firestore.firestore().collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching matched users: \(error.localizedDescription)")
                        } else if let documents = snapshot?.documents {
                            let users = documents.compactMap { doc -> User? in
                                User(id: doc.documentID, data: doc.data())
                            }
                            lock.lock()
                            allUsers.append(contentsOf: users)
                            lock.unlock()
                        }
                        group.leave()
                    }
            }

            group.notify(queue: .main) {
                matchedUsers = allUsers
                fetchRecentMessages(currentUserID: currentUserID)
                isLoading = false
            }
        }
    }

    /// COST OPTIMIZATION: previously this ran ONE query per match to fetch each
    /// chat's most recent message (N reads for N matches, repeated every time this
    /// screen opens). Now that `lastMessageText`/`lastMessageSenderID`/`unreadBy`
    /// are denormalized onto the parent chat doc (written once at send-time in
    /// ChatView), we can get the same information for every chat the user is in
    /// with a single `whereField("participants", arrayContains:)` query.
    private func fetchRecentMessages(currentUserID: String) {
        Firestore.firestore().collection("chats")
            .whereField("participants", arrayContains: currentUserID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching chat summaries: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                var newRecentMessages: [String: String] = [:]
                var newUnreadChats: Set<String> = []

                for doc in documents {
                    let data = doc.data()
                    guard let participants = data["participants"] as? [String],
                          let otherUserID = participants.first(where: { $0 != currentUserID }) else {
                        continue
                    }

                    if let text = data["lastMessageText"] as? String {
                        newRecentMessages[otherUserID] = text
                    }

                    let unreadBy = data["unreadBy"] as? [String] ?? []
                    if unreadBy.contains(currentUserID) {
                        newUnreadChats.insert(otherUserID)
                    }
                }

                DispatchQueue.main.async {
                    recentMessages = newRecentMessages
                    unreadChats = newUnreadChats
                }
            }
    }
}

#Preview {
    MessagesView(unreadCount: .constant(0))
}
