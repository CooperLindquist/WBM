import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct LikesView: View {
    @Binding var likesCount: Int
    @State private var likedUsers: [User] = []
    @State private var selectedUser: User? = nil
    @State private var isLoading = true

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading Likes...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if likedUsers.isEmpty {
                Text("No one has liked you yet!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
            } else {
                VStack(alignment: .leading) {
                    Text("Likes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(likedUsers) { user in
                                Button(action: { selectedUser = user }) {
                                    ProfilePreviewTile(user: user)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        fetchLikedUsers()
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedUser) { user in
            ProfileFeedDetailCover(
                user: user,
                onClose: { selectedUser = nil },
                onSkip: { skipUser($0); selectedUser = nil },
                onApprove: { approveUser($0); selectedUser = nil }
            )
        }
        .onAppear(perform: fetchLikedUsers)
    }

    // Fetch the users who have liked the current user
    private func fetchLikedUsers() {
        isLoading = true
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        Firestore.firestore().collection("users").document(currentUserID).getDocument { document, error in
            if let error = error {
                print("Error fetching likes: \(error.localizedDescription)")
                isLoading = false
                return
            }

            guard let data = document?.data(),
                  let likedUserIDs = data["likes"] as? [String],
                  !likedUserIDs.isEmpty else {
                likedUsers = []
                likesCount = 0
                isLoading = false
                return
            }
            likesCount = likedUserIDs.count

            Firestore.firestore().collection("users").whereField(FieldPath.documentID(), in: likedUserIDs).getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching liked users: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    likedUsers = documents.compactMap { doc -> User? in
                        let data = doc.data()
                        return User(id: doc.documentID, data: data)
                    }
                }
                isLoading = false
            }
        }
    }

    // Skip User: removes them from my received-likes, and records the skip
    // in the swipedUsers subcollection (not a legacy array — see HomePageView).
    private func skipUser(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let myRef = Firestore.firestore().collection("users").document(currentUserID)

        myRef.updateData([
            "likes": FieldValue.arrayRemove([user.id])
        ]) { error in
            if let error = error {
                print("Error updating skipped user: \(error.localizedDescription)")
            } else {
                likedUsers.removeAll { $0.id == user.id }
            }
        }

        myRef.collection("swipedUsers").document(user.id)
            .setData(["swipedAt": Timestamp(date: Date())]) { error in
                if let error = error {
                    print("Error recording swipe: \(error.localizedDescription)")
                }
            }
    }

    // Approve User: Adds user to "matches" if both have liked each other
    private func approveUser(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)
        let likedUserRef = Firestore.firestore().collection("users").document(user.id)

        Firestore.firestore().runTransaction { transaction, errorPointer in
            let currentUserDoc: DocumentSnapshot
            let likedUserDoc: DocumentSnapshot

            do {
                try currentUserDoc = transaction.getDocument(currentUserRef)
                try likedUserDoc = transaction.getDocument(likedUserRef)
            } catch {
                print("❌ Error fetching user documents: \(error.localizedDescription)")
                return nil
            }

            // My own `likes` array holds the IDs of people who liked ME.
            let myLikesReceived = currentUserDoc.data()?["likes"] as? [String] ?? []

            var currentUserMatches = currentUserDoc.data()?["matches"] as? [String] ?? []
            var likedUserMatches = likedUserDoc.data()?["matches"] as? [String] ?? []

            // Mutual if `user` already appears in my own likes-received list.
            let isMutualLike = myLikesReceived.contains(user.id)

            if isMutualLike {
                // If mutual, add to matches
                if !currentUserMatches.contains(user.id) {
                    currentUserMatches.append(user.id)
                }
                if !likedUserMatches.contains(currentUserID) {
                    likedUserMatches.append(currentUserID)
                }

                // Update Firestore
                transaction.updateData([
                    "matches": currentUserMatches,
                    "likes": FieldValue.arrayRemove([user.id])
                ], forDocument: currentUserRef)

                transaction.updateData([
                    "matches": likedUserMatches,
                    "likes": FieldValue.arrayRemove([currentUserID])
                ], forDocument: likedUserRef)

                print("✅ Match created between \(currentUserID) and \(user.id)!")
            } else {
                // Fix: my like goes onto THEIR document (their `likes` = who liked them),
                // not onto my own document.
                transaction.updateData([
                    "likes": FieldValue.arrayUnion([currentUserID])
                ], forDocument: likedUserRef)

                print("👍 Liked \(user.id), waiting for them to like back.")
            }

            return nil
        } completion: { _, error in
            if let error = error {
                print("❌ Error processing like: \(error.localizedDescription)")
            } else {
                likedUsers.removeAll { $0.id == user.id } // Remove from UI
            }
        }
    }

}
