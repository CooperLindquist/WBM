import SwiftUI

struct PremiumPromptView: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Header
                Text("Upgrade to WBM Premium")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.top, 40)

                Text("Get the most out of WBM with these exclusive perks:")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                // Features List
                VStack(alignment: .leading, spacing: 15) {
                    FeatureItem(icon: "heart.fill", text: "Unlimited Likes")
                    FeatureItem(icon: "diamond.fill", text: "More Diamonds")
                    FeatureItem(icon: "eye.fill", text: "See Who Liked You")
                    FeatureItem(icon: "star.fill", text: "Boost Your Profile")
                    FeatureItem(icon: "gobackward", text: "Unlimited Rewinds")
                }
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(15)
                .padding(.horizontal)

                Spacer()

                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: {
                        // Placeholder for purchase action
                    }) {
                        Text("Get Premium")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        // Placeholder for dismiss action
                    }) {
                        Text("Maybe Later")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .font(.title2)
            Text(text)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    PremiumPromptView()
}
