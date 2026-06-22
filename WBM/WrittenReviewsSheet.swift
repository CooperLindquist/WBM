//
//  WrittenReviewsSheet.swift
//  WBM
//
//  Shown when someone taps "See written reviews" on a profile card.
//  Fetches the target user's `reviews` array on demand (not preloaded
//  into the User model, since most profiles won't be opened for this).
//

import SwiftUI
import FirebaseFirestore

struct WrittenReviewsSheet: View {
    let userID: String
    let userName: String
    var onDismiss: () -> Void

    @State private var reviews: [Review] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Reviews...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if reviews.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                        Text("No written reviews yet")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(reviews) { review in
                                reviewCard(review)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(userName)'s Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear { fetchReviews() }
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: review.isAnonymous ? "person.fill.questionmark" : "person.fill")
                    .foregroundColor(.white.opacity(0.85))
                Text(review.isAnonymous ? "Anonymous" : "WBM User")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            Text(review.text)
                .font(.body)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.15))
        .cornerRadius(15)
    }

    private func fetchReviews() {
        Firestore.firestore().collection("users").document(userID).getDocument { doc, error in
            defer { isLoading = false }
            guard let rawReviews = doc?.data()?["reviews"] as? [[String: Any]] else { return }
            reviews = rawReviews.compactMap { Review(data: $0) }
        }
    }
}
