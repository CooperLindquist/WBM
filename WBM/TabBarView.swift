//
//  TabBarView.swift
//  WBM
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TabBarView: View {
    @State private var selectedTab: String = "house"

    @State private var likesCount: Int = 0
    @State private var messagesCount: Int = 0

    @State private var userListener: ListenerRegistration?
    @State private var previousLikesCount: Int = -1
    @State private var previousMatchesCount: Int = -1

    var body: some View {
        VStack(spacing: 0) {
            NavigationView {
                selectedScreen
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())

            ZStack {
                Color.white
                    .frame(height: 80)
                    .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: -1)

                HStack {
                    tabButton(tab: "house",   imageName: "house",              filledImageName: "house.fill")
                    Spacer()
                    tabButton(tab: "tag",     imageName: "tag",                filledImageName: "tag.fill")
                    Spacer()
                    tabButton(tab: "heart",   imageName: "heart",              filledImageName: "heart.fill",        count: likesCount)
                    Spacer()
                    tabButton(tab: "bubble",  imageName: "text.bubble",        filledImageName: "text.bubble.fill",  count: messagesCount)
                    Spacer()
                    tabButton(tab: "profile", imageName: "person.crop.circle", filledImageName: "person.crop.circle.fill")
                }
                .padding(.horizontal, 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.cancelEngagementReminder()
            startListeners()
        }
        .onDisappear { stopListeners() }
        .onChange(of: selectedTab) { _ in clearBadgeForTab(selectedTab) }
    }

    // MARK: - Tab Button

    private func tabButton(tab: String, imageName: String, filledImageName: String, count: Int = 0) -> some View {
        Button(action: {
            selectedTab = tab
            clearBadgeForTab(tab)
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedTab == tab ? filledImageName : imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)

                if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 12, y: -10)
                }
            }
        }
    }

    // MARK: - Selected Screen

    @ViewBuilder
    private var selectedScreen: some View {
        switch selectedTab {
        case "house":   HomePageView()
        case "tag":     SpotlightView()
        case "heart":   LikesView(likesCount: $likesCount)
        case "bubble":  MessagesView(unreadCount: $messagesCount)
        case "profile": ProfileView()
        default:        HomePageView()
        }
    }

    // MARK: - Listeners

    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        userListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data() else { return }

                let newLikes   = (data["likes"]   as? [String] ?? []).count
                let newMatches = (data["matches"] as? [String] ?? []).count

                if previousLikesCount >= 0 && newLikes > previousLikesCount && selectedTab != "heart" {
                    NotificationManager.shared.scheduleNewLikeNotification(count: newLikes)
                }
                if previousMatchesCount >= 0 && newMatches > previousMatchesCount && selectedTab != "bubble" {
                    NotificationManager.shared.scheduleNewMatchNotification(matchName: "someone")
                }

                previousLikesCount   = newLikes
                previousMatchesCount = newMatches

                // Fix: always keep the real count in sync, even while on the heart tab —
                // otherwise accepting a like while viewing it leaves a stale badge number
                // until you leave and come back. Badge *visibility* is handled by
                // clearBadgeForTab when you actually open the tab; this just keeps
                // the underlying count honest at all times.
                likesCount = newLikes
                NotificationManager.shared.setBadge(count: selectedTab == "heart" ? messagesCount : likesCount + messagesCount)
            }

        startUnreadMessagesListener(uid: uid)
    }

    /// COST OPTIMIZATION: previously this fetched the user's match list, then ran
    /// ONE query per match to check that chat's latest message (N reads, repeated
    /// every time the tab bar appears / app launches). Now that chat docs carry a
    /// denormalized `unreadBy` array (written once at send-time in ChatView), the
    /// unread badge count comes from a single `whereField` query across all of the
    /// user's chats — 1 read total instead of N+1.
    private func startUnreadMessagesListener(uid: String) {
        Firestore.firestore().collection("chats")
            .whereField("participants", arrayContains: uid)
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }

                let unread = documents.reduce(into: 0) { count, doc in
                    let unreadBy = doc.data()["unreadBy"] as? [String] ?? []
                    if unreadBy.contains(uid) { count += 1 }
                }

                if selectedTab != "bubble" { messagesCount = unread }
                NotificationManager.shared.setBadge(count: likesCount + messagesCount)
            }
    }

    private func stopListeners() {
        userListener?.remove()
        NotificationManager.shared.scheduleEngagementReminder()
    }

    private func clearBadgeForTab(_ tab: String) {
        switch tab {
        case "heart":  likesCount = 0
        case "bubble": messagesCount = 0
        default: break
        }
        NotificationManager.shared.setBadge(count: likesCount + messagesCount)
    }
}
