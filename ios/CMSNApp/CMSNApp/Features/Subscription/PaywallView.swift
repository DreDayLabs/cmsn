import SwiftUI
import StoreKit

/// The CMSN+ paywall. Pricing/positioning per `brand/08-app-strategy.md`:
/// $9.99/mo or $59.99/yr against Fitbod's $15.99/$95.99 — framed here as a
/// value comparison, not just a lower price, per the "can't win by being a
/// cheaper clone" doctrine.
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
            if appState.storeKitManager.products.isEmpty {
                Text("Products load from App Store Connect once CMSN+ is configured there — this screen is fully wired, just waiting on real product IDs.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            ForEach(appState.storeKitManager.products) { product in
                Button {
                    Task {
                        isPurchasing = true
                        await appState.storeKitManager.purchase(product)
                        isPurchasing = false
                    }
                } label: {
                    HStack {
                        Text(product.displayName)
                        Spacer()
                        Text(product.displayPrice)
                    }
                }
                .buttonStyle(.cmsnPrimary)
                .disabled(isPurchasing)
            }

            Button("Restore Purchases") {
                Task { await appState.storeKitManager.restorePurchases() }
            }
            .buttonStyle(.cmsnGhost)

            if let error = appState.storeKitManager.lastError {
                Text(error).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.gray)
            }
        }
    }

    private var footer: some View {
        Text("7-day free trial, then billed monthly or annually. Cancel anytime in Settings.")
            .font(CMSNTypography.bodyQuiet())
            .foregroundStyle(CMSNColor.Semantic.textSecondary)
    }
}
