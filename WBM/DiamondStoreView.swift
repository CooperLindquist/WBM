import SwiftUI
import GoogleMobileAds
import StoreKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - IAP Coordinator
// Uses SKPayment (StoreKit 1) to avoid the Product naming conflict with Firestore.
// Handles purchase callbacks via delegate and calls back into the view via closures.

class IAPCoordinator: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {

    static let shared = IAPCoordinator()
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    var onPurchaseSuccess: ((String) -> Void)?
    var onPurchaseFailed: ((Error?) -> Void)?
    private var products: [SKProduct] = []

    func fetchProducts(productIDs: [String]) {
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
        request.delegate = self
        request.start()
    }

    func buy(productID: String) {
        guard SKPaymentQueue.canMakePayments() else { return }
        if let product = products.first(where: { $0.productIdentifier == productID }) {
            SKPaymentQueue.default().add(SKPayment(product: product))
        } else {
            // Products not loaded yet — fetch then buy
            fetchProducts(productIDs: [productID])
            onPurchaseFailed?(nil)
        }
    }

    // SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products
    }

    // SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                onPurchaseSuccess?(transaction.payment.productIdentifier)
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                onPurchaseFailed?(transaction.error)
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}

// MARK: - Diamond Store View

struct DiamondStoreView: View {

    @State private var diamonds = 0
    @State private var rewardedAd: GADRewardedAd?
    @State private var navigateToBlackjack = false
    @State private var purchaseError: String? = nil
    @State private var showError = false
    @State private var diamondListener: ListenerRegistration?

    let packs: [DiamondPack] = [
        DiamondPack(id: 1, imageName: "bag.circle.fill", price: "$0.99",  amount: 100,   productID: "wbm_100_diamonds"),
        DiamondPack(id: 2, imageName: "bag.circle.fill", price: "$4.99",  amount: 2000,  productID: "wbm_2000_diamonds"),
        DiamondPack(id: 3, imageName: "bag.circle.fill", price: "$9.99",  amount: 13000, productID: "wbm_13000_diamonds")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

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
            .navigationDestination(isPresented: $navigateToBlackjack) {
                BlackJackView()
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseError ?? "Something went wrong. Please try again.")
            }
        }
        .onAppear {
            loadRewardedAd()
            startDiamondListener() // Fix #8: live listener instead of one-time fetch
            setupIAP()
        }
        .onDisappear {
            diamondListener?.remove()
        }
    }

    // MARK: - IAP Setup

    private func setupIAP() {
        IAPCoordinator.shared.fetchProducts(productIDs: packs.map { $0.productID })

        IAPCoordinator.shared.onPurchaseSuccess = { productID in
            guard let pack = packs.first(where: { $0.productID == productID }),
                  let uid = Auth.auth().currentUser?.uid else { return }

            Firestore.firestore().collection("users").document(uid)
                .updateData(["diamonds": FieldValue.increment(Int64(pack.amount))])

            DispatchQueue.main.async {
                diamonds += pack.amount
            }
        }

        IAPCoordinator.shared.onPurchaseFailed = { error in
            DispatchQueue.main.async {
                purchaseError = error?.localizedDescription ?? "Purchase could not be completed."
                showError = true
            }
        }
    }

    // MARK: - Ad Section

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

            Button { showRewardedAd() } label: {
                Text(rewardedAd == nil ? "Loading..." : "Watch")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(rewardedAd == nil ? Color.gray : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(rewardedAd == nil)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal)
    }

    // MARK: - Premium Section

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

    // MARK: - Packs Section

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
                ForEach(packs) { pack in
                    Button {
                        IAPCoordinator.shared.buy(productID: pack.productID)
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

    // MARK: - Diamonds

    func startDiamondListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Fix #8: snapshot listener keeps diamond count live — if user earns diamonds
        // in blackjack or another screen, the count here updates automatically
        diamondListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { doc, _ in
                DispatchQueue.main.async {
                    diamonds = doc?.data()?["diamonds"] as? Int ?? 0
                }
            }
    }

    // MARK: - Ads

    func loadRewardedAd() {
        GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-3940256099942544/5224354917",
            request: GADRequest()
        ) { ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ad load failed: \(error.localizedDescription)")
                    return
                }
                rewardedAd = ad
            }
        }
    }

    func showRewardedAd() {
        guard let ad = rewardedAd else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        ad.present(fromRootViewController: rootVC) {
            rewardedAd = nil
            loadRewardedAd()

            guard let uid = Auth.auth().currentUser?.uid else { return }
            Firestore.firestore().collection("users").document(uid)
                .updateData(["diamonds": FieldValue.increment(Int64(75))])
            DispatchQueue.main.async {
                diamonds += 75
            }
        }
    }
}

// MARK: - Diamond Pack Model

struct DiamondPack: Identifiable {
    let id: Int
    let imageName: String
    let price: String
    let amount: Int
    let productID: String
}
