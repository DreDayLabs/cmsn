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
    /// One session for every method. XCTest builds a new instance per test,
    /// so an instance property would not survive. A second `SKTestSession`
    /// in the same process does not own the store the first one cleared.
    /// At `351cc35` restore failed in the class (`isSubscribed` false from
    /// `waitUntil`) and passed when that method was selected alone.
    private static var sharedSession: SKTestSession?

    private static let purchaseFlowTestNames = [
        "testLocalStoreKitFileMatchesLockedProducts",
        "testSevenDayTrialAcceptsOnlyEquivalentPeriods",
        "testCompletionGateSeesFinishAndTimesOut",
        "testBuyingTheTrialUnlocksCMSNPlus",
        "testRestoreBringsBackEntitlementAfterReset",
        "testExpiryAndCancellationLockCMSNPlus",
        "testFailedPurchaseShowsCleanErrorWithoutStuckPurchasing",
        "testCancelledPurchaseShowsCleanErrorWithoutStuckPurchasing",
    ]

    override func tearDown() async throws {
        if let session = Self.sharedSession {
            session.resetToDefaultState()
            session.clearTransactions()
            session.disableDialogs = true
            session.askToBuyEnabled = false
            try await within("tearDown setSimulatedError nil purchase", seconds: 10) {
                try await session.setSimulatedError(nil, forAPI: .purchase)
            }
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
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        XCTAssertEqual(
            Self.classLevelTestMethodNames(in: source),
            Self.purchaseFlowTestNames,
            "A test method nested in another test is not discovered. Counting func test with a regex still sees the nested one."
        )
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

    func testBuyingTheTrialUnlocksCMSNPlus() async throws {
        let session = try await openSession()
        let manager = StoreKitManager(autoStart: false)
        try await ensureStoreKitCatalog()
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        let annual = try await loadProduct(CMSNProductID.annual, manager: manager)

        assertLockedPrice(monthly, "9.99", periodUnit: .month)
        assertLockedPrice(annual, "59.99", periodUnit: .year)
        // A failed trial check must not enter purchase(). The 2026-11-06
        // unsigned iOS 26.5 log failed the week-vs-7-days asserts and still
        // entered product.purchase, which returned "Purchase cancelled."
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
        let cleared = StoreKitManager(autoStart: false)
        try await waitUntil(cleared, subscribed: false)
        try await buyProduct(CMSNProductID.monthly, session: session)

        let primed = StoreKitManager(autoStart: false)
        try await waitUntil(primed, subscribed: true)

        // A new manager is the reset: nothing cached, the store still has the purchase.
        let restored = StoreKitManager(autoStart: false)
        XCTAssertFalse(restored.isSubscribed)
        XCTAssertFalse(restored.isPurchasing)
        try await within("restorePurchases", seconds: 30) {
            await restored.restorePurchases()
        }
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
        let session: SKTestSession
        if let existing = Self.sharedSession {
            session = existing
        } else {
            let url = try XCTUnwrap(
                Self.configurationURL(),
                "Configuration.storekit is missing from the test bundle and the app bundle."
            )
            // configurationFileNamed is the path StoreKit Test uses to hand the
            // host a real file. contentsOf is the fallback when the test bundle
            // name lookup misses the copied resource.
            do {
                session = try SKTestSession(configurationFileNamed: "Configuration")
            } catch {
                session = try SKTestSession(contentsOf: url)
            }
            Self.sharedSession = session
        }
        session.resetToDefaultState()
        session.clearTransactions()
        // 54a7bb9 set disableDialogs before reset. Run 1 and run 2 on iOS 18.6
        // then logged "Could not find a UI anchor" and the purchase did not
        // return. The log does not say reset cleared the flag. The flag is
        // written again after reset so it is the value in effect at purchase.
        session.disableDialogs = true
        session.askToBuyEnabled = false
        try await within("setSimulatedError nil purchase", seconds: 10) {
            try await session.setSimulatedError(nil, forAPI: .purchase)
        }
        // iOS 26 needs a beat after the session attaches before the first
        // Product.products request. A request that lands earlier stays empty.
        try await Task.sleep(nanoseconds: 500_000_000)
        return session
    }

    /// `func test…` whose brace depth is the class body. A method nested in
    /// another test is omitted. This is the source shape, not XCTest's runtime list.
    static func classLevelTestMethodNames(in source: String) -> [String] {
        let marker = "final class StoreKitPurchaseFlowTests"
        guard let header = source.range(of: marker),
              let open = source[header.upperBound...].firstIndex(of: "{") else {
            return []
        }
        var index = source.index(after: open)
        var depth = 1
        var names: [String] = []
        var lineComment = false
        var blockComment = false
        var inString = false
        var triple = false
        while index < source.endIndex, depth > 0 {
            let character = source[index]
            let next = source.index(after: index)
            if lineComment {
                if character == "\n" { lineComment = false }
                index = next
                continue
            }
            if blockComment {
                if character == "*", next < source.endIndex, source[next] == "/" {
                    blockComment = false
                    index = source.index(after: next)
                    continue
                }
                index = next
                continue
            }
            if triple {
                if source[index...].hasPrefix("\"\"\"") {
                    triple = false
                    index = source.index(index, offsetBy: 3)
                    continue
                }
                index = next
                continue
            }
            if inString {
                if character == "\\" {
                    index = next < source.endIndex ? source.index(after: next) : source.endIndex
                    continue
                }
                if character == "\"" { inString = false }
                index = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                lineComment = true
                index = source.index(after: next)
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "*" {
                blockComment = true
                index = source.index(after: next)
                continue
            }
            if source[index...].hasPrefix("\"\"\"") {
                triple = true
                index = source.index(index, offsetBy: 3)
                continue
            }
            if character == "\"" {
                inString = true
                index = next
                continue
            }
            if character == "{" {
                depth += 1
                index = next
                continue
            }
            if character == "}" {
                depth -= 1
                index = next
                continue
            }
            if depth == 1, source[index...].hasPrefix("func test") {
                var nameIndex = source.index(index, offsetBy: 5)
                while nameIndex < source.endIndex, source[nameIndex].isWhitespace {
                    nameIndex = source.index(after: nameIndex)
                }
                var end = nameIndex
                while end < source.endIndex {
                    let part = source[end]
                    if part.isLetter || part.isNumber || part == "_" {
                        end = source.index(after: end)
                        continue
                    }
                    break
                }
                let name = String(source[nameIndex..<end])
                if name.hasPrefix("test") {
                    names.append(name)
                }
                index = end
                continue
            }
            index = next
        }
        return names
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
                let fetched = try await within("Product.products", seconds: 10) {
                    try await Product.products(for: CMSNProductID.all)
                }
                ids = fetched.map(\.id).sorted()
                if Set(CMSNProductID.all).isSubset(of: Set(ids)) {
                    return
                }
            } catch LoadError.purchaseTimeout {
                throw LoadError.purchaseTimeout
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
    Skipping StoreKitPurchaseFlowTests on the iOS 26.5 simulator does not prove purchases. SKTestSession does not connect there (FB22500243, fixed in the iOS 26.6 simulator). A skip is not a pass. An iOS 18.6 pass of this class was reported for head 6950582 only. Later heads are not that pass.
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
                let fetched = try await within("Product.products", seconds: 10) {
                    try await Product.products(for: CMSNProductID.all)
                }
                directIDs = fetched.map(\.id).sorted()
            } catch LoadError.purchaseTimeout {
                throw LoadError.purchaseTimeout
            } catch {
                directError = error.localizedDescription
            }
            try await within("loadProducts", seconds: 10) {
                await manager.loadProducts()
            }
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

    /// Fails if the call does not return. `task.cancel()` does not mean
    /// StoreKit stopped. The call may still be running after this returns.
    private func within<T>(
        _ label: String,
        seconds: TimeInterval,
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let gate = CompletionGate()
        let task = Task { @MainActor () throws -> T in
            defer { gate.finish() }
            return try await operation()
        }
        if await gate.wait(seconds: seconds) {
            return try await task.value
        }
        task.cancel()
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTFail(
            """
            \(label) did not return within \(Int(seconds))s. \
            iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion). \
            Cancelling the waiter does not stop the call.
            """
        )
        throw LoadError.purchaseTimeout
    }

    /// The 2026-11-06 unsigned log (`CODE_SIGNING_ALLOWED=NO`) recorded
    /// "Purchase cancelled." from this call. The ad-hoc log
    /// (`CODE_SIGN_IDENTITY=-`) ends during the purchase and has no result.
    /// On `54a7bb9` iOS 18.6 the same call did not return within 30s. The
    /// failure text names the runtime it is running on.
    private func finishPurchase(_ product: Product, manager: StoreKitManager) async throws {
        try await within("purchase \(product.id)", seconds: 30) {
            await manager.purchase(product)
        }
    }

    private func buyProduct(_ productID: String, session: SKTestSession) async throws {
        try await within("buyProduct \(productID)", seconds: 30) {
            _ = try await session.buyProduct(identifier: productID, options: [])
        }
    }

    private func waitUntil(_ manager: StoreKitManager, subscribed: Bool) async throws {
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            try await within("refreshEntitlements", seconds: 6) {
                await manager.refreshEntitlements()
            }
            if manager.isSubscribed == subscribed { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTFail(
            """
            Expected isSubscribed \(subscribed) but it was \(manager.isSubscribed). \
            \(manager.lastError ?? "") \
            iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion).
            """
        )
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
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTFail(
            """
            Transaction.currentEntitlements did not finish within 6s for \(productID). \
            iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion). \
            Cancelling the waiter does not stop the call.
            """
        )
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
