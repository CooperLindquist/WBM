//
//  ProfileFeedCardView.swift
//  WBM
//
//  Hinge-style scrollable profile page for the home feed.
//  Photos and info sections are interspersed; a heart button sits on every
//  photo, and a persistent bottom bar (Pass / Like) is always available.
//  Pages page horizontally between people (see ProfileFeedView).
//

import SwiftUI
import SDWebImageSwiftUI
import CoreLocation

struct ProfileFeedCardView: View {
    let user: User
    let canApprove: Bool
    var currentUserLocation: CLLocation? = nil
    var onApprove: () -> Void
    var onSkip: () -> Void

    @State private var showOutOfDiamonds = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 14) {
                    // 1. First photo + name/age overlay
                    if let first = user.imageURLs[safe: 0] {
                        photo(url: first, isFirst: true)
                    }

                    quickFactsRow

                    // 2. Second photo
                    if let second = user.imageURLs[safe: 1] {
                        photo(url: second)
                    }

                    // 3. Bio
                    if let bio = user.bio, !bio.isEmpty {
                        infoSection(title: "About Me") {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    // 4. Third photo
                    if let third = user.imageURLs[safe: 2] {
                        photo(url: third)
                    }

                    // 5. Stats grid
                    statsGrid

                    // 6. Lifestyle & beliefs
                    if hasLifestyleInfo {
                        infoSection(title: "Lifestyle & Beliefs") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                if let religion = user.religion { statCard(icon: "sparkles", title: "Religion", value: religion) }
                                if let ethnicity = user.ethnicity { statCard(icon: "person.2.fill", title: "Ethnicity", value: ethnicity) }
                                if let smoking = user.smoking { statCard(icon: "leaf.fill", title: "Smoking", value: smoking) }
                                if let drinking = user.drinking { statCard(icon: "wineglass.fill", title: "Drinking", value: drinking) }
                            }
                        }
                    }

                    // 7. Any remaining photos
                    if user.imageURLs.count > 3 {
                        ForEach(user.imageURLs[3...], id: \.self) { url in
                            photo(url: url)
                        }
                    }

                    // 8. Ratings, if they have any
                    if hasRatings {
                        infoSection(title: "Ratings") {
                            VStack(spacing: 10) {
                                if let v = user.trueToLooksRating { ratingRow(label: "True to Looks", value: v) }
                                if let v = user.personalityRating { ratingRow(label: "Personality", value: v) }
                                if let v = user.communicationRating { ratingRow(label: "Communication", value: v) }
                            }
                        }
                    }

                    // End-of-profile spacer so the bottom bar never clips content
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    // MARK: - Photo with heart button

    private func photo(url: String, isFirst: Bool = false) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                WebImage(url: URL(string: url))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width * 5 / 4)
                    .clipped()

                if isFirst {
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(user.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let age = user.age {
                                Text(age)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(16)
                }

                heartButton
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: UIScreen.main.bounds.width * 5 / 4)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }

    private var heartButton: some View {
        Button(action: handleLikeTap) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(10)
                .background(Circle().fill(Color.black.opacity(0.4)))
        }
    }

    // MARK: - Quick facts pills

    private var quickFactsRow: some View {
        HStack(spacing: 10) {
            if let gender = user.gender { pill(icon: "person.fill", text: gender) }
            if let goal = user.relationshipGoal { pill(icon: "heart.fill", text: goal) }
            if let distance = distanceText { pill(icon: "location.fill", text: distance) }
            Spacer()
        }
    }

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

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            if let height = user.height, let formatted = formatHeight(height) {
                statCard(icon: "ruler.fill", title: "Height", value: formatted)
            }
            if let weight = user.weight {
                statCard(icon: "scalemass.fill", title: "Weight", value: "\(weight) lbs")
            }
            if let languages = user.languages, !languages.isEmpty {
                statCard(icon: "globe", title: "Languages", value: languages.joined(separator: ", "))
            }
            if let age = user.age {
                statCard(icon: "calendar", title: "Age", value: "\(age) years")
            }
        }
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 10) {
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

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3).fontWeight(.semibold).foregroundColor(.white)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .cornerRadius(18)
    }

    private func ratingRow(label: String, value: Double) -> some View {
        HStack {
            Text(label).foregroundColor(.white.opacity(0.9))
            Spacer()
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Image(systemName: i < Int(value.rounded()) ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
    }

    // MARK: - Bottom Bar (always available)

    private var bottomBar: some View {
        HStack(spacing: 24) {
            Button(action: onSkip) {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.red))
            }

            Button(action: handleLikeTap) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.green))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 30)
        .background(
            Capsule().fill(Color.black.opacity(0.55))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
        .padding(.bottom, 16)
        .overlay(alignment: .top) {
            if showOutOfDiamonds {
                Text("OUT OF DIAMONDS")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .offset(y: -38)
                    .transition(.opacity)
            }
        }
    }

    private func handleLikeTap() {
        if canApprove {
            onApprove()
        } else {
            withAnimation { showOutOfDiamonds = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { showOutOfDiamonds = false }
            }
        }
    }

    // MARK: - Helpers

    private var hasLifestyleInfo: Bool {
        user.religion != nil || user.ethnicity != nil || user.smoking != nil || user.drinking != nil
    }

    private var hasRatings: Bool {
        user.trueToLooksRating != nil || user.personalityRating != nil || user.communicationRating != nil
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
