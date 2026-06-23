//
//  MatchProfileCover.swift
//  WBM
//
//  Read-only version of the full profile card, used when viewing a match's
//  profile from inside an active chat. Skip/Like don't make sense here —
//  you're already matched — so this reuses ProfileFeedCardView's layout
//  but hides its bottom action bar entirely.
//

import SwiftUI

struct MatchProfileCover: View {
    let user: User
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ProfileFeedCardView(
                user: user,
                canApprove: false,
                onApprove: {},  // unused — action bar is hidden below
                onSkip: {},     // unused — action bar is hidden below
                showActionBar: false
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
