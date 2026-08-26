# CMSN Phase 3B — Glyph-by-Glyph Vector Reconstruction Validation Report

Status: reconstruction complete, geometric validation complete. **No glyph geometry has been optically corrected, smoothed, or beautified to hide any deviation reported below.**

## 1. Coordinate System

- **Convention:** SVG-native, y-down. `y = 0` is the cap line; `y = cap height` is the baseline.
- This is the **mathematical inverse** of `CMSN-GEOMETRY-SPEC.json`'s typographic Y convention (baseline = Y0, cap line = Y1000). The inversion is a necessary, documented translation for authoring standard SVG (whose own coordinate system is y-down) — it is not a design change and does not alter any measured relationship.
- **Units:** each glyph's own viewBox height equals exactly 1000.00 units (its measured cap height, scaled by `CMSN-GEOMETRY-SPEC.json` → `coordinateSystem.scaleUnitsPerPx` = 9.174311926605505 units/px). All four glyphs and the assembled wordmark share this same cap height, so they compose on one consistent vertical scale.
- **Pixel-to-vector coordinate convention:** an inclusive measured pixel span `[a,b]` (as reported throughout the spec) is treated as the continuous coordinate range `[a, b+1]`. This matches how the spec itself computed every width value (`x1-x0+1`) and is necessary for glyph shapes to compose without gaps or overlaps at their own edges.
- **Construction method:** every glyph is a single **stroke-based centerline path** (`fill="none"`, `stroke="currentColor"`, explicit `stroke-width`) — not a filled outline. This was chosen because Phase 3A's own measurements show a genuinely uniform ~19px (174.31u) stroke system throughout C, M, S, and N; centerline+stroke-width is the most direct, literal translation of that measured system, and avoids introducing outline-offset math (miter/bevel corner decisions) that Phase 3A did not specify. `currentColor` is used deliberately so the same geometry can serve both the black-fill and white-fill colorways referenced in the brand structure, per "one geometry, two colorways" — no color is hardcoded.

## 2. Cap Height & Baseline

Cap height = 1000.00u (definition). Baseline = y=1000.00u in each glyph's own box; y=0 is the cap line. Identical across all four glyphs and the assembled wordmark — confirmed by construction (every glyph's viewBox height is exactly 1000.00).

## 3. Individual Glyph Dimensions — Target vs. Constructed

| Glyph | Target width (u) | Constructed width (u) | Δ | Target height (u) | Constructed height (u) | Δ |
|---|---|---|---|---|---|---|
| C | 1614.68 | 1614.68 | 0.00 | 1000.00 | 1000.00 | 0.00 |
| M | 1715.60 | 1715.60 | 0.00 | 1000.00 | 1000.00 | 0.00 |
| S | 1853.21 | 1853.21 | 0.00 | 1000.00 | 1000.00 | 0.00 |
| N | 1495.41 | 1495.41 | 0.00 | 1000.00 | 1000.00 | 0.00 |

Overall bounding-box width and height match exactly for all four glyphs, because each glyph's outer path was anchored directly to its own measured bounding-box edges (the top/bottom terminal tips for C and S touch the glyph's own left/right edges by measured fact, not by construction choice). **This is expected and not a meaningful validation on its own** — the real test is the internal geometry, below.

## 4. Width : Height Ratios

| Glyph | Target | Constructed | Δ |
|---|---|---|---|
| C | 1.6147 | 1.6147 | 0.0000 |
| M | 1.7156 | 1.7156 | 0.0000 |
| S | 1.8532 | 1.8532 | 0.0000 |
| N | 1.4954 | 1.4954 | 0.0000 |

Exact, for the same reason as §3.

## 5. Stroke Measurements

| Item | Target | Constructed | Δ |
|---|---|---|---|
| Primary stroke thickness (all glyphs) | 174.31u (19px) | 174.31u | 0.00 |
| Stroke : cap-height ratio | 17.43% | 17.43% | 0.00 |

Exact — a single stroke-width value was used for every glyph, matching the measured monoline system.

## 6. Terminal Measurements

