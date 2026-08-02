import SwiftUI

/// Profile summary + the CMSN+ entry point. Deliberately thin in V0 — most
/// of what a "settings" screen would hold (notification prefs, unit
/// toggles, program switching) is V1 scope; this exists mainly so
/// `PaywallView` has somewhere to live.
struct SettingsView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            CMSNWordmark(height: 22)
                            Text(athlete.name?.isEmpty == false ? athlete.name! : "CMSNer")
                                .font(CMSNTypography.displaySmall(30))
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        }

                        profileSummary

                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CMSN+").font(CMSNTypography.body())
                                    Text(appState.storeKitManager.isSubscribed ? "Active" : "Unlock advanced coaching, analytics & Watch")
                                        .font(CMSNTypography.bodyQuiet())
                                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .padding(16)
                            .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 40)

                        Text("CMSN — Earn Your CMSN")
                            .font(CMSNTypography.bodyQuiet())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    .padding(24)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Training Profile")
            row("Equipment", athlete.equipmentProfile.displayName)
            row("Experience", athlete.experienceLevel.displayName)
            row("Goals", athlete.goalTypes.map(\.displayName).joined(separator: ", "))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            Spacer()
            Text(value).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }
}
