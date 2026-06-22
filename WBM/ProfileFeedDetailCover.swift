//
//  ProfileFeedDetailCover.swift
//  WBM
//
//  Shared full-screen cover used by LikesView and SpotlightView when a grid
//  tile is tapped. Shows the same Hinge-style scrollable profile used on the
//  home feed (ProfileFeedCardView), with skip/like wired to that screen's
//  own logic via closures.
//

import SwiftUI

struct ProfileFeedDetailCover: View {
    let user: User
    var onClose: () -> Void
    var onSkip: (User) -> Void
    var onApprove: (User) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ProfileFeedCardView(
                user: user,
                canApprove: true, // these flows (likes/spotlight) don't spend diamonds
                onApprove: { onApprove(user) },
                onSkip: { onSkip(user) }
            )

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
