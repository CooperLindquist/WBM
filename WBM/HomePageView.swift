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
                    if let currentUser = users.last {
                        UserCardView(
                            user: currentUser,
                            onSkip: skipUser,
                            onApprove: approveUser
                        )
                    }
                }
            }

            // Move the filter button inside ZStack to ensure visibility
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showFilterSheet = true
                    }) {
                        Image(systemName: "line.horizontal.3.decrease.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
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

// UserCardView
struct UserCardView: View {
    let user: User
    var onSkip: (() -> Void)?
    var onApprove: (() -> Void)?

    var body: some View {
        VStack {
            TabView {
                ForEach(user.imageURLs, id: \.self) { imageUrl in
                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding()
                }
            }
            .tabViewStyle(PageTabViewStyle())

            Text(user.name)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 5) {
                if let formattedHeight = formatHeight(user.height) {
                    Text("Height: \(formattedHeight)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                if let weight = user.weight {
                    Text("Weight: \(weight) lbs")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                if let gender = user.gender {
                    Text("Gender: \(gender)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                // Keep languages and relationship goal here
                if let languages = user.languages {
                    Text("Languages: \(languages.joined(separator: ", "))")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                if let relationshipGoal = user.relationshipGoal {
                    Text("Relationship Goal: \(relationshipGoal)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            .padding()

            Spacer()

            HStack {
                Button(action: { onSkip?() }) {
                    Image("skip")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)
                }

                Button(action: { onApprove?() }) {
                    Image("check")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 93)
                }
            }
            .padding()
        }
        .padding()
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
