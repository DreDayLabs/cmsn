import StoreKit
import StoreKitTest
import XCTest
@testable import CMSNApp

/// Local StoreKit proof for CMSN+. Uses `Configuration.storekit` through
/// `SKTestSession` — no App Store Connect account and no charge.
///
/// Run and Test both reference Configuration.storekit with a path that
/// resolves from the .xcscheme file. These tests still open an
/// SKTestSession themselves and do not use a purchase dialog.
///
/// The iOS 26.5 simulator does not connect SKTestSession (FB22500243).
/// On that runtime a failed product load skips. A skip is not a pass and
/// does not prove purchases. Other runtimes still fail when products do
/// not load, and still run the full assertions when they do.
@MainActor
final class StoreKitPurchaseFlowTests: XCTestCase {
    private var session: SKTestSession?

    override func tearDown() async throws {
        let session = self.session
        self.session = nil
        // The 2026-11-06 logs show reset/clear returning SKInternalErrorDomain
        // Code=3 in the same millisecond. They were not the 600s waiter.
        if let session {
            session.disableDialogs = true
            session.resetToDefaultState()
            session.clearTransactions()
        }
        try await super.tearDown()
    }

    func testLocalStoreKitFileMatchesLockedProducts() throws {
        let url = try XCTUnwrap(Self.configurationURL(), "Configuration.storekit is missing from the app bundle.")
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(StoreKitConfigurationFile.self, from: data)
        let products = file.subscriptionGroups.flatMap(\.subscriptions)
        let monthly = try XCTUnwrap(products.first { $0.productID == CMSNProductID.monthly })
        let annual = try XCTUnwrap(products.first { $0.productID == CMSNProductID.annual })

        XCTAssertEqual(monthly.displayPrice, "9.99")
        XCTAssertEqual(monthly.recurringSubscriptionPeriod, "P1M")
        XCTAssertEqual(annual.displayPrice, "59.99")
        XCTAssertEqual(annual.recurringSubscriptionPeriod, "P1Y")
        for product in [monthly, annual] {
            let intro = try XCTUnwrap(product.introductoryOffer, product.productID)
            XCTAssertEqual(intro.paymentMode, "free")
            XCTAssertEqual(intro.subscriptionPeriod, "P1W")
            XCTAssertEqual(intro.numberOfPeriods, 1)
        }
    }

    /// No SKTestSession. StoreKit may report the file's P1W as one week or as
    /// seven days. Both are a 7-day free trial. Other lengths fail.
    func testSevenDayTrialAcceptsOnlyEquivalentPeriods() {
        XCTAssertTrue(CMSNIntroductoryTrial.isSingleFreeSevenDays(unit: .week, value: 1))
        XCTAssertTrue(CMSNIntroductoryTrial.isSingleFreeSevenDays(unit: .day, value: 7))
        let rejected: [(Product.SubscriptionPeriod.Unit, Int)] = [
            (.day, 0),
            (.day, 1),
            (.day, 6),
            (.day, 8),
            (.week, 0),
            (.week, 2),
            (.month, 1),
            (.year, 1),
        ]
        for (unit, value) in rejected {
        XCTAssertFalse(
            CMSNIntroductoryTrial.isSingleFreeSevenDays(unit: unit, value: value),
            "\(unit) \(value) must not count as 7 days"
        )
    }

    func testCompletionGateSeesFinishAndTimesOut() async {
        let gate = CompletionGate()
        let started = Date()
        let missed = await gate.wait(seconds: 0.25)
        XCTAssertFalse(missed)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)

        let waiting = CompletionGate()
        let waiter = Task { await waiting.wait(seconds: 2) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        waiting.finish()
        let saw = await waiter.value
        XCTAssertTrue(saw)
    }
    }

