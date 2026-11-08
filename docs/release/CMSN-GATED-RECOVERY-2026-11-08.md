# CMSN gated recovery evidence — 2026-11-08

Recovered the uncommitted Nov 7 CMSN+ implementation without changing its source checkout into release/cmsn-gated-20261108 based on main 36da2b775afcc0193798e905140b582a914efa5f. Retained main's Watch upload fix; regenerated Xcode project with XcodeGen.

Additional corrections: separate Monthly/Annual selection from purchase action, visible and accessible selected state; disclose Open Food Facts retained diagnostic logs in app privacy manifest, legal page, and website privacy source. No prices or product identifiers changed.

## Verified
- xcodebuild test on dedicated iPhone 16 Pro Max iOS18.6 simulator F5D9074B-DACC-4606-B597-DF230EE14168: 249 tests, zero failures, TEST SUCCEEDED, exit0.
- Evidence: /Users/thoughtgardenlabsllc/Documents/CMSNGatedRelease-20261108/evidence/gated-final-unit.xcresult and gated-final-unit.log.
- CMSN App Store Connect privacy label published and verified 2026-11-08: Other Diagnostic Data, Analytics and App Functionality, linked to user, no tracking. Build3 untouched; no App Review submission.
- Open Food Facts privacy policy https://world.openfoodfacts.org/privacy states IP and logs retained three years for security, technical analyses and popularity. App sends barcode/search query, fixed user agent and network IP to world.openfoodfacts.org. No custom analytics/crash SDK or CMSN backend found. Apple StoreKit/MapKit network services also exist; network traffic is not automatically developer collection.

## NOT final release approval
- Required lifetime purchase lacks a verified StoreKit product identifier and implementation. Do not invent one.
- Exact mandated Bench Press 4x8@185lb example with last-Tuesday 8/8/8/7, readiness86 cannot be reproduced by current engine, which uses a latest-set rule and categorical readiness. Existing truthful Smith Machine80kg example remains; it does NOT fulfill exact brief truth test.
- No structured running-program surface exists; run recording remains available.
- The requested 10-step signed archive/TestFlight verification matrix has NOT run. Simulator unit tests (including local StoreKit tests) are not a substitute. Step8 lifetime is unsupported; step10 exact fixture is unmet.
- No new gated archive/upload or final screenshot capture has been certified. Version1.0/build3 remains source project configuration, not a claim of newly archived gated build. Increment before any new upload, never disturb accepted build3.
- Website privacy source correction is not yet deployed.
