import Foundation
import StoreKit
import Observation

/// Product identifiers — placeholders until real App Store Connect
/// products exist. Pricing target from `brand/08-app-strategy.md`:
/// $9.99/mo, $59.99/yr, 7-day free trial (the trial is configured in App
/// Store Connect / the local `.storekit` file, not in Swift).
enum CMSNProductID {
    static let monthly = "com.earnyourcmsn.app.plus.monthly"
    static let annual = "com.earnyourcmsn.app.plus.annual"
    static let all: [String] = [monthly, annual]
}

/// V0's StoreKit 2 scaffolding: local product loading, purchase, restore,
/// and entitlement state — wired against `Resources/Configuration.storekit`
/// for local testing. The full CMSN+ feature set this gates (unlimited
/// video, Watch app, cloud sync) is V1 scope; this file only needs to prove
/// the plumbing works end-to-end.
@Observable
@MainActor
final class StoreKitManager {
    private(set) var products: [Product] = []
    private(set) var isSubscribed: Bool = false
    private(set) var lastError: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: CMSNProductID.all)
        } catch {
            lastError = "Couldn't load CMSN+ products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
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
                break
            case .pending:
                lastError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Walks current entitlements to decide whether CMSN+ is active. This
    /// is the single source of truth every feature-gate should read from
    /// (`appState.storeKitManager.isSubscribed`) rather than re-deriving it.
    func refreshEntitlements() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, CMSNProductID.all.contains(transaction.productID) {
                subscribed = true
            }
        }
        isSubscribed = subscribed
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
