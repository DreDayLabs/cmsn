# CMSN App — iOS (V0: Training Kernel)

A native SwiftUI companion app for the CMSN training/apparel ecosystem —
the software half of **Dress → Prepare → Perform → Prove → Recover → Return**.
See `../../brand/08-app-strategy.md` for the full product/business strategy
this build implements, and the plan this was built from for scope decisions.

The canonical project is preserved from `preservation/cmsn-canonical-ios-project-20260826`
and synchronized with current sources using XcodeGen 2.46.0. Both generated project and
plists are committed; `project.yml` governs configuration changes. See
`../../docs/consolidation/2026-09-14.md` for current verification and limitations.

## Requirements

- macOS, Xcode 26.6 for the verified build; iOS deployment target 17.
- XcodeGen 2.46.0 to regenerate after configuration/source changes.

## First build

```bash
cd ios/CMSNApp
xcodegen generate
open CMSNApp.xcodeproj
```

In Xcode:

1. Select the `CMSNApp` scheme and an iOS 17+ simulator.
2. **Signing:** `DEVELOPMENT_TEAM` in `project.yml` under `settings.base` is
   `G2MXBX48PD` (Thought Garden Labs LLC). The `CMSNApp` target uses
   automatic signing. The bundle id stays `com.earnyourcmsn.app`. The watch
   build step passes `CODE_SIGNING_ALLOWED=NO`. The unit-test step passes
   `CODE_SIGN_IDENTITY=-` for hosted CI. That is an ad-hoc signature with
   no team. At `6950582`, iPhone 16 on iOS 18.6 ran
   `StoreKitPurchaseFlowTests` 7/7 under that ad-hoc signature, with no
   skip and no hang. That 7 is how many methods that tree discovered.
   A device install and a signed archive are a
   separate gate: they need a provisioning profile for
   `com.earnyourcmsn.app` and `com.earnyourcmsn.app.watchkitapp`. Ad-hoc
   with `TeamIdentifier` unset is not that profile.
3. Camera and calendar usage strings are in the generated Info.plist.
   HealthKit is declared for the phone and the watch
   (`CMSNApp.entitlements` and `CMSNWatchApp.entitlements`). Enable the
   HealthKit capability on App IDs `com.earnyourcmsn.app` and
   `com.earnyourcmsn.app.watchkitapp` in the Apple developer portal before
   a signed device or TestFlight build. The watch build step sets
   `CODE_SIGNING_ALLOWED=NO` and can compile without that portal switch.
   StoreKit 2 needs no entitlement key. EventKit needs no capability, only
   the calendar usage strings. Location, motion, and Bluetooth usage
   strings are present because a run asks for them when it starts.
4. Build & run (⌘R).

## Local subscription testing

`CMSNApp/Resources/Configuration.storekit` is a local StoreKit test
configuration with the CMSN+ monthly ($9.99) and annual ($59.99) products
and a 7-day free introductory trial (`P1W`, one free period). The product
IDs are the ones in `StoreKitManager.swift`:

- `com.earnyourcmsn.app.plus.monthly`
- `com.earnyourcmsn.app.plus.annual`

The CMSNApp, CMSNAppTests, and CMSNScreenshots schemes select this file
for Run and for Test. The identifier is
`../../../CMSNApp/Resources/Configuration.storekit`, the path from the
shared `.xcscheme` to `CMSNApp/Resources/Configuration.storekit`. No App
Store Connect account and no charge. `SKTestSession` loads the same file
from the test bundle by the name `Configuration`. This app stays an iOS
target. There is no Catalyst scheme.

`StoreKitPurchaseFlowTests` has eight class-level test methods: the local
file, the 7-day period check, the completion-gate timeout, buy, restore,
expiry, a failed purchase, and a cancelled purchase. A `func test` nested
inside another method is not one of them. XCTest did not discover
`testCompletionGateSeesFinishAndTimesOut` at `351cc35` because the `for`
in `testSevenDayTrialAcceptsOnlyEquivalentPeriods` had no closing brace,
so the gate method was inside the trial method. That class run was 6/7,
exit 65, 77 seconds, no hang. `testRestoreBringsBackEntitlementAfterReset`
failed in `waitUntil` with `isSubscribed` false. The same method passed
when selected alone. An isolated pass is not a pass of the class.

These runs stay separate. They are not one signing failure.

