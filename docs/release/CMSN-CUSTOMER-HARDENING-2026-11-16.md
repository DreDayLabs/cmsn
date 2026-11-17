# CMSN customer hardening, 2026-11-16

Base: build-6 source `de133e2`. Isolated branch `codex/cmsn-customer-hardening-20261116`; no pricing, submission, deployment, signing or production changes.

## Implemented
- Release builds ignore the destructive screenshot reset launch argument (Debug harness retained).
- Paywall cards and selected-plan disclosure use StoreKit's localized display price. Unavailable products show unavailable, not a USD fallback. No unconditional trial promise. Actual trial eligibility remains Apple-confirmed.
- Export fetch failures now fail export rather than producing apparently successful partial exports; UUID filenames prevent same-second overwrites.
- Erasure clears app-managed store backup directories, temporary export JSON copies and the active-run backup before committing live-record removal. Cleanup failures roll back pending record deletions so the profile remains available for retry. Copies can already have been deleted when a later save fails, so error copy says live records were not confirmed deleted, not that nothing changed. External copies shared/saved by the user are not recalled.
- Erasure is disabled during live/countdown run recording so sensors cannot immediately rewrite a deleted backup. Shared MainActor lifecycle state also blocks erasure during in-flight Apple Health writes, and invalidates older queued finished-run/retry work after an erase attempt.
- Fabricated supplement review dates are nil, with explicit pending/unverified review text. No review or evidence endorsement was invented.
- Regression coverage added for copy cleanup/preservation of unrelated files, cleanup failure rollback, release reset behavior and fail-closed export/paywall source contracts.

## Still not release-ready
- Adult nutrition calculations and restrictive-diet/fasting flows for under-18 profiles need a complete multi-screen policy and regression pass (not solved by changing one age picker).
- Supplement references/evidence labels still need substantive verification; a truthful pending label does not complete content validation.
- Active run/sensor/Watch/HealthKit asynchronous behavior during offboarding still needs end-to-end testing, including historical Watch payload delivery after creating a new profile. `RunSessionController.end` also clears its backup after a failed save; that pre-existing defect remains to investigate separately.
- Real-store purchase/restore, eligible/ineligible trials, native clean install/upgrades, two-device Watch behavior, physical device tests, exact archive provenance and current ASC/reviewer access remain unverified.
- Web wording changes are local source only, not published.

## Verification
First and incremental Release simulator builds passed before the separate lifecycle change. Focused XCTest app/test targets compiled, but neither runtime attempt launched the suite; both were stopped after stalled launch. No runtime test pass claimed. Final lifecycle app + XCTest target build passed (`/tmp/cmsn-codex-1116-lifecycle-compile.log`). Exact-source host-side lifecycle gate probe passed overlapping-write blocking and generation invalidation (`/tmp/cmsn-data-activity-probe.swift`). These are not simulator end-to-end runtime results. Do not infer readiness from a compile or focused tests alone.
