# CMSN+ v1 implementation checkpoint

Base: main affd099633f7dc6fd46f19ba04dfc23d3b8c0f10.
Local branch: codex/cmsn-plus-v1-20261107. No merge/push/upload/submission.

## Approved contract

A subscriber receives useful training guidance that a free user does not, while both can safely record training and retain their data.

Monthly $9.99 / annual $59.99, seven-day Apple trial. No lifetime product.
No advanced analytics UI/claim, AI backend, cloud sync, videos, community or Run Club.

The seven-day no-card runway starts at persisted profile/assessment completion. It does not start at install and cannot be restarted by editing/repeating assessment. Existing profiles use their original completion date. Reinstalling without restoring local app data can begin another local runway; no cross-install identity/server enforcement is claimed. Apple trial eligibility remains Apple's decision and is separate from the runway. A revoked subscription does not cancel any remaining independent no-card runway.

## Implemented access boundaries

One PlusEntitlementService over a Codable policy serves every feature.
- Always free: manual workout entry, run recording, Watch recording, workout history and saved explanations, export/erase, score, basic macro calculation, manual food entry.
- Runway/paid: planned rotation/equipment substitutions/quick paths, next-set coaching, prep meal builder/reuse/suggestions, training-day fuel adjustments.
- A workout captures access in a separate persisted PlusSessionRecord at creation. Lapse never changes this snapshot. A manual workout stays manual even after a later purchase; the app's other premium surfaces open immediately without relaunch.
- Legacy already-open workouts retain coaching; newly created free workouts record false explicitly.
- Verified Apple current entitlements include subscription trial/active/grace. Online status checks distinguish subscribed/grace from expired/revoked. Failed/offline refreshes preserve last-verified paid access, as explicitly directed. Verified revocation updates remove purchased access; an independent unexpired runway may still apply.
- New schema V6 adds only the access/explanation table. Existing workout models are unchanged. Recorded guidance is readable/exportable without entitlement and included in erase/rollback coverage. Free nutrition entry preserves previously recorded paid targets rather than rewriting them on lapse.

## Known scope distinction

The source has run recording but no structured run-programming surface. This implementation keeps recording free and makes no structured-programming claim. Seeded rotation and equipment substitution are not represented as a full adaptive block planner. The basic macro calculator and its estimates remain available free; paid fueling means prep tools and training-day adjustments.

## Paywall truth

Headline: Coaching that reads your history.
Subline: The coach that knows how ready you are.
Example: explicitly labelled Smith Machine Bench Press, 80 kg × 12 at effort 8, moderate readiness. The actual RuleBasedSuggestionEngine produces 82.5 kg for the next session. The UI and truth test call the same fixture/engine function. No four-set/date-aware reasoning or numerical readiness score is invented.

## Verification status

- XcodeGen project regeneration succeeded; signing, version and product IDs unchanged.
- App-source compiler type-check succeeded (not an Xcode build or runtime test).
- Full unit-test source type-check succeeded (not test execution).
- Eight new unit test methods cover the capability matrix, runway boundaries, persisted policy, session snapshot, offer example, coaching persistence/export/erase, V5→V6 migration.
- Existing erase-all fixtures/probes now include the new table; assertions retained.
- Existing StoreKit transition helper now also asserts planning/coaching/fueling access and always-free access; eight regression methods retained.
- Existing UI onboarding journeys include the added runway screen.
- Restricted-context unsigned Xcode build failed at asset compilation: CoreSimulator runtime access unavailable. No test executions were attempted here. The original main's green results do not transfer to this modified tree.

Required next gate: run scripts/verify-plus-v1.sh in regular macOS Terminal on a dedicated iOS 18.6 simulator. Inspect every test count/failure/skip and retain its bundles. Then manually verify feature access, session resume after lapse/relaunch, data preservation, grace/refund/restore and offline behavior. No visual/device/purchase acceptance is claimed from compilation.

Signed archive and TestFlight verification require the separately authorized signing/upload flow. Do not claim completion of the handoff's ten TestFlight steps before those exist. No ASC controls may be changed under this implementation task.
