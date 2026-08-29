# CMSN iOS App — Current State

Audit date: 2026-08-29. Scope: repository `main` + PR #1 (`claude/cmsn-ios-fitness-app-yozz0i`,
"Add CMSN iOS app (V0 Training Kernel) and app/ecosystem strategy") against the product
direction in `brand/08-app-strategy.md`.

**Product framing.** CMSN the apparel company and CMSN the training app are connected but
distinct products. This document covers only the iOS app (`ios/CMSNApp/`) — the Next.js
site under `app/` and the apparel/brand material under `brand/` are a separate surface with
their own release posture and are out of scope here. Nothing in this audit assumes the app
must ship in lockstep with apparel drops, and nothing here touches the marketing site.

**Environment note.** This audit was performed in a Linux container with no Xcode/macOS
toolchain — everything below is a source-level read of the Swift code, not a local build.
Where the native gate's actual pass/fail status is asserted, it's sourced from PR #1's own
GitHub Actions run on a real macOS runner (`ios-build.yml`, job `build-and-test`), not from
anything run in this session. The fixes below were made by direct source edits and have not
been compiled locally; pushing this branch re-triggers `ios-build.yml` (it runs on any
`claude/**` branch), which is the actual verification step.

---

## READY

Verified either by reading the code against its own tests/spec, or by the PR's own CI run.

- **Native gate (build + test).** PR #1's CI run (`ios-build.yml`, run `32982329001`) built
  the app and ran the full `CMSNAppTests` suite on Xcode 26.6 / iOS 17 simulator: **52/52
  tests passed**, build succeeded. (This session added ~10 more tests as part of the fixes
  below — see "Verification still pending" at the end.)
- **SwiftData persistence.** Every `@Relationship(inverse:)` pair checked by hand — all
  correctly matched, no dangling or mismatched inverses (the risk the PR's own README
  flagged as unverified). Real `VersionedSchema`/`SchemaMigrationPlan` exists (not a single
  unversioned schema), with a correctly-additive V1→V2 stage. One `ModelContainer` is built
  once in `CMSNAppApp.init()` and shared everywhere. No cross-thread `ModelContext` access.
  Cascade-delete rules are correct for every parent/child pair that exists.
- **StoreKit / paywall plumbing.** Product identifiers match exactly across
  `StoreKitManager.swift`, `Configuration.storekit`, and the README. Pricing/trial
  ($9.99/mo, $59.99/yr, 7-day trial) matches `brand/08-app-strategy.md` §11 exactly.
  Entitlement checking uses `Transaction.currentEntitlements` + a live `Transaction.updates`
  listener + `AppStore.sync()` — reacts to purchase/refund/expiration while the app is
  running, not just at launch. No force-unwraps in the Subscription feature; product-load,
  purchase, and restore failures are all caught and surfaced via `lastError`, never crash.
- **CMSN Score weights.** `ScoreWeights` (25/25/20/30, summing to 1.0) match
  `brand/08-app-strategy.md` §7 exactly. No divergent second copy of the weights anywhere.
- **Return-after-inactivity scoring.** Scales positively (10 → 16 → 22 pts) with no
  off-by-one at the 7/14/21-day boundaries.
- **Rest-day Discipline parity.** A rest day's point contribution to Discipline is
  genuinely comparable to a completed training day's contribution to Work — not a token
  gesture.
- **No purchase-buys-score leakage.** Confirmed by direct search: `ScoreCalculator`,
  `ScoreEvent`, and `ScoreView` have zero references to `ApparelFeedback`, `StoreKitManager`,
  or `PaywallView`.
- **Mild-vs-significant limitation branching.** Correctly reduces load (0.8×) for mild
  limitations and attempts substitution-then-exclusion for significant ones.
- **Equipment substitution (no injury involved).** Residential/travel/quick-session
  equipment resolution is correct, and a quick-session equipment override never mutates the
  athlete's real persisted profile (verified: `ResolutionContext` is a value type, `Athlete`
  is never touched).
