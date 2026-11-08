import SwiftUI
import StoreKit

/// The CMSN+ paywall. Monthly $9.99 and annual $59.99 are locked.
/// Both are display strings. They are not App Store Connect products.
/// Positioning against Fitbod's $15.99/$95.99 is in `brand/08-app-strategy.md`.
struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = CMSNProductID.monthly

    private var selectedPlanName: String {
        selectedProductID == CMSNProductID.lifetime ? "Lifetime" : (selectedProductID == CMSNProductID.monthly ? "Monthly" : "Annual")
    }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    exampleCard
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
            Text("Coaching that reads your history.")
                .font(CMSNTypography.displaySmall(40))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("The coach that knows how ready you are.")
                .font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }

    /// Capabilities this build actually has. A video library, cloud
    /// sync, and founding status are not listed. Nothing in the app
    /// grants a founding benefit.
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([
                "Progression coaching with the reason shown",
                "Sessions planned around your equipment",
                "Fueling built for prep — protein targets and repeatable meals, food as recovery",
                "Your records stay yours whether you subscribe or not",
            ], id: \.self) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Text("·").foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text(feature).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                }
            }
        }
    }

    private var exampleCard: some View {
        let example = PlusPaywallExample.make()
        return VStack(alignment: .leading, spacing: 16) {
            EyebrowLabel(text: "Example · 80 kg × 12 at effort 8 · moderate readiness")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    exampleColumn("Without Plus", example.withoutPlus).frame(width: 140)
                    exampleColumn("With Plus", example.withPlus).frame(width: 180)
                }
                VStack(alignment: .leading, spacing: 16) {
                    exampleColumn("Without Plus", example.withoutPlus)
                    exampleColumn("With Plus", example.withPlus)
                }
            }
        }.padding(16).cmsnCard().accessibilityIdentifier("paywall.example")
    }
    private func exampleColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(CMSNTypography.body()).bold()
            Text(value).font(CMSNTypography.bodyQuiet()).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(CMSNColor.Semantic.textPrimary)
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

            planButton(title: "Lifetime", productID: CMSNProductID.lifetime, fallbackPrice: CMSNPlusDisplayPrice.lifetime, accessibilityID: "paywall.lifetime")

            Button("Continue with \(selectedPlanName)") {
                guard let product = appState.storeKitManager.products.first(where: { $0.id == selectedProductID }) else { return }
                Task { await appState.storeKitManager.purchase(product) }
            }
            .buttonStyle(.cmsnPrimary)
            .disabled(appState.storeKitManager.isPurchasing || !appState.storeKitManager.products.contains(where: { $0.id == selectedProductID }))
            .accessibilityIdentifier("paywall.purchase")

            if appState.storeKitManager.isPurchasing {
                ProgressView()
                    .controlSize(.small)
                    .tint(CMSNColor.Semantic.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Purchasing")
                    .accessibilityIdentifier("paywall.purchasing")
            }

            Button("Restore Purchases") {
                Task { await appState.storeKitManager.restorePurchases() }
            }
            .buttonStyle(.cmsnGhost)
            .disabled(appState.storeKitManager.isPurchasing)

            if let error = appState.storeKitManager.lastError {
                Text(error)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.destructive)
                    .accessibilityIdentifier("paywall.error")
            }
        }
    }

    private func planButton(title: String, productID: String, fallbackPrice: String, accessibilityID: String) -> some View {
        let product = appState.storeKitManager.products.first { $0.id == productID }
        let price = CMSNPlusDisplayPrice.resolve(storePrice: product?.displayPrice, fallback: fallbackPrice)
        return Button {
            guard !appState.storeKitManager.isPurchasing else { return }
            selectedProductID = productID
        } label: {
            HStack {
                Image(systemName: selectedProductID == productID ? "checkmark.circle.fill" : "circle")
                Text(title)
                Spacer()
                Text(price)
                if selectedProductID == productID { Text("Selected").font(.caption) }
            }
        }
        .buttonStyle(.cmsnGhost)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedProductID == productID ? CMSNColor.Semantic.textPrimary : .clear, lineWidth: 2))
        .disabled(appState.storeKitManager.isPurchasing)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel("\(title), \(price)")
        .accessibilityValue(selectedProductID == productID ? "Selected" : "Not selected")
        .accessibilityAddTraits(selectedProductID == productID ? .isSelected : [])
    }

    /// Always on screen. Apple reviews the paywall whether or not StoreKit
    /// has loaded products, so this is not gated on `products.isEmpty`.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedProductID == CMSNProductID.lifetime ? "CMSN+ Lifetime: \(CMSNPlusDisplayPrice.lifetime), one payment. No subscription or renewal. Restore your purchase with the same Apple ID." : "7-day free trial, then \(CMSNPlusDisplayPrice.monthly) a month or \(CMSNPlusDisplayPrice.annual) a year. Cancel anytime in Settings.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.trial")

            Text("Your no-card first week begins after assessment. The App Store's 7-day subscription trial is separate and depends on eligibility.")
                .font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text("Monthly and Annual are auto-renewing subscriptions. Lifetime is a one-time non-consumable purchase and does not renew. Payment is charged to your Apple ID at confirmation of purchase. Subscriptions renew unless you cancel at least 24 hours before the current period ends, and your account is charged for subscription renewal within 24 hours before that period ends. Manage or cancel in iPhone Settings → your name → Subscriptions. Any unused portion of the free trial is forfeited if you subscribe before it ends.")
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
        .accessibilityValue(url.absoluteString)
    }
}
