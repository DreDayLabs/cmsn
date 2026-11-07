import SwiftUI
import SwiftData

/// Settings, structured around what App Store review expects to find:
/// who you are, your subscription, your data rights (partial export and
/// erase), and the legal/support pages. The app is local-first — there is
/// no login because there is no account; "Delete Everything" is the
/// offboarding once the save succeeds, returning the app to a fresh start.
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
    @State private var deleteFailed = false
    @State private var calendarSaveFailed = false
    @State private var restoring = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNPageVideoBackground(
                    clip: .settings,
                    isActive: appState.selectedTab == .settings && !showingPaywall
                )
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
                .scrollContentBackground(.hidden)
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
                Text("This permanently erases your profile, diet choices, weight history, workouts, runs, nutrition, meals, and score from this device. There is no undo. Consider Export My Data first.")
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
                NavigationLink {
                    WeightLogView(athlete: athlete)
                } label: {
                    rowLabel(
                        "Body Weight",
                        value: athlete.unitPreference.formattedWeight(kilograms: athlete.weightKG),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                divider
                settingsRow("Equipment", value: athlete.equipmentProfile.displayName)
                divider
                settingsRow("Goals", value: athlete.goalTypes.filter(\.isOfferedInProfile).map(\.displayName).filter { !$0.isEmpty }.joined(separator: ", "))
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
                    showsChevron: true,
                    identifier: "settings.cmsnPlus",
                    valueIdentifier: "settings.cmsnPlus.status"
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
                calendarRow
                divider
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
            Text(LegalCopy.yourData)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            if deleteFailed {
                Text(LegalCopy.deleteSaveFailedMessage)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.destructive)
                    .accessibilityIdentifier("settings.deleteError")
            }
            if calendarSaveFailed {
                Text("Couldn't save the calendar choice. It stays as it was.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.destructive)
                    .accessibilityIdentifier("settings.calendarSaveError")
            }
        }
    }

    private var calendarRow: some View {
        Toggle(isOn: Binding(
            get: { athlete.calendarAuthorized },
            set: { enabled in
                let previous = athlete.calendarAuthorized
                athlete.calendarAuthorized = enabled
                Task { await persistCalendarOptIn(enabled, previous: previous) }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's calendar")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text(CalendarAccessPolicy.statusLine(
                    userOptedIn: athlete.calendarAuthorized,
                    authorization: appState.calendarService.authorizationState
                ))
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .accessibilityIdentifier("settings.calendarStatus")
            }
        }
        .tint(CMSNColor.offWhite)
        .padding(16)
        .accessibilityIdentifier("settings.calendarOptIn")
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
                Link(destination: LegalLinks.terms) {
                    rowLabel("Terms of Use", value: "", showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.terms")
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
        VStack(spacing: 4) {
            Text("CMSN Performance")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text("Earn Your CMSN")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
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

    private func rowLabel(_ label: String, value: String, showsChevron: Bool = false, destructive: Bool = false, valueIdentifier: String? = nil) -> some View {
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
                    .cmsnIdentifier(valueIdentifier)
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

    private func settingsRow(_ label: String, value: String, showsChevron: Bool = false, destructive: Bool = false, identifier: String? = nil, valueIdentifier: String? = nil, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    rowLabel(label, value: value, showsChevron: showsChevron, destructive: destructive, valueIdentifier: valueIdentifier)
                }
                .buttonStyle(.plain)
                .cmsnIdentifier(identifier)
                .cmsnAccessibilityValue(valueIdentifier == nil ? nil : value)
            } else {
                rowLabel(label, value: value, showsChevron: showsChevron, destructive: destructive, valueIdentifier: valueIdentifier)
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
        do {
            try AccountDataService.eraseEverything(context: modelContext)
            deleteFailed = false
            // RootView's @Query sees zero athletes and returns to first-run
            // onboarding on its own — no navigation needed here.
        } catch {
            deleteFailed = true
        }
    }

    private func persistCalendarOptIn(_ enabled: Bool, previous: Bool) async {
        do {
            try modelContext.save()
            calendarSaveFailed = false
        } catch {
            athlete.calendarAuthorized = previous
            calendarSaveFailed = true
            return
        }
        guard CalendarAccessPolicy.shouldRequestPermission(
            userOptedIn: enabled,
            authorization: appState.calendarService.authorizationState
        ) else { return }
        _ = await appState.calendarService.requestAccess()
    }
}

private extension View {
    @ViewBuilder
    func cmsnIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    @ViewBuilder
    func cmsnAccessibilityValue(_ value: String?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
