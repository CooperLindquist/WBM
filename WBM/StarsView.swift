import SwiftUI
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI

struct Review: Identifiable, Hashable {
    var id = UUID() // Unique identifier
    var reviewerID: String
    var reviewText: String
    var isAnonymous: Bool
}

struct StarsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var ratings: [String: Double] = [:]
    @State private var reviews: [Review] = [] // Custom model for reviews
    @State private var userDetails: [String: (name: String, profileImageURL: String)] = [:] // Cache for user details

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            Text("Your Ratings")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Ratings Display
                        VStack(spacing: 15) {
                            if let trueToLooks = ratings["trueToLooks"] {
                                ratingRow(title: "True to Looks", value: trueToLooks)
                            }

                            if let personality = ratings["personality"] {
                                ratingRow(title: "Personality", value: personality)
                            }

                            if let communication = ratings["communication"] {
                                ratingRow(title: "Communication", value: communication)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.2))
                                .shadow(radius: 5)
                        )
                        .padding(.horizontal)

                        // Reviews Section
                        if !reviews.isEmpty {
                            Text("Written Reviews")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.top)

                            ForEach(reviews) { review in
                                reviewCard(review: review)
                            }
                        } else {
                            Text("No written reviews yet.")
                                .foregroundColor(.white.opacity(0.8))
                                .italic()
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: fetchRatingsAndReviews)
    }

    private func fetchRatingsAndReviews() {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true

        Firestore.firestore().collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching ratings and reviews: \(error.localizedDescription)")
                isLoading = false
                return
            }

            if let document = document, document.exists {
                if let data = document.data() {
                    ratings = [
                        "trueToLooks": data["trueToLooks"] as? Double ?? 0.0,
                        "personality": data["personality"] as? Double ?? 0.0,
                        "communication": data["communication"] as? Double ?? 0.0
                    ]

                    let rawReviews = data["reviews"] as? [[String: Any]] ?? []
                    reviews = rawReviews.compactMap { rawReview in
                        guard let reviewerID = rawReview["reviewerID"] as? String,
                              let reviewText = rawReview["review"] as? String,
                              let isAnonymous = rawReview["isAnonymous"] as? Bool else { return nil }

                        return Review(reviewerID: reviewerID, reviewText: reviewText, isAnonymous: isAnonymous)
                    }
                }
            }

            // Fetch details for non-anonymous reviewers
            fetchUserDetails()
        }
    }

    private func fetchUserDetails() {
        let nonAnonymousReviewers = reviews
            .filter { !$0.isAnonymous }
            .map { $0.reviewerID }

        let group = DispatchGroup()
        var fetchedDetails: [String: (name: String, profileImageURL: String)] = [:]

        for userID in nonAnonymousReviewers {
            group.enter()
            Firestore.firestore().collection("users").document(userID).getDocument { document, error in
                if let document = document, document.exists {
                    let name = document.data()?["name"] as? String ?? "User"
                    let profileImageURL = document.data()?["profileImageURLs"] as? String ?? ""
                    fetchedDetails[userID] = (name: name, profileImageURL: profileImageURL)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.userDetails = fetchedDetails
            self.isLoading = false
        }
    }

    private func ratingRow(title: String, value: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(String(format: "%.1f", value)) // Displays the accurate average as a number
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            HStack(spacing: 4) {
                // Displays stars, rounding down the value
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(value) ? "star.fill" : "star")
                        .foregroundColor(index < Int(value) ? .yellow : .gray)
                }
            }
            .font(.title3)
        }
        .padding(.horizontal)
    }

    private func reviewCard(review: Review) -> some View {
        let isAnonymous = review.isAnonymous
        let reviewerID = review.reviewerID
        let userDetails = self.userDetails[reviewerID]
        let displayName = isAnonymous ? "Anonymous" : (userDetails?.name ?? "User")

        return HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(review.reviewText)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true) // Allows multi-line reviews
            }
            Spacer() // Ensures the VStack content stays aligned to the left
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.2))
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }






}

#Preview {
    StarsView()
}