- `77ef95f`, iOS 26.5 simulator `6E241A20-3408-48C5-8B6F-DE4D07BCE21A`, `CODE_SIGNING_ALLOWED=NO`. `SKTestSession` logged `SKInternalErrorDomain` Code=3 for saving the configuration, setting two values, and deleting transactions. The trial asserts then failed (Day / 7 versus Week / 1). `product.purchase` returned. The test recorded `Purchase cancelled.` and `isSubscribed` false. The case ended in 86 seconds. This log does not show a 600 second kill.
- `77ef95f`, same simulator, `CODE_SIGN_IDENTITY=-` (`codesign --sign -`). The same Code=3 lines and the same Day / 7 mismatch are in that log. The file ends during the purchase, with no purchase result and no 600 second kill.
- `6950582`, iPhone 16 / iOS 18.6, ad-hoc, `TeamIdentifier` unset. Reported 7/7, the strict period test 1/1, exit 0, no skip, no hang. That report does not include Code=3. It is the only reported iOS 18.6 pass of this class. Later heads are not that pass.
- `351cc35`, independent Mac. Reported 6/7, exit 65, 77 seconds, no hang, restore as above. That report does not include Code=3 or a signature.
- `54a7bb9`, iPhone 16 / iOS 18.6 simulator `D7E9E290-F385-47B9-A72E-B50989F6965C`, ad-hoc (`codesign --sign -`, `TeamIdentifier` not set). Two whole-class runs were killed at 600 seconds, exit 142. `testCompletionGateSeesFinishAndTimesOut` and `testLocalStoreKitFileMatchesLockedProducts` passed. `testBuyingTheTrialUnlocksCMSNPlus`, `testCancelledPurchaseShowsCleanErrorWithoutStuckPurchasing`, `testExpiryAndCancellationLockCMSNPlus`, and `testFailedPurchaseShowsCleanErrorWithoutStuckPurchasing` each failed in about 30 seconds: `purchase did not return within 30s`. The failure text named iOS 26.5 and Code=3. The runtime log has no `SKInternalErrorDomain` Code=3. Run 2 logs `Could not find a UI anchor` and `Could not get confirmation scene ID` for the monthly product, then `Making a purchase`. `testRestoreBringsBackEntitlementAfterReset` started and recorded no result. `testSevenDayTrialAcceptsOnlyEquivalentPeriods` did not start. That is 7 of 8 started. It is not 8/8.

Compile warnings left unchanged, from the `77ef95f` build: `RunSensors.swift:159` (`RunSpeechService.synthesizer` is `AVSpeechSynthesizer` and is non-Sendable) and `StoreKitManager.swift:51` (`nonisolated(unsafe)` has no effect on `transactionListenerTask`).

