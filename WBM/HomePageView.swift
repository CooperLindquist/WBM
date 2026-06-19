import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct HomePageView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var users: [User] = [] {
        didSet {
            withAnimation(.spring()) {}
        }
    }
    @State private var lastSwipedUser: User?
    @State private var excludedUsers: Set<String> = []
    @State private var isLoading = true
    @State private var showFilterSheet = false
    @State private var filters: Filters = Filters.loadFilters()
    @State private var diamonds: Int = 0
    @State private var showDiamondStore = false
    @State private var selectedUser: User? = nil
    
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
                VStack {
                    Spacer()
                    
                    // Compact Card View
                    ZStack {
                        // 👀 Next card peeking
                        if users.count > 1 {
                            CompactUserCardView(
                                user: users[users.count - 2],
                                onInfoTapped: {},
                                onSkip: {},
                                onApprove: {}
                            )
                            .scaleEffect(0.95)
                            .offset(y: 12)
                        }

                        // 👆 Top swipeable card
                        if let currentUser = users.last {
                            SwipeableUserCard(
                                user: currentUser,
                                canApprove: diamonds >= 10,
                                onInfoTapped: { showDetailedView(for: currentUser) },
                                onSkip: skipUser,
                                onApprove: approveUser
                            )

                        }
                    }
                    .frame(width: UIScreen.main.bounds.width - 40)

                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 30) {
                        Button {
                            undoSwipe()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(lastSwipedUser == nil ? .gray : .white)
                        }
                        .disabled(lastSwipedUser == nil)
                        .opacity(lastSwipedUser == nil ? 0.4 : 1.0)


                        Button(action: { skipUser() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.red)
                        }
                        
                        Button(action: { approveUser() }) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.green)
                        }
                    }
                    .offset(y: -30)
                    .padding(.bottom, 20)
                }
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
        .sheet(item: $selectedUser) { user in
                    // Detailed User View
                    UserDetailView(user: user)
                }
        .onAppear {
            loadExcludedUsersAndFetchUsers()
        }
    }
    private func showDetailedView(for user: User) {
            selectedUser = user
        }
    
    // Resets only people the user skipped or unliked — never touches matches,
    // since those are active conversations and shouldn't reappear in the swipe stack.
    private func resetSwipes() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(currentUserID)

        lastSwipedUser = nil
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
    
    private func skipUser() {
        guard !users.isEmpty else { return }
        let skippedUser = users.removeLast()
        lastSwipedUser = skippedUser
        updateExcludedUsers(skippedUser.id)
        refetchIfNeeded()
    }
    private func undoSwipe() {
        guard let user = lastSwipedUser else { return }

        // Prevent duplicates
        if !users.contains(user) {
            users.append(user)
        }

        lastSwipedUser = nil
    }


    
    /// Silently fetch more users when stack is running low
    private func refetchIfNeeded() {
        guard users.count <= refetchThreshold, !isLoading else { return }
        fetchUsers()
    }

    private func approveUser() {
        guard !users.isEmpty else { return }
        guard diamonds >= 10 else { return } // Ensure the user has enough diamonds
        let approvedUser = users.removeLast()
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
        
        Firestore.firestore().collection("users").document(approvedUser.id).updateData([
            "likes": FieldValue.arrayUnion([currentUserID])
        ]) { error in
            if let error = error {
                print("Error adding like: \(error.localizedDescription)")
            }
        }
        
        updateExcludedUsers(approvedUser.id)
        refetchIfNeeded()
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
struct CompactUserCardView: View {
    let user: User
    var onInfoTapped: () -> Void
    var onSkip: () -> Void
    var onApprove: () -> Void
    
    @State private var currentImageIndex = 0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Image
            GeometryReader { geo in
                let width = geo.size.width
                let height = width * 4 / 3   // ✅ 3:4 portrait ratio

                if let imageUrl = user.imageURLs[safe: currentImageIndex] {
                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .onTapGesture { location in
                            handleImageTap(location: location)
                        }
                }
            }
            .frame(height: UIScreen.main.bounds.width * 4 / 3)

            
            // Info Button
            Button(action: onInfoTapped) {
                Image(systemName: "info.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding()
            
            // Bottom Info Overlay
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let age = user.age {
                            Text("\(age) years")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            
            // Image Indicators
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    ForEach(user.imageURLs.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentImageIndex ? Color.white : Color.gray.opacity(0.7))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    private func handleImageTap(location: CGPoint) {
        let screenWidth = UIScreen.main.bounds.width * 0.9
        if location.x < screenWidth / 2 {
            // Tap left side - previous image
            if currentImageIndex > 0 {
                currentImageIndex -= 1
            }
        } else {
            // Tap right side - next image
            if currentImageIndex < user.imageURLs.count - 1 {
                currentImageIndex += 1
            }
        }
    }
}

// MARK: - Detailed User View
struct UserDetailView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image Carousel
                TabView {
                    ForEach(user.imageURLs, id: \.self) { url in
                        WebImage(url: URL(string: url))
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .clipped()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // User Information
                VStack(alignment: .leading, spacing: 16) {
                    Text(user.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let age = user.age {
                        DetailRow(icon: "calendar", text: "\(age) years")
                    }
                    
                    if let gender = user.gender {
                        DetailRow(icon: "person.fill", text: gender)
                    }
                    
                    if let height = user.height, let formattedHeight = formatHeight(height) {
                        DetailRow(icon: "ruler.fill", text: formattedHeight)
                    }
                    
                    if let weight = user.weight {
                        DetailRow(icon: "scalemass.fill", text: "\(weight) lbs")
                    }
                    
                    if let languages = user.languages, !languages.isEmpty {
                        DetailRow(icon: "globe", text: languages.joined(separator: ", "))
                    }
                    
                    if let goal = user.relationshipGoal {
                        DetailRow(icon: "heart.fill", text: goal)
                    }
                    
                    if let bio = user.bio, !bio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Me")
                                .font(.headline)
                            Text(bio)
                                .font(.body)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    private func formatHeight(_ height: String) -> String? {
        guard let inches = Double(height) else { return nil }
        let feet = Int(inches / 12)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
        return "\(feet)' \(remainingInches)\""
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}


struct UserCardView: View {
    let user: User
    var onSkip: (() -> Void)?
    var onApprove: (() -> Void)?
    
    @State private var currentImageIndex = 0
    @State private var showFullProfile = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background Image
            if let imageUrl = user.imageURLs[safe: currentImageIndex] {
                WebImage(url: URL(string: imageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                self.dragOffset = value.translation
                            }
                            .onEnded { value in
                                if value.translation.width < -100 {
                                    showNextImage()
                                } else if value.translation.width > 100 {
                                    showPreviousImage()
                                }
                                self.dragOffset = .zero
                            }
                    )
            }
            
            // Top Info Bar (always visible)
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                        
                        if let age = user.age {
                            Text("\(age) years old")
                                .font(.title2)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Info Button to expand profile
                    Button(action: {
                        withAnimation(.spring()) {
                            showFullProfile.toggle()
                        }
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 50)
                
                Spacer()
                
                // Expanded Profile Details (slides up when active)
                if showFullProfile {
                    VStack(alignment: .leading, spacing: 15) {
                        // Close button
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring()) {
                                    showFullProfile = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 10)
                        
                        // User details
                        DetailRow(icon: "person.fill", text: user.gender ?? "Not specified")
                        
                        if let height = user.height {
                            DetailRow(icon: "ruler", text: "\(height) inches")
                        }
                        
                        if let weight = user.weight {
                            DetailRow(icon: "scalemass", text: "\(weight) lbs")
                        }
                        
                        if let goal = user.relationshipGoal {
                            DetailRow(icon: "heart.fill", text: goal)
                        }
                        
                        if let languages = user.languages, !languages.isEmpty {
                            DetailRow(icon: "globe", text: languages.joined(separator: ", "))
                        }
                        
                        if let bio = user.bio {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("About Me")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(bio)
                                    .foregroundColor(.white)
                                    .font(.body)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(25)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.7))
                    )
                    .transition(.move(edge: .bottom))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                } else {
                    // Image indicators at bottom when not expanded
                    if user.imageURLs.count > 1 {
                        HStack {
                            ForEach(user.imageURLs.indices, id: \.self) { index in
                                Circle()
                                    .fill(index == currentImageIndex ? Color.white : Color.gray.opacity(0.7))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func showNextImage() {
        withAnimation {
            currentImageIndex = min(currentImageIndex + 1, user.imageURLs.count - 1)
        }
    }
    
    private func showPreviousImage() {
        withAnimation {
            currentImageIndex = max(currentImageIndex - 1, 0)
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
