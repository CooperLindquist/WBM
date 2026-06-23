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

    private func startUnreadMessagesListener(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
            guard let matchIDs = snapshot?.data()?["matches"] as? [String], !matchIDs.isEmpty else { return }
            var unread = 0
            let group = DispatchGroup()

            for matchID in matchIDs {
                let chatID = [uid, matchID].sorted().joined(separator: "_")
                group.enter()
                Firestore.firestore().collection("chats").document(chatID)
                    .collection("messages")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments { snap, _ in
                        if let doc = snap?.documents.first,
                           let senderID = doc.data()["senderID"] as? String,
                           senderID != uid {
                            let readBy = doc.data()["readBy"] as? [String] ?? []
                            if !readBy.contains(uid) { unread += 1 }
                        }
                        group.leave()
                    }
            }

            group.notify(queue: .main) {
                if selectedTab != "bubble" { messagesCount = unread }
                NotificationManager.shared.setBadge(count: likesCount + messagesCount)
            }
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
