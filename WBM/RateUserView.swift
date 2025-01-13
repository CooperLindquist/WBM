import SwiftUI
import Firebase

struct RateUserView: View {
    let chatPartner: User
    @State private var trueToLooksRating: Int = 3
    @State private var personalityRating: Int = 3
    @State private var communicationRating: Int = 3
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
                Text("Rate \(chatPartner.name)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 2)

                ratingStars(title: "True to Looks", rating: $trueToLooksRating)
                ratingStars(title: "Personality", rating: $personalityRating)
                ratingStars(title: "Communication", rating: $communicationRating)

                Button(action: submitRatings) {
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

                Spacer()
            }
            .padding()
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
                // No previous ratings, create new data
                var newData: [String: Any] = [:]
                for (key, newRating) in ratings {
                    newData[key] = newRating
                    newData["\(key)Count"] = 1
                }
                Firestore.firestore().collection("stars").document(chatPartner.id).setData(newData)
            }

            presentationMode.wrappedValue.dismiss()
        }
    }
}
