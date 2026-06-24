//
//  PremiumPromptView.swift
//  WBM
//
//  Full paywall UI for the 3-tier subscription system.
//  Displays Silver / Gold / Diamond tiers with weekly / monthly / yearly
//  billing options and discount badges.
//

import SwiftUI
import StoreKit

// MARK: - Billing Period

enum BillingPeriod: String, CaseIterable, Identifiable {
    case weekly  = "Weekly"
    case monthly = "Monthly"
    case yearly  = "Yearly"
    var id: String { rawValue }

    func productID(for tier: TierConfig) -> String {
        switch self {
        case .weekly:  return tier.weeklyProductID
        case .monthly: return tier.monthlyProductID
        case .yearly:  return tier.yearlyProductID
        }
    }

    var discountLabel: String? {
        switch self {
        case .weekly:  return nil
        case .monthly: return "Save ~35%"
        case .yearly:  return "Best Value"
        }
    }
}

// MARK: - Tier Config (static display data)

struct TierConfig: Identifiable {
    let id: String
    let tier: SubscriptionTier
    let accentColor: Color
    let gradientColors: [Color]
    let weeklyProductID: String
    let monthlyProductID: String
    let yearlyProductID: String
    /// Base weekly price used to show monthly/yearly savings
    let weeklyBasePrice: Double
    let monthlyPrice: Double
    let yearlyPrice: Double
    let perks: [String]

    // Convenience: formatted price strings (before StoreKit prices load)
    var fallbackWeeklyLabel:  String { "$\(String(format: "%.2f", weeklyBasePrice))/wk" }
    var fallbackMonthlyLabel: String { "$\(String(format: "%.2f", monthlyPrice))/mo" }
    var fallbackYearlyLabel:  String { "$\(String(format: "%.2f", yearlyPrice))/yr" }
}

private let tierConfigs: [TierConfig] = [
    TierConfig(
        id: "silver",
        tier: .silver,
        accentColor: Color(hex: "#C0C0C0"),
        gradientColors: [Color(hex: "#6C6C6C"), Color(hex: "#C0C0C0")],
        weeklyProductID:  WBMProductIDs.silverWeekly,
        monthlyProductID: WBMProductIDs.silverMonthly,
        yearlyProductID:  WBMProductIDs.silverYearly,
        weeklyBasePrice: 2.99,
        monthlyPrice: 7.99,
        yearlyPrice: 59.99,
        perks: [
            "100 free 💎 every week",
            "Up to 100 likes per day",
            "10 blackjack hands/day",
            "1 Spotlight boost/week",
            "Advanced filters",
            "Silver badge on profile"
        ]
    ),
    TierConfig(
        id: "gold",
        tier: .gold,
        accentColor: Color(hex: "#FFD700"),
        gradientColors: [Color(hex: "#B8860B"), Color(hex: "#FFD700")],
        weeklyProductID:  WBMProductIDs.goldWeekly,
        monthlyProductID: WBMProductIDs.goldMonthly,
        yearlyProductID:  WBMProductIDs.goldYearly,
        weeklyBasePrice: 5.99,
        monthlyPrice: 14.99,
        yearlyPrice: 109.99,
        perks: [
            "300 free 💎 every week",
            "Unlimited likes",
            "Unlimited blackjack",
            "3 Spotlight boosts/week",
            "See who liked you 👀",
            "Super likes ⭐",
            "Read receipts in chat",
            "Gold badge on profile"
        ]
    ),
    TierConfig(
        id: "diamond",
        tier: .diamond,
        accentColor: Color(hex: "#B9F2FF"),
        gradientColors: [Color(hex: "#0077B6"), Color(hex: "#B9F2FF")],
        weeklyProductID:  WBMProductIDs.diamondWeekly,
        monthlyProductID: WBMProductIDs.diamondMonthly,
        yearlyProductID:  WBMProductIDs.diamondYearly,
        weeklyBasePrice: 9.99,
        monthlyPrice: 24.99,
        yearlyPrice: 179.99,
        perks: [
            "750 free 💎 every week",
            "Unlimited everything",
            "Daily Spotlight boost 🔥",
            "See who liked you 👀",
            "Super likes ⭐",
            "Read receipts in chat",
            "Priority in swipe feed",
            "Diamond badge on profile",
            "Early access to new features"
        ]
    )
]

// MARK: - PremiumPromptView