| Item | Target (u) | Constructed (u) | Δ (u) | Δ (% cap height) | Status |
|---|---|---|---|---|---|
| C top terminal width | 1321.10 | 1321.10 | 0.00 | 0.00% | Exact — measured anchor (32px) used directly |
| C bottom terminal width | 1348.62 | 1348.62 | 0.00 | 0.00% | Exact — measured anchor (29px) used directly |
| S top terminal width | 1541.28 | 1541.28 | 0.00 | 0.00% | Exact — measured anchor (34px) used directly |
| S bottom terminal width | 1550.45 | 1541.28 | **−9.17** | **−0.92%** | **Exceeds ±0.50% character-width tolerance** — see §10.3 |

## 7. Wordmark Assembly — Spacing & Total Width

| Pair | Documented gap (u, from spec) | Applied in assembly | Δ |
|---|---|---|---|
| C→M | 330.28 | 330.28 | 0.00 |
| M→S | 284.40 | 284.40 | 0.00 |
| S→N | 284.40 | 284.40 | 0.00 |

Every gap was taken directly from `CMSN-GEOMETRY-SPEC.json` `spacing.*.bboxGapUnits` with no adjustment — as instructed ("use the documented spacing relationships... do not visually guess the spacing, do not introduce kerning corrections").

| Item | Value |
|---|---|
| Sum of 4 glyph widths + 3 documented gaps | **7577.98u** |
| Target: original raster's whole-wordmark bounding-box width (`global.normalizedWordmarkWidth`) | **7550.46u** |
| **Deviation** | **+27.52u = +2.75% of cap height** |

**This is the single largest deviation found in Phase 3B, and it is not a construction error — it traces to an internal inconsistency in Phase 3A's own spec.** Root cause, verified against the raw pixel data:

- Glyph widths were computed as `x1 - x0 + 1` (continuous-coordinate convention, e.g. C: 437−262+1=176px).
- Gaps were computed as `next.x0 − prev.x1` (a *different* convention, one pixel short of continuous, e.g. C→M: 473−437=36px).
- These two conventions are **not composable**: summing widths-by-one-convention and gaps-by-another over-counts by exactly 1px per gap. Verified directly: `823px` (true, directly-measured C-to-N span) vs `826px` (sum of the four individually-reported widths plus the three individually-reported gaps) — a 3px difference, ×9.174 units/px = 27.5u, matching the deviation found here exactly.
- Per this phase's Zero-Interpretation Rule, **I did not silently correct the gap values** to make the sum agree (that would be "fixing it because it looks wrong," which is explicitly prohibited). The assembled wordmark uses the documented gaps exactly as specified. **This requires a decision from you**: either (a) treat the gap values as correct and accept that the whole-wordmark bounding width in the spec was measured under a slightly different convention (the wordmark will run ~2.75% wider than the original raster's outer silhouette), or (b) redefine the three gaps as one pixel narrower each (35/30/30px instead of 36/31/31px) for future work, which would make the assembly reproduce the raster's exact 823px span. I have not chosen for you.

## 8. Diagonal Measurements

| Glyph | Measured angle from vertical (avg) | Constructed angle from vertical | Δ | Notes |
|---|---|---|---|---|
| M left diagonal | 46.65° (range 46.33–46.65°) | 46.22° | 0.43° | Vertex position is a derived value — see §10.1 |
| M right diagonal | 46.80° (range 46.70–46.89°) | 46.22° (mirror of left) | 0.58° | Same derived vertex |
| N diagonal | 54.13° (range 54.02–54.24°) | 52.88° | **1.25°** | Largest angular deviation — see §10.2 |
| S spine | 48.09° (measured, start only) | 48.09° at start point by construction | 0.00° at origin | Full curve is a constructed interpolation — see §10.3 |

## 9. Relevant Curve/Corner Constructions (not independently measured in Phase 3A)

Phase 3A explicitly flagged these as needing more work for tight tolerance conformance (`CMSN-GEOMETRY-SPEC.json` → `tolerances.documentedLimitation`, and `measurementConfidence.cInnerCurvatureAndSBowlRadii: "NOT_MEASURED"`). Phase 3B did not re-measure them at higher resolution; it constructed reasonable, endpoint-anchored curves and is reporting that construction method plainly rather than presenting it as re-measured fact:

