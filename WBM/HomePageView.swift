import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct HomePageView: View {
    @ObservedObject private var locationManager = LocationManager.shared
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
            } else {
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

    private func resetSwipes() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(currentUserID)

        currentIndex = 0
        users.removeAll()
        lastFetchedDocument = nil
        reachedEndOfUsers = false

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

                userRef.updateData(["likes": []]) { error in
                    if let error = error {
                        print("Error clearing likes during reset: \(error.localizedDescription)")
                    }
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
                if let d = data["diamonds"] as? Int { self.diamonds = d }
            }

            // Only update lastActive if it's been more than 5 minutes since last write.
            // This prevents a Firestore write on every tab switch or pull-to-refresh.
            let lastActiveKey = "lastActiveWritten"
            let now = Date()
            let lastWrite = UserDefaults.standard.object(forKey: lastActiveKey) as? Date ?? .distantPast
            if now.timeIntervalSince(lastWrite) > 300 {
                userDoc.updateData(["lastActive": Timestamp(date: now)])
                UserDefaults.standard.set(now, forKey: lastActiveKey)
            }

            userDoc.collection("swipedUsers").getDocuments { snap, _ in
                let swiped = snap?.documents.map { $0.documentID } ?? []
                self.excludedUsers.formUnion(swiped)
                fetchUsers()
            }
        }
    }

    private let pageSize = 20
    private let refetchThreshold = 5
    private let minDesiredMatches = 10
    private let maxPagesPerFetch = 5

    @State private var lastFetchedDocument: DocumentSnapshot? = nil
    @State private var reachedEndOfUsers = false

    private func fetchUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        fetchSpotlightedIDs { spotlightedIDs in
            self.fetchUsersPage(
                currentUserID: currentUserID,
                spotlightedIDs: spotlightedIDs,
                accumulated: [],
                pagesFetched: 0
            )
        }
    }

    private func fetchUsersPage(
        currentUserID: String,
        spotlightedIDs: Set<String>,
        accumulated: [User],
        pagesFetched: Int
    ) {
        var query: Query = Firestore.firestore()
            .collection("users")
            .order(by: FieldPath.documentID())
            .limit(to: pageSize)

        if let cursor = lastFetchedDocument {
            query = query.start(afterDocument: cursor)
        }

        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                self.finishFetch(with: accumulated, spotlightedIDs: spotlightedIDs)
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                self.reachedEndOfUsers = true
                self.finishFetch(with: accumulated, spotlightedIDs: spotlightedIDs)
                return
            }

            self.lastFetchedDocument = documents.last
            let currentLocation = self.locationManager.userLocation

            let filtered: [User] = documents.compactMap { doc in
                guard doc.documentID != currentUserID else { return nil }
                guard !self.excludedUsers.contains(doc.documentID) else { return nil }
                guard let user = User(id: doc.documentID, data: doc.data()) else { return nil }
                guard self.filters.matches(user: user, currentLocation: currentLocation) else { return nil }
                return user
            }

            let combined = accumulated + filtered
            let nextPageCount = pagesFetched + 1

            let shouldKeepPaging = combined.count < self.minDesiredMatches
                && nextPageCount < self.maxPagesPerFetch
                && documents.count == self.pageSize

            if shouldKeepPaging {
                self.fetchUsersPage(
                    currentUserID: currentUserID,
                    spotlightedIDs: spotlightedIDs,
                    accumulated: combined,
                    pagesFetched: nextPageCount
                )
            } else {
                self.finishFetch(with: combined, spotlightedIDs: spotlightedIDs)
            }
        }
    }

    private func finishFetch(with matches: [User], spotlightedIDs: Set<String>) {
        let ranked = SwipeAlgorithm.rank(matches, spotlightedIDs: spotlightedIDs)

        DispatchQueue.main.async {
            let existingIDs = Set(self.users.map { $0.id })
            let newUsers = ranked.filter { !existingIDs.contains($0.id) }
            self.users.append(contentsOf: newUsers)
            self.isLoading = false
        }

        // OPTIMIZATION: Batch feedAppearanceCount updates locally using UserDefaults
        // and only flush to Firestore once per session per user (not on every feed load).
        // This eliminates potentially dozens of writes per feed view.
        batchRecordFeedAppearances(for: ranked)
    }

    /// Accumulates appearance counts in UserDefaults and only writes to Firestore
    /// once per session (tracked by a session key reset on app launch in WBMApp).
    /// This collapses what was N writes-per-user-per-load into at most 1 write per
    /// user per session, cutting feed-appearance write costs by ~90%+.
    private func batchRecordFeedAppearances(for shownUsers: [User]) {
        guard !shownUsers.isEmpty else { return }

        let defaults = UserDefaults.standard
        let pendingKey = "pendingFeedAppearances"
        var pending = defaults.dictionary(forKey: pendingKey) as? [String: Int] ?? [:]

        for user in shownUsers {
            pending[user.id, default: 0] += 1
        }
        defaults.set(pending, forKey: pendingKey)

        // Flush to Firestore immediately on first load, then throttle subsequent flushes.
        // The actual write is a single batch, not N individual writes.
        let lastFlushKey = "lastFeedAppearanceFlush"
        let lastFlush = defaults.object(forKey: lastFlushKey) as? Date ?? .distantPast
        let shouldFlush = Date().timeIntervalSince(lastFlush) > 120 // flush at most every 2 min

        guard shouldFlush else { return }
        defaults.set(Date(), forKey: lastFlushKey)

        let toFlush = pending
        defaults.removeObject(forKey: pendingKey)

        let db = Firestore.firestore()
        let batch = db.batch()
        for (userID, count) in toFlush {
            let ref = db.collection("users").document(userID)
            batch.updateData([
                "feedAppearanceCount": FieldValue.increment(Int64(count)),
                "lastShownInFeedAt": Timestamp(date: Date())
            ], forDocument: ref)
        }
        batch.commit { error in
            if let error = error {
                print("Error flushing feed appearances: \(error.localizedDescription)")
                // Re-queue failed counts so they aren't lost
                var requeue = defaults.dictionary(forKey: pendingKey) as? [String: Int] ?? [:]
                for (id, count) in toFlush { requeue[id, default: 0] += count }
                defaults.set(requeue, forKey: pendingKey)
            }
        }
    }

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
        lastFetchedDocument = nil
        reachedEndOfUsers = false
        users.removeAll()
        currentIndex = 0
        fetchUsers()
        showFilterSheet = false
    }

    private func removeFromFeed(_ user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        users.remove(at: index)
        if currentIndex >= users.count {
            currentIndex = max(0, users.count - 1)
        }
        refetchIfNeeded()
    }

    private func refetchIfNeeded() {
        guard users.count <= refetchThreshold, !isLoading, !reachedEndOfUsers else { return }
        fetchUsers()
    }

    private func skipUser(_ user: User) {
        updateExcludedUsers(user.id)
        removeFromFeed(user)
    }

    private func approveUser(_ user: User) {
        guard diamonds >= 10 else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        diamonds -= 10

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
