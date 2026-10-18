import SwiftUI

/// In-app privacy policy. Founder decision 2026-08-23: ship starter pages
/// in-app now; App Store review will additionally want a public web URL
/// for the privacy policy at submission time — swap these to links then.
/// The copy below states what the app ACTUALLY does today (local-only
/// store, Open Food Facts lookups); update it if the data story changes.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalPageScaffold(title: "PRIVACY", eyebrow: "Privacy Policy") {
            LegalSection(
                heading: "The Short Version",
                text: "Your data stays on your phone. CMSN has no server, no account system, and no analytics or ad tracking. We can't see your workouts, your meals, or your body stats — nobody can but you."
            )
            LegalSection(
                heading: "What's Stored, And Where",
                text: "Your training profile, body-weight history, workouts, runs, routes, shoes, nutrition logs, saved meals, supplements, and score history are stored in the app's private database on this device only. A photo you attach to a run stays there too. Deleting the app deletes them. You can also erase everything from Settings at any time."
            )
            LegalSection(
                heading: "Running",
                text: "Location is used only while a run is being recorded, including in the background if you allow it, and it stops the moment the run ends. Indoor runs use motion to estimate treadmill distance, and only during that run. Heart rate comes from Apple Health, or from a strap if you turn that option on, and only during the run. A finished run can be written to Apple Health. If you later turn Health access off, the run stays on this phone and the app says sync is waiting — it does not drop the workout quietly. Runs are private. There is no club, no feed, and no analytics in the run. A run recorded on Apple Watch is copied to this iPhone after."
            )
            LegalSection(
                heading: "Food Lookups",
                text: "When you scan a barcode or search for a food, the barcode number or search text is sent to Open Food Facts, a non-profit public food database, to fetch nutrition facts. Nothing about you goes with it — no name, no identifier, no location. The camera is used only to read barcodes; barcode scans are not saved as photos."
            )
            LegalSection(
                heading: "Optional Permissions",
                text: "Calendar access is optional, off by default, and used only to see whether today has a scheduled workout. The camera is used only to read food barcodes. Location, motion, Bluetooth, and Apple Health are requested only for running, and each one can be denied without blocking the rest of the app. Purchases and subscriptions are handled entirely by Apple; CMSN never sees your payment details."
            )
            LegalSection(
                heading: "Changes",
                text: "If a future version adds accounts, sync, or anything that moves data off your device, this policy will change and the app will say so clearly before any of it happens."
            )
        }
    }
}

struct SupportPageView: View {
    var body: some View {
        LegalPageScaffold(title: "SUPPORT", eyebrow: "Help & Contact") {
            LegalSection(
                heading: "Get In Touch",
                text: "Questions, bugs, or ideas — email support@earnyourcmsn.com and include what you were doing when the problem happened. Screenshots help."
            )
            LegalSection(
                heading: "Your Data",
                text: "Everything lives on your device. Settings → Export My Data gives you a full copy as a readable file; Settings → Delete Everything erases it permanently."
            )
            LegalSection(
                heading: "Subscriptions",
                text: "CMSN+ billing is managed by Apple. To change or cancel, open iPhone Settings → your name → Subscriptions. Refunds are requested through Apple at reportaproblem.apple.com."
            )
            LegalSection(
                heading: "A Note On Health",
                text: "CMSN is a training log and education tool, not medical advice. Talk to a professional before changing your training, diet, or supplements — especially with an injury or health condition."
            )
        }
    }
}

// MARK: - Shared scaffold

private struct LegalPageScaffold<Content: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: eyebrow)
                        Text(title)
                            .font(CMSNTypography.displaySmall(34))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    }
                    content
                    Text("Last updated October 2026")
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .padding(24)
            }
        }
    }
}

private struct LegalSection: View {
    let heading: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: heading)
            Text(text)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .lineSpacing(3)
        }
    }
}
