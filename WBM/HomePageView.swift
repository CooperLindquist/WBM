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
            .edgesIgnoringSafeArea(.all)
            
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
            fetchDiamonds()
        }
    }
    private func showDetailedView(for user: User) {
            selectedUser = user
        }
    
    private func resetSwipes() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // 1️⃣ Clear local state
        excludedUsers.removeAll()
        lastSwipedUser = nil

        // 2️⃣ Clear Firestore swipe history
        Firestore.firestore()
            .collection("users")
            .document(currentUserID)
            .updateData([
                "swipedUsers": [],
                "likes": [] // OPTIONAL: remove this line if you want likes to persist
            ]) { error in
                if let error = error {
                    print("Error resetting swipes: \(error.localizedDescription)")
                } else {
                    // 3️⃣ Reload users after reset completes
                    fetchUsers()
                }
            }
    }


    private func fetchDiamonds() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let userDoc = Firestore.firestore().collection("users").document(currentUserID)
        
        userDoc.getDocument { document, error in
            if let error = error {
                print("Error fetching diamonds: \(error.localizedDescription)")
                return
            }
            
            if let data = document?.data(), let userDiamonds = data["diamonds"] as? Int {
                self.diamonds = userDiamonds
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
                let liked = data["likes"] as? [String] ?? []
                let matched = data["matches"] as? [String] ?? []
                self.excludedUsers = Set(liked + matched)
            }
            
            fetchUsers()
        }
    }
    
    private func fetchUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            guard let currentLocation = locationManager.userLocation else {
                print("User location not available yet.")
                isLoading = false
                return
            }
            
            if let documents = snapshot?.documents {
                let fetchedUsers = documents.compactMap { doc -> User? in
                    guard let data = doc.data() as? [String: Any], doc.documentID != currentUserID else { return nil }
                    
                    // Create the User object without filtering by distance here
                    return User(id: doc.documentID, data: data)
                }
                
                // Now apply the filter including distance only if enabled
                self.users = fetchedUsers.filter { user in
                    !self.excludedUsers.contains(user.id) && filters.matches(user: user, currentLocation: currentLocation)
                }
            }
            
            isLoading = false
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
    }
    private func undoSwipe() {
        guard let user = lastSwipedUser else { return }

        // Prevent duplicates
        if !users.contains(user) {
            users.append(user)
        }

        lastSwipedUser = nil
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
    }
    
    
    
    private func updateExcludedUsers(_ userID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        excludedUsers.insert(userID)
        
        Firestore.firestore().collection("users").document(currentUserID).updateData([
            "swipedUsers": FieldValue.arrayUnion([userID])
        ]) { error in
            if let error = error {
                print("Error updating excluded users: \(error.localizedDescription)")
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
    @Environment(\.presentationMode) var presentationMode
    
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
        .edgesIgnoringSafeArea(.top)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
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


// Filters Struct - Updated to support UserDefaults
struct Filters {
    var minWeight: Double = 100
    var maxWeight: Double = 300
    var minHeight: Double = 50
    var maxHeight: Double = 84
    var gender: String? = nil
    var weightFilterEnabled: Bool = false
    var heightFilterEnabled: Bool = false
    var genderFilterEnabled: Bool = false
    var locationFilterEnabled: Bool = false
    var maxDistance: Double = 50  // Add this line
    
    func matches(user: User, currentLocation: CLLocation?) -> Bool {
        if weightFilterEnabled {
            if let weight = Double(user.weight ?? ""), weight < minWeight || weight > maxWeight {
                return false
            }
        }
        if heightFilterEnabled {
            if let height = Double(user.height ?? ""), height < minHeight || height > maxHeight {
                return false
            }
        }
        if genderFilterEnabled {
            if let gender = gender, user.gender != gender {
                return false
            }
        }
        if locationFilterEnabled {
            if let currentLocation = currentLocation, let userLocation = user.location {
                let distanceInMeters = currentLocation.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                let distanceInMiles = distanceInMeters / 1609.34
                if distanceInMiles > maxDistance {
                    return false
                }
            } else {
                // If the user location is not available, we should exclude this user
                return false
            }
        }
        return true
    }
    
    
    // Save filters to UserDefaults
    func saveFilters() {
        UserDefaults.standard.set(minWeight, forKey: "minWeight")
        UserDefaults.standard.set(maxWeight, forKey: "maxWeight")
        UserDefaults.standard.set(minHeight, forKey: "minHeight")
        UserDefaults.standard.set(maxHeight, forKey: "maxHeight")
        UserDefaults.standard.set(gender, forKey: "gender")
        UserDefaults.standard.set(weightFilterEnabled, forKey: "weightFilterEnabled")
        UserDefaults.standard.set(heightFilterEnabled, forKey: "heightFilterEnabled")
        UserDefaults.standard.set(genderFilterEnabled, forKey: "genderFilterEnabled")
        UserDefaults.standard.set(locationFilterEnabled, forKey: "locationFilterEnabled")
        UserDefaults.standard.set(maxDistance, forKey: "maxDistance")  // Save distance
    }
    
    // Load filters from UserDefaults
    static func loadFilters() -> Filters {
        let minWeight = UserDefaults.standard.double(forKey: "minWeight")
        let maxWeight = UserDefaults.standard.double(forKey: "maxWeight")
        let minHeight = UserDefaults.standard.double(forKey: "minHeight")
        let maxHeight = UserDefaults.standard.double(forKey: "maxHeight")
        let gender = UserDefaults.standard.string(forKey: "gender")
        let weightFilterEnabled = UserDefaults.standard.bool(forKey: "weightFilterEnabled")
        let heightFilterEnabled = UserDefaults.standard.bool(forKey: "heightFilterEnabled")
        let genderFilterEnabled = UserDefaults.standard.bool(forKey: "genderFilterEnabled")
        let locationFilterEnabled = UserDefaults.standard.bool(forKey: "locationFilterEnabled")
        let maxDistance = UserDefaults.standard.double(forKey: "maxDistance") // Load distance
        
        return Filters(
            minWeight: minWeight,
            maxWeight: maxWeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
            gender: gender,
            weightFilterEnabled: weightFilterEnabled,
            heightFilterEnabled: heightFilterEnabled,
            genderFilterEnabled: genderFilterEnabled,
            locationFilterEnabled: locationFilterEnabled,
            maxDistance: maxDistance > 0 ? maxDistance : 50  // Default to 50 if not set
        )
    }
}


// FilterSheet UI - Added switches for each filter and set default to off
struct FilterSheet: View {
    @Binding var filters: Filters
    var applyFilters: () -> Void
    @State private var distance: Double = 50  // default value
    
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weight Range")) {
                    Toggle("Enable Weight Filter", isOn: $filters.weightFilterEnabled)
                    if filters.weightFilterEnabled {
                        VStack {
                            Text("Min Weight: \(Int(filters.minWeight)) lbs")
                            Slider(value: $filters.minWeight, in: 50...300, step: 1)
                        }
                        VStack {
                            Text("Max Weight: \(Int(filters.maxWeight)) lbs")
                            Slider(value: $filters.maxWeight, in: 50...300, step: 1)
                        }
                    }
                }
                Section(header: Text("Height Range")) {
                    Toggle("Enable Height Filter", isOn: $filters.heightFilterEnabled)
                    if filters.heightFilterEnabled {
                        VStack {
                            Text("Min Height: \(Int(filters.minHeight)) inches")
                            Slider(value: $filters.minHeight, in: 50...84, step: 1)
                        }
                        VStack {
                            Text("Max Height: \(Int(filters.maxHeight)) inches")
                            Slider(value: $filters.maxHeight, in: 50...84, step: 1)
                        }
                    }
                }
                
                
                Section(header: Text("Gender")) {
                    Toggle("Enable Gender Filter", isOn: $filters.genderFilterEnabled)
                    if filters.genderFilterEnabled {
                        Picker("Gender", selection: $filters.gender) {
                            Text("Any").tag(nil as String?)
                            Text("Male").tag("Male" as String?)
                            Text("Female").tag("Female" as String?)
                            Text("Other").tag("Other" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Distance Filter")) {
                    Toggle("Enable Distance Filter", isOn: $filters.locationFilterEnabled)
                    if filters.locationFilterEnabled {
                        VStack(alignment: .leading) {
                            Slider(value: $filters.maxDistance, in: 1...100, step: 1)
                            Text("\(Int(filters.maxDistance)) miles")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
            }
            .navigationTitle("Filters")
            .navigationBarItems(trailing: Button("Apply") {
                applyFilters()
            })
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
        .edgesIgnoringSafeArea(.all)
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





import CoreLocation


struct User: Identifiable, Hashable {
    let id: String
    let age: String?
    let name: String
    let bio: String?
    let height: String?
    let weight: String?
    let gender: String?
    let languages: [String]?
    let relationshipGoal: String?
    let imageURLs: [String]
    let premium: Bool
    let location: CLLocationCoordinate2D?
    
    init?(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let imageURLs = data["profileImageURLs"] as? [String], !imageURLs.isEmpty else { return nil }
        
        self.id = id
        self.name = name
        self.age = data["age"] as? String
        self.bio = data["bio"] as? String
        self.height = data["height"] as? String
        self.weight = data["weight"] as? String
        self.gender = data["gender"] as? String
        self.languages = data["languages"] as? [String]
        self.relationshipGoal = data["relationshipGoal"] as? String
        self.imageURLs = imageURLs
        self.premium = data["premium"] as? Bool ?? false
        
        if let locationData = data["location"] as? [String: Any],
           let lat = locationData["latitude"] as? CLLocationDegrees,
           let lon = locationData["longitude"] as? CLLocationDegrees {
            self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            self.location = nil
        }
    }
    
    
    // ✅ Manual Hashable & Equatable conformance
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


#Preview {
    HomePageView()
}
