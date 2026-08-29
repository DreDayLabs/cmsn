import SwiftUI
import SwiftData

/// Settings, structured around what App Store review expects to find:
/// who you are, your subscription, your data rights (export + full
/// erase), and the legal/support pages. The app is local-first — there is
/// no login because there is no account; "Delete Everything" IS the
/// offboarding, returning the app to a fresh-install state.
struct SettingsView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showingPaywall = false
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var exportURL: URL?
    @State private var exportError = false
    @State private var confirmingErase = false
    @State private var restoring = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        accountSection
                        membershipSection
                        dataSection
                        aboutSection
                        footer
                    }
                    .padding(24)
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .confirmationDialog(
                "Delete everything?",
                isPresented: $confirmingErase,
                titleVisibility: .visible
            ) {
                Button("Delete All My Data", role: .destructive) { eraseEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases your profile, workouts, nutrition, meals, and score from this device. There is no undo. Consider Export My Data first.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            CMSNWordmark(height: 22)
            Text(displayName)
                .font(CMSNTypography.displaySmall(30))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var displayName: String {
        (athlete.name?.isEmpty == false ? athlete.name! : "CMSNer")
    }

    // MARK: Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Account")
            VStack(spacing: 0) {
                if editingName {
                    HStack(spacing: 10) {
                        TextField("Your name", text: $nameDraft)
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .submitLabel(.done)
                            .onSubmit(saveName)
                        Button("Save") { saveName() }.buttonStyle(.cmsnText)
                    }
                    .padding(16)
                } else {
                    settingsRow("Name", value: displayName) {
                        nameDraft = athlete.name ?? ""
                        editingName = true
                    }
                }
                divider
                settingsRow("Equipment", value: athlete.equipmentProfile.displayName)
                divider
                settingsRow("Goals", value: athlete.goalTypes.map(\.displayName).joined(separator: ", "))
            }
            .cmsnCard()
        }
    }

    // MARK: Membership

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Membership")
            VStack(spacing: 0) {
                settingsRow(
                    "CMSN+",
                    value: appState.storeKitManager.isSubscribed ? "Active" : "Not active",
                    showsChevron: true
                ) { showingPaywall = true }
                divider
                settingsRow("Restore Purchases", value: restoring ? "Restoring…" : "") {
                    guard !restoring else { return }
                    restoring = true
                    Task {
                        await appState.storeKitManager.restorePurchases()
                        restoring = false
                    }
                }
                divider
                settingsRow("Manage Subscription", value: "", showsChevron: true) {
                    // Apple's own management UI — cancellations must go
                    // through Apple, never through us.
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .cmsnCard()
        }
    }

    // MARK: Data rights

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Your Data")
            VStack(spacing: 0) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        rowLabel("Export My Data", value: "Ready — tap to share", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    settingsRow("Export My Data", value: exportError ? "Failed — try again" : "", showsChevron: true) {
                        prepareExport()
                    }
                }
                divider
                settingsRow("Delete Everything", value: "", showsChevron: true, destructive: true) {
                    confirmingErase = true
                }
            }
            .cmsnCard()
            Text("Everything lives on this device. Export gives you a readable copy; Delete Everything is permanent and returns the app to a fresh start.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }

    // MARK: About / legal

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "About")
            VStack(spacing: 0) {
                NavigationLink { PrivacyPolicyView() } label: {
                    rowLabel("Privacy Policy", value: "", showsChevron: true)
                }
                .buttonStyle(.plain)
                divider
                NavigationLink { SupportPageView() } label: {
                    rowLabel("Support", value: "", showsChevron: true)
                }
                .buttonStyle(.plain)
                divider
                settingsRow("Version", value: appVersion)
            }
            .cmsnCard()
        }
    }

    private var footer: some View {
        Text("CMSN — Earn Your CMSN")
            .font(CMSNTypography.bodyQuiet())
            .foregroundStyle(CMSNColor.Semantic.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Row plumbing

    private var divider: some View {
        Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1).padding(.leading, 16)
    }

    private func rowLabel(_ label: String, value: String, showsChevron: Bool = false, destructive: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(CMSNTypography.body())
                .foregroundStyle(destructive ? CMSNColor.gray : CMSNColor.Semantic.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Text("›")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func settingsRow(_ label: String, value: String, showsChevron: Bool = false, destructive: Bool = false, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) { rowLabel(label, value: value, showsChevron: showsChevron, destructive: destructive) }
                    .buttonStyle(.plain)
            } else {
                rowLabel(label, value: value, showsChevron: showsChevron, destructive: destructive)
            }
        }
    }

    // MARK: Actions

    private func saveName() {
        athlete.name = nameDraft.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
        editingName = false
    }

    private func prepareExport() {
        exportError = false
        do {
            exportURL = try AccountDataService.exportJSON(context: modelContext)
        } catch {
            exportError = true
        }
    }

    private func eraseEverything() {
        AccountDataService.eraseEverything(context: modelContext)
        // RootView's @Query sees zero athletes and returns to first-run
        // onboarding on its own — no navigation needed here.
    }
}
