import SwiftUI
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI

struct StarsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var ratings: [String: Double] = [:]

    var body: some View {
        ZStack {
            // Background Gradient Matching ProfileView
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
                VStack(spacing: 20) {
                    // Header with Back Button
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
                        Spacer() // Keeps title centered
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

                    Spacer()
                }
                .padding()
            }
        }
        .onAppear(perform: fetchRatings)
    }

    private func fetchRatings() {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true

        Firestore.firestore().collection("stars").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching star ratings: \(error.localizedDescription)")
                isLoading = false
                return
            }

            if let document = document, document.exists {
                ratings = document.data() as? [String: Double] ?? [:]
            }
            isLoading = false
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
}

#Preview {
    StarsView()
}
