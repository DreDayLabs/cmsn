import StoreKit
import XCTest
@testable import CMSNApp

/// Product IDs, locked display prices, and the screenshot launch argument.
/// Live buy / restore / expire / cancel runs in `StoreKitPurchaseFlowTests`
/// against `Configuration.storekit`.
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

    func testScreenshotSubscribedArgument() {
        XCTAssertEqual(StoreKitManager.screenshotSubscribedArgument, "-CMSNScreenshotSubscribed")
        XCTAssertFalse(StoreKitManager.prefersSubscribedScreenshot([]))
        XCTAssertFalse(StoreKitManager.prefersSubscribedScreenshot(["-CMSNResetFirstRun"]))
        #if DEBUG
        XCTAssertTrue(StoreKitManager.prefersSubscribedScreenshot([StoreKitManager.screenshotSubscribedArgument]))
        #else
        XCTAssertFalse(StoreKitManager.prefersSubscribedScreenshot([StoreKitManager.screenshotSubscribedArgument]),
                       "Release must never grant access from a screenshot launch argument.")
        #endif
    }

    func testPurchaseErrorCopyStaysClean() {
        XCTAssertEqual(
            StoreKitManager.purchaseErrorMessage(for: SKError(.paymentCancelled)),
            "Purchase cancelled."
        )
        XCTAssertEqual(
            StoreKitManager.purchaseErrorMessage(for: StoreKitError.userCancelled),
            "Purchase cancelled."
        )
        XCTAssertEqual(
            StoreKitManager.purchaseErrorMessage(for: BlankError()),
            "Purchase failed."
        )
    }

    func testManagerStartsUnsubscribedBeforeAnyEntitlementCheck() {
        // A fresh manager must never default to "subscribed" — that would
        // silently unlock CMSN+ gating for every user before any real
        // entitlement check has run.
        let manager = StoreKitManager()
        XCTAssertFalse(manager.isSubscribed)
        XCTAssertFalse(manager.isPurchasing)
    }
}

private struct BlankError: LocalizedError {
    var errorDescription: String? { "  " }
}