struct PremiumPromptView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SubscriptionManager.shared

    @State private var selectedPeriod: BillingPeriod = .monthly
    @State private var selectedTierID: String = "gold"     // default highlighted tier
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color(hex: "#0A0A2E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        billingToggle
                        tierCards
                        currentTierBanner
                        restoreButton
                        legalFooter
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseError ?? "Something went wrong. Please try again.")
            }
            .alert("You're all set! 🎉", isPresented: $showSuccess) {
                Button("Let's Go!", role: .cancel) { dismiss() }
            } message: {
                Text("Your \(manager.currentTier.displayName) subscription is now active.")
            }
        }
        .task {
            await manager.fetchProducts()
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("💎 WBM Premium")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Choose the plan that fits you.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }

    // MARK: Billing Period Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            ForEach(BillingPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedPeriod == period ? .black : .white)
                        if let label = period.discountLabel {
                            Text(label)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(selectedPeriod == period ? .black.opacity(0.7) : .green)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedPeriod == period
                            ? Color.white
                            : Color.white.opacity(0.1)
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: Tier Cards

    private var tierCards: some View {
        VStack(spacing: 16) {
            ForEach(tierConfigs) { config in
                TierCard(
                    config: config,
                    period: selectedPeriod,
                    isSelected: selectedTierID == config.id,
                    isCurrentPlan: manager.currentTier == config.tier,
                    isPurchasing: isPurchasing && selectedTierID == config.id,
                    priceLabel: priceLabel(for: config, period: selectedPeriod)
                ) {
                    selectedTierID = config.id
                    Task { await purchase(config: config) }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Current Tier Banner

    @ViewBuilder
    private var currentTierBanner: some View {
        if manager.currentTier > .none {
            HStack {
                Image(systemName: manager.currentTier.badgeImageName ?? "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Current plan: \(manager.currentTier.displayName)")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(.horizontal)
        }
    }

    // MARK: Restore

    private var restoreButton: some View {
        Button {
            Task {
                isPurchasing = true
                await manager.restore()
                isPurchasing = false
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: Legal Footer

    private var legalFooter: some View {
        Text("Subscriptions auto-renew until cancelled. Cancel any time in your App Store settings. Prices may vary by region.")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
    }

    // MARK: Helpers

    private func priceLabel(for config: TierConfig, period: BillingPeriod) -> String {
        let productID = period.productID(for: config)
        if let product = manager.product(for: productID) {
            return product.displayPrice
        }
        switch period {
        case .weekly:  return config.fallbackWeeklyLabel
        case .monthly: return config.fallbackMonthlyLabel
        case .yearly:  return config.fallbackYearlyLabel
        }
    }

    private func purchase(config: TierConfig) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        let productID = selectedPeriod.productID(for: config)
        do {
            let success = try await manager.purchase(productID: productID)
            if success { showSuccess = true }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - TierCard

private struct TierCard: View {

    let config: TierConfig
    let period: BillingPeriod
    let isSelected: Bool
    let isCurrentPlan: Bool
    let isPurchasing: Bool
    let priceLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {

                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if let badgeName = config.tier.badgeImageName {
                                Image(systemName: badgeName)
                                    .foregroundColor(config.accentColor)
                            }
                            Text("WBM \(config.tier.displayName)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        Text(perPeriodLabel)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(priceLabel)
                            .font(.title2.bold())
                            .foregroundColor(config.accentColor)
                        if let savings = savingsLabel {
                            Text(savings)
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider().background(config.accentColor.opacity(0.3))

                // Perks
                ForEach(config.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(config.accentColor)
                        Text(perk)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                // CTA
                HStack {
                    Spacer()
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if isCurrentPlan {
                        Text("Current Plan ✓")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Get \(config.tier.displayName)")
                            .font(.subheadline.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(config.accentColor)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                ZStack {
                    LinearGradient(
                        colors: config.gradientColors.map { $0.opacity(0.25) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? config.accentColor : config.accentColor.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isCurrentPlan || isPurchasing)
    }

    private var perPeriodLabel: String {
        switch period {
        case .weekly:  return "per week"
        case .monthly: return "per month"
        case .yearly:  return "per year"
        }
    }

    private var savingsLabel: String? {
        switch period {
        case .weekly:  return nil
        case .monthly: return "~35% off"
        case .yearly:  return "~65% off"
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b)  / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PremiumPromptView()
}
