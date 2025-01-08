////
////  SpotlightView.swift
////  WBM
////
////  Created by Cooper Lindquist on 1/7/25.
////
//
//// Add Spotlight functionality to Firestore and design SpotlightView UI
//import SwiftUI
//import Firebase
//import SDWebImageSwiftUI
//import FirebaseAuth
//
//// Update Firestore structure:
//// 1. Add a 'spotlightsRemaining' field to the users collection
//// 2. Create a new collection 'Spotlight' to manage spotlighted users
//
//// Function to give users one spotlight per month
//func allocateMonthlySpotlights() {
//    let usersRef = Firestore.firestore().collection("users")
//
//    usersRef.getDocuments { snapshot, error in
//        if let error = error {
//            print("Error fetching users: \(error.localizedDescription)")
//            return
//        }
//
//        guard let documents = snapshot?.documents else { return }
//
//        for document in documents {
//            let userRef = usersRef.document(document.documentID)
//            userRef.updateData(["spotlightsRemaining": FieldValue.increment(Int64(1))]) { error in
//                if let error = error {
//                    print("Error allocating spotlight to user: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//}
//
//// Function to add a user to SpotlightView
//func addToSpotlight(userID: String, additionalDuration: TimeInterval = 18000) {
//    let spotlightRef = Firestore.firestore().collection("Spotlight").document(userID)
//
//    spotlightRef.getDocument { document, error in
//        if let error = error {
//            print("Error checking spotlight document: \(error.localizedDescription)")
//            return
//        }
//
//        let currentExpiration: Date
//        if let data = document?.data(), let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() {
//            // Extend the existing expiration time
//            currentExpiration = max(expiresAt, Date())
//        } else {
//            // Start from the current time if not already in spotlight
//            currentExpiration = Date()
//        }
//
//        let newExpiration = currentExpiration.addingTimeInterval(additionalDuration)
//        spotlightRef.setData(["userID": userID, "expiresAt": newExpiration]) { error in
//            if let error = error {
//                print("Error adding user to Spotlight: \(error.localizedDescription)")
//            }
//        }
//
//        // Update the user's spotlight count
//        let userRef = Firestore.firestore().collection("users").document(userID)
//        userRef.updateData(["spotlightsRemaining": FieldValue.increment(Int64(-1))]) { error in
//            if let error = error {
//                print("Error decrementing user's spotlights: \(error.localizedDescription)")
//            }
//        }
//    }
//}
//
//
//
//// Function to check if a user is currently spotlighted
//func fetchSpotlightedUsers(completion: @escaping ([(String, TimeInterval)]) -> Void) {
//    let spotlightRef = Firestore.firestore().collection("Spotlight")
//
//    spotlightRef.getDocuments { snapshot, error in
//        if let error = error {
//            print("Error fetching spotlighted users: \(error.localizedDescription)")
//            completion([])
//            return
//        }
//
//        let activeUsers = snapshot?.documents.compactMap { doc -> (String, TimeInterval)? in
//            guard let expiresAt = (doc["expiresAt"] as? Timestamp)?.dateValue() else { return nil }
//            let timeRemaining = expiresAt.timeIntervalSince(Date())
//            return timeRemaining > 0 ? (doc.documentID, timeRemaining) : nil
//        } ?? []
//
//        completion(activeUsers)
//    }
//}
//
//
//// SpotlightView UI
//struct SpotlightView: View {
//    @State private var spotlightedUsers: [User] = []
//    @State private var isLoading = true
//    @State private var spotlightsRemaining: Int = 0
//    @State private var selectedUser: User? // To track the selected user
//
//    var body: some View {
//        ZStack {
//            LinearGradient(
//                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .edgesIgnoringSafeArea(.all)
//
//            VStack {
//                HStack {
//                    Text("Spotlights Remaining: \(spotlightsRemaining)")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(
//                            Capsule()
//                                .fill(Color.white.opacity(0.2))
//                        )
//                        .padding(.top, 20)
//                }
//
//                if isLoading {
//                    ProgressView("Loading Spotlighted Users...")
//                        .progressViewStyle(CircularProgressViewStyle())
//                } else if spotlightedUsers.isEmpty {
//                    Text("No users in Spotlight right now!")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                } else {
//                    ScrollView {
//                        VStack(spacing: 20) {
//                            ForEach(spotlightedUsers, id: \.id) { user in
//                                SpotlightCardView(user: user)
//                                    .onTapGesture {
//                                        selectedUser = user // Set the selected user when tapped
//                                    }
//                                    .frame(width: 350)
//                                    .padding()
//                                    .background(Color.white)
//                                    .cornerRadius(20)
//                                    .shadow(radius: 5)
//                            }
//                        }
//                        .padding(.top, 20)
//                    }
//                }
//            }
//        }
//        .onAppear(perform: loadSpotlightedUsersAndCount)
//        .sheet(item: $selectedUser) { user in // Display the UserCardView as a sheet
//            UserCardView(user: user)
//        }
//    }
//
//    private func loadSpotlightedUsersAndCount() {
//        isLoading = true
//
//        fetchSpotlightedUsers { userIdsWithTime in
//            guard !userIdsWithTime.isEmpty else {
//                DispatchQueue.main.async {
//                    self.spotlightedUsers = []
//                    self.isLoading = false
//                }
//                return
//            }
//
//            let userIds = userIdsWithTime.map { $0.0 }
//            let timeRemainingMap = Dictionary(uniqueKeysWithValues: userIdsWithTime)
//
//            let usersRef = Firestore.firestore().collection("users")
//            usersRef.whereField(FieldPath.documentID(), in: userIds).getDocuments { snapshot, error in
//                if let error = error {
//                    print("Error fetching spotlighted user data: \(error.localizedDescription)")
//                    isLoading = false
//                    return
//                }
//
//                DispatchQueue.main.async {
//                    self.spotlightedUsers = snapshot?.documents.compactMap { doc -> User? in
//                        guard var user = User(id: doc.documentID, data: doc.data()) else { return nil }
//                        if let timeRemaining = timeRemainingMap[user.id] {
//                            user.timeRemaining = timeRemaining // Modify the local copy
//                        }
//                        return user // Return the modified copy
//                    } ?? []
//
//                    self.isLoading = false
//                }
//            }
//        }
//
//        // Load user's remaining spotlight count
//        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
//        Firestore.firestore().collection("users").document(currentUserID).getDocument { document, error in
//            if let error = error {
//                print("Error fetching user spotlight count: \(error.localizedDescription)")
//                return
//            }
//
//            if let data = document?.data(), let count = data["spotlightsRemaining"] as? Int {
//                DispatchQueue.main.async {
//                    self.spotlightsRemaining = count
//                }
//            }
//        }
//    }
//
//
//
//
//    private func useSpotlight() {
//        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
//        guard spotlightsRemaining > 0 else { return }
//
//        // Add current user to the Spotlight collection
//        addToSpotlight(userID: currentUserID)
//
//        // Decrease spotlight count locally
//        spotlightsRemaining -= 1
//    }
//}
//
//
//// SpotlightCardView
//struct SpotlightCardView: View {
//    let user: User
//
//    var body: some View {
//        VStack(spacing: 20) {
//            WebImage(url: URL(string: user.imageURLs.first ?? ""))
//                .resizable()
//                .scaledToFill()
//                .frame(width: 300, height: 300)
//                .clipShape(Circle())
//                .shadow(radius: 10)
//
//            Text(user.name)
//                .font(.title)
//                .fontWeight(.bold)
//
//            if let bio = user.bio {
//                Text(bio)
//                    .multilineTextAlignment(.center)
//                    .foregroundColor(.gray)
//            }
//
//            if let timeRemaining = user.timeRemaining {
//                Text("Time Remaining: \(formatTimeRemaining(timeRemaining))")
//                    .font(.headline)
//                    .foregroundColor(.blue)
//            }
//        }
//    }
//
//    private func formatTimeRemaining(_ time: TimeInterval) -> String {
//        let hours = Int(time) / 3600
//        let minutes = (Int(time) % 3600) / 60
//        return "\(hours)h \(minutes)m"
//    }
//}
//
//
//
//
//
//#Preview {
//    SpotlightView()
//}
