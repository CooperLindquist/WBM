//
//  ProfilePreviewTile.swift
//  WBM
//
//  Shared grid-preview tile used by LikesView and SpotlightView.
//  Tapping opens the full Hinge-style ProfileFeedCardView.
//

import SwiftUI
import SDWebImageSwiftUI

struct ProfilePreviewTile: View {
    let user: User
    var badge: String? = nil // e.g. "⭐ Spotlight" — optional small tag

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WebImage(url: URL(string: user.imageURLs.first ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(8)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let age = user.age {
                        Text(age)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}
