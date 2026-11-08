import SwiftUI

/// Consistent presentation over the single entitlement policy. The underlying
/// feature's action/destination must also check that policy (not only a button).
struct PlusFeature<Content: View>: View {
    let capability: PlusAccessPolicy.Capability
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(AppState.self) private var appState
    @State private var showingPaywall = false

    var body: some View {
        if appState.plus.allows(capability) {
            content()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                EyebrowLabel(text: "CMSN+")
                Text(title).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("Your logging and records stay available.")
                    .font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
                Button("Explore CMSN+") { showingPaywall = true }.buttonStyle(.cmsnGhost)
            }
            .padding(20).cmsnCard()
            .accessibilityIdentifier("plus.locked.\(capability.rawValue)")
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }
}

struct PlusRunwayIntroView: View {
    let onContinue: () -> Void
    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                EyebrowLabel(text: "Your first week")
                Text("Your first week is the full system — coaching, planning, and fueling. After that, CMSN+ keeps your coach on.")
                    .font(CMSNTypography.displaySmall(34)).foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("No payment is needed to start this week. Any eligible App Store subscription trial is a separate offer shown when you subscribe.")
                    .font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textSecondary)
                Button("Start my week", action: onContinue).buttonStyle(.cmsnPrimary)
            }.padding(24)
        }
    }
}
