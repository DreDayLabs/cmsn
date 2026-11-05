import XCTest
@testable import CMSNApp

/// StoreKit 2's live purchase/entitlement flow needs a `.storekit`
/// configuration attached to the running scheme (`SKTestSession`) to
/// exercise meaningfully, which this test target doesn't assume is present
/// in every environment. These tests stick to what's safe to assert without
/// that: product ID configuration and the manager's default state.
@MainActor
final class StoreKitManagerTests: XCTestCase {
    func testProductIdentifiersAreDistinct() {
        XCTAssertNotEqual(CMSNProductID.monthly, CMSNProductID.annual)
    }

    func testAllProductIdentifiersListsBothProducts() {
        XCTAssertEqual(Set(CMSNProductID.all), Set([CMSNProductID.monthly, CMSNProductID.annual]))
    }

    func testPaywallDisplayPrices() {
        XCTAssertEqual(CMSNPlusDisplayPrice.monthly, "$9.99")
        XCTAssertEqual(CMSNPlusDisplayPrice.annual, "$59.99")
        XCTAssertEqual(
            CMSNPlusDisplayPrice.resolve(storePrice: nil, fallback: CMSNPlusDisplayPrice.monthly),
            "$9.99"
        )
        XCTAssertEqual(
            CMSNPlusDisplayPrice.resolve(storePrice: "  ", fallback: CMSNPlusDisplayPrice.annual),
            "$59.99"
        )
        XCTAssertEqual(
            CMSNPlusDisplayPrice.resolve(storePrice: "$9.99", fallback: CMSNPlusDisplayPrice.monthly),
            "$9.99"
        )
    }

    func testManagerStartsUnsubscribedBeforeAnyEntitlementCheck() {
        // A fresh manager must never default to "subscribed" — that would
        // silently unlock CMSN+ gating for every user before any real
        // entitlement check has run.
        let manager = StoreKitManager()
        XCTAssertFalse(manager.isSubscribed)
    }
}