- **Onboarding softlock risk.** None found — every `OnboardingDraft` field ships a sane
  default, so there's no required-field dead end.

## BLOCKED

Real defects found this audit, **fixed in this session** (source-level, unverified by a
local build — see "Verification still pending"). Do not consider these closed until CI is
green on the commit that includes them.

1. **CMSN Score could be farmed by instantly finishing empty sessions.**
   `WorkoutSessionView.finishSession()` set `session.endedAt` *before* calling
   `ScoreCalculator.events(forSession:)`, and the scorer's "was this a full completion"
   check was `session.isComplete` — literally just `endedAt != nil`. So tapping "Finish
   Session" the instant a session was created (zero sets attempted) earned the full
   10-point completion bonus, not zero, and could be repeated indefinitely.
   **Fix:** added `WorkoutSession.wasFullyCompleted` (true only when every planned set was
   actually attempted) and switched `ScoreCalculator.events(forSession:)` to use it instead
   of `isComplete`. `SessionSummaryView` (which already computed the equivalent honestly)
   now delegates to the same model property instead of duplicating the logic.
2. **Consistency bonus awarded unconditionally, including on empty sessions.**
   `eventsForOnScheduleConsistency` was called on every `finishSession()` regardless of
   whether any real work happened — the same farming exploit as #1, on a second dimension.
   **Fix:** gated the call on `session.hasAnyLoggedWork` in `WorkoutSessionView`. (Full
   cadence-awareness — actually checking the athlete's planned training frequency — is not
   implemented and would be new scope; flagged under Founder Review below rather than
   invented here.)
3. **Abandoned in-progress sessions were silently orphaned, never scored.**
   `WorkoutSessionView.buildSession()` always created a brand-new `WorkoutSession` when a
   workout screen appeared. If the user backgrounded/killed the app, or simply navigated
   back before tapping "Finish," the previously-created session's `endedAt` stayed `nil`
   forever — excluded from rotation/history math, and since `finishSession()` was never
   called, **no `ScoreEvent`s were ever generated for that real logged work.** This directly
   contradicted the model's own documented guarantee ("partial completion is native...
   never coerced into didn't happen").
   **Fix:** added `WorkoutRepository.openSession()` (any session with `endedAt == nil`,
   mirroring the existing `NutritionRepository.createOrFetchToday` resume pattern) and had
   `buildSession()` resume it instead of creating a duplicate.
4. **Injury substitution only checked the single limitation that triggered the swap.**
   `ProgramResolver.isUsable(_:context:avoiding:)` took one optional `BodyArea` and only
   excluded a substitute if it loaded *that* area — never the athlete's full limitation
   list. Two concrete failure modes verified by hand-tracing against the real exercise
   catalog: (a) an athlete with both a significant shoulder limitation *and* a significant
   lower-back limitation, doing a lat-pulldown, could be substituted onto
   `seated-cable-row` — which loads lower back, never checked because the swap was only
   triggered by (and checked against) the shoulder conflict; (b) the **equipment**
   substitution path called `substitute(..., avoiding: nil)`, so it never checked
   limitations *at all* — an athlete with a significant shoulder limitation and a `.travel`
   equipment profile doing `db-bicep-curl` (safe on its own) could be equipment-substituted
   onto `band-pulldown`, which loads shoulder, with zero check.
   **Fix:** `substitute`/`isUsable` now take the athlete's full `activeLimitations` as a
   `Set<BodyArea>` and check every substitute against all of them, on both the
   limitation-triggered and equipment-triggered paths.
