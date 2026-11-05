import SwiftUI
import StoreKit

/// The CMSN+ paywall. Monthly $9.99 and annual $59.99 are locked.
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

    /// Always on screen. Apple reviews the paywall whether or not StoreKit
    /// has loaded products, so this is not gated on `products.isEmpty`.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-day free trial, then \(CMSNPlusDisplayPrice.monthly) a month or \(CMSNPlusDisplayPrice.annual) a year. Cancel anytime in Settings.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.trial")

            Text("CMSN+ is an auto-renewing subscription. Payment is charged to your Apple ID at confirmation of purchase. It renews unless you cancel at least 24 hours before the current period ends, and your account is charged for renewal within 24 hours before that period ends. Manage or cancel in iPhone Settings → your name → Subscriptions. Any unused portion of the free trial is forfeited if you subscribe before it ends.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.disclosure")

            HStack(spacing: 16) {
                legalLink("Terms of Use", url: LegalLinks.terms, identifier: "paywall.terms")
                Text("·")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                legalLink("Privacy Policy", url: LegalLinks.privacy, identifier: "paywall.privacy")
            }
        }
    }

    private func legalLink(_ title: String, url: URL, identifier: String) -> some View {
        Link(destination: url) {
            Text(title)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .underline()
        }
        .tint(CMSNColor.Semantic.textPrimary)
        .accessibilityIdentifier(identifier)
    }
}
