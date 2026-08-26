# CMSN Master Specification

**Spec version:** 1.0.0 · **Phase:** 3C — Master Reconstruction and Production Lock · **Date:** 2026-08-26
**Status:** APPROVED (clear-space unit approved 2026-08-26; print minimum-size figure remains a DPI-math extrapolation pending physical proof)

This document and `CMSN-MASTER-SPEC.json` describe the same system and must agree. Where a number appears in both, it is copied from the JSON, not independently re-derived.

## 1. Authority Hierarchy

| Level | What | Mutability |
|---|---|---|
| 1 | `brand/source/approved-reference/CMSN-horizontal-approved-reference.png` | Immutable visual authority |
| 2 | `brand/vector-masters/CMSN-GLYPH-{C,M,S,N}.svg` | Immutable — Phase 3B evidence-validated geometry |
| 3 | `brand/master/CMSN-MASTER-GLYPH-{C,M,S,N}.svg`, `CMSN-MASTER-WORDMARK-HORIZONTAL.svg` | Immutable — geometrically identical to Level 2 by fingerprint (see `CMSN-MASTER-INTEGRITY.json`) |
| 4 | Future production assets (web, app, print, apparel, social, motion, favicon, icon, vendor) | May scale/format only — may not reinterpret geometry |

## 2. Master Geometry

Five canonical files, all in `brand/master/`:

- `CMSN-MASTER-GLYPH-C.svg`
- `CMSN-MASTER-GLYPH-M.svg`
- `CMSN-MASTER-GLYPH-S.svg`
- `CMSN-MASTER-GLYPH-N.svg`
- `CMSN-MASTER-WORDMARK-HORIZONTAL.svg`

Each is geometrically identical (verified by geometry fingerprint — see §16 and `CMSN-MASTER-INTEGRITY.json`) to its Phase 3B source in `brand/vector-masters/`. A short provenance comment was added to each file's header; no path, viewBox, or stroke attribute was touched.

**Coordinate system:** SVG-native, y-down. Cap line at y=0, baseline at y=1000.00. Cap height = 1000.00 units by definition. This is the mathematical inverse of the typographic Y convention used in `CMSN-GEOMETRY-SPEC.json` (baseline=Y0, cap line=Y1000) — a documented translation for SVG authoring, unchanged since Phase 3A/3B.

**Coordinate precision:** 2 decimal places throughout (0.01 unit ≈ 0.001% of cap height), matching what Phase 3B already used — not re-rounded in this phase.

## 3. Glyph Measurements

| Glyph | viewBox | Width (u) | Height (u) | Stroke (u) | Linecap | Linejoin | Path count |
|---|---|---|---|---|---|---|---|
| C | 0 0 1614.68 1000.00 | 1614.68 | 1000.00 | 174.31 | butt | round | 1 |
| M | 0 0 1715.60 1000.00 | 1715.60 | 1000.00 | 174.31 | butt | round | 1 |
| S | 0 0 1853.21 1000.00 | 1853.21 | 1000.00 | 174.31 | butt | round | 1 |
| N | 0 0 1495.41 1000.00 | 1495.41 | 1000.00 | 174.31 | butt | miter | 1 |

**Bounding boxes:** for all four glyphs, the stroke-inclusive visible-ink bounding box is exactly `[0,0]` to `[width, 1000.00]` — i.e., identical to the viewBox. This was verified analytically: every path terminus is a butt cap positioned exactly at a viewBox edge, and every stroke's perpendicular half-width (87.155u) was already absorbed into the centerline insets used during Phase 3B construction. This is a designed property of the system, not a coincidence.

## 4. M Corner-Curve Authorization

**This is permanent and must not be reverted.** The straight-line stem-to-vertex model was rejected after quantitative multi-candidate evaluation (control, fitted-vertex, angle-anchored, and free-fit candidates — none of the locked-endpoint options met tolerance). Root-cause analysis of the raster's merge zone showed a genuine curved transition, not a vertex-placement problem. A cubic Bézier was fit by least-squares directly to the measured edge boundary:

