//
//  SubscriptionManager.swift
//  WBM
//
//  Central source of truth for subscription state.
//  Uses StoreKit 2 (async/await) for receipt validation and
//  writes the resolved tier to Firestore so server-side logic
//  (swipe algorithm, spotlight, etc.) can read it without
//  re-verifying the receipt on every request.
//
//  Usage:
//    await SubscriptionManager.shared.refresh()
//    let tier = SubscriptionManager.shared.currentTier   // .none / .silver / .gold / .diamond
//    if SubscriptionManager.shared.currentTier >= .gold { … }
//

import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Subscription Tier

enum SubscriptionTier: Int, Comparable, CaseIterable {
    case none    = 0
    case silver  = 1
    case gold    = 2
    case diamond = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .none:    return "Free"
        case .silver:  return "Silver"
        case .gold:    return "Gold"
        case .diamond: return "Diamond"
        }
    }

    // Firestore field value (also written to user doc)
    var firestoreValue: String { displayName.lowercased() }

    // ── Per-tier feature limits ──────────────────────────────────────────────

    /// Daily likes before hitting the paywall (nil = unlimited)
    var dailyLikeLimit: Int? {
        switch self {
        case .none:    return 20
        case .silver:  return 100
        case .gold:    return nil
        case .diamond: return nil
        }
    }

    /// Blackjack hands allowed per day (nil = unlimited)
    var blackjackHandLimit: Int? {
        switch self {
        case .none:    return 3
        case .silver:  return 10
        case .gold:    return nil
        case .diamond: return nil
        }
    }

    /// Free diamonds awarded each week
    var weeklyDiamondBonus: Int {
        switch self {
        case .none:    return 0
        case .silver:  return 100
        case .gold:    return 300
        case .diamond: return 750
        }
    }

    /// Whether the user can see who liked them
    var canSeeWhoLikedThem: Bool {
        switch self {
        case .none, .silver: return false
        case .gold, .diamond: return true
        }
    }

    /// Whether profile boosts (Spotlight) are included
    var includedSpotlightsPerWeek: Int {
        switch self {
        case .none:    return 0
        case .silver:  return 1
        case .gold:    return 3
        case .diamond: return 7   // daily
        }
    }

    /// Whether the "super like" / priority send feature is unlocked
    var hasSuperLikes: Bool { self >= .gold }

    /// Read receipts in chat
    var hasReadReceipts: Bool { self >= .gold }

    /// Advanced filters (height, religion, ethnicity, etc.)
    var hasAdvancedFilters: Bool { self >= .silver }

    /// Profile badge visible to other users
    var badgeImageName: String? {
        switch self {
        case .none:    return nil
        case .silver:  return "medal.fill"       // SF Symbol
        case .gold:    return "star.fill"
        case .diamond: return "diamond.fill"
        }
    }

    var badgeColor: String {
        switch self {
        case .none:    return "#FFFFFF"
        case .silver:  return "#C0C0C0"
        case .gold:    return "#FFD700"
        case .diamond: return "#B9F2FF"
        }
    }
}

// MARK: - Product ID Registry

struct WBMProductIDs {
    // Silver
    static let silverWeekly  = "wbm_silver_weekly"
    static let silverMonthly = "wbm_silver_monthly"
    static let silverYearly  = "wbm_silver_yearly"

    // Gold
    static let goldWeekly    = "wbm_gold_weekly"
    static let goldMonthly   = "wbm_gold_monthly"
    static let goldYearly    = "wbm_gold_yearly"

    // Diamond
    static let diamondWeekly  = "wbm_diamond_weekly"
    static let diamondMonthly = "wbm_diamond_monthly"
    static let diamondYearly  = "wbm_diamond_yearly"

    // Diamond packs (consumables – unchanged)
    static let pack50    = "wbm_50_diamonds"
    static let pack100   = "wbm_100_diamonds"
    static let pack200   = "wbm_200_diamonds"
    static let pack500   = "wbm_500_diamonds"

    // All subscription product IDs grouped by tier
    static let silverIDs:  Set<String> = [silverWeekly,  silverMonthly,  silverYearly]
    static let goldIDs:    Set<String> = [goldWeekly,    goldMonthly,    goldYearly]
    static let diamondIDs: Set<String> = [diamondWeekly, diamondMonthly, diamondYearly]

    static let allSubscriptionIDs: [String] = Array(silverIDs) + Array(goldIDs) + Array(diamondIDs)
}

// MARK: - SubscriptionManager

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()
    private init() {}

    // ── Published state ──────────────────────────────────────────────────────
    @Published private(set) var currentTier: SubscriptionTier = .none
    @Published private(set) var isLoading = false

    // Cache the SK2 products so PremiumPromptView can read prices
    @Published private(set) var products: [Product] = []

    // ── Refresh ──────────────────────────────────────────────────────────────

    /// Call on app launch, foreground, and after a purchase.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let resolved = await resolveCurrentTier()
        currentTier = resolved

        // Keep Firestore in sync so server-side features (swipe boost, etc.)
        // can gate on subscriptionTier without re-checking receipts.
        if let uid = Auth.auth().currentUser?.uid {
            try? await Firestore.firestore()
                .collection("users").document(uid)
                .updateData([
                    "subscriptionTier": resolved.firestoreValue,
                    "premium": resolved > .none          // keep legacy bool
                ])
        }
    }

    /// Fetch StoreKit 2 products for display in the paywall.
    func fetchProducts() async {
        do {
            products = try await Product.products(for: WBMProductIDs.allSubscriptionIDs)
        } catch {
            print("SubscriptionManager: fetchProducts error – \(error)")
        }
    }

    /// Returns the product for a given product ID (for display/price).
    func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    // ── Purchase ─────────────────────────────────────────────────────────────

    /// Purchase a subscription. Returns true on success.
    @discardableResult
    func purchase(productID: String) async throws -> Bool {
        guard let product = product(for: productID) else {
            // Products not loaded yet – fetch and retry once
            await fetchProducts()
            guard let product = product(for: productID) else {
                throw SubscriptionError.productNotFound
            }
            return try await doPurchase(product)
        }
        return try await doPurchase(product)
    }

    private func doPurchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified = verification else { throw SubscriptionError.verificationFailed }
            await refresh()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Restore previous purchases.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private func resolveCurrentTier() async -> SubscriptionTier {
        var best: SubscriptionTier = .none

        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil,
                  tx.productType == .autoRenewable else { continue }

            let tier = tierForProductID(tx.productID)
            if tier > best { best = tier }
        }
        return best
    }

    private func tierForProductID(_ id: String) -> SubscriptionTier {
        if WBMProductIDs.diamondIDs.contains(id) { return .diamond }
        if WBMProductIDs.goldIDs.contains(id)    { return .gold    }
        if WBMProductIDs.silverIDs.contains(id)  { return .silver  }
        return .none
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:     return "Could not find that subscription. Please try again."
        case .verificationFailed:  return "Purchase verification failed. Please contact support."
        }
    }
}
