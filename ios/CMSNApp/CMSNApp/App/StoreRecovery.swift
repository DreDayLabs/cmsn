import Observation
import SwiftData
import SwiftUI

/// Opens the on-disk store at launch and, if that fails, keeps the app on a
/// recovery screen. A failed open never moves or deletes the store. Moving
/// it aside happens only when the athlete confirms start-fresh.
@MainActor
@Observable
final class StoreBootstrap {
    enum Phase {
        case ready(ModelContainer, AppState)
        case failed(String)
    }

    private(set) var phase: Phase

    private let openStore: () throws -> ModelContainer
    private let quarantine: (URL) throws -> URL
    private let storeURL: () -> URL

    init(
        openStore: @escaping () throws -> ModelContainer = CMSNModelContainerFactory.makeDefault,
        quarantine: @escaping (URL) throws -> URL = { url in
            try CMSNModelContainerFactory.quarantinePersistentStore(at: url)
        },
        storeURL: @escaping () -> URL = { CMSNModelContainerFactory.defaultPersistentConfiguration().url }
    ) {
        self.openStore = openStore
        self.quarantine = quarantine
        self.storeURL = storeURL
        phase = Self.load(openStore: openStore)
    }

    func retry() {
        phase = Self.load(openStore: openStore)
    }

    /// Explicit recovery. The live store is renamed into a backup folder
    /// first; only then does the app try to open a new empty store.
    func startFreshPreservingExistingStore() {
        var preservedNote = ""
        do {
            let backup = try quarantine(storeURL())
            preservedNote = "The previous store was moved to \(backup.path) and was not deleted. "
        } catch StoreQuarantineError.nothingToMove {
            preservedNote = ""
        } catch {
            phase = .failed("Couldn't move the existing store aside, so it was left in place. \(error.localizedDescription)")
            return
        }

        switch Self.load(openStore: openStore) {
        case .ready(let container, let appState):
            phase = .ready(container, appState)
        case .failed(let message):
            phase = .failed(preservedNote + message)
        }
    }

    private static func load(openStore: () throws -> ModelContainer) -> Phase {
        do {
            let container = try openStore()
            return .ready(container, AppState(modelContainer: container))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

/// Shown when the on-disk store cannot be opened. Retry leaves every file
/// where it is. Start fresh asks first, then moves the store aside.
struct StoreRecoveryView: View {
    let message: String
    let onRetry: () -> Void
    let onStartFresh: () -> Void

    @State private var confirmingStartFresh = false

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                EyebrowLabel(text: "Saved data")
                Text("Couldn't open your data")
                    .font(CMSNTypography.displaySmall(34))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("Your workouts and profile are still on this device. CMSN did not erase them.")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text(message)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                Button("Try Again", action: onRetry)
                    .buttonStyle(.cmsnPrimary)
                Button("Start Fresh") { confirmingStartFresh = true }
                    .buttonStyle(.cmsnGhost)
                Spacer()
            }
            .padding(24)
        }
        .confirmationDialog(
            "Start fresh?",
            isPresented: $confirmingStartFresh,
            titleVisibility: .visible
        ) {
            Button("Move store aside and start fresh", role: .destructive, action: onStartFresh)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The existing store is moved into a backup folder on this device. It is not deleted and not uploaded. The app then opens with an empty profile.")
        }
    }
}
