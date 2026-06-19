//
//  ProfileFeedView.swift
//  WBM
//
//  Pages horizontally between people (native page-turn animation via TabView),
//  while each person's content scrolls vertically inside ProfileFeedCardView.
//

import SwiftUI
import CoreLocation

struct ProfileFeedView: View {
    let users: [User]
    let canApprove: Bool
    var currentUserLocation: CLLocation? = nil
    var onApprove: (User) -> Void
    var onSkip: (User) -> Void

    /// Index into `users`. Bound from the parent so liking/passing can
    /// remove from the array while keeping the page position sane.
    @Binding var currentIndex: Int

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                ProfileFeedCardView(
                    user: user,
                    canApprove: canApprove,
                    currentUserLocation: currentUserLocation,
                    onApprove: { onApprove(user) },
                    onSkip: { onSkip(user) }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }
}
