//
//  ProfileView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//



import SwiftUI
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI



struct ProfileView: View {
    @State private var showingPhotoManager = false
    @State private var showingStarsView = false
    @State private var showingOnboarding = false
    @State private var userData: [String: Any] = [:]
    @State private var isLoading = true
    @State private var profileImageURLs: [String] = []
    @State private var selectedImageIndex = 0
    @EnvironmentObject var sessionManager: SessionManager
    
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.7)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Main Profile Image (updated to use selectedImageIndex)
                        // Circular Profile Photo
                        Button {
                            showingPhotoManager = true
                        } label: {
                            if let firstPhoto = profileImageURLs.first,
                               let url = URL(string: firstPhoto) {
                                WebImage(url: url)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 160, height: 160)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: 4)
                                    )
                                    .shadow(radius: 10)
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 160, height: 160)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 30)

                        
                        // Profile Info Card
                        VStack(spacing: 20) {
                            // Name and Basic Info
                            VStack(spacing: 8) {
                                Text(userData["name"] as? String ?? "")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 20) {
                                    if let age = userData["age"] as? String {
                                        InfoPill(text: "\(age) years", icon: "calendar")
                                    }
                                    if let gender = userData["gender"] as? String {
                                        InfoPill(text: gender, icon: "person.fill")
                                    }
                                }
                                
                                if let relationshipGoal = userData["relationshipGoal"] as? String {
                                    InfoPill(text: relationshipGoal, icon: "heart.fill")
                                        .padding(.top, 8)
                                }
                            }
                            
                            // Stats Grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                                StatsCard(icon: "ruler.fill", title: "Height", value: formatHeight(userData["height"] as? String ?? "") ?? "N/A")
                                StatsCard(icon: "scalemass.fill", title: "Weight", value: "\(userData["weight"] as? String ?? "") lbs")
                                StatsCard(
                                    icon: "globe",
                                    title: "Languages",
                                    value: (userData["languages"] as? [String] ?? [])
                                        .joined(separator: ", ")
                                )
                                StatsCard(
                                        icon: "calendar",
                                        title: "Age",
                                        value: {
                                            guard let age = userData["age"] as? String, !age.isEmpty else {
                                                return "N/A"
                                            }
                                            return "\(age) years"
                                        }()
                                    )
                                }
                            // Lifestyle & Beliefs
                            if let religion = userData["religion"] as? String,
                               let ethnicity = userData["ethnicity"] as? String {

                                VStack(alignment: .leading, spacing: 15) {

                                    Text("Lifestyle & Beliefs")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {

                                        StatsCard(
                                            icon: "sparkles",
                                            title: "Religion",
                                            value: religion
                                        )

                                        StatsCard(
                                            icon: "person.2.fill",
                                            title: "Ethnicity",
                                            value: ethnicity
                                        )

                                        StatsCard(
                                            icon: "leaf.fill",
                                            title: "Smoking",
                                            value: userData["smoking"] as? String ?? "N/A"
                                        )

                                        StatsCard(
                                            icon: "wineglass.fill",
                                            title: "Drinking",
                                            value: userData["drinking"] as? String ?? "N/A"
                                        )

                                    }

                                }
                            }
                            if let languages = userData["languages"] as? [String], !languages.isEmpty {

                                VStack(alignment: .leading, spacing: 12) {

                                    Text("Languages")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)

                                    FlexibleTagView(tags: languages)

                                }
                            }
                            
                            // Bio Section
                            if let bio = userData["bio"] as? String, !bio.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("About Me")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text(bio)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(15)
                            }
                            
                            // Action Buttons
                            VStack(spacing: 15) {
                                
                                
                                GradientButton(title: "View Ratings", icon: "star.fill", colors: [Color.purple, Color.blue]) {
                                    showingStarsView = true
                                }
                                
                                Button(action: signOut) {
                                    HStack {
                                        Text("Sign Out")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                        Image(systemName: "arrow.right.square.fill")
                                            .foregroundColor(.red)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.top)
                        }
                        .padding(25)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.5)]),
                                           startPoint: .top,
                                           endPoint: .bottom)
                            .cornerRadius(30)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            EditProfileView(mode: .editing) {
                fetchProfileData()   // 🔥 refresh profile immediately
            }
        }
        .fullScreenCover(isPresented: $showingPhotoManager) {
            PhotoManagerView(
                photoURLs: $profileImageURLs
            )
        }

        .fullScreenCover(isPresented: $showingStarsView) {
            StarsView() // Replace with your ratings view
        }
        
        .onAppear {
            if profileImageURLs.isEmpty {
                fetchProfileData()
            }
        }
        .overlay(
            Button(action: { showingOnboarding = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.blue))
                    .shadow(radius: 10)
            }
                .padding(.top, 40)
                .padding(.trailing, 20),
            alignment: .topTrailing
        )
        // Keep existing fullScreenCover modifiers
    }
    
    // New component for info pills
    private func InfoPill(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.2))
        .cornerRadius(20)
    }
    private func formatHeight(_ height: String) -> String? {
        guard let totalInches = Int(height), totalInches > 0 else {
            return nil
        }

        let feet = totalInches / 12
        let inches = totalInches % 12

        return "\(feet)'\(inches)\""
    }


    
    // New component for stats cards
    private func StatsCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(15)
    }
    
    // New gradient button component
    private func GradientButton(title: String, icon: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(gradient: Gradient(colors: colors),
                               startPoint: .leading,
                               endPoint: .trailing)
                .cornerRadius(12)
            )
            .shadow(color: colors.first?.opacity(0.3) ?? .clear, radius: 10, y: 5)
        }
    }
    
    // Helper Views
    private func DetailItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func SectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.bottom, 4)
    }
    
    private func LifestyleIndicator(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .padding(8)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
        }
    }
    
    private func ActionButton(title: String, icon: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: gradient),
                                       startPoint: .leading,
                                       endPoint: .trailing))
            .cornerRadius(15)
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 10, y: 5)
        }
    }
    
    private func fetchProfileData() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            sessionManager.signOut() // Force sign out if no user found
            return
        }
        
        isLoading = true
        
        Firestore.firestore().collection("users").document(user.uid).getDocument { document, error in
            defer { isLoading = false }
            
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("Document does not exist for user: \(user.uid)")
                return
            }
            
            // Safely unpack all data with defaults
            let data = document.data() ?? [:]
            userData = data
            Firestore.firestore().collection("users").document(user.uid).getDocument { document, error in
            }
            // Handle profile images with empty state
            profileImageURLs = data["profileImageURLs"] as? [String] ?? []
            
            // If you want to force at least one image
            if profileImageURLs.isEmpty {
                profileImageURLs = ["placeholder_image_url"]
            }
        }
    }
    
    
    private func signOut() {
        sessionManager.signOut()
    }
    
    private func profileDetailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.body)
    }
}
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
struct FlexibleTagView: View {

    let tags: [String]

    var body: some View {

        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100))],
            spacing: 10
        ) {

            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }

        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}
