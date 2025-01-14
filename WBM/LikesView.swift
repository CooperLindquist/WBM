//
//  GroupListView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct LikesView: View {
    @State private var likedUsers: [User] = []
    @State private var selectedUser: User? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                if isLoading {
                    ProgressView("Loading Likes...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if likedUsers.isEmpty {
                    Text("No one has liked you yet!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(likedUsers) { user in
                                Button(action: {
                                    selectedUser = user
                                }) {
                                    VStack {
                                        WebImage(url: URL(string: user.imageURLs.first ?? ""))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        Text(user.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        fetchLikedUsers()
                    }
                }
            }
            .fullScreenCover(item: $selectedUser) { user in
                VStack {
                    HStack {
                        Button(action: { selectedUser = nil }) {
                            Image(systemName: "chevron.backward")
                                .font(.title2)
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.8)))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    Spacer()

                    UserCardView(
                        user: user,
                        onSkip: {
                            handleAction(user: user, action: "reject")
                            selectedUser = nil
                        },
                        onApprove: {
                            handleAction(user: user, action: "accept")
                            selectedUser = nil
                        }
                    )
                    .frame(width: 350, height: 500)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(.top, 30)

                    Spacer()
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                )
            }
            .onAppear(perform: fetchLikedUsers)
        }
    }

    private func fetchLikedUsers() {
        isLoading = true
        let currentUserID = Auth.auth().currentUser?.uid ?? ""
        Firestore.firestore().collection("users").document(currentUserID).getDocument { document, error in
            if let error = error {
                print("Error fetching likes: \(error.localizedDescription)")
                isLoading = false
                return
            }

            guard let data = document?.data(),
                  let likedUserIDs = data["likes"] as? [String],
                  !likedUserIDs.isEmpty else {
                likedUsers = []
                isLoading = false
                return
            }

            Firestore.firestore().collection("users").whereField(FieldPath.documentID(), in: likedUserIDs).getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching liked users: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    likedUsers = documents.compactMap { doc -> User? in
                        let data = doc.data()
                        return User(id: doc.documentID, data: data)
                    }
                }
                isLoading = false
            }
        }
    }

    private func handleAction(user: User, action: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(currentUserID).updateData([
            "likes": FieldValue.arrayRemove([user.id])
        ]) { error in
            if let error = error {
                print("Error updating likes: \(error.localizedDescription)")
            } else {
                likedUsers.removeAll { $0.id == user.id }
                
                if action == "accept" {
                    Firestore.firestore().collection("users").document(user.id).updateData([
                        "matches": FieldValue.arrayUnion([currentUserID])
                    ])
                    Firestore.firestore().collection("users").document(currentUserID).updateData([
                        "matches": FieldValue.arrayUnion([user.id])
                    ])
                }
            }
        }
    }
}




#Preview {
    LikesView()
}
