import SwiftUI
import GoogleMobileAds

struct DiamondStoreView: View {
    @State private var diamonds = 0 // Mock state variable for diamonds
    @State private var rewardedAd: GADRewardedAd? // Rewarded ad instance
    @State private var adLoadingError: String? // Optional error message
    @State private var navigateToBlackjack = false // State to navigate

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Navigate to Blackjack
                    NavigationLink(destination: BlackJackView(), isActive: $navigateToBlackjack) {
                        EmptyView()
                    }
                    .hidden()

                    Button(action: {
                        navigateToBlackjack = true
                    }) {
                        Text("Play Blackjack ♠️")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)

                    // Ad section
                    HStack {
                        Image(systemName: "tv.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Watch a video to get free gems")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Earn 75 💎")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                        Button(action: {
                            showRewardedAd()
                        }) {
                            Text("Watch a video")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    // Subscription section
                    VStack(spacing: 10) {
                        Text("WBM+ SUBSCRIPTION")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Exclusive perks and benefits")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Get more 💎 weekly")
                            Text("• Exclusive rewards")
                            Text("• And much more!")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                        NavigationLink(destination: PremiumPromptView()) {
                            Text("Go Premium")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(Color.pink)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.pink.opacity(0.9))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    // Packs section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Packs of 💎")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            ForEach(diamondPacks, id: \.id) { pack in
                                VStack {
                                    Image(systemName: pack.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.yellow)
                                    Text(pack.price)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("\(pack.amount) 💎")
                                        .font(.subheadline)
                                        .foregroundColor(.yellow)
                                }
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(LinearGradient(colors: [.black, .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle("Diamond Store")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadRewardedAd()
        }
    }

    // Mock diamond packs data
    var diamondPacks: [DiamondPack] {
        [
            DiamondPack(id: 1, imageName: "bag.circle.fill", price: "$1.99", amount: 2000),
            DiamondPack(id: 2, imageName: "bag.circle.fill", price: "$5.99", amount: 7200),
            DiamondPack(id: 3, imageName: "bag.circle.fill", price: "$9.99", amount: 13000),
            DiamondPack(id: 4, imageName: "bag.circle.fill", price: "$19.99", amount: 27000),
            DiamondPack(id: 5, imageName: "bag.circle.fill", price: "$29.99", amount: 42000),
            DiamondPack(id: 6, imageName: "bag.circle.fill", price: "$39.99", amount: 60000),
        ]
    }

    // Load rewarded ad
    private func loadRewardedAd() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: "ca-app-pub-3940256099942544/5224354917", request: request) { ad, error in
            if let error = error {
                adLoadingError = "Failed to load ad: \(error.localizedDescription)"
                return
            }
            rewardedAd = ad
            rewardedAd?.fullScreenContentDelegate = RewardedAdDelegate()
        }
    }

    // Show rewarded ad
    private func showRewardedAd() {
        if let ad = rewardedAd {
            ad.present(fromRootViewController: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()) {
                // Reward the user with diamonds
                diamonds += 75
            }
        } else {
            print(adLoadingError ?? "Ad is not ready yet")
        }
    }
}

// Data model for diamond packs
struct DiamondPack {
    let id: Int
    let imageName: String
    let price: String
    let amount: Int
}

// Delegate for ad lifecycle events
class RewardedAdDelegate: NSObject, GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad dismissed, loading a new one.")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present ad: \(error.localizedDescription)")
    }
}

struct DiamondStoreView_Previews: PreviewProvider {
    static var previews: some View {
        DiamondStoreView()
    }
}
