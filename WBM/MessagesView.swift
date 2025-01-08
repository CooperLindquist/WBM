import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct MessagesView: View {
    @State private var matchedUsers: [User] = []
    @State private var isLoading = true
    @State private var selectedUser: User? = nil
    @State private var recentMessages: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                if isLoading {
                    ProgressView("Loading Matches...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.white)
                }
                else if matchedUsers.isEmpty {
                    Text("No matches yet!")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
                else {
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

                                            Text(recentMessages[user.id] ?? "Tap to chat")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear(perform: fetchMatchedUsers)
            .navigationDestination(for: User.self) { user in
                ChatView(chatPartner: user)
            }
            .navigationTitle("Messages")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func fetchMatchedUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        let userDoc = Firestore.firestore().collection("users").document(currentUserID)
        userDoc.getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching matches: \(error.localizedDescription)")
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
                        print("🔥 Error fetching matched users: \(error.localizedDescription)")
                    } else if let documents = snapshot?.documents {
                        matchedUsers = documents.compactMap { doc -> User? in
                            let data = doc.data()
                            return User(id: doc.documentID, data: data)
                        }
                        fetchRecentMessages(for: matchIDs)
                    }
                    isLoading = false
                }
        }
    }

    private func fetchRecentMessages(for matchIDs: [String]) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        for matchID in matchIDs {
            let chatID = [currentUserID, matchID].sorted().joined(separator: "_")
            Firestore.firestore().collection("chats")
                .document(chatID)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("🔥 Error fetching recent message: \(error.localizedDescription)")
                    } else if let document = snapshot?.documents.first {
                        recentMessages[matchID] = document.data()["text"] as? String
                    }
                }
        }
    }
}

#Preview {
    MessagesView()
}
