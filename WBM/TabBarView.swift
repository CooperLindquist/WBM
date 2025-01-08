//
//  TabBarView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//


import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: String = "house"

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            NavigationView {
                selectedScreen
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarHidden(true)
                    .toolbar {
                        // Add a sample toolbar item, can be customized based on need
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                print("Toolbar button tapped!")
                            }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            }

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
                    tabButton(tab: "heart", imageName: "heart", filledImageName: "heart.fill")
                    Spacer()
                    tabButton(tab: "bubble", imageName: "text.bubble", filledImageName: "text.bubble.fill")
                    Spacer()
                    tabButton(tab: "profile", imageName: "person.crop.circle", filledImageName: "person.crop.circle.fill")
                }
                .padding(.horizontal, 20)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // Tab button component
    private func tabButton(tab: String, imageName: String, filledImageName: String) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            Image(systemName: selectedTab == tab ? filledImageName : imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(selectedTab == tab ? .blue : .gray)
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
            LikesView()
        case "bubble":
            MessagesView()
        case "profile":
            ProfileView()
        default:
            HomePageView()
        }
    }
}

struct TabBarView_Preview: PreviewProvider {
    static var previews: some View {
        TabBarView()
    }
}
