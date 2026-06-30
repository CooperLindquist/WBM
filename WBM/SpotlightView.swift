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
func addToSpotlight(userID: String, additionalDuration: TimeInterval = 18000, completion: ((Date?) -> Void)? = nil) {
    let spotlightRef = Firestore.firestore().collection("Spotlight").document(userID)

    spotlightRef.getDocument { document, error in
        if let error = error {
            print("Error checking spotlight document: \(error.localizedDescription)")
            completion?(nil)
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
                completion?(nil)
            } else {
                // Fix: only call completion once the write has actually landed,
                // so the UI doesn't read stale data immediately after.
                completion?(newExpiration)
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


// Companion to fetchSpotlightedUsers — returns a [userID: source] lookup so
// the UI can distinguish manually-activated Spotlight from automatic boosts.
// Kept separate from fetchSpotlightedUsers (rather than changing its return
// type) since other call sites only need the ID list.
func fetchSpotlightSources(completion: @escaping ([String: String]) -> Void) {
    let spotlightRef = Firestore.firestore().collection("Spotlight")
    let now = Date()

    spotlightRef
        .whereField("expiresAt", isGreaterThan: Timestamp(date: now))
        .getDocuments { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else {
                completion([:])
                return
            }

            var sources: [String: String] = [:]
            for doc in documents {
                sources[doc.documentID] = doc.data()["source"] as? String ?? "manual"
            }
            completion(sources)
        }
}

// Function to check if a user is currently spotlighted.
// Queries Firestore for only non-expired documents (instead of fetching
// the whole collection and discarding most of it client-side), and
// opportunistically deletes any expired documents it happens to see
// along the way — since there's no scheduled Cloud Function doing this
// server-side, this keeps the Spotlight collection from growing forever
// as a side effect of normal usage (anyone opening Spotlight helps clean up).
func fetchSpotlightedUsers(completion: @escaping ([String]) -> Void) {
    let spotlightRef = Firestore.firestore().collection("Spotlight")
    let now = Date()

    // Active spotlights — filtered server-side, not fetched-then-discarded.
    spotlightRef
        .whereField("expiresAt", isGreaterThan: Timestamp(date: now))
        .getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching spotlighted users: \(error.localizedDescription)")
                completion([])
                return
            }

            let activeUserIDs = snapshot?.documents.map { $0.documentID } ?? []
            completion(activeUserIDs)
        }

    // Opportunistic cleanup — deletes a batch of expired docs in the background.
    // Capped at 100 per call so a single screen-open can't trigger a huge write burst.
    spotlightRef
        .whereField("expiresAt", isLessThanOrEqualTo: Timestamp(date: now))
        .limit(to: 100)
        .getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, !documents.isEmpty, error == nil else { return }

            let batch = Firestore.firestore().batch()
            documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { error in
                if let error = error {
                    print("Error cleaning up expired spotlight docs: \(error.localizedDescription)")
                }
            }
        }
}

// COST OPTIMIZATION: SpotlightView is recreated from scratch every time the tab
// bar switches to/from it (TabBarView's @ViewBuilder switch tears down the old
// view), which re-triggers onAppear and re-runs ~7 reads every time — even for
// a user just glancing at the tab and switching away again. This cache lives
// outside the view struct (a plain class, not @State) so it survives those
// re-creations; a short TTL means rapid tab-switching reuses the same data
// instead of re-fetching, while still refreshing periodically so the feed
// doesn't go stale for someone who leaves the tab open in the background.
private final class SpotlightCache {
    static let shared = SpotlightCache()
    var users: [User] = []
    var sources: [String: String] = [:]
    var spotlightsRemaining: Int = 0
    var lastFetched: Date = .distantPast
    let ttl: TimeInterval = 60 // seconds

    var isFresh: Bool { Date().timeIntervalSince(lastFetched) < ttl }
}

// SpotlightView UI
struct SpotlightView: View {
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var spotlightedUsers: [User] = []
    @State private var isLoading = true
    @State private var spotlightsRemaining: Int = 0
    @State private var selectedUser: User?
    @State private var ownSpotlightExpiresAt: Date?
    @State private var timeRemainingText: String = ""
    @State private var countdownTimer: Timer?
    @State private var filters: Filters = Filters.loadFilters()
    @State private var spotlightSources: [String: String] = [:]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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

