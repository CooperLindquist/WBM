import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct HomePageView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var users: [User] = []
    @State private var currentIndex: Int = 0
    @State private var excludedUsers: Set<String> = []
    @State private var isLoading = true
    @State private var showFilterSheet = false
    @State private var filters: Filters = Filters.loadFilters()
    @State private var diamonds: Int = 0
    @State private var showDiamondStore = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading Users...")
            } else if users.isEmpty {
                VStack(spacing: 16) {
                    Text("No more users available!")
                        .font(.title3)
                        .foregroundColor(.white)

                    Button {
                        resetSwipes()
                    } label: {
                        Text("Reset Swipes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
            }
            else {
                // Hinge-style scrollable profile feed. Each person's full profile
                // scrolls vertically; swiping horizontally pages to the next person
                // with a native page-turn animation.
                ProfileFeedView(
                    users: users,
                    canApprove: diamonds >= 10,
                    currentUserLocation: locationManager.userLocation,
                    onApprove: { user in approveUser(user) },
                    onSkip: { user in skipUser(user) },
                    currentIndex: $currentIndex
                )
            }
            
         
           

        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()

                Button {
                    showDiamondStore = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundColor(.yellow)
                        Text("\(diamonds)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                }

                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.top, 6)
        }

        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(filters: $filters, applyFilters: applyFilters)
        }
        .sheet(isPresented: $showDiamondStore) {
            DiamondStoreView()
        }
        .onAppear {
            loadExcludedUsersAndFetchUsers()
        }
    }
// Resets only people the user skipped or unliked — never touches matches,
    // since those are active conversations and shouldn't reappear in the swipe stack.
    private func resetSwipes() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(currentUserID)

        currentIndex = 0
        users.removeAll()

        // Delete every doc in the swipedUsers subcollection (skips)
        userRef.collection("swipedUsers").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching swiped users to reset: \(error.localizedDescription)")
                return
            }

            let batch = Firestore.firestore().batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }

            batch.commit { error in
                if let error = error {
                    print("Error resetting swipes: \(error.localizedDescription)")
                    return
                }

                // Clear likes (one-sided likes you sent that never matched) —
                // matches are intentionally left untouched.
                userRef.updateData(["likes": []]) { error in
                    if let error = error {
                        print("Error clearing likes during reset: \(error.localizedDescription)")
                    }
                    // Rebuild excludedUsers properly (will now just contain matches)
                    // then fetch a fresh stack.
                    loadExcludedUsersAndFetchUsers()
                }
            }
        }
    }



    
    private func loadExcludedUsersAndFetchUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        let userDoc = Firestore.firestore().collection("users").document(currentUserID)

        userDoc.getDocument { document, error in
            if let error = error {
                print("Error fetching excluded users: \(error.localizedDescription)")
                isLoading = false
                return
            }

            if let data = document?.data() {
                let liked   = data["likes"]   as? [String] ?? []
                let matched = data["matches"] as? [String] ?? []
                self.excludedUsers = Set(liked + matched)
                // Fix #9: read diamonds here — same doc, no extra Firestore read needed
                if let d = data["diamonds"] as? Int { self.diamonds = d }
            }

            userDoc.updateData(["lastActive": Timestamp(date: Date())])

            // Fix #2: load swiped users from subcollection before fetching candidates
            userDoc.collection("swipedUsers").getDocuments { snap, _ in
                let swiped = snap?.documents.map { $0.documentID } ?? []
                self.excludedUsers.formUnion(swiped)
                fetchUsers()
            }
        }
    }

    // MARK: - Paginated + Scored Fetch
    // Fetches up to `pageSize` users at a time. Called again automatically
    // when the stack drops to `refetchThreshold` cards.

    private let pageSize = 20
    private let refetchThreshold = 5

    private func fetchUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // Fetch active spotlights first so we can boost them in scoring
        fetchSpotlightedIDs { spotlightedIDs in
            var query: Query = Firestore.firestore()
                .collection("users")
                .limit(to: self.pageSize)

            Firestore.firestore().collection("users")
                .limit(to: self.pageSize)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching users: \(error.localizedDescription)")
                        self.isLoading = false
                        return
                    }

                    let currentLocation = self.locationManager.userLocation

                    let fetched: [User] = snapshot?.documents.compactMap { doc in
                        guard doc.documentID != currentUserID else { return nil }
                        guard !self.excludedUsers.contains(doc.documentID) else { return nil }
                        guard let user = User(id: doc.documentID, data: doc.data()) else { return nil }

                        // Apply filters (distance, weight, height, etc.)
                        guard self.filters.matches(user: user, currentLocation: currentLocation) else { return nil }

                        return user
                    } ?? []

                    // Score and rank the candidates
                    let ranked = SwipeAlgorithm.rank(fetched, spotlightedIDs: spotlightedIDs)

                    DispatchQueue.main.async {
                        // Avoid duplicates if called while cards are still in stack
                        let existingIDs = Set(self.users.map { $0.id })
                        let newUsers = ranked.filter { !existingIDs.contains($0.id) }
                        self.users.append(contentsOf: newUsers)
                        self.isLoading = false
                    }
                }
        }
    }

    /// Fetch currently active spotlight user IDs from Firestore
    private func fetchSpotlightedIDs(completion: @escaping (Set<String>) -> Void) {
        Firestore.firestore().collection("Spotlight").getDocuments { snapshot, _ in
            let ids: Set<String> = Set(
                snapshot?.documents.compactMap { doc -> String? in
                    guard let expiresAt = (doc.data()["expiresAt"] as? Timestamp)?.dateValue(),
                          expiresAt > Date() else { return nil }
                    return doc.documentID
                } ?? []
            )
            completion(ids)
        }
    }
    
    
    
    private func applyFilters() {
        filters.saveFilters()
        fetchUsers()
        showFilterSheet = false  // Close the filter sheet
    }
    
    /// Removes a person from the feed by id. Using id (not array position)
    /// because in the page-feed model the user could be liked/passed from
    /// any page, not just "the top of a stack."
    private func removeFromFeed(_ user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        users.remove(at: index)
        // Keep currentIndex in bounds so TabView doesn't point past the end
        if currentIndex >= users.count {
            currentIndex = max(0, users.count - 1)
        }
        refetchIfNeeded()
    }

    /// Silently fetch more people when the feed is running low
    private func refetchIfNeeded() {
        guard users.count <= refetchThreshold, !isLoading else { return }
        fetchUsers()
    }

    private func skipUser(_ user: User) {
        updateExcludedUsers(user.id)
        removeFromFeed(user)
    }

    private func approveUser(_ user: User) {
        guard diamonds >= 10 else { return } // Ensure the user has enough diamonds
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // Deduct 10 diamonds in the state immediately
        diamonds -= 10

        // Update Firestore asynchronously
        Firestore.firestore().collection("users").document(currentUserID).updateData([
            "diamonds": diamonds
        ]) { error in
            if let error = error {
                print("Error deducting diamonds: \(error.localizedDescription)")
            }
        }

        Firestore.firestore().collection("users").document(user.id).updateData([
            "likes": FieldValue.arrayUnion([currentUserID])
        ]) { error in
            if let error = error {
                print("Error adding like: \(error.localizedDescription)")
            }
        }

        updateExcludedUsers(user.id)
        removeFromFeed(user)
    }

    private func updateExcludedUsers(_ userID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        excludedUsers.insert(userID)

        // Fix #2: write to subcollection instead of array on the user doc.
        // Arrays grow forever and Firestore docs have a 1MB limit.
        // Subcollection entries are tiny and scale to millions of swipes.
        Firestore.firestore()
            .collection("users")
            .document(currentUserID)
            .collection("swipedUsers")
            .document(userID)
            .setData(["swipedAt": Timestamp(date: Date())]) { error in
                if let error = error {
                    print("Error recording swipe: \(error.localizedDescription)")
                }
            }
    }
}
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    HomePageView()
}
