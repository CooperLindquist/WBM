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
    @State private var showingStarsView = false
    @State private var showingOnboarding = false
    @State private var userData: [String: Any] = [:]
    @State private var isLoading = true
    @State private var profileImageURLs: [String] = []
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Images
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                if !profileImageURLs.isEmpty {
                                    ForEach(profileImageURLs, id: \.self) { url in
                                        WebImage(url: URL(string: url))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 15))
                                    }
                                } else {
                                    Text("No images uploaded")
                                        .foregroundColor(.white)
                                        .italic()
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Name
                        if let name = userData["name"] as? String {
                            Text(name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }

                        // Bio
                        if let bio = userData["bio"] as? String {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)
                        }

                        Spacer().frame(height: 20)

                        // Profile Details
                        VStack(alignment: .leading, spacing: 12) {
                            if let heightInInches = userData["height"] as? String {
                                profileDetailRow(icon: "ruler", title: "Height", value: formatHeight(heightInInches) ?? "Unknown")
                            }

                            if let weight = userData["weight"] as? String {
                                profileDetailRow(icon: "scalemass", title: "Weight", value: "\(weight) lbs")
                            }

                            if let gender = userData["gender"] as? String {
                                profileDetailRow(icon: "person.fill", title: "Gender", value: gender)
                            }

                            if let relationshipGoal = userData["relationshipGoal"] as? String {
                                profileDetailRow(icon: "heart.fill", title: "Relationship Goal", value: relationshipGoal)
                            }

                            if let languages = userData["languages"] as? [String] {
                                profileDetailRow(icon: "globe", title: "Languages", value: languages.joined(separator: ", "))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.2))
                                .shadow(radius: 5)
                        )
                        .padding(.horizontal)

                        Spacer()

                        // Edit Profile Button
                        Button(action: {
                            showingOnboarding = true
                        }) {
                            Text("Edit Profile")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.pink, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 16)
                        .fullScreenCover(isPresented: $showingOnboarding) {
                            EditProfileView(initialProfileData: userData)
                        }
                        
                        
                        Button(action: {
                            // Navigate to StarsView
                            showingStarsView = true
                        }) {
                            Text("View Ratings")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 16)
                        .fullScreenCover(isPresented: $showingStarsView) {
                            StarsView()
                        }


                        // Sign Out Button
                        Button(action: signOut) {
                            Text("Sign Out")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: fetchProfileData)
    }

    private func fetchProfileData() {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true

        Firestore.firestore().collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching profile data: \(error.localizedDescription)")
                isLoading = false
                return
            }

            if let document = document, document.exists {
                userData = document.data() ?? [:]
                fetchProfileImages(userId: user.uid)
            } else {
                isLoading = false
            }
        }
    }

    private func fetchProfileImages(userId: String) {
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error fetching profile image URLs: \(error.localizedDescription)")
                isLoading = false
                return
            }

            if let document = document, document.exists,
               let imageURLs = document.data()?["profileImageURLs"] as? [String] {
                profileImageURLs = imageURLs
            }
            isLoading = false
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

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}
