//
//  TabBarView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//


import SwiftUI
import Firebase
import FirebaseAuth


struct TabBarView: View {
    @State private var selectedTab: String = "house"
    @State private var likesCount: Int = 0 // State for the likes count

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            NavigationView {
                selectedScreen
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())

            // Tab bar
            ZStack {
                Color.white
                    .frame(height: 80)
                    .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: -1)

                HStack {
                    tabButton(tab: "house", imageName: "house", filledImageName: "house.fill")
                    Spacer()
                    tabButton(tab: "tag", imageName: "tag", filledImageName: "tag.fill")
                    Spacer()
                    tabButton(tab: "heart", imageName: "heart", filledImageName: "heart.fill", count: likesCount)
                    Spacer()
                    tabButton(tab: "bubble", imageName: "text.bubble", filledImageName: "text.bubble.fill")
                    Spacer()
                    tabButton(tab: "profile", imageName: "person.crop.circle", filledImageName: "person.crop.circle.fill")
                }
                .padding(.horizontal, 20)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear(perform: fetchLikesCount) // Fetch likes count when TabBarView appears
    }

    // Tab button component
    private func tabButton(tab: String, imageName: String, filledImageName: String, count: Int = 0) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedTab == tab ? filledImageName : imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)

                if count > 0 && tab == "heart" {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 10, y: -10)
                }
            }
        }
    }

    // Selected screen view
    @ViewBuilder
    private var selectedScreen: some View {
        switch selectedTab {
        case "house":
            HomePageView()
        case "tag":
            SpotlightView()
        case "heart":
            LikesView(likesCount: $likesCount) // Pass likes count binding
        case "bubble":
            MessagesView()
        case "profile":
            ProfileView()
        default:
            HomePageView()
        }
    }

    // Fetch the likes count
    private func fetchLikesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(currentUserID).getDocument { document, error in
            if let error = error {
                print("Error fetching likes: \(error.localizedDescription)")
                return
            }

            guard let data = document?.data(),
                  let likedUserIDs = data["likes"] as? [String] else {
                likesCount = 0
                return
            }

            likesCount = likedUserIDs.count
        }
    }
}



struct TabBarView_Preview: PreviewProvider {
    static var previews: some View {
        TabBarView()
    }
}
