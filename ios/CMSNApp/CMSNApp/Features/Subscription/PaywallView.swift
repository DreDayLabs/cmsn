import SwiftUI
import StoreKit

/// The CMSN+ paywall. Monthly is $9.99. Annual $59.99 is a placeholder
/// until the founder confirms it (`CMSNPlusDisplayPrice.annualIsPlaceholder`).
/// Both are display strings. They are not App Store Connect products.
/// Positioning against Fitbod's $15.99/$95.99 is in `brand/08-app-strategy.md`.
struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    featureList
                    productButtons
                    footer
                }
                .padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Close") { dismiss() }
                .buttonStyle(.cmsnText)
                .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "CMSN+")
            Text("Train with\nthe full system.")
                .font(CMSNTypography.displaySmall(40))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([
                "Full instructional video library",
                "Advanced strength & volume analytics",
                "Apple Watch companion",
                "Cloud backup & cross-device sync",
                "Recovery-aware program adjustments",
                "Founding CMSNer status",
            ], id: \.self) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Text("·").foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text(feature).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                }
            }
        }
    }

    private var productButtons: some View {
        VStack(spacing: 12) {
            planButton(
                title: "Monthly",
                productID: CMSNProductID.monthly,
                fallbackPrice: CMSNPlusDisplayPrice.monthly,
                accessibilityID: "paywall.monthly"
            )
            planButton(
                title: "Annual",
                productID: CMSNProductID.annual,
                fallbackPrice: CMSNPlusDisplayPrice.annual,
                accessibilityID: "paywall.annual"
            )

            if appState.storeKitManager.products.isEmpty {
                Text("These are the CMSN+ prices. Subscribing starts once the App Store products are available. Nothing is billed from this screen until then.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }

            Button("Restore Purchases") {
                Task { await appState.storeKitManager.restorePurchases() }
            }
            .buttonStyle(.cmsnGhost)

            if let error = appState.storeKitManager.lastError {
                Text(error).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.destructive)
            }
        }
    }

    private func planButton(title: String, productID: String, fallbackPrice: String, accessibilityID: String) -> some View {
        let product = appState.storeKitManager.products.first { $0.id == productID }
        let price = CMSNPlusDisplayPrice.resolve(storePrice: product?.displayPrice, fallback: fallbackPrice)
        return Button {
            guard let product else { return }
            Task {
                isPurchasing = true
                await appState.storeKitManager.purchase(product)
                isPurchasing = false
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(price)
            }
        }
        .buttonStyle(.cmsnPrimary)
        .disabled(isPurchasing)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel("\(title), \(price)")
    }

    private var footer: some View {
        Text("7-day free trial, then \(CMSNPlusDisplayPrice.monthly) a month or \(CMSNPlusDisplayPrice.annual) a year. Cancel anytime in Settings.")
            .font(CMSNTypography.bodyQuiet())
            .foregroundStyle(CMSNColor.Semantic.textSecondary)
    }
}
