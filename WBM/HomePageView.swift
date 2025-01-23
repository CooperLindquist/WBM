import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct HomePageView: View {
    @State private var users: [User] = []
    @State private var excludedUsers: Set<String> = []
    @State private var isLoading = true
    @State private var showFilterSheet = false
    @State private var filters: Filters = Filters.loadFilters()

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
                    .progressViewStyle(CircularProgressViewStyle())
            } else if users.isEmpty {
                Text("No more users available!")
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                VStack {
                    Spacer()
                    if let currentUser = users.last {
                        UserCardView(
                            user: currentUser,
                            onSkip: skipUser,
                            onApprove: approveUser
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.9) // Adjust width to 90% of the screen
                        .aspectRatio(2/4, contentMode: .fit) // Keep the desired height
                        .cornerRadius(25)
                        .shadow(radius: 15)
                        .padding(.horizontal, 15) // Add extra padding for narrower look
                        .padding(.top, 20)
                       
                        
                        
                    }
                    Spacer()

                    // Action Buttons
                    HStack(spacing: 30) {
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
                    .padding(.bottom, 20)
                }
            }

            // Filter Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showFilterSheet = true
                    }) {
                        Image(systemName: "line.horizontal.3.decrease.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(filters: $filters, applyFilters: applyFilters)
        }
        .onAppear {
            loadExcludedUsersAndFetchUsers()
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
                let swiped = data["swipedUsers"] as? [String] ?? []
                let liked = data["likes"] as? [String] ?? []
                let matched = data["matches"] as? [String] ?? []
                self.excludedUsers = Set(swiped + liked + matched)
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

            if let documents = snapshot?.documents {
                let fetchedUsers = documents.compactMap { doc -> User? in
                    guard let data = doc.data() as? [String: Any], doc.documentID != currentUserID else { return nil }
                    return User(id: doc.documentID, data: data)
                }
                self.users = fetchedUsers.filter { user in
                    !self.excludedUsers.contains(user.id) && filters.matches(user: user)
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
        updateExcludedUsers(skippedUser.id)
    }

    private func approveUser() {
        guard !users.isEmpty else { return }
        let approvedUser = users.removeLast()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

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
    

    func matches(user: User) -> Bool {
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

        return Filters(minWeight: minWeight, maxWeight: maxWeight, minHeight: minHeight, maxHeight: maxHeight, gender: gender, weightFilterEnabled: weightFilterEnabled, heightFilterEnabled: heightFilterEnabled, genderFilterEnabled: genderFilterEnabled)
    }
}

// FilterSheet UI - Added switches for each filter and set default to off
struct FilterSheet: View {
    @Binding var filters: Filters
    var applyFilters: () -> Void

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

    var body: some View {
        VStack {
            ZStack {
                // User Image
                if let imageUrl = user.imageURLs[safe: currentImageIndex] {
                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture { location in
                            let screenWidth = UIScreen.main.bounds.width
                            if location.x < screenWidth / 2 {
                                showPreviousImage()
                            } else {
                                showNextImage()
                            }
                        }
                }

                // Bottom Gradient Overlay with User Details
                VStack(alignment: .leading, spacing: 8) {
                    // User Name
                    Text(user.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 3)

                    // User Details with Icons
                    HStack(spacing: 15) {
                        if let formattedHeight = formatHeight(user.height) {
                            Label("\(formattedHeight)", systemImage: "ruler")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        if let weight = user.weight {
                            Label("\(weight) lbs", systemImage: "scalemass")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        if let gender = user.gender {
                            Label("\(gender)", systemImage: "person.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                .offset(x: 50, y: 255)

                // Indicators for Images
                VStack {
                    Spacer()
                    HStack {
                        ForEach(user.imageURLs.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentImageIndex ? Color.white : Color.gray.opacity(0.7))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 15)
                }
            }

            Spacer()

         
        }
    }

    private func showNextImage() {
        if currentImageIndex < user.imageURLs.count - 1 {
            currentImageIndex += 1
        }
    }

    private func showPreviousImage() {
        if currentImageIndex > 0 {
            currentImageIndex -= 1
        }
    }

    private func formatHeight(_ height: String?) -> String? {
        guard let height = height, let inches = Double(height) else { return nil }
        let feet = Int(inches / 12)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(remainingInches)\""
    }
}


extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}





struct User: Identifiable, Hashable {
    let id: String
    let name: String
    let bio: String?
    let height: String?
    let weight: String?
    let gender: String?
    let languages: [String]?
    let relationshipGoal: String?
    let imageURLs: [String]

    init?(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let imageURLs = data["profileImageURLs"] as? [String], !imageURLs.isEmpty else { return nil }

        self.id = id
        self.name = name
        self.bio = data["bio"] as? String
        self.height = data["height"] as? String
        self.weight = data["weight"] as? String
        self.gender = data["gender"] as? String
        self.languages = data["languages"] as? [String]
        self.relationshipGoal = data["relationshipGoal"] as? String
        self.imageURLs = imageURLs
    }
}

#Preview {
    HomePageView()
}