    func testBuyingTheTrialUnlocksCMSNPlus() async throws {
        let session = try await openSession()
        let manager = StoreKitManager(autoStart: false)
        try await ensureStoreKitCatalog()
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        let annual = try await loadProduct(CMSNProductID.annual, manager: manager)

        assertLockedPrice(monthly, "9.99", periodUnit: .month)
        assertLockedPrice(annual, "59.99", periodUnit: .year)
        // A failed trial check must not enter purchase(). On the 2026-11-06
        // iOS 26.5 run the week-vs-7-days asserts failed and XCTest continued
        // into product.purchase. That call returned "Purchase cancelled" after
        // about 80s on the unsigned run. The suite was killed at 600s.
        try assertSevenDayTrial(monthly)
        try assertSevenDayTrial(annual)

        XCTAssertFalse(manager.isSubscribed)
        XCTAssertFalse(manager.isPurchasing)
        try await finishPurchase(monthly, manager: manager)

        XCTAssertFalse(manager.isPurchasing)
        XCTAssertNil(manager.lastError)
        try await waitUntil(manager, subscribed: true)
        // XCTUnwrap takes an autoclosure, so the await has to finish first.
        let found = try await currentTransaction(for: CMSNProductID.monthly)
        let transaction = try XCTUnwrap(found)
        if #available(iOS 17.2, *) {
            XCTAssertEqual(transaction.offer?.type, .introductory)
        } else {
            XCTAssertEqual(transaction.offerType, .introductory)
        }
        _ = session
    }

    func testRestoreBringsBackEntitlementAfterReset() async throws {
        let session = try await openSession()
        try await ensureStoreKitCatalog()
        session.clearTransactions()
        try await buyProduct(CMSNProductID.monthly, session: session)

        let primed = StoreKitManager(autoStart: false)
        try await waitUntil(primed, subscribed: true)

        // A new manager is the reset: nothing cached, the store still has the purchase.
        let restored = StoreKitManager(autoStart: false)
        XCTAssertFalse(restored.isSubscribed)
        XCTAssertFalse(restored.isPurchasing)
        await restored.restorePurchases()
        XCTAssertNil(restored.lastError)
        XCTAssertFalse(restored.isPurchasing)
        try await waitUntil(restored, subscribed: true)
    }

    func testExpiryAndCancellationLockCMSNPlus() async throws {
        let session = try await openSession()
        let manager = StoreKitManager(autoStart: false)
        try await ensureStoreKitCatalog()
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)

        try await finishPurchase(monthly, manager: manager)
        try await waitUntil(manager, subscribed: true)
        try session.expireSubscription(productIdentifier: CMSNProductID.monthly)
        try await waitUntil(manager, subscribed: false)

        try await buyProduct(CMSNProductID.annual, session: session)
        try await waitUntil(manager, subscribed: true)
        let external = try XCTUnwrap(
            session.allTransactions().last { $0.productIdentifier == CMSNProductID.annual }
        )
        try session.disableAutoRenewForTransaction(identifier: external.identifier)
        try session.expireSubscription(productIdentifier: CMSNProductID.annual)
        try await waitUntil(manager, subscribed: false)

        try await buyProduct(CMSNProductID.monthly, session: session)
        try await waitUntil(manager, subscribed: true)
        let refundable = try XCTUnwrap(
            session.allTransactions().last { $0.productIdentifier == CMSNProductID.monthly }
        )
        try session.refundTransaction(identifier: refundable.identifier)
        try await waitUntil(manager, subscribed: false)
        XCTAssertFalse(manager.isPurchasing)
    }

    func testFailedPurchaseShowsCleanErrorWithoutStuckPurchasing() async throws {
        let session = try await openSession()
        let manager = StoreKitManager(autoStart: false)
        try await ensureStoreKitCatalog()
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))),
            forAPI: .purchase
        )

        XCTAssertFalse(manager.isPurchasing)
        try await finishPurchase(monthly, manager: manager)
        XCTAssertFalse(manager.isPurchasing, "The purchasing flag stayed on after a failed purchase.")
        XCTAssertFalse(manager.isSubscribed)
        let message = try XCTUnwrap(manager.lastError)
        XCTAssertTrue(message.hasPrefix("Purchase failed:"), message)
        XCTAssertNotEqual(message, "Purchase cancelled.")
    }

    func testCancelledPurchaseShowsCleanErrorWithoutStuckPurchasing() async throws {
        let session = try await openSession()
        let manager = StoreKitManager(autoStart: false)
        try await ensureStoreKitCatalog()
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)

        XCTAssertFalse(manager.isPurchasing)
        try await finishPurchase(monthly, manager: manager)
        XCTAssertFalse(manager.isPurchasing, "The purchasing flag stayed on after a cancelled purchase.")
        XCTAssertFalse(manager.isSubscribed)
        XCTAssertEqual(manager.lastError, "Purchase cancelled.")
    }

    // MARK: - Session

    private func openSession() async throws -> SKTestSession {
        let url = try XCTUnwrap(
            Self.configurationURL(),
            "Configuration.storekit is missing from the test bundle and the app bundle."
        )
        // configurationFileNamed is the path StoreKit Test uses to hand the
        // host a real file. contentsOf is the fallback when the test bundle
        // name lookup misses the copied resource.
        let session: SKTestSession
        do {
            session = try SKTestSession(configurationFileNamed: "Configuration")
        } catch {
            session = try SKTestSession(contentsOf: url)
        }
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        self.session = session
        // iOS 26 needs a beat after the session attaches before the first
        // Product.products request. A request that lands earlier stays empty.
        try await Task.sleep(nanoseconds: 500_000_000)
        return session
    }

    private static func configurationURL() -> URL? {
        let bundles = [Bundle(for: StoreKitPurchaseFlowTests.self), Bundle.main]
        for bundle in bundles {
            if let url = bundle.url(forResource: "Configuration", withExtension: "storekit") {
                return url
            }
        }
        return nil
    }

    /// Asks StoreKit for both CMSN+ products. A miss on the iOS 26.5
    /// simulator skips the test. A miss on any other runtime fails it.
    private func ensureStoreKitCatalog() async throws {
        let deadline = Date().addingTimeInterval(Self.isIOS26_5Simulator ? 5 : 20)
        var ids: [String] = []
        var errorText: String?
        while Date() < deadline {
            do {
                let fetched = try await Product.products(for: CMSNProductID.all)
                ids = fetched.map(\.id).sorted()
                if Set(CMSNProductID.all).isSubset(of: Set(ids)) {
                    return
                }
            } catch {
                errorText = error.localizedDescription
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        if Self.isIOS26_5Simulator {
            throw XCTSkip(Self.ios26_5SkipMessage)
        }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTFail(
            """
            CMSN+ products did not load.
            configuration: \(Self.configurationURL()?.path ?? "missing")
            Product.products ids: \(ids)
            Product.products error: \(errorText ?? "none")
            runtime \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)
            """
        )
        throw LoadError.missingProduct
    }

    /// iOS 26.5.x simulator only. FB22500243 is fixed in iOS 26.6.
    /// A macOS version number must not take this branch.
    private static var isIOS26_5Simulator: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        #if targetEnvironment(simulator)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion == 26 && version.minorVersion == 5
        #else
        return false
        #endif
        #endif
    }

    private static let ios26_5SkipMessage = """
    Skipping StoreKitPurchaseFlowTests on the iOS 26.5 simulator does not prove purchases. SKTestSession does not connect there (FB22500243, fixed in the iOS 26.6 simulator). The full CMSNAppTests suite, including these tests, passed on the iOS 18.6 simulator on Nov 6, 2026. A 26.5 skip is still not a pass.
    """

    private func loadProduct(_ id: String, manager: StoreKitManager) async throws -> Product {
        let deadline = Date().addingTimeInterval(20)
        var directIDs: [String] = []
        var directError: String?
        while Date() < deadline {
            if let product = manager.products.first(where: { $0.id == id }) {
                return product
            }
            do {
                let fetched = try await Product.products(for: CMSNProductID.all)
                directIDs = fetched.map(\.id).sorted()
            } catch {
                directError = error.localizedDescription
            }
            await manager.loadProducts()
            if let product = manager.products.first(where: { $0.id == id }) {
                return product
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTFail(
            """
            \(id) did not load.
            configuration: \(Self.configurationURL()?.path ?? "missing")
            Product.products ids: \(directIDs)
            Product.products error: \(directError ?? "none")
            manager error: \(manager.lastError ?? "none")
            iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)
            """
        )
        throw LoadError.missingProduct
    }

    private func assertLockedPrice(
        _ product: Product,
        _ expected: String,
        periodUnit: Product.SubscriptionPeriod.Unit
    ) {
        guard let expectedPrice = Decimal(string: expected, locale: Locale(identifier: "en_US")) else {
            return XCTFail("Could not parse \(expected)")
        }
        XCTAssertEqual(product.price, expectedPrice)
        XCTAssertTrue(product.displayPrice.contains(expected), product.displayPrice)
        XCTAssertEqual(product.subscription?.subscriptionPeriod.unit, periodUnit)
        XCTAssertEqual(product.subscription?.subscriptionPeriod.value, 1)
    }

    /// Throws after recording the failure so a wrong period does not call purchase.
    private func assertSevenDayTrial(_ product: Product) throws {
        let offer = product.subscription?.introductoryOffer
        XCTAssertEqual(offer?.paymentMode, .freeTrial, product.id)
        XCTAssertEqual(offer?.periodCount, 1, product.id)
        let unit = offer?.period.unit
        let value = offer?.period.value ?? 0
        let matches = unit.map { CMSNIntroductoryTrial.isSingleFreeSevenDays(unit: $0, value: value) } ?? false
        XCTAssertTrue(
            matches,
            "\(product.id) introductory period \(String(describing: unit)) \(value) is not 7 days (one week or seven days)."
        )
        if offer?.paymentMode != .freeTrial || offer?.periodCount != 1 || !matches {
            throw LoadError.trialMismatch
        }
    }

    /// `product.purchase` returned "Purchase cancelled" about 80s after
    /// SKInternalErrorDomain Code=3 on the 2026-11-06 unsigned run, and the
    /// ad-hoc log ended inside that call. The suite was killed at 600s.
    /// This bound fails the test instead of waiting out the runner. It cannot
    /// force StoreKit to return if that call ignores cancellation.
    private func finishPurchase(_ product: Product, manager: StoreKitManager) async throws {
        let gate = CompletionGate()
        let task = Task { @MainActor in
            await manager.purchase(product)
            gate.finish()
        }
        if await gate.wait(seconds: 30) {
            _ = await task.value
            return
        }
        task.cancel()
        XCTFail(
            """
            purchase did not return within 30s for \(product.id). \
            A stuck purchase is a failure. On iOS 26.5, SKTestSession logged \
            SKInternalErrorDomain Code=3 before product.purchase blocked.
            """
        )
        throw LoadError.purchaseTimeout
    }

    private func buyProduct(_ productID: String, session: SKTestSession) async throws {
        let gate = CompletionGate()
        let task = Task { @MainActor in
            defer { gate.finish() }
            _ = try await session.buyProduct(identifier: productID, options: [])
        }
        if await gate.wait(seconds: 30) {
            try await task.value
            return
        }
        task.cancel()
        XCTFail("buyProduct did not return within 30s for \(productID).")
        throw LoadError.purchaseTimeout
    }

    private func waitUntil(_ manager: StoreKitManager, subscribed: Bool) async throws {
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            await manager.refreshEntitlements()
            if manager.isSubscribed == subscribed { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("Expected isSubscribed \(subscribed) but it was \(manager.isSubscribed). \(manager.lastError ?? "")")
        throw LoadError.entitlementTimeout
    }

    private func currentTransaction(for productID: String) async throws -> Transaction? {
        let gate = CompletionGate()
        let task = Task { () -> Transaction? in
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, transaction.productID == productID {
                    return transaction
                }
            }
            return nil
        }
        let watcher = Task {
            let found = await task.value
            gate.finish()
            return found
        }
        if await gate.wait(seconds: 6) {
            return await watcher.value
        }
        task.cancel()
        watcher.cancel()
        XCTFail("Transaction.currentEntitlements did not finish within 6s for \(productID).")
        throw LoadError.entitlementTimeout
    }
}

private enum LoadError: Error {
    case missingProduct
    case entitlementTimeout
    case trialMismatch
    case purchaseTimeout
}

/// One free introductory period of exactly seven days.
/// `P1W` in Configuration.storekit is one week. StoreKit on iOS 26.5 reported
/// that same offer as unit Day, value 7 (log lines for both product ids).
enum CMSNIntroductoryTrial {
    static func isSingleFreeSevenDays(unit: Product.SubscriptionPeriod.Unit, value: Int) -> Bool {
        switch unit {
        case .day:
            return value == 7
        case .week:
            return value == 1
        case .month, .year:
            return false
        @unknown default:
            return false
        }
    }
}

/// Set from a purchase task. `wait` returns without joining that task, so a
/// StoreKit call that ignores cancellation does not keep the test method parked
/// for the runner's 600s kill. The call itself can still outlive the test.
private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func finish() {
        setDone(true)
    }

    func wait(seconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if isDone() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return isDone()
    }

    /// Lock use stays in these synchronous methods. Swift 6 rejects
    /// `NSLock.lock()` directly inside an async function, including across
    /// a later `await`. The lock is not held while `wait` sleeps.
    private func isDone() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return done
    }

    private func setDone(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        done = value
    }
}

private struct StoreKitConfigurationFile: Decodable {
    struct Group: Decodable {
        struct Subscription: Decodable {
            struct Intro: Decodable {
                let numberOfPeriods: Int
                let paymentMode: String
                let subscriptionPeriod: String
            }

            let displayPrice: String
            let productID: String
            let introductoryOffer: Intro?
            let recurringSubscriptionPeriod: String
        }

        let subscriptions: [Subscription]
    }

    let subscriptionGroups: [Group]
}
