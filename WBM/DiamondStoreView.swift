import SwiftUI
import GoogleMobileAds
import StoreKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - IAP Coordinator
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
            fetchProducts(productIDs: [productID])
            onPurchaseFailed?(nil)
        }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products
    }

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

// MARK: - Ad Load State
enum AdLoadState {
    case loading
    case ready
    case failed
}

// MARK: - Rewarded Ad Delegate
// GADFullScreenContentDelegate is the correct modern way to receive ad events.
// We use a class (not a struct) because GMA SDK holds a weak reference to the delegate.
class RewardedAdDelegate: NSObject, GADFullScreenContentDelegate {
    private let onReward: () -> Void
    private let onDismiss: (() -> Void)?

    init(onReward: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.onReward = onReward
        self.onDismiss = onDismiss
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismiss?()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("RewardedAd failed to present: \(error.localizedDescription)")
    }
}

// MARK: - Diamond Store View

struct DiamondStoreView: View {

    @State private var diamonds = 0
    @State private var rewardedAd: GADRewardedAd?
    @State private var adDelegate: RewardedAdDelegate?   // retain delegate for ad lifetime
    @State private var adState: AdLoadState = .loading
    @State private var adRetryCount = 0
    @State private var navigateToBlackjack = false
    @State private var purchaseError: String? = nil
    @State private var showError = false
    @State private var diamondListener: ListenerRegistration?

    private let maxAdRetries = 3
    private let retryDelays: [Double] = [2, 4, 8]

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
            startDiamondListener()
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

            Button {
                switch adState {
                case .ready:   showRewardedAd()
                case .failed:  retryAdLoad()
                case .loading: break
                }
            } label: {
                Text(adButtonLabel)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(adButtonColor)
                    .cornerRadius(8)
            }
            .disabled(adState == .loading)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal)
    }

    private var adButtonLabel: String {
        switch adState {
        case .loading: return "Loading..."
        case .ready:   return "Watch"
        case .failed:  return "Retry"
        }
    }

    private var adButtonColor: Color {
        switch adState {
        case .loading: return .gray
        case .ready:   return .blue
        case .failed:  return .orange
        }
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
        diamondListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { doc, _ in
                DispatchQueue.main.async {
                    diamonds = doc?.data()?["diamonds"] as? Int ?? 0
                }
            }
    }

    // MARK: - Ads

    func loadRewardedAd() {
        adRetryCount = 0
        adState = .loading
        attemptAdLoad()
    }

    private func retryAdLoad() {
        adRetryCount = 0
        adState = .loading
        attemptAdLoad()
    }

    private func attemptAdLoad() {
        GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-3940256099942544/5224354917",
            request: GADRequest()
        ) { ad, error in
            DispatchQueue.main.async {
                if let ad = ad {
                    rewardedAd = ad
                    adState = .ready
                    adRetryCount = 0
                    return
                }

                print("Ad load failed (attempt \(adRetryCount + 1)): \(error?.localizedDescription ?? "unknown")")

                if adRetryCount < maxAdRetries {
                    let delay = retryDelays[min(adRetryCount, retryDelays.count - 1)]
                    adRetryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attemptAdLoad()
                    }
                } else {
                    adState = .failed
                }
            }
        }
    }

    // MARK: - Show Rewarded Ad (FIXED)

    /// Walks the VC hierarchy to find the topmost presented controller.
    /// GMA requires you present from the VC that is currently on top —
    /// passing a VC that is already presenting something else causes the
    /// "already presenting another view controller" error.
    private func topmostViewController(_ base: UIViewController) -> UIViewController {
        if let presented = base.presentedViewController {
            return topmostViewController(presented)
        }
        if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
            return topmostViewController(visible)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topmostViewController(selected)
        }
        return base
    }

    func showRewardedAd() {
        guard let ad = rewardedAd else {
            print("showRewardedAd: no ad loaded")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.keyWindow?.rootViewController else {
            print("showRewardedAd: could not resolve rootViewController")
            return
        }
        // Walk up to the topmost VC so GMA does not complain about an already-presenting VC
        let rootVC = topmostViewController(root)

        // FIX 2: Use GADFullScreenContentDelegate to receive reward callbacks.
        // The old trailing-closure pattern (ad.present { reward }) no longer reliably fires.
        let delegate = RewardedAdDelegate(
            onReward: {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                Firestore.firestore().collection("users").document(uid)
                    .updateData(["diamonds": FieldValue.increment(Int64(75))])
                DispatchQueue.main.async {
                    diamonds += 75
                }
            },
            onDismiss: {
                DispatchQueue.main.async {
                    rewardedAd = nil
                    adDelegate = nil
                    loadRewardedAd() // pre-load next ad after dismissal
                }
            }
        )

        // Retain delegate — GMA SDK holds only a weak reference
        adDelegate = delegate
        ad.fullScreenContentDelegate = delegate

        // FIX 3: userDidEarnRewardHandler is the correct modern present API.
        // Pass the reward logic here; GMA calls this closure when the user earns the reward.
        ad.present(fromRootViewController: rootVC) {
            let rewardAmount = ad.adReward.amount.int64Value
            guard let uid = Auth.auth().currentUser?.uid else { return }
            Firestore.firestore().collection("users").document(uid)
                .updateData(["diamonds": FieldValue.increment(rewardAmount)])
            DispatchQueue.main.async {
                diamonds += Int(rewardAmount)
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