- Vertex: **(92.80, 83.64)** — directly evidenced as the intersection of two independently-fit straight diagonal lines, not derived by interpolation.
- Diagonal-zone RMS: **3.55% of cap height → 0.20–0.39% of cap height.**
- Stem centerlines, stroke width, and bounding box: **unchanged.**

Do not straighten this curve, "clean it up," or replace it with a conventional mitered vertex. Full derivation: `CMSN-M-CORNER-CURVE-EVALUATION.md`.

**Other Phase 3B resolutions preserved without exception:**
- **C** — validated, no further geometry work authorized.
- **S** — bottom terminal correction (169px / 1550.46u, independently re-measured) approved and permanent.
- **N** — diagonal investigated and retained; do not modify to appear more geometrically conventional.
- **Wordmark spacing** — corrected Phase 3B gaps approved; no further optical kerning.

## 5. Wordmark Assembly

`CMSN-MASTER-WORDMARK-HORIZONTAL.svg`: viewBox `0 0 7550.46 1000.00`, width:height ratio 7.5505.

**Assembly contract** — deterministic from 4 immutable glyph masters + 3 explicit gap values, reproducible without visual judgment:

```
x_C = 0
x_M = x_C + width_C + gap_CM
x_S = x_M + width_M + gap_MS
x_N = x_S + width_S + gap_SN
total_width = x_N + width_N
```

| | Value |
|---|---|
| x_C | 0.00 |
| x_M | 1935.78 |
| x_S | 3926.61 |
| x_N | 6055.05 |
| total width | 7550.46 |

Verification: `1614.68 + 321.10 + 1715.60 + 275.23 + 1853.21 + 275.23 + 1495.41 = 7550.46` exactly.

## 6. Spacing

| Pair | Gap (u) | Gap (px) | Status |
|---|---|---|---|
| C→M | 321.10 | 35 | Approved (Phase 3B correction) |
| M→S | 275.23 | 30 | Approved (Phase 3B correction) |
| S→N | 275.23 | 30 | Approved (Phase 3B correction) |

These supersede the original Phase 3A-reported values (330.28/284.40/284.40u) — a documented, intentional correction (see `CMSN-PHASE3B-CORRECTION-LOG.md` item 1), not a new discrepancy. Spacing is an assembly property only; do not re-kern or modify glyph geometry to adjust spacing.

## 7. Scaling

Master geometry may be scaled uniformly (preserving the 7.5505:1 aspect ratio) for any production use. Non-uniform scaling (stretching width or height independently) is prohibited — it would alter the stroke-to-cap-height ratio and every angle in the system.

## 8. Clear Space

**Status: APPROVED 2026-08-26.** Candidate 1 (1 Stroke Width) was approved as the official clear-space unit. The other two candidates are retained below only for the audit trail.

| # | Unit | Value | Derivation | Decision |
|---|---|---|---|---|
| **1** | **1 Stroke Width** | **174.31u (17.43% cap ht)** | The only structural measurement shared exactly and identically across all four glyphs — the most literal "native unit." | **✅ APPROVED** |
| 2 | 1 Cap Height | 1000u (100% cap ht) | The fundamental vertical measurement of the whole system; common convention in many logo systems. | Not chosen |
| 3 | Average Inter-Glyph Gap | 290.52u (29.05% cap ht) | Mean of the three approved gaps; ties clear space to the wordmark's own internal rhythm. | Not chosen |

**Approved rule:** minimum horizontal and vertical clear space = 1 Stroke Width (174.31u), measured from the wordmark's visible ink bounding box (which equals its viewBox, per §3).

## 9. Minimum Size

**Digital — tested.** The wordmark master was rasterized at exact target pixel widths (48–200px) and inspected at 8× nearest-neighbor magnification (no smoothing) to see true small-size rendering, not a smoothed approximation.

| Width (px) | Cap height (px) | Stroke (px) | Observed |
|---|---|---|---|
| 48 | 6 | 1.05 | At/below safe floor — fine detail not reliably discernible |
| 60 | 8 | 1.39 | All four letters clearly distinguishable |
| 72 | 10 | 1.74 | Good |
| **90** | **12** | **2.09** | **Very good — recommended minimum** |
| 120 | 16 | 2.79 | Excellent |
| 160 | 21 | 3.69 | Excellent |
| 200 | 27 | 4.62 | Excellent |

