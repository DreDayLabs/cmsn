import Foundation
import StoreKit
import Observation
import Network

/// Product identifiers verified against App Store Connect. Locked prices:
/// $9.99/mo and $59.99/yr. The 7-day free trial is configured in App
/// Store Connect / the local `.storekit` file, not in Swift.
enum CMSNProductID {
    static let monthly = "com.earnyourcmsn.app.plus.monthly"
    static let annual = "com.earnyourcmsn.app.plus.annual"
    static let all: [String] = [monthly, annual]
}

/// Prices drawn on the paywall. These are display strings, not App Store
/// Connect products. Both prices are locked: $9.99 a month and $59.99 a year.
enum CMSNPlusDisplayPrice {
    static let monthly = "$9.99"
    static let annual = "$59.99"

    /// StoreKit's localized price wins once a product is actually loaded.
    /// Until then the paywall shows the configured display string.
    static func resolve(storePrice: String?, fallback: String) -> String {
        guard let storePrice else { return fallback }
        let trimmed = storePrice.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

/// Apple transaction transport. The shared PlusEntitlementService owns access
/// policy; the local StoreKit configuration is only used for development.
@Observable
@MainActor
final class StoreKitManager {
    /// Debug-only launch argument for the screenshot harness. Production
    /// and Release builds ignore it. The UI test duplicates this string
    /// because the two targets do not share a module.
    static let screenshotSubscribedArgument = "-CMSNScreenshotSubscribed"

    private(set) var products: [Product] = []
    let entitlement: PlusEntitlementService
    var isSubscribed: Bool { entitlement.policy.paidAccess }
    private let network = NWPathMonitor()
    private var isOnline = false
    private var verificationGeneration: UInt = 0
    private(set) var isPurchasing: Bool = false
    private(set) var lastError: String?

    // nonisolated(unsafe): only `deinit` (always nonisolated) needs to
    // touch this outside the main actor, and `Task.cancel()` is documented
    // safe to call from any context.
    private nonisolated(unsafe) var transactionListenerTask: Task<Void, Never>?

    /// `autoStart` is false in StoreKit tests that need a manager with no
    /// in-flight entitlement refresh. The app always uses the default.
    init(autoStart: Bool = true) {
        // Hosted StoreKit tests never read or write the app's paid-access cache.
        let defaults = Self.isRunningInsideTestHost ? UserDefaults(suiteName: "cmsn.tests.\(UUID().uuidString)")! : .standard
        entitlement = PlusEntitlementService(defaults: defaults)
        network.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let reconnected = !self.isOnline && path.status == .satisfied
                self.isOnline = path.status == .satisfied
                if reconnected && autoStart && !Self.isRunningInsideTestHost { await self.refreshEntitlements() }
            }
        }
        network.start(queue: DispatchQueue(label: "cmsn.store.network"))
        if Self.prefersSubscribedScreenshot() {
            entitlement.applyVerifiedPaidAccess(true)
        }
        // The test host launches this manager before the test builds an
        // SKTestSession. A product request in that window comes back empty
        // and StoreKit keeps serving that empty result. Tests call
        // loadProducts() themselves after the session exists.
        guard autoStart, !Self.isRunningInsideTestHost else { return }
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    /// True when this process is the unit-test host. The screenshot app
    /// is a separate process and does not load XCTest.
    static var isRunningInsideTestHost: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }

    /// True only for a Debug process launched with
    /// `-CMSNScreenshotSubscribed`. Release builds cannot be flipped on.
    static func prefersSubscribedScreenshot(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        return arguments.contains(screenshotSubscribedArgument)
        #else
        _ = arguments
        return false
        #endif
    }

    deinit {
        transactionListenerTask?.cancel()
        network.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: CMSNProductID.all)
        } catch {
            lastError = "Couldn't load CMSN+ products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    lastError = "Purchase could not be verified."
                }
            case .userCancelled:
                lastError = "Purchase cancelled."
            case .pending:
                lastError = "Purchase is pending approval."
            @unknown default:
                lastError = "Purchase failed."
            }
        } catch {
            lastError = Self.purchaseErrorMessage(for: error)
        }
    }

    /// Shown on the paywall. Cancellation is its own sentence so a dismissed
    /// sheet does not look like a failed charge.
    static func purchaseErrorMessage(for error: Error) -> String {
        if let storeError = error as? StoreKitError, case .userCancelled = storeError {
            return "Purchase cancelled."
        }
        if let skError = error as? SKError, skError.code == .paymentCancelled {
            return "Purchase cancelled."
        }
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            return "Purchase failed."
        }
        return "Purchase failed: \(description)"
    }

    func restorePurchases() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            // Local StoreKit testing can throw from sync even when the
            // entitlement is already in `Transaction.currentEntitlements`.
            // Remember the failure, then still read the local store.
            lastError = "Restore failed: \(error.localizedDescription)"
        }
        await refreshEntitlements()
        if isSubscribed {
            lastError = nil
        }
    }

    /// Walks current entitlements to decide whether CMSN+ is active. This
    /// is the single source of truth every feature-gate should read from
    /// (`appState.storeKitManager.isSubscribed`) rather than re-deriving it.
    func refreshEntitlements() async {
        verificationGeneration &+= 1
        let generation = verificationGeneration
        if Self.prefersSubscribedScreenshot() {
            entitlement.applyVerifiedPaidAccess(true)
            return
        }
        var active = false
        var revoked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, CMSNProductID.all.contains(transaction.productID) {
                if transaction.revocationDate != nil { revoked = true } else { active = true }
            }
        }
        guard generation == verificationGeneration else { return }
        // Apple's currentEntitlements includes active subscriptions and grace.
        if active {
            entitlement.applyVerifiedPaidAccess(true)
            return
        }
        if revoked { entitlement.applyVerifiedPaidAccess(false); return }
        // An absent cached transaction while offline is not a new verification.
        guard isOnline || Self.isRunningInsideTestHost else { return }
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: "22552778")
            var hasAccess = false
            var unverified = false
            for status in statuses {
                guard case .verified(let transaction) = status.transaction,
                      case .verified = status.renewalInfo else { unverified = true; continue }
                guard CMSNProductID.all.contains(transaction.productID) else { continue }
                if transaction.revocationDate == nil && (status.state == .subscribed || status.state == .inGracePeriod) {
                    hasAccess = true
                }
            }
            guard generation == verificationGeneration else { return }
            if hasAccess || !unverified { entitlement.applyVerifiedPaidAccess(hasAccess) }
        } catch {
            // Keep last-verified access when the store cannot verify a refresh.
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    if transaction.revocationDate != nil, CMSNProductID.all.contains(transaction.productID) {
                        await self?.entitlement.applyVerifiedPaidAccess(false)
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
