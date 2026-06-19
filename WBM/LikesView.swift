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
        NavigationView {
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
                    VStack {
                        Text("Likes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                            .offset(x: -150, y: -65)

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                ForEach(likedUsers) { user in
                                    Button(action: {
                                        selectedUser = user
                                    }) {
                                        VStack {
                                            WebImage(url: URL(string: user.imageURLs.first ?? ""))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 150, height: 150)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            Text(user.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(10)
                                        .shadow(radius: 5)
                                    }
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
                VStack {
                    HStack {
                        Button(action: { selectedUser = nil }) {
                            Image(systemName: "chevron.backward")
                                .font(.title2)
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.8)))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    Spacer()

                    UserCardView(
                        user: user,
                        onSkip: {
                            skipUser(user)
                            selectedUser = nil
                        },
                        onApprove: {
                            approveUser(user)
                            selectedUser = nil
                        }
                    )
                    .frame(width: 350, height: 500)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(.top, 30)

                    Spacer()

                    // Skip & Approve Buttons
                    HStack(spacing: 30) {
                        Button(action: { skipUser(user) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.red)
                        }

                        Button(action: { approveUser(user) }) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            .onAppear(perform: fetchLikedUsers)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

    // Skip User: Removes user from "likes" and adds to "swipedUsers"
    private func skipUser(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(currentUserID).updateData([
            "likes": FieldValue.arrayRemove([user.id]),
            "swipedUsers": FieldValue.arrayUnion([user.id])
        ]) { error in
            if let error = error {
                print("Error updating skipped user: \(error.localizedDescription)")
            } else {
                likedUsers.removeAll { $0.id == user.id }
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

            // Get current user's likes (who liked them)
            let currentUserLikes = currentUserDoc.data()?["likes"] as? [String] ?? []
            // Get liked user's likes (who they liked)
            let likedUserLikes = likedUserDoc.data()?["likes"] as? [String] ?? []

            var currentUserMatches = currentUserDoc.data()?["matches"] as? [String] ?? []
            var likedUserMatches = likedUserDoc.data()?["matches"] as? [String] ?? []

            // Check if mutual match: If the liked user (user.id) is in my likes list
            let isMutualLike = currentUserLikes.contains(user.id)

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
                // If not mutual, just store the like
                transaction.updateData([
                    "likes": FieldValue.arrayUnion([user.id])
                ], forDocument: currentUserRef)

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


