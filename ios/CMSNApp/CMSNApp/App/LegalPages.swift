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
                text: "Your training profile, workouts, nutrition logs, saved meals, supplements, and score history are stored in the app's private database on this device only. Deleting the app deletes them. You can also erase everything from Settings at any time."
            )
            LegalSection(
                heading: "Food Lookups",
                text: "When you scan a barcode or search for a food, the barcode number or search text is sent to Open Food Facts, a non-profit public food database, to fetch nutrition facts. Nothing about you goes with it — no name, no identifier, no location. The camera is used only to read barcodes; no photos are captured or stored."
            )
            LegalSection(
                heading: "Optional Permissions",
                text: "Calendar access (to auto-detect a scheduled workout) and Apple Health access (to read body weight or write completed workouts) are optional, off by default, and used only for the stated purpose. Purchases and subscriptions are handled entirely by Apple; CMSN never sees your payment details."
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
                    Text("Last updated August 2026")
                        .font(.system(size: 11))
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
