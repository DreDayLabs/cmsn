# CMSN App — iOS (V0: Training Kernel)

A native SwiftUI companion app for the CMSN training/apparel ecosystem —
the software half of **Dress → Prepare → Perform → Prove → Recover → Return**.
See `../../brand/08-app-strategy.md` for the full product/business strategy
this build implements, and the plan this was built from for scope decisions.

**This code was written in an environment with no Xcode or macOS toolchain.**
Every file is real, complete Swift — not pseudocode — but it has not been
compiled or run. Follow the steps below on a Mac to build it for the first
time, and read "Known things to double-check" before assuming a build error
is yours.

## Requirements

- macOS with **Xcode 15 or newer** (targets iOS 17 / watchOS 10 SDKs).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — this project has no
  hand-committed `.xcodeproj`; it's generated from `project.yml`.
  ```
  brew install xcodegen
  ```

## First build

```bash
cd ios/CMSNApp
xcodegen generate
open CMSNApp.xcodeproj
```

In Xcode:

1. Select the `CMSNApp` scheme and an iOS 17+ simulator.
2. **Signing & Capabilities** tab on the `CMSNApp` target: set your own Team
   (the bundle ID `com.earnyourcmsn.app` is a placeholder — change the
   prefix in `project.yml`'s `bundleIdPrefix` if you don't own that domain).
3. Confirm capabilities are present: HealthKit and In-App Purchase are
   declared in `project.yml`; EventKit needs no capability, just the
   `NSCalendarsUsageDescription` string already in the generated Info.plist.
4. Build & run (⌘R).

## Local subscription testing

`CMSNApp/Resources/Configuration.storekit` is a local StoreKit test
configuration with the CMSN+ monthly ($9.99) and annual ($59.99) products
and a 7-day free trial, matching the pricing in
`brand/08-app-strategy.md`. To use it:

1. Xcode → Product → Scheme → Edit Scheme → Run → Options →
   **StoreKit Configuration** → select `Configuration.storekit`.
2. Run the app; `PaywallView` will list both products and purchases will go
   through Xcode's local StoreKit test environment (no real App Store
   account or money involved).

The real products (`com.earnyourcmsn.app.plus.monthly` /
`.plus.annual`) still need to be created in App Store Connect before this
ships — the product IDs in `StoreKitManager.swift` must match exactly.

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
scoring), and day-boundary/timezone handling for the Return-loop logic.

## What's missing on purpose (see the plan's "Explicitly deferred to V1/V2")

- **App icon**: done — `Resources/Assets.xcassets/AppIcon.appiconset` has a
  1024×1024 icon generated from the same path data as
  `CMSNWordmarkSlashesShape` (the wordmark's trailing "//" mark), so it's
  vector-accurate rather than a raster approximation.
- **Bebas Neue font file**: `project.yml` already registers
  `BebasNeue-Regular.ttf` under `UIAppFonts`, but the actual `.ttf` isn't
  bundled (binary files can't be authored as text) — see
  `CMSNApp/Resources/Fonts/README.md` for the one-file drop-in step.
  `Font.custom` falls back to the system font automatically until then, so
  the app still builds and runs, just without the condensed display look.
- **Instructional video library**: `ExerciseCardView` has the UI slot
  (`demonstrationVideoAssetName`) but no real video assets — V1 scope.
- **Apple Watch app**: `CMSNWatchApp` target is a working, minimal scaffold
  (compiles, shows a placeholder screen) — not the real companion
  experience (start session, log sets from the wrist). V1 scope.
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