5. **Five `BodyArea` cases were selectable in injury intake but mapped to zero exercises.**
   `.quadriceps` and `.glute` never appeared in any seeded exercise's `loadedBodyAreas` —
   only the joint-level tags (`knee`, `hip`) were present — even though those same
   exercises' `primaryMuscleGroups` correctly listed `.quadriceps`/`.glutes`. A user
   reporting "Quadriceps — Clinician-directed limitation" would have been prescribed
   unmodified heavy squats, leg press, and lunges: the resolver would silently do nothing.
   **Fix:** added `.quadriceps`/`.glute` to `loadedBodyAreas` on `smith-squat`,
   `leg-press`, `db-walking-lunge`, `kb-goblet-squat` (both tags) and
   `db-romanian-deadlift`/`kb-swing` (`.glute`), matching what each exercise's own
   `primaryMuscleGroups` already claimed. `.hand`, `.generalSoreness`, and `.other` remain
   unmapped — see Founder Review, this needs a product/clinical decision, not a guess.
6. **A profile edit silently didn't persist.** `WorkoutPlanConfirmView.save()` mutated
   `athlete.preferredSessionLengthMinutes`/`trainingFrequencyPerWeek` directly without
   calling `context.save()`/`AthleteRepository.save()`, unlike every other write in the
   onboarding flow. Likely survived via SwiftData's scene-phase autosave in practice, but
   was an inconsistent, easy-to-regress pattern for a value the app treats as important.
   **Fix:** added the same `athleteRepository.save()` call used elsewhere in onboarding.

Regression tests were added for #1, #2 (indirectly, via #1's fix), #3, #4, and #5 in
`ScoreCalculatorTests.swift`, `WorkoutRepositoryTests.swift`, and `ProgramResolverTests.swift`
— see "Verification still pending."

## FOUNDER REVIEW

Not code bugs — decisions or business actions this audit can't make unilaterally.

- **`.hand` / `.generalSoreness` / `.other` limitation areas map to nothing.** Unlike the
  quad/glute gap above (an objective data-tagging fix), deciding what "General Soreness" or
  "Other" should actually do — apply a blanket session-wide load reduction? require a
  free-text note and no automated response? — is a product/clinical judgment call, not
  something to guess at in a bug-fix pass. `.hand` is narrower (grip involvement) but still
  debatable exercise-by-exercise. Needs a founder/clinical decision before it's implemented.
- **Real StoreKit product IDs don't exist in App Store Connect yet.**
  `com.earnyourcmsn.app.plus.monthly` / `.plus.annual` are consistent everywhere in code
  (this is correct, intentional V0 scope per the README and strategy doc) but until they're
  created in ASC, `Product.products(for:)` returns empty in production and the paywall
  permanently shows its "not configured yet" state. Business/App Store Connect task, not
  code.
- **StoreKit entitlement validation is 100% on-device**, with no server-side receipt
  check — explicit, documented V0/V1 scope (`brand/08-app-strategy.md`: real backend
  validation is V2). This is a standard scope tradeoff, but it's more vulnerable to
  jailbreak/tampering-based entitlement spoofing than a server-validated model, and revenue
  will start flowing through it once real products exist. Worth an explicit founder
  go/no-go before scaling on it, not just a fallthrough default.
