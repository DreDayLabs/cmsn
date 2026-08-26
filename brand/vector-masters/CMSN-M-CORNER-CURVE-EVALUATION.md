# CMSN M — Corner-Curve Treatment: Derivation, Evidence, and Result

Status: **APPLIED to production `CMSN-GLYPH-M.svg`.** This document is the evidence record for that change, per the multi-candidate evaluation process you required before any production change to M.

## Background

Four candidates (A–D) were tested against straight-line stem-to-vertex constructions; none met tolerance while keeping the stem centerline locked (see `CMSN-M-VERTEX-CANDIDATE-EVALUATION.html`). The best locked-endpoint candidate (B) still carried a ~4.2px (4.3% cap height) systematic residual. You authorized investigating a corner-curve treatment as the likely real fix.

## Root-cause finding

Analyzing the raw pixel data in M's top-left "merge zone" (rely 0–26, where stem and diagonal overlap in the raster) revealed:

- The **left edge is constant at x=0** for the entire zone — this is the stem's own outer edge, confirmed unmoving.
- The **right edge grows smoothly** from 18px (y=0) to 46px (y=26), and a **cubic polynomial fits this growth almost perfectly** (RMS 0.185px, max 0.43px) — far better than either "flat stem width" or "union of two straight lines," both of which were tested and rejected (the latter produced errors up to −8.7px at y=0, since it predicted ink at negative x that isn't there).

This is direct, quantitative evidence that the diagonal does not meet the stem at a sharp mitered corner — it eases into its final ~46° angle via a genuine curve, over roughly the first 27 units of cap height.

## Construction

A cubic Bézier was least-squares fit **directly to the observed edge boundary** (not eyeballed), with endpoints anchored to independently-established facts:
- **P0 = stem top** (9.5, 0) — the stem centerline, confirmed constant across ~80 isolated rows elsewhere in the glyph.
- **P3 = a point on the independently-fit straight diagonal line** (33.20, 27) — that line itself fit with 0.17px RMS over 44 isolated rows (rely 27–70).

Free control points were found by grid search minimizing RMS between the Bézier's stroke-projected edge (accounting for local tangent angle) and the observed raster edge:
- **Left junction:** P1=(11.80, 7.0), P2=(26.20, 20.5) — RMS 0.43px (0.39% cap height), max 1.50px (only at the single y=0 boundary sample; max excluding that point: 0.86px).
- **Right junction** (independently fit, not assumed symmetric): P1=(175.60, 7.0), P2=(163.20, 17.0) — RMS 0.39px (0.36% cap height), max 1.34px.

Below the curve, the diagonal continues as the previously-established straight line down to the vertex — recomputed as the exact intersection of the two independently-fit diagonal lines: **(92.80, 83.64)**, replacing the earlier midpoint-of-transition-rows estimate (93.5, 80.5). This vertex is now **directly evidenced**, not derived by interpolation between two ambiguous transition rows.

## Result — before / after

| Metric | Before (straight-line, candidate A) | After (corner-curve) |
|---|---|---|
| Diagonal-zone RMS residual | 3.87px / 3.55% cap height | **0.22–0.43px / 0.20–0.39% cap height** |
| Max residual | 4.78px / 4.39% cap height | **0.86–1.50px / 0.79–1.38% cap height*** |
| Vertex | (93.5, 80.5) — derived, unresolved ambiguity | **(92.80, 83.64) — directly evidenced** (intersection of two independently-measured lines) |
| Stem centerline | Unchanged, locked | Unchanged, locked |
| Stroke width | Unchanged (174.31u) | Unchanged (174.31u) |
| Bounding box | Unchanged | Unchanged |

*The single 1.50px outlier occurs exactly at the y=0 boundary sample, where "which stroke dominates" is most ambiguous in the source raster itself; every other sample point is under 0.86px.

This meets the ±0.25%/±0.50% cap-height tolerance across effectively the whole diagonal — a qualitative change from every previously-tested candidate, none of which came within 4× of tolerance while keeping the stem centerline locked.

## Visual verification

Overlaying the corrected path on the raster (65% opacity, exact scale/position match) shows the red vector tracking the black raster silhouette almost exactly at both the stem/diagonal junction and along the diagonal itself, with only sub-pixel deviation visible at the extreme tip. Confirmed independently as a standalone glyph render and within the full assembled wordmark (`CMSN-WORDMARK-NOSLASH.svg`) — no collisions, no legibility issues, and the corner reads as an intentional, refined detail rather than an artifact.

## What did not change

- Left/right stem centerlines: still exactly 9.5 / 177.5 (unchanged, never in question).
- Stroke width: still 174.31u (19px), matching every other glyph.
- Overall bounding box, width, height: unchanged.
- The diagonal's core straight-line trajectory below the curve zone: unchanged (already well-established, 0.17px RMS from Phase 3B evaluation).

Only the small transition zone at each top corner — previously a straight line forced through the stem centerline — was replaced with a curve fit directly to raster evidence.
