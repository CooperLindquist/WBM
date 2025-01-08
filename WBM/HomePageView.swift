import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct HomePageView: View {
    @State private var users: [User] = []
    @State private var excludedUsers: Set<String> = []
    @State private var isLoading = true

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
        }
        .onAppear(perform: loadExcludedUsersAndFetchUsers)
    }
//
    private func loadExcludedUsersAndFetchUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        let userDoc = Firestore.firestore().collection("users").document(currentUserID)

        // Fetch excluded users (swiped, liked, matched)
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

            // Fetch users after loading excluded users
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
                self.users = fetchedUsers.filter { !self.excludedUsers.contains($0.id) }
            }
            isLoading = false
        }
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

        // Add the current user to the "likes" field of the approved user's document
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
                if let height = formatHeight(user.height) {
                    Text("Height: \(height)")
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
                if let relationshipGoal = user.relationshipGoal {
                    Text("Relationship Goal: \(relationshipGoal)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                if let languages = user.languages, !languages.isEmpty {
                    Text("Languages: \(languages.joined(separator: ", "))")
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            .padding()

            if let bio = user.bio {
                Text(bio)
                    .padding()
                    .multilineTextAlignment(.center)
            }

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
    let relationshipGoal: String?
    let languages: [String]?
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
        self.relationshipGoal = data["relationshipGoal"] as? String
        self.languages = data["languages"] as? [String]
        self.imageURLs = imageURLs
    }
}

#Preview {
    HomePageView()
}
