import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

struct StarsView: View {
    @State private var isLoading = true
    @State private var ratings: [String: Double] = [:]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                VStack(spacing: 20) {
                    Text("Your Ratings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 2)

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
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 4) {
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
