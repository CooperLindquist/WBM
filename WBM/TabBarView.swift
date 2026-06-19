//
//  TabBarView.swift
//  WBM
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TabBarView: View {
    @State private var selectedTab: String = "house"

    // Badge counts
    @State private var likesCount: Int = 0
    @State private var messagesCount: Int = 0
    @State private var matchesCount: Int = 0  // for a future "new match" flash if needed

    // Firestore listeners — stored so we can detach them on disappear
    @State private var userListener: ListenerRegistration?
    @State private var messagesListener: ListenerRegistration?

    // Previous counts so we can detect *new* likes/matches and fire local notifications
    @State private var previousLikesCount: Int = -1
    @State private var previousMatchesCount: Int = -1

    var body: some View {
        VStack(spacing: 0) {
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
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.cancelEngagementReminder()
            startListeners()
        }
        .onDisappear {
            stopListeners()
        }
        // Schedule engagement reminder when app goes to background
        .onChange(of: selectedTab) { _ in
            // Clear badge for the tab the user just switched to
            clearBadgeForTab(selectedTab)
        }
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

    // MARK: - Real-Time Firestore Listeners

    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Listen to the current user's document for likes + matches
        userListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }

                let newLikes    = (data["likes"]   as? [String] ?? []).count
                let newMatches  = (data["matches"] as? [String] ?? []).count

                // Fire local notification if likes went up and heart tab isn't active
                if previousLikesCount >= 0 && newLikes > previousLikesCount && selectedTab != "heart" {
                    NotificationManager.shared.scheduleNewLikeNotification(count: newLikes)
                }

                // Fire local notification if matches went up and messages tab isn't active
                if previousMatchesCount >= 0 && newMatches > previousMatchesCount && selectedTab != "bubble" {
                    // We don't know the name here easily, so use a generic notification
                    NotificationManager.shared.scheduleNewMatchNotification(matchName: "someone")
                }

                previousLikesCount   = newLikes
                previousMatchesCount = newMatches

                // Only show badge if not on that tab
                if selectedTab != "heart" {
                    likesCount = newLikes
                }

                // Update app badge to total unread
                NotificationManager.shared.setBadge(count: likesCount + messagesCount)
            }

        // Listen for unread messages across all chats
        startUnreadMessagesListener(uid: uid)
    }

    private func startUnreadMessagesListener(uid: String) {
        // We track unread by checking chats where the last message wasn't sent by us
        // and has no "readBy" entry for us. Simple version: count chats with messages
        // newer than the user's "lastSeenMessages" timestamp.
        //
        // Simple approach: count matches that have at least one message not from us
        // by listening to each chat document's "lastSenderID" field.
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument { snapshot, _ in
                guard let matchIDs = snapshot?.data()?["matches"] as? [String], !matchIDs.isEmpty else { return }

                var unread = 0
                let group = DispatchGroup()

                for matchID in matchIDs {
                    let chatID = [uid, matchID].sorted().joined(separator: "_")
                    group.enter()
                    Firestore.firestore()
                        .collection("chats")
                        .document(chatID)
                        .collection("messages")
                        .order(by: "timestamp", descending: true)
                        .limit(to: 1)
                        .getDocuments { snap, _ in
                            if let doc = snap?.documents.first,
                               let senderID = doc.data()["senderID"] as? String,
                               let readBy = doc.data()["readBy"] as? [String],
                               senderID != uid,
                               !readBy.contains(uid) {
                                unread += 1
                            } else if let doc = snap?.documents.first,
                                      let senderID = doc.data()["senderID"] as? String,
                                      senderID != uid,
                                      doc.data()["readBy"] == nil {
                                // No readBy field yet — treat as unread
                                unread += 1
                            }
                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    if selectedTab != "bubble" {
                        messagesCount = unread
                    }
                    NotificationManager.shared.setBadge(count: likesCount + messagesCount)
                }
            }
    }

    private func stopListeners() {
        userListener?.remove()
        messagesListener?.remove()
        NotificationManager.shared.scheduleEngagementReminder()
    }

    // MARK: - Badge Clearing

    private func clearBadgeForTab(_ tab: String) {
        switch tab {
        case "heart":
            likesCount = 0
        case "bubble":
            messagesCount = 0
        default:
            break
        }
        NotificationManager.shared.setBadge(count: likesCount + messagesCount)
    }
}

struct TabBarView_Preview: PreviewProvider {
    static var previews: some View {
        TabBarView()
    }
}