                if let expiresAt = ownSpotlightExpiresAt, expiresAt > Date() {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("You're in the Spotlight — \(timeRemainingText) left")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .padding(.bottom, 10)
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
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(spotlightedUsers, id: \.id) { user in
                                Button(action: { selectedUser = user }) {
                                    ProfilePreviewTile(
                                        user: user,
                                        badge: spotlightSources[user.id] == "auto" ? "✨ Rising" : "⭐ Spotlight"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear { loadSpotlightedUsersAndCount() }
        .onDisappear { countdownTimer?.invalidate() }
        .fullScreenCover(item: $selectedUser) { user in
            ProfileFeedDetailCover(
                user: user,
                onClose: { selectedUser = nil },
                onSkip: { skipUser(user: $0); selectedUser = nil },
                onApprove: { approveUser(user: $0); selectedUser = nil }
            )
        }
    }

    private func useSpotlight() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        guard spotlightsRemaining > 0 else {
            print("No spotlights remaining.")
            return
        }

        addToSpotlight(userID: currentUserID) { expiresAt in
            DispatchQueue.main.async {
                spotlightsRemaining -= 1
                // Fix: start the countdown immediately with the real expiry time
                // returned from Firestore, instead of waiting for a full reload.
                if let expiresAt = expiresAt {
                    self.ownSpotlightExpiresAt = expiresAt
                    self.startCountdown(to: expiresAt)
                }
                loadSpotlightedUsersAndCount(forceRefresh: true) // still refresh the feed itself
            }
        }
    }


    private func loadSpotlightedUsersAndCount(forceRefresh: Bool = false) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // COST OPTIMIZATION: reuse recently-fetched data instead of re-running the
        // full read chain every time this view appears (see SpotlightCache comment
        // above). `forceRefresh` is used right after the user actively changes
        // something themselves (e.g. spending a Spotlight), where stale data would
        // visibly contradict what they just did.
        if !forceRefresh, SpotlightCache.shared.isFresh {
            spotlightedUsers = SpotlightCache.shared.users
            spotlightSources = SpotlightCache.shared.sources
            spotlightsRemaining = SpotlightCache.shared.spotlightsRemaining
            isLoading = false
            refreshOwnSpotlightStatus(currentUserID: currentUserID)
            return
        }

        isLoading = true

        // Fire-and-forget: tops up automatic Spotlight slots if any are
        // available. Runs in the background; doesn't block this load, and
        // any newly-boosted users will appear next time this view refreshes
        // (e.g. after using a manual Spotlight, or next time the tab opens).
        AutoSpotlight.topUpIfNeeded(excludingUserID: currentUserID)
        fetchSpotlightSources { sources in
            DispatchQueue.main.async {
                self.spotlightSources = sources
                SpotlightCache.shared.sources = sources
            }
        }

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

            currentUserRef.collection("swipedUsers").getDocuments { swipedSnapshot, _ in
                let swipedUsers = swipedSnapshot?.documents.map { $0.documentID } ?? []
                let likedUsers = data["likes"] as? [String] ?? []
                let matchedUsers = data["matches"] as? [String] ?? []

                // Fix: also exclude the current user's own ID so they never see
                // themselves as a tappable, likeable card in their own Spotlight feed.
                let excludedUserIDs = Set(swipedUsers + likedUsers + matchedUsers + [currentUserID])

                fetchSpotlightedUsers { userIds in
                    let filteredUserIds = userIds.filter { !excludedUserIDs.contains($0) }

                    guard !filteredUserIds.isEmpty else {
                        DispatchQueue.main.async {
                            self.spotlightedUsers = []
                            self.isLoading = false
                            SpotlightCache.shared.users = []
                            SpotlightCache.shared.lastFetched = Date()
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

                        let currentLocation = self.locationManager.userLocation
                        let candidates = snapshot?.documents.compactMap { doc -> User? in
                            return User(id: doc.documentID, data: doc.data())
                        } ?? []

                        // Apply the same distance filter used on the home feed —
                        // a spotlighted user outside your distance range still
                        // shouldn't show up here.
                        let filtered = candidates.filter { user in
                            self.filters.matches(user: user, currentLocation: currentLocation)
                        }
                        spotlightedUsers = filtered
                        isLoading = false

                        SpotlightCache.shared.users = filtered
                        SpotlightCache.shared.lastFetched = Date()
                    }
                }
            }

            if let count = data["spotlightsRemaining"] as? Int {
                DispatchQueue.main.async {
                    self.spotlightsRemaining = count
                    SpotlightCache.shared.spotlightsRemaining = count
                }
            }
        }

        refreshOwnSpotlightStatus(currentUserID: currentUserID)
    }

    /// Separately checks if the current user is themselves spotlighted right now,
    /// so we can show the "You're in the Spotlight" banner + countdown. This is a
    /// single cheap doc read, kept outside the cache above so the countdown banner
    /// always reflects the true current state (e.g. immediately after using a
    /// Spotlight) rather than a minute-old cached snapshot.
    private func refreshOwnSpotlightStatus(currentUserID: String) {
        Firestore.firestore().collection("Spotlight").document(currentUserID).getDocument { doc, _ in
            guard let expiresAt = (doc?.data()?["expiresAt"] as? Timestamp)?.dateValue(),
                  expiresAt > Date() else {
                DispatchQueue.main.async {
                    self.ownSpotlightExpiresAt = nil
                    self.countdownTimer?.invalidate()
                }
                return
            }
            DispatchQueue.main.async {
                self.ownSpotlightExpiresAt = expiresAt
                self.startCountdown(to: expiresAt)
            }
        }
    }

    private func startCountdown(to expiresAt: Date) {
        countdownTimer?.invalidate()
        updateTimeRemainingText(until: expiresAt)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if expiresAt <= Date() {
                timer.invalidate()
                ownSpotlightExpiresAt = nil
                return
            }
            updateTimeRemainingText(until: expiresAt)
        }
    }

