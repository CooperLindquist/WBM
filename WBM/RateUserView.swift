import SwiftUI
import Firebase

struct RateUserView: View {
    let chatPartner: User
    @State private var trueToLooksRating: Int = 3
    @State private var personalityRating: Int = 3
    @State private var communicationRating: Int = 3
    @State private var showAlert: Bool = false
    @State private var hasRated: Bool = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.orange.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

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

                Spacer()
            }
            .padding()
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
            checkIfUserHasRated()
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

        Firestore.firestore().collection("stars").document(chatPartner.id).getDocument { document, error in
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
                Firestore.firestore().collection("stars").document(chatPartner.id).setData(data)
            } else {
                var newData: [String: Any] = [:]
                for (key, newRating) in ratings {
                    newData[key] = newRating
                    newData["\(key)Count"] = 1
                }
                Firestore.firestore().collection("stars").document(chatPartner.id).setData(newData)
            }

            Firestore.firestore().collection("ratingsSubmitted").document(chatPartner.id).setData([
                "hasRated": true
            ])

            hasRated = true
        }
    }

    private func checkIfUserHasRated() {
        Firestore.firestore().collection("ratingsSubmitted").document(chatPartner.id).getDocument { document, error in
            if let error = error {
                print("Error checking rating status: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                hasRated = true
            }
        }
    }
}