- **`CMSNSchema.makeDefault()` crashes the app (`fatalError`) if the persistent store fails
  to open** (disk full, corrupt store, failed migration). The code's own comment
  acknowledges this is a deliberate V0 tradeoff ("a production app would surface a recovery
  path... V0 makes the failure loud"), not an oversight — but it means there is currently no
  path back for a real user whose store gets corrupted; the app is unusable until it's
  manually deleted and reinstalled. Founder/eng call on whether a recovery path (export +
  reset, or fall back to a fresh store) is needed before wider release.
- **Baseline accessibility gaps concentrated in the Design system**, which means they
  multiply across the whole app rather than being one-off: `CMSNTypography`'s
  `eyebrow()`/`body()`/`bodyQuiet()`/`numeric()` use fixed `.font(.system(size:))` with no
  Dynamic Type text style, so "Larger Text" does nothing for most of the app's body copy
  (contrast with `display()`, which correctly uses `relativeTo:`). The Readiness Check
  rating control on `Today` — the primary interaction before every single workout — is a
  bare `Rectangle().onTapGesture` roughly 6pt tall with no accessible label, well under
  Apple's ~44pt tap-target guidance, for anyone tapping precisely, not only VoiceOver users.
  The shared `CMSNTextButtonStyle` (backing several small actions app-wide) has effectively
  no padding around its label. Chip selection (goals, training styles, and — notably —
  injury/limitation area picking) is conveyed by color/fill alone with no accessible
  selected-state or icon backup, unlike the equipment picker, which does this correctly.
  `brand/08-app-strategy.md` explicitly scopes "accessibility and privacy hardening" to V1,
  and most polish items (VoiceOver hints, rotor actions, reduce-motion) are legitimately
  V1 — but these four are baseline usability gaps on the single most-used screen in the app,
  not hardening. This audit did not fix them: they're UI/Design-system changes that can't be
  verified without a Simulator/Accessibility Inspector, which isn't available in this
  environment, and touching shared Design primitives without being able to see the result
  is a real risk of a different, harder-to-spot regression. Founder call on whether this
  lands before ship or as an immediate fast-follow.

## POST-V1

Already correctly out of scope per `brand/08-app-strategy.md` — listed here for
completeness, not as gaps.

- No Apple Watch companion beyond a compiling scaffold (V1 scope).
- No cloud sync, auth, or cross-device (V2 scope — local-only via SwiftData is intentional).
- CMSN+ entitlement plumbing works end-to-end, but nothing in the app actually gates a
  feature on it yet (only a "Active"/"Not active" display in Settings) — explicit V0 scope,
  the real feature set is V1.
- No exercise-demonstration video library (`ExerciseCardView` has the UI slot, no assets).
- Full accessibility "hardening" (VoiceOver hints, rotor custom actions, a full contrast
  audit, reduce-motion alternatives) beyond the baseline gaps flagged above.
- No "you already did today's workout" state — nothing currently stops starting a second
  full session the same day. UX polish, not a correctness bug (and it's what made the score
  farming bugs above easy to trigger repeatedly — now closed regardless).
- Paywall has no retry affordance if the initial product load fails — low severity while
  products aren't live in ASC, will matter once they are.
- Fallback exercise substitution always picks the first safe catalog match with no
  diversity check — could produce repeated identical substitute exercises in a heavily
  limited session. Program-quality nit, not a safety issue (every substitute is now
  correctly safety-checked per the BLOCKED fixes above).
- Every SwiftData repository save uses `try? context.save()`, silently swallowing errors —
  won't crash, but a save can fail with zero user-facing signal. Worth surfacing eventually.
- Two `#Preview` blocks (`WelcomeView`, `RootView`) each build their own separate in-memory
  container instead of sharing one — Xcode-preview-only cosmetic issue, not shipped code.
- `CustomExercise` defaults to an empty `loadedBodyAreas`, which would silently bypass all
  injury logic — currently unreachable since no UI creates a `CustomExercise` yet; flag for
  whenever exercise-creation ships.

---

## Verification still pending

This audit's fixes (BLOCKED #1–#6) were made as direct source edits with no local Xcode
toolchain available to compile or run them. Regression tests were added for #1, #3, #4, and
#5, following the existing test files' own conventions exactly
(`ScoreCalculatorTests.swift`, `WorkoutRepositoryTests.swift`, `ProgramResolverTests.swift`),
and hand-traced against the real exercise catalog and equipment data to confirm the expected
before/after behavior — but "hand-traced" is not "compiled and green." Pushing this branch
re-triggers `ios-build.yml` on a real macOS runner; **do not treat these six fixes as closed
until that run is confirmed green**, and do not merge PR #1 into `main` on the basis of this
document alone — per the audit brief, PR #1 requires founder review before merge regardless
of CI status.
