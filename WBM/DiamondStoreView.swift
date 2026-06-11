import SwiftUI
import GoogleMobileAds
import StoreKit
import FirebaseAuth
import FirebaseFirestore

struct DiamondStoreView: View {

    @State private var diamonds = 0
    @State private var rewardedAd: GADRewardedAd?
    @State private var navigateToBlackjack = false

    var body: some View {

        NavigationView {

            ScrollView {

                VStack(spacing: 20) {

                    NavigationLink(destination: BlackJackView(), isActive: $navigateToBlackjack) {
                        EmptyView()
                    }
                    .hidden()

                    Text("Diamonds: \(diamonds) 💎")
                        .font(.title2)
                        .foregroundColor(.yellow)

                    Button {
                        navigateToBlackjack = true
                    } label: {
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

                    adSection

                    premiumSection

                    packsSection
                }
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [.black, .blue.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Diamond Store")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadRewardedAd()
            fetchDiamonds()
        }
    }
}

extension DiamondStoreView {

    var adSection: some View {

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

            Button {
                showRewardedAd()
            } label: {

                Text("Watch")
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
    }

    var premiumSection: some View {

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
    }

    var packsSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Packs of 💎")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.leading)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 15
            ) {

                ForEach(diamondPacks, id: \.id) { pack in

                    Button {

                        purchase(pack)

                    } label: {

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
            }
            .padding(.horizontal)
        }
    }
}

extension DiamondStoreView {

    var diamondPacks: [DiamondPack] {

        [
            DiamondPack(id: 1, imageName: "bag.circle.fill", price: "$0.99", amount: 100, productID: "wbm_100_diamonds"),
            DiamondPack(id: 2, imageName: "bag.circle.fill", price: "$4.99", amount: 2000, productID: "wbm_2000_diamonds"),
            DiamondPack(id: 3, imageName: "bag.circle.fill", price: "$9.99", amount: 13000, productID: "wbm_13000_diamonds")
        ]
    }
}

extension DiamondStoreView {

    func purchase(_ pack: DiamondPack) {

        Task {

            do {

                let products = try await Product.products(for: [pack.productID])

                guard let product = products.first else { return }

                let result = try await product.purchase()

                switch result {

                case .success(let verification):

                    switch verification {

                    case .verified(_):

                        addDiamonds(pack.amount)
                        print("Purchase successful")

                    case .unverified(_, _):

                        print("Purchase failed verification")
                    }

                case .pending:

                    print("Purchase pending")

                case .userCancelled:

                    print("User cancelled")

                default:
                    break
                }

            } catch {

                print("Purchase error: \(error)")
            }
        }
    }
}

extension DiamondStoreView {

    func fetchDiamonds() {

        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument { doc, _ in

                if let data = doc?.data(),
                   let value = data["diamonds"] as? Int {

                    diamonds = value
                }
            }
    }

    func addDiamonds(_ amount: Int) {

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)

        ref.updateData([
            "diamonds": FieldValue.increment(Int64(amount))
        ])

        diamonds += amount
    }
}

extension DiamondStoreView {

    func loadRewardedAd() {

        let request = GADRequest()

        GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-3940256099942544/5224354917",
            request: request
        ) { ad, error in

            if let error = error {

                print("Ad load failed:", error.localizedDescription)
                return
            }

            rewardedAd = ad
        }
    }

    func showRewardedAd() {

        guard let ad = rewardedAd else { return }

        ad.present(
            fromRootViewController: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()
        ) {

            addDiamonds(75)
        }
    }
}

struct DiamondPack {

    let id: Int
    let imageName: String
    let price: String
    let amount: Int
    let productID: String
}