- **C's two corners** (terminal-to-stem transition, top and bottom): built as quadratic Béziers, anchored at the measured transition-row coordinates, with the control point placed at the sharp-corner vertex formed by extending the terminal and stem centerlines to their intersection (a standard, neutral rounded-corner construction — not a freehand curve). The Phase 3A circle fit (radius ≈744–761u) describes only the *first, very gentle portion* of this corner (verified: extrapolating that circle's curvature to a full 90° turn would require far more vertical travel than the corner actually occupies before reaching the stable stem) — the corner's true curvature visibly *tightens* partway through, i.e. it is a compound/variable-radius curve, not a single arc. This Bézier reconstruction is anchored at measured endpoints but does not attempt to replicate that compound curvature exactly.
- **S's spine** (upper-bowl-to-lower-bowl transition): built as a cubic Bézier. The start tangent is set to the measured spine angle (48.09°). The end tangent was **assumed symmetric** with the start tangent, based on S's measured 180°-rotational symmetry (§F of the geometry spec) — this end tangent was not independently measured and is the single largest unverified assumption in this phase's reconstruction.
- **M's center-V vertex position**: Phase 3A measured two transition rows (inner-edge-touch at row 239, outer-edge-converge at row 258) and explicitly could not resolve which represents "the" vertex depth (flagged `INFERRED` in Phase 3A). Phase 3B used the **midpoint** of these two rows (738.53u) as the centerline vertex, reasoned as follows: for two straight, finite-width strokes meeting at a shared centerline point, the inner edges touch *before* the true centerline crossing and the outer edges converge *after* it — the true crossing lies between the two, and by the near-symmetry of the measured left/right widths and angles, the midpoint is a reasonable point estimate. This is a geometric derivation from measured data, not an independent measurement, and is reported as such.

## 10. Unresolved Discrepancies (ranked by magnitude)

### 10.1 — Wordmark total width: +2.75% of cap height
See §7. Traced to a Phase 3A gap/width convention mismatch. **Requires your decision, not mine.**

### 10.2 — N diagonal angle: 1.25° off measured
Constructed by connecting the two stem centerlines corner-to-corner (9.5, 0) → (153.5, 109). This is the simplest, most constrained construction (both endpoints are already fixed by the independently-established stem centerlines, no free parameter), but it does not reproduce the angle Phase 3A measured by directly fitting the diagonal's own edge trace (54.13°). The true diagonal likely does not meet the stem exactly at centerline — it appears (from the raw row data) to originate closer to the stem's *inner edge* — but Phase 3A did not measure that corner-anchor point precisely enough to use it with confidence. Flagging rather than guessing.

### 10.3 — S bottom terminal width: 9.17u (0.92% of cap height) short
Built using the same 168px anchor as the top terminal (for left-right constructive symmetry) rather than the independently measured 169px bottom-terminal width. Exceeds the ±0.50% character-width tolerance. A one-pixel correction (169 instead of 168) would close this gap if approved.

### 10.4 — M/N corner and S bowl curve shapes: unmeasured curve family
See §9. Endpoints are measured; the curve connecting them is a constructed, undocumented-in-Phase-3A interpolation. Not a numeric deviation from a target (no target curve-shape exists to deviate from) but an open item if pixel-level curve fidelity is required later.

## 11. Measured Fact vs. Inference vs. Unresolved Ambiguity — Summary

| Classification | Items |
|---|---|
| **Measured fact, reproduced exactly** | All 4 glyph bounding boxes and w:h ratios; stroke thickness (all glyphs); C's top/bottom terminal widths; S's top terminal width; all 3 inter-letter gaps as documented |
| **Derived from measured data (not itself an independent measurement)** | M's vertex depth (midpoint of two measured transition rows); S's spine end-tangent (assumed via measured symmetry) |
| **Constructed interpolation between measured endpoints (curve family not measured)** | C's two corner curves; S's spine curve body |
| **Documented deviation from a measured target** | N diagonal angle (1.25°); S bottom terminal width (9.17u); wordmark total width (27.52u) |
| **Root-caused spec inconsistency requiring a decision** | Gap vs. width pixel-counting convention mismatch (§7) |

No inference in this list was converted into a silent design decision. Where a choice was required, the reasoning is stated above and the resulting numeric consequence is reported in the tables, not corrected.