    private func updateTimeRemainingText(until expiresAt: Date) {
        let remaining = max(0, expiresAt.timeIntervalSinceNow)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        if hours > 0 {
            timeRemainingText = String(format: "%dh %dm", hours, minutes)
        } else {
            timeRemainingText = String(format: "%dm %ds", minutes, seconds)
        }
    }

    private func skipUser(user: User) {
        spotlightedUsers.removeAll { $0.id == user.id }
        selectedUser = nil
    }

    // Data model used across the whole app: a user's `likes` array holds the
    // IDs of people who liked THEM (not people they liked). So when I (currentUserID)
    // like `user`, the write goes onto `user`'s document, not mine.
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

            // Fix: check whether `user` already liked ME — that lives in MY likes array.
            let myLikesReceived = currentUserDoc.data()?["likes"] as? [String] ?? []
            var currentUserMatches = currentUserDoc.data()?["matches"] as? [String] ?? []
            var likedUserMatches = likedUserDoc.data()?["matches"] as? [String] ?? []

            let isMutualLike = myLikesReceived.contains(user.id)

            if isMutualLike {
                if !currentUserMatches.contains(user.id) {
                    currentUserMatches.append(user.id)
                }
                if !likedUserMatches.contains(currentUserID) {
                    likedUserMatches.append(currentUserID)
                }

                // Fix: remove user.id from MY likes (they liked me, now matched),
                // and remove currentUserID from THEIR likes (I liked them, now matched).
                transaction.updateData(["matches": currentUserMatches, "likes": FieldValue.arrayRemove([user.id])], forDocument: currentUserRef)
                transaction.updateData(["matches": likedUserMatches, "likes": FieldValue.arrayRemove([currentUserID])], forDocument: likedUserRef)

                print("✅ Match created between \(currentUserID) and \(user.id)!")
            } else {
                // Fix: my like goes onto THEIR document, not mine.
                transaction.updateData(["likes": FieldValue.arrayUnion([currentUserID])], forDocument: likedUserRef)
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




#Preview {
    SpotlightView()
}
