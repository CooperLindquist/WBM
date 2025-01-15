//
//  SpotlightView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/7/25.
//

// Add Spotlight functionality to Firestore and design SpotlightView UI
import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

// Update Firestore structure:
// 1. Add a 'spotlightsRemaining' field to the users collection
// 2. Create a new collection 'Spotlight' to manage spotlighted users

// Function to give users one spotlight per month
func allocateMonthlySpotlights() {
    let usersRef = Firestore.firestore().collection("users")

    usersRef.getDocuments { snapshot, error in
        if let error = error {
            print("Error fetching users: \(error.localizedDescription)")
            return
        }

        guard let documents = snapshot?.documents else { return }

        for document in documents {
            let userRef = usersRef.document(document.documentID)
            userRef.updateData(["spotlightsRemaining": FieldValue.increment(Int64(1))]) { error in
                if let error = error {
                    print("Error allocating spotlight to user: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Function to add a user to SpotlightView
func addToSpotlight(userID: String, additionalDuration: TimeInterval = 18000) {
    let spotlightRef = Firestore.firestore().collection("Spotlight").document(userID)

    spotlightRef.getDocument { document, error in
        if let error = error {
            print("Error checking spotlight document: \(error.localizedDescription)")
            return
        }

        let currentExpiration: Date
        if let data = document?.data(), let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() {
            // Extend the existing expiration time
            currentExpiration = max(expiresAt, Date())
        } else {
            // Start from the current time if not already in spotlight
            currentExpiration = Date()
        }

        let newExpiration = currentExpiration.addingTimeInterval(additionalDuration)
        spotlightRef.setData(["userID": userID, "expiresAt": newExpiration]) { error in
            if let error = error {
                print("Error adding user to Spotlight: \(error.localizedDescription)")
            }
        }

        // Update the user's spotlight count
        let userRef = Firestore.firestore().collection("users").document(userID)
        userRef.updateData(["spotlightsRemaining": FieldValue.increment(Int64(-1))]) { error in
            if let error = error {
                print("Error decrementing user's spotlights: \(error.localizedDescription)")
            }
        }
    }
}


// Function to check if a user is currently spotlighted
func fetchSpotlightedUsers(completion: @escaping ([String]) -> Void) {
    let spotlightRef = Firestore.firestore().collection("Spotlight")

    spotlightRef.getDocuments { snapshot, error in
        if let error = error {
            print("Error fetching spotlighted users: \(error.localizedDescription)")
            completion([])
            return
        }

        let activeUsers = snapshot?.documents.compactMap { doc -> String? in
            guard let expiresAt = (doc["expiresAt"] as? Timestamp)?.dateValue() else { return nil }
            return expiresAt > Date() ? doc.documentID : nil
        } ?? []

        completion(activeUsers)
    }
}

// SpotlightView UI
struct SpotlightView: View {
    @State private var spotlightedUsers: [User] = []
    @State private var isLoading = true
    @State private var spotlightsRemaining: Int = 0
    @State private var selectedUser: User?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Text("Spotlights Remaining: \(spotlightsRemaining)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        .padding(.top, 20)
                }

                Button(action: useSpotlight) {
                    Text("Use Spotlight")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(spotlightsRemaining > 0 ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(spotlightsRemaining == 0)

                if isLoading {
                    ProgressView("Loading Spotlighted Users...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if spotlightedUsers.isEmpty {
                    Text("No users in Spotlight right now!")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(spotlightedUsers, id: \.id) { user in
                                SpotlightCardView(user: user)
                                    .onTapGesture {
                                        selectedUser = user
                                    }
                                    .frame(width: 350)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(radius: 5)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
        }
        .onAppear(perform: loadSpotlightedUsersAndCount)
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

                UserCardView(user: user)
                    .frame(width: 350, height: 500)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(.top, 30)

                Spacer()
                
                // 🆕 Skip & Like Buttons
                HStack {
                    Button(action: { skipUser(user: user) }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 40)

                    Button(action: { approveUser(user: user) }) {
                        Image(systemName: "heart.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 30)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            )
        }

    }

    private func useSpotlight() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        if spotlightsRemaining > 0 {
            addToSpotlight(userID: currentUserID)
            spotlightsRemaining -= 1
            loadSpotlightedUsersAndCount() // Refresh the page
        } else {
            print("No spotlights remaining.")
        }
    }


    private func loadSpotlightedUsersAndCount() {
        isLoading = true
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)

        currentUserRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                isLoading = false
                return
            }

            guard let data = document?.data() else {
                isLoading = false
                return
            }

            let swipedUsers = data["swipedUsers"] as? [String] ?? []
            let likedUsers = data["likes"] as? [String] ?? []
            let matchedUsers = data["matches"] as? [String] ?? []
            let excludedUserIDs = Set(swipedUsers + likedUsers + matchedUsers)

            fetchSpotlightedUsers { userIds in
                let filteredUserIds = userIds.filter { !excludedUserIDs.contains($0) }

                guard !filteredUserIds.isEmpty else {
                    DispatchQueue.main.async {
                        self.spotlightedUsers = []
                        self.isLoading = false
                    }
                    return
                }

                let usersRef = Firestore.firestore().collection("users")
                usersRef.whereField(FieldPath.documentID(), in: filteredUserIds).getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching spotlighted user data: \(error.localizedDescription)")
                        isLoading = false
                        return
                    }

                    spotlightedUsers = snapshot?.documents.compactMap { doc -> User? in
                        return User(id: doc.documentID, data: doc.data())
                    } ?? []

                    isLoading = false
                }
            }

            if let count = data["spotlightsRemaining"] as? Int {
                DispatchQueue.main.async {
                    self.spotlightsRemaining = count
                }
            }
        }
    }

    private func skipUser(user: User) {
        spotlightedUsers.removeAll { $0.id == user.id }
        selectedUser = nil
    }

    private func approveUser(user: User) {
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

            let currentUserLikes = currentUserDoc.data()?["likes"] as? [String] ?? []
            let likedUserLikes = likedUserDoc.data()?["likes"] as? [String] ?? []
            var currentUserMatches = currentUserDoc.data()?["matches"] as? [String] ?? []
            var likedUserMatches = likedUserDoc.data()?["matches"] as? [String] ?? []

            let isMutualLike = currentUserLikes.contains(user.id)

            if isMutualLike {
                if !currentUserMatches.contains(user.id) {
                    currentUserMatches.append(user.id)
                }
                if !likedUserMatches.contains(currentUserID) {
                    likedUserMatches.append(currentUserID)
                }

                transaction.updateData(["matches": currentUserMatches, "likes": FieldValue.arrayRemove([user.id])], forDocument: currentUserRef)
                transaction.updateData(["matches": likedUserMatches, "likes": FieldValue.arrayRemove([currentUserID])], forDocument: likedUserRef)

                print("✅ Match created between \(currentUserID) and \(user.id)!")
            } else {
                transaction.updateData(["likes": FieldValue.arrayUnion([user.id])], forDocument: currentUserRef)
                print("👍 Liked \(user.id), waiting for them to like back.")
            }

            return nil
        } completion: { _, error in
            if let error = error {
                print("❌ Error processing like: \(error.localizedDescription)")
            } else {
                spotlightedUsers.removeAll { $0.id == user.id }
                selectedUser = nil
            }
        }
    }
}




// SpotlightCardView
struct SpotlightCardView: View {
    let user: User

    var body: some View {
        VStack(spacing: 20) {
            WebImage(url: URL(string: user.imageURLs.first ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 300, height: 300)
                .clipShape(Circle())
                .shadow(radius: 10)

            Text(user.name)
                .font(.title)
                .fontWeight(.bold)

            if let bio = user.bio {
                Text(bio)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
        }
    }
}




#Preview {
    SpotlightView()
}
