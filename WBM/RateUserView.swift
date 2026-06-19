import SwiftUI
import Firebase
import FirebaseAuth

struct RateUserView: View {
    let chatPartner: User
    @State private var trueToLooksRating: Int = 3
    @State private var personalityRating: Int = 3
    @State private var communicationRating: Int = 3
    @State private var writtenReview: String = ""
    @State private var isAnonymous: Bool = false
    @State private var showAlert: Bool = false
    @State private var hasRated: Bool = false
    @State private var hasReviewed: Bool = false

    // Fix #3: use Firebase Auth directly, never AppStorage
    private var currentUserID: String { Auth.auth().currentUser?.uid ?? "" }

    // Fix #11: use modern @Environment(\.dismiss)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea() // Fix #13

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(.leading)
                        }
                        Spacer()
                    }

                    Text("Rate \(chatPartner.name)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 2)

                    if hasRated {
                        Text("You have already rated this user.")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        ratingStars(title: "True to Looks",  rating: $trueToLooksRating)
                        ratingStars(title: "Personality",    rating: $personalityRating)
                        ratingStars(title: "Communication",  rating: $communicationRating)

                        Button(action: { showAlert = true }) {
                            Text("Submit Ratings")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal)
                    }

                    Divider().background(Color.white)

                    if hasReviewed {
                        Text("You have already submitted a written review.")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Write a Review (100 words max)")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            TextEditor(text: $writtenReview)
                                .frame(height: 100)
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 5)
                                .onChange(of: writtenReview) { _ in limitReviewText() }

                            Toggle("Submit Anonymously", isOn: $isAnonymous)
                                .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                                .foregroundColor(.white)
                                .padding(.top, 10)

                            Button(action: submitWrittenReview) {
                                Text("Submit Review")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .alert("Submit Rating", isPresented: $showAlert) {
            Button("Yes", action: submitRatings)
            Button("No", role: .cancel) {}
        } message: {
            Text("Once you submit a rating, you cannot change it.")
        }
        .onAppear {
            checkIfUserHasRated()
            checkIfUserHasReviewed()
        }
    }

    private func ratingStars(title: String, rating: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            HStack {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating.wrappedValue ? "star.fill" : "star")
                        .foregroundColor(star <= rating.wrappedValue ? .yellow : .gray)
                        .onTapGesture { rating.wrappedValue = star }
                        .font(.largeTitle)
                }
            }
        }
        .padding(.horizontal)
    }

    private func submitRatings() {
        guard !currentUserID.isEmpty else { return }

        let ratings: [String: Double] = [
            "trueToLooks":    Double(trueToLooksRating),
            "personality":    Double(personalityRating),
            "communication":  Double(communicationRating)
        ]

        let partnerRef = Firestore.firestore().collection("users").document(chatPartner.id)

        partnerRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user ratings: \(error.localizedDescription)")
                return
            }

            let existingData = document?.data() ?? [:]
            var updates: [String: Any] = [:]

            for (key, newRating) in ratings {
                let currentAvg = existingData[key] as? Double ?? 0.0
                let count      = existingData["\(key)Count"] as? Int ?? 0
                let newAvg     = ((currentAvg * Double(count)) + newRating) / Double(count + 1)
                updates[key]              = newAvg
                updates["\(key)Count"]   = count + 1
            }

            // Fix: use updateData with merge so we never overwrite the whole document
            partnerRef.updateData(updates)

            Firestore.firestore()
                .collection("ratingsSubmitted")
                .document("\(chatPartner.id)_\(currentUserID)")
                .setData(["hasRated": true])

            hasRated = true
        }
    }

    private func submitWrittenReview() {
        guard !currentUserID.isEmpty else { return }

        let reviewData: [String: Any] = [
            "review":     writtenReview,
            "isAnonymous": isAnonymous,
            "reviewerID": currentUserID
        ]

        Firestore.firestore().collection("users").document(chatPartner.id)
            .updateData(["reviews": FieldValue.arrayUnion([reviewData])]) { error in
                if let error = error {
                    print("Error submitting review: \(error.localizedDescription)")
                    return
                }

                Firestore.firestore()
                    .collection("reviewsSubmitted")
                    .document("\(chatPartner.id)_\(currentUserID)")
                    .setData(["hasReviewed": true])

                hasReviewed = true
            }
    }

    private func checkIfUserHasRated() {
        guard !currentUserID.isEmpty else { return }
        Firestore.firestore()
            .collection("ratingsSubmitted")
            .document("\(chatPartner.id)_\(currentUserID)")
            .getDocument { doc, _ in hasRated = doc?.exists == true }
    }

    private func checkIfUserHasReviewed() {
        guard !currentUserID.isEmpty else { return }
        Firestore.firestore()
            .collection("reviewsSubmitted")
            .document("\(chatPartner.id)_\(currentUserID)")
            .getDocument { doc, _ in hasReviewed = doc?.exists == true }
    }

    private func limitReviewText() {
        let words = writtenReview.split { $0.isWhitespace }
        if words.count > 100 {
            writtenReview = words.prefix(100).joined(separator: " ")
        }
    }
}
