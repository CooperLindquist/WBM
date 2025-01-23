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
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("userID") private var currentUserID: String = "" // Assumes current user ID is stored locally.

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
                        ratingStars(title: "True to Looks", rating: $trueToLooksRating)
                        ratingStars(title: "Personality", rating: $personalityRating)
                        ratingStars(title: "Communication", rating: $communicationRating)

                        Button(action: {
                            showAlert = true
                        }) {
                            Text("Submit Ratings")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .background(Color.white)

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
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                .onChange(of: writtenReview) { _ in
                                    limitReviewText()
                                }

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
                                    .cornerRadius(10)
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Submit Rating"),
                message: Text("Are you sure you want to submit this rating? Once you submit a rating, you cannot change it."),
                primaryButton: .default(Text("Yes"), action: submitRatings),
                secondaryButton: .cancel(Text("No"))
            )
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                    currentUserID = user.uid
                }
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
                        .onTapGesture {
                            rating.wrappedValue = star
                        }
                        .font(.largeTitle)
                }
            }
        }
        .padding(.horizontal)
    }

    private func submitRatings() {
        let ratings = [
            "trueToLooks": Double(trueToLooksRating),
            "personality": Double(personalityRating),
            "communication": Double(communicationRating)
        ]

        Firestore.firestore().collection("users").document(chatPartner.id).getDocument { document, error in
            if let error = error {
                print("Error fetching user ratings: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists, var data = document.data() {
                for (key, newRating) in ratings {
                    let currentAvg = data[key] as? Double ?? 0.0
                    let count = data["\(key)Count"] as? Int ?? 0
                    let updatedAvg = ((currentAvg * Double(count)) + newRating) / Double(count + 1)
                    data[key] = updatedAvg
                    data["\(key)Count"] = count + 1
                }
                Firestore.firestore().collection("users").document(chatPartner.id).setData(data)
            } else {
                var newData: [String: Any] = [:]
                for (key, newRating) in ratings {
                    newData[key] = newRating
                    newData["\(key)Count"] = 1
                }
                Firestore.firestore().collection("users").document(chatPartner.id).setData(newData)
            }

            Firestore.firestore().collection("ratingsSubmitted").document("\(chatPartner.id)_\(currentUserID)").setData([
                "hasRated": true
            ])

            hasRated = true
        }
    }

    private func submitWrittenReview() {
        guard !currentUserID.isEmpty else {
            print("Error: currentUserID is empty")
            return // Handle error, maybe show an alert to the user
        }

        let reviewData: [String: Any] = [
            "review": writtenReview,
            "isAnonymous": isAnonymous,
            "reviewerID": currentUserID // This ensures reviewerID is correctly set
        ]

        Firestore.firestore().collection("users").document(chatPartner.id).updateData([
            "reviews": FieldValue.arrayUnion([reviewData])
        ]) { error in
            if let error = error {
                print("Error submitting review: \(error.localizedDescription)")
                return
            }

            Firestore.firestore().collection("reviewsSubmitted").document("\(chatPartner.id)_\(currentUserID)").setData([
                "hasReviewed": true
            ])

            hasReviewed = true
        }
    }


    private func checkIfUserHasRated() {
        Firestore.firestore().collection("ratingsSubmitted").document("\(chatPartner.id)_\(currentUserID)").getDocument { document, error in
            if let error = error {
                print("Error checking rating status: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                hasRated = true
            }
        }
    }

    private func checkIfUserHasReviewed() {
        Firestore.firestore().collection("reviewsSubmitted").document("\(chatPartner.id)_\(currentUserID)").getDocument { document, error in
            if let error = error {
                print("Error checking review status: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                hasReviewed = true
            }
        }
    }

    private func limitReviewText() {
        let wordLimit = 100
        let words = writtenReview.split { $0.isWhitespace }
        if words.count > wordLimit {
            writtenReview = words.prefix(wordLimit).joined(separator: " ")
        }
    }
}
