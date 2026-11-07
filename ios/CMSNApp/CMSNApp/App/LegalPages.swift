import SwiftUI

/// Public copies of these pages. App Store Connect's Privacy Policy URL
/// and Support URL fields point here; the web copy lives in
/// app/privacy/page.tsx and app/support/page.tsx and must stay in sync.
enum LegalLinks {
    static let privacy = URL(string: "https://earnyourcmsn.com/privacy")!
    static let support = URL(string: "https://earnyourcmsn.com/support")!
    /// Apple's standard Licensed Application EULA. App Review accepts this
    /// link. Swap it for a CMSN terms page when one is published.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Sentences shared by the in-app legal pages and the website sources.
/// `app/privacy/page.tsx` and `app/support/page.tsx` must contain the same
/// text. The website is not published from this change.
enum LegalCopy {
    static let deleteSaveFailedMessage = AccountDataService.deleteSaveFailedMessage

    static let shortVersion = "Training data stays on your iPhone. The app has no account, no ad tracking, and no analytics SDK, and it does not send workouts, meals, or body stats to a CMSN server. If you request an invite on earnyourcmsn.com, that email is stored for the invite list. Deleting the app does not delete that email."

    static let stored = "Your training profile, body-weight history, workouts, runs, routes, shoes, nutrition logs, saved meals, supplements, and score history are stored in the app's private database on this device only. A photo you attach to a run stays there too. Deleting the app deletes them. You can also erase everything from Settings. If that save fails, Settings shows: \(deleteSaveFailedMessage)"

    static let running = "Location is used only while a run is being recorded, including in the background if you allow it, and it stops the moment the run ends. Indoor runs use motion to estimate treadmill distance, and only during that run. Heart rate comes from Apple Health, or from a strap if you turn that option on, and only during the run. A finished run can be written to Apple Health. If Apple Health does not accept the run, it stays on this phone and Run shows the reason, or the words A run is waiting to sync. Runs are private. There is no club and no feed. Pace and distance stay on the phone and are not sent to an analytics service. A run recorded on Apple Watch is copied to this iPhone after."

    static let foodLookups = "When you scan a barcode or search for a food, the barcode number or search text is sent to Open Food Facts, a non-profit public food database, to fetch nutrition facts. The request sends that barcode or search text, plus a fixed app name in the User-Agent (CMSNApp/0.1). It does not send your name, account, or location. Open Food Facts sees the connection's IP address. The camera is used only to read barcodes; barcode scans are not saved as photos."

    static let optionalPermissions = "Calendar access is off until you turn on Today's calendar in Settings. CMSN does not ask before that. If you turn it on and allow access, CMSN reads the titles of today's events and looks for a workout word. It does not create or edit events. Turning the switch off stops that read. If you deny access, or turn it off later in iOS Settings, the read stops too. The camera is used only to read food barcodes. Location, motion, Bluetooth, and Apple Health are requested only for running, and each one can be denied without blocking the rest of the app. Purchases and subscriptions are handled entirely by Apple; CMSN never sees your payment details."

    static let changes = "If a future version adds accounts, sync, or anything that moves training data off your device, this policy will change and the app will say so clearly before any of it happens."

    static let yourData = "Training data lives on this iPhone. Settings → Export My Data writes a JSON file of the profile summary, workout sessions, nutrition logs, saved meals, custom supplements, weight entries, finished-run summaries, and score events. It does not include route coordinates, split times, shoes, the run photo, readiness checks, injury notes, or set effort (RPE). A finished run is marked photoAttached when a photo is stored. Settings → Delete Everything removes the on-device records, including records the export leaves out. If that save fails, Settings shows: \(deleteSaveFailedMessage)"
}

/// In-app privacy policy (works offline). Each page also links to its
/// hosted copy above.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalPageScaffold(title: "PRIVACY", eyebrow: "Privacy Policy", webURL: LegalLinks.privacy) {
            LegalSection(heading: "The Short Version", text: LegalCopy.shortVersion)
            LegalSection(heading: "What's Stored, And Where", text: LegalCopy.stored)
            LegalSection(heading: "Running", text: LegalCopy.running)
            LegalSection(heading: "Food Lookups", text: LegalCopy.foodLookups)
            LegalSection(heading: "Optional Permissions", text: LegalCopy.optionalPermissions)
            LegalSection(heading: "Changes", text: LegalCopy.changes)
        }
    }
}

struct SupportPageView: View {
    var body: some View {
        LegalPageScaffold(title: "SUPPORT", eyebrow: "Help & Contact", webURL: LegalLinks.support) {
            LegalSection(
                heading: "Get In Touch",
                text: "Questions, bugs, or ideas — email support@earnyourcmsn.com and include what you were doing when the problem happened. Screenshots help."
            )
            LegalSection(heading: "Your Data", text: LegalCopy.yourData)
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
    let webURL: URL
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
                    Link("View online at \(webURL.host ?? "")\(webURL.path)", destination: webURL)
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .accessibilityIdentifier("legal.webLink")
                    Text("Last updated November 2026")
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
