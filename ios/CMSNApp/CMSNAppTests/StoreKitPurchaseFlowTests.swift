import StoreKit
import StoreKitTest
import XCTest
@testable import CMSNApp

/// Local StoreKit proof for CMSN+. Uses `Configuration.storekit` through
/// `SKTestSession` — no App Store Connect account and no charge.
///
/// The Run action of the CMSNApp scheme points at the same file for a
/// Simulator ⌘R. These tests load the file themselves and do not use a
/// purchase dialog.
@MainActor
final class StoreKitPurchaseFlowTests: XCTestCase {
    private var session: SKTestSession?

    override func tearDown() async throws {
        if let session {
            session.disableDialogs = true
            session.resetToDefaultState()
            session.clearTransactions()
        }
        session = nil
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

    func testBuyingTheTrialUnlocksCMSNPlus() async throws {
        let session = try openSession()
        let manager = StoreKitManager(autoStart: false)
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        let annual = try await loadProduct(CMSNProductID.annual, manager: manager)

        assertLockedPrice(monthly, "9.99", periodUnit: .month)
        assertLockedPrice(annual, "59.99", periodUnit: .year)
        assertSevenDayTrial(monthly)
        assertSevenDayTrial(annual)

        XCTAssertFalse(manager.isSubscribed)
        XCTAssertFalse(manager.isPurchasing)
        await manager.purchase(monthly)

        XCTAssertFalse(manager.isPurchasing)
        XCTAssertNil(manager.lastError)
        try await waitUntil(manager, subscribed: true)
        let transaction = try await XCTUnwrapAsync(currentTransaction(for: CMSNProductID.monthly))
        if #available(iOS 17.2, *) {
            XCTAssertEqual(transaction.offer?.type, .introductory)
        } else {
            XCTAssertEqual(transaction.offerType, .introductory)
        }
        _ = session
    }

    func testRestoreBringsBackEntitlementAfterReset() async throws {
        let session = try openSession()
        session.clearTransactions()
        _ = try await session.buyProduct(identifier: CMSNProductID.monthly, options: [])

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
        let session = try openSession()
        let manager = StoreKitManager(autoStart: false)
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)

        await manager.purchase(monthly)
        try await waitUntil(manager, subscribed: true)
        try session.expireSubscription(productIdentifier: CMSNProductID.monthly)
        try await waitUntil(manager, subscribed: false)

        _ = try await session.buyProduct(identifier: CMSNProductID.annual, options: [])
        try await waitUntil(manager, subscribed: true)
        let external = try XCTUnwrap(
            session.allTransactions().last { $0.productIdentifier == CMSNProductID.annual }
        )
        try session.disableAutoRenewForTransaction(identifier: external.identifier)
        try session.expireSubscription(productIdentifier: CMSNProductID.annual)
        try await waitUntil(manager, subscribed: false)

        _ = try await session.buyProduct(identifier: CMSNProductID.monthly, options: [])
        try await waitUntil(manager, subscribed: true)
        let refundable = try XCTUnwrap(
            session.allTransactions().last { $0.productIdentifier == CMSNProductID.monthly }
        )
        try session.refundTransaction(identifier: refundable.identifier)
        try await waitUntil(manager, subscribed: false)
        XCTAssertFalse(manager.isPurchasing)
    }

    func testFailedPurchaseShowsCleanErrorWithoutStuckPurchasing() async throws {
        let session = try openSession()
        let manager = StoreKitManager(autoStart: false)
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))),
            forAPI: .purchase
        )

        XCTAssertFalse(manager.isPurchasing)
        await manager.purchase(monthly)
        XCTAssertFalse(manager.isPurchasing, "The purchasing flag stayed on after a failed purchase.")
        XCTAssertFalse(manager.isSubscribed)
        let message = try XCTUnwrap(manager.lastError)
        XCTAssertTrue(message.hasPrefix("Purchase failed:"), message)
        XCTAssertNotEqual(message, "Purchase cancelled.")
    }

    func testCancelledPurchaseShowsCleanErrorWithoutStuckPurchasing() async throws {
        let session = try openSession()
        let manager = StoreKitManager(autoStart: false)
        let monthly = try await loadProduct(CMSNProductID.monthly, manager: manager)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)

        XCTAssertFalse(manager.isPurchasing)
        await manager.purchase(monthly)
        XCTAssertFalse(manager.isPurchasing, "The purchasing flag stayed on after a cancelled purchase.")
        XCTAssertFalse(manager.isSubscribed)
        XCTAssertEqual(manager.lastError, "Purchase cancelled.")
    }

    // MARK: - Session

    private func openSession() throws -> SKTestSession {
        let url = try XCTUnwrap(
            Self.configurationURL(),
            "Configuration.storekit is missing from the test bundle and the app bundle."
        )
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.resetToDefaultState()
        session.clearTransactions()
        self.session = session
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

    private func loadProduct(_ id: String, manager: StoreKitManager) async throws -> Product {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let product = manager.products.first(where: { $0.id == id }) {
                return product
            }
            await manager.loadProducts()
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        XCTFail("\(id) did not load. \(manager.lastError ?? "no error")")
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

    private func assertSevenDayTrial(_ product: Product) {
        let offer = product.subscription?.introductoryOffer
        XCTAssertEqual(offer?.paymentMode, .freeTrial, product.id)
        XCTAssertEqual(offer?.period.unit, .week, product.id)
        XCTAssertEqual(offer?.period.value, 1, product.id)
        XCTAssertEqual(offer?.periodCount, 1, product.id)
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

    private func currentTransaction(for productID: String) async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID {
                return transaction
            }
        }
        return nil
    }
}

private func XCTUnwrapAsync<T>(
    _ value: T?,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    try XCTUnwrap(value, message, file: file, line: line)
}

private enum LoadError: Error {
    case missingProduct
    case entitlementTimeout
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