**Recommended digital minimum: 90px wordmark width (12px cap height).** Absolute floor: 48px (6px cap height) — below this, stroke width approaches 1px and fine structure isn't reliably reproduced.

**Print — estimated, not physically verified.** 90px ÷ 300dpi = 0.30in recommended minimum wordmark width. This is a direct unit conversion of the digital test, not an independently-run print proof. Physical proofing across substrates/print methods is recommended before treating this figure as validated.

No special small-size logo was created — the same master geometry was rendered as-is at every size tested.

## 10. Color Handling

No new colors were introduced. Master SVGs use `stroke="currentColor"` with `fill="none"`, making them colorway-agnostic by design — the existing brand architecture's "one geometry, two colorways" (black fill / white fill) applies directly. Approved colors: `#000000`, `#FFFFFF`. No gradients, gray/tonal variants, effects, added outlines, or new brand colors are introduced or authorized.

## 11. Background Handling

Master SVGs have no background rectangle — transparent by default. Production use on a black or white ground should set `color` on a container or the SVG root to select the colorway; do not bake a background into the master files.

## 12. SVG Requirements

Preserve viewBox and path `d` data exactly; verify via geometry fingerprint before redistribution. `stroke-width`/`stroke-linecap`/`stroke-linejoin` must match the master exactly. No embedded raster images, no `font-family`/`@font-face`, no `<text>` elements as production geometry.

## 13. Raster Export Requirements

Export at or above the tested legibility floor (§9). Rasterize directly from the master path data — never from an intermediate re-traced or hand-cleaned version. Maintain the 7.5505:1 aspect ratio.

## 14. Apparel/Vendor Handling

Vendors receive the master SVG (or a geometry-preserving format conversion, e.g. PDF/EPS) plus this specification. Vendors must not "clean up" or re-vectorize the mark. Vendor-side digitization for embroidery or similar processes is a separate, explicitly-scoped derivative activity outside this phase, and any such derivative must be validated against the geometry fingerprint before approval.

## 15. Prohibited Alterations

Altering Bézier control points, path nodes, or endpoints; altering stroke/stem widths; altering diagonal angles; altering terminal geometry; altering the M corner curve; altering proportions, cap height, or bounding boxes; optical correction; path simplification or rounding beyond established precision; curve-family conversion; node addition/removal; SVG-optimizer geometry rewriting; Illustrator "simplify path" or similar cleanup; automatic tracing; font-software reinterpretation; AI-generated approximation; re-kerning; merging the slash into the wordmark without a separately-approved lockup.

## 16. Integrity Verification

Two fingerprints are recorded per master in `CMSN-MASTER-INTEGRITY.json`:
- **File fingerprint** — SHA-256 of the entire SVG file (changes if even a comment changes).
- **Geometry fingerprint** — SHA-256 of a canonical JSON extraction of only geometry-critical data (viewBox, path order, exact `d` values, geometry-affecting transforms, stroke-width/linecap/linejoin, fill/fill-rule) — unaffected by comments, whitespace, or attribute reordering. This is the number that must never change without explicit authorization.

Verified in this phase: every Level 3 master's geometry fingerprint is byte-identical to its Level 2 source's geometry fingerprint. Zero drift.

## 17. Versioning

This is spec version 1.0.0 — the first canonical lock. Any future authorized change to master geometry must increment the version and record the prior geometry fingerprint alongside the new one in a change log, so drift is always traceable. No such change is authorized by this phase.

## 18. Future Custom-Type Relationship

The four glyph masters may serve as the starting point for a future proprietary CMSN display alphabet. Documented foundation: 1000-unit cap-height system; single 174.31u (17.43%) monoline stroke weight throughout; flat butt-capped terminals; two evidence-derived corner treatments (C's large-radius outer corners, M's corner-curve junctions); non-uniform, evidenced letter spacing rather than a general kerning table. **No additional letters were designed in this phase.** A future typeface must extend this system's logic for new characters — it must never become a pretext to retroactively normalize, clean up, or redraw C, M, S, or N. Logo geometry (frozen, this spec) and future typeface geometry (not yet started) are and must remain distinct.