On 6 Nov 2026, before pull request #31 merged as `a777587`, the iOS 18.6
simulator reported `CMSNAppTests` 222/222, including the six purchase tests
in that tree. GitHub Actions run
[42229926250](https://github.com/DreDayLabs/cmsn/actions/runs/42229926250)
on `a777587` did not execute it: mac preflight hit a billing lock and
`build-and-test` was skipped.

The iOS 26.5 simulator still skips the purchase tests when products do not
load (`XCTSkip`, FB22500243). A skip is not a pass. A 26.5 skip is not the
iOS 18.6 result. Do not read the iOS 18.6 simulator pass as a signed
archive. No provisioning profile for `com.earnyourcmsn.app` or the watch
id was present for that check, and a signed archive was not attempted.

This tree has not been run here. Linux has no `xcodebuild`. A pass of this
class is two back-to-back runs of all eight methods, 8/8 and exit 0 each
time. Selecting only restore is not that run.

```bash
cd ios/CMSNApp
xcrun simctl list devices available
xcodebuild test \
  -project CMSNApp.xcodeproj \
  -scheme CMSNApp \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -only-testing:CMSNAppTests/StoreKitPurchaseFlowTests
```

Run that command a second time on the same simulator. Both results have to
list these eight names: `testLocalStoreKitFileMatchesLockedProducts`,
`testSevenDayTrialAcceptsOnlyEquivalentPeriods`,
`testCompletionGateSeesFinishAndTimesOut`,
`testBuyingTheTrialUnlocksCMSNPlus`,
`testRestoreBringsBackEntitlementAfterReset`,
`testExpiryAndCancellationLockCMSNPlus`,
`testFailedPurchaseShowsCleanErrorWithoutStuckPurchasing`,
`testCancelledPurchaseShowsCleanErrorWithoutStuckPurchasing`.

The CMSNScreenshots harness still passes `-CMSNResetFirstRun`. After the
main captures it relaunches with `-CMSNScreenshotSubscribed` (Debug only)
and writes `settings-subscribed.png` with the CMSN+ row Active. The page
videos are in the app target, not Git LFS. A fresh clone of the repository
still needs `GIT_LFS_SKIP_SMUDGE=1`, because the LFS quota blocks smudge of
`media/higgsfield` and `public/videos`. Screenshots captured before
marketing version 1.0 are not submission assets. A submission set has to be
captured from this main, with that provenance recorded.

App Store Connect already has both product IDs (GET snapshot 2026-11-06
6:28 PM EST). Both subscriptions were `MISSING_METADATA`, and both review
screenshots were null. Prices and the introductory offer were not in that
snapshot. The IDs in `StoreKitManager.swift` must stay exact.

## Running tests

Once the project is generated and opens in Xcode: ⌘U, or from the command
line:

```bash
xcodebuild test -project CMSNApp.xcodeproj -scheme CMSNApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

`CMSNAppTests/` covers the pure-logic layer: e1RM/progression math, weight
rounding, equipment substitution, injury-based exercise exclusion/load
reduction, program rotation, macro targets, readiness banding, the
four-dimension score model (including partial-session and rest-day
scoring), day-boundary/timezone handling for the Return-loop logic, and
the run kernel (pace, splits, personal records, GPS spike rejection,
the auto-pause state machine, and the V3 → V4 SwiftData migration).

## What's missing on purpose (see the plan's "Explicitly deferred to V1/V2")

- **App icon**: done — `Resources/Assets.xcassets/AppIcon.appiconset` has a
  1024×1024 icon generated from the same path data as
  `CMSNWordmarkSlashesShape` (the wordmark's trailing "//" mark), so it's
  vector-accurate rather than a raster approximation.
- **Bebas Neue font file**: done — `Resources/Fonts/BebasNeue-Regular.ttf`
  is bundled (OFL license alongside it) and registered under `UIAppFonts`.
- **Instructional video library**: `ExerciseCardView` has the UI slot
  (`demonstrationVideoAssetName`) but no real video assets — V1 scope.
- **Apple Watch run**: `CMSNWatchApp` is a watchOS application embedded
  in the iOS app (Embed Watch Content). It records an outdoor or indoor
  run, including a night-visibility screen, and transfers the finished
  file to the phone. Logging strength sets from the wrist is still out
  of scope.
- **Cloud sync / backend**: everything is local-only via SwiftData. No
  Supabase, no auth, no cross-device sync, no server-side entitlement
  validation. V2 scope — see `brand/08-app-strategy.md`.

## Known things to double-check on first build

I'm confident in the domain logic (it's unit-tested), less confident in a
few API-surface details that shift across Xcode versions and that I
couldn't verify by compiling:

1. **SwiftData `@Relationship(inverse:)` syntax** in `WorkoutModels.swift`,
   `NutritionModels.swift` etc. — written against the Xcode 15 SwiftData
   API. If your Xcode version's SwiftData macro expansion differs, this is
   the first place to look for compiler errors.
2. **`StoreKitManager.swift`** uses `Transaction.currentEntitlements`,
   `AppStore.sync()`, and the `Product.PurchaseResult` switch — these are
   stable StoreKit 2 APIs but double-check against your SDK version if you
   see unexpected warnings.
3. **`Configuration.storekit`** — hand-authored JSON matching the schema I
   last saw Xcode generate. If Xcode complains about the file's structure,
   the fastest fix is: delete it, let Xcode create a fresh empty
   `.storekit` file via File → New → File → StoreKit Configuration File,
   then re-add the two subscription products through Xcode's UI using the
   pricing/trial details in `brand/08-app-strategy.md`.
4. **`.onChange(of:)` zero-argument closures** in `TrainingProfileStepView`
   — valid iOS 17 API, but confirm your deployment target didn't slip
   below 17.0 anywhere in `project.yml`.
5. **EventKit `requestFullAccessToEvents`** in `CalendarSplitService` is
   iOS 17+; if you lower the deployment target below that, this needs to
   fall back to the older `requestAccess(to:completion:)` API.

None of these are guesses made carelessly — they're the specific spots
where SwiftData/StoreKit's newest APIs are most likely to have moved
between SDK point releases. Everything else (the design system, the
suggestion/score/resolver logic, the view hierarchy) is ordinary,
well-established SwiftUI and should build without surprises.
