//
//  UserCardView.swift
//  WBM
//
//  Redesigned swipe card. Two layers:
//   1. UserCardView — the "cover": full-bleed photo, name + age, tap-to-expand hint.
//   2. UserProfileDetailSheet — pulls up over the cover to show every profile field,
//      styled to match ProfileView's stat cards / pills so it feels like one app.
//

import SwiftUI
import SDWebImageSwiftUI
import CoreLocation

// MARK: - Cover Card

struct UserCardView: View {
    let user: User
    var onInfoTapped: () -> Void

    @State private var currentImageIndex = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                photoLayer(width: geo.size.width, height: geo.size.height)

                // Bottom frosted info bar — tap or swipe up to expand full profile
                VStack(spacing: 0) {
                    imageProgressDots
                        .padding(.bottom, 12)

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(user.name)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                if let age = user.age {
                                    Text(age)
                                        .font(.system(size: 22, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }

                            // Tiny hint row so it's obvious there's more to see
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.caption2)
                                Text("Tap the info button for more")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Button(action: onInfoTapped) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.25)).frame(width: 38, height: 38))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                }
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        }
    }

    private func photoLayer(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let imageUrl = user.imageURLs[safe: currentImageIndex] {
                WebImage(url: URL(string: imageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in handleImageTap(location: location, width: width) }
    }

    private var imageProgressDots: some View {
        HStack(spacing: 5) {
            ForEach(user.imageURLs.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: index == currentImageIndex ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentImageIndex)
            }
        }
    }

    private func handleImageTap(location: CGPoint, width: CGFloat) {
        if location.x < width / 2 {
            if currentImageIndex > 0 { currentImageIndex -= 1 }
        } else {
            if currentImageIndex < user.imageURLs.count - 1 { currentImageIndex += 1 }
        }
    }
}

// MARK: - Full Detail Sheet
// Slides up over the card. Styled to match ProfileView (StatsCard / pill language)
// so the swipe screen and the user's own profile screen feel like the same app.

struct UserProfileDetailSheet: View {
    let user: User
    var onDismiss: () -> Void
    var currentUserLocation: CLLocation? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Photo carousel up top
                TabView {
                    ForEach(user.imageURLs, id: \.self) { url in
                        WebImage(url: URL(string: url))
                            .resizable()
                            .scaledToFill()
                            .frame(height: 340)
                            .clipped()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 340)
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

                VStack(alignment: .leading, spacing: 22) {
                    // Name / age / quick pills — same pill language as ProfileView
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(user.name)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let age = user.age {
                                Text(age)
                                    .font(.system(size: 22, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        HStack(spacing: 10) {
                            if let gender = user.gender {
                                pill(icon: "person.fill", text: gender)
                            }
                            if let goal = user.relationshipGoal {
                                pill(icon: "heart.fill", text: goal)
                            }
                            if let distance = distanceText {
                                pill(icon: "location.fill", text: distance)
                            }
                        }
                    }

                    // Stats grid — mirrors ProfileView's StatsCard grid exactly
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                        if let height = user.height, let formatted = formatHeight(height) {
                            statsCard(icon: "ruler.fill", title: "Height", value: formatted)
                        }
                        if let weight = user.weight {
                            statsCard(icon: "scalemass.fill", title: "Weight", value: "\(weight) lbs")
                        }
                        if let languages = user.languages, !languages.isEmpty {
                            statsCard(icon: "globe", title: "Languages", value: languages.joined(separator: ", "))
                        }
                        if let age = user.age {
                            statsCard(icon: "calendar", title: "Age", value: "\(age) years")
                        }
                    }

                    // Lifestyle & Beliefs section — mirrors ProfileView
                    if user.religion != nil || user.ethnicity != nil || user.smoking != nil || user.drinking != nil {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Lifestyle & Beliefs")
                                .font(.title3).fontWeight(.semibold).foregroundColor(.white)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                                if let religion = user.religion {
                                    statsCard(icon: "sparkles", title: "Religion", value: religion)
                                }
                                if let ethnicity = user.ethnicity {
                                    statsCard(icon: "person.2.fill", title: "Ethnicity", value: ethnicity)
                                }
                                if let smoking = user.smoking {
                                    statsCard(icon: "leaf.fill", title: "Smoking", value: smoking)
                                }
                                if let drinking = user.drinking {
                                    statsCard(icon: "wineglass.fill", title: "Drinking", value: drinking)
                                }
                            }
                        }
                    }

                    // Bio
                    if let bio = user.bio, !bio.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About Me")
                                .font(.title3).fontWeight(.semibold).foregroundColor(.white)
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(15)
                    }
                }
                .padding(25)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .cornerRadius(30, corners: [.topLeft, .topRight])
                )
            }
        }
        .background(
            LinearGradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding()
        }
    }

    // MARK: - Reusable pieces (match ProfileView's visual language)

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(.white)
            Text(text).fontWeight(.medium).foregroundColor(.white)
        }
        .font(.subheadline)
        .padding(.vertical, 7)
        .padding(.horizontal, 13)
        .background(Color.white.opacity(0.2))
        .cornerRadius(20)
    }

    private func statsCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(.white).font(.title3)
                Text(title).font(.headline).foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            Text(value)
                .font(.body).fontWeight(.medium).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(15)
    }

    private var distanceText: String? {
        guard let myLocation = currentUserLocation, let theirLocation = user.location else { return nil }
        let other = CLLocation(latitude: theirLocation.latitude, longitude: theirLocation.longitude)
        let miles = myLocation.distance(from: other) / 1609.34
        return miles < 1 ? "< 1 mi away" : "\(Int(miles)) mi away"
    }

    private func formatHeight(_ height: String) -> String? {
        guard let totalInches = Int(height), totalInches > 0 else { return nil }
        let feet = totalInches / 12
        let inches = totalInches % 12
        return "\(feet)'\(inches)\""
    }
}
