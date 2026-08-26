# CMSN Custom Lettering — Geometry Specification (Phase 3A)

Status: **measurement and documentation only.** No production vector geometry has been constructed from this spec. See `PROVENANCE.md` for the full development record and `measurement-overlay.html` for a visual proof of every measurement below.

## A. Source Provenance

| Field | Value |
|---|---|
| Original Downloads path | `~/Downloads/brand source approved-reference CMSN-horizontal-approved-reference.png` |
| Repository reference path | `brand/source/approved-reference/CMSN-horizontal-approved-reference.png` |
| SHA-256 (both copies, verified identical) | `2e7e8e4e0d331e588aebf73fecfe5db15e44db4d639691e2484bb95f399560c5` |
| Pixel dimensions | 1536 × 1024 |
| File type | PNG, 8-bit RGB, non-interlaced |
| Measurement date | 2026-08-25 |

**Discrepancy note (must be read before using this spec):** the phase brief stated the slashes were "intentionally removed" from this PNG. On inspection, the file contains rendered `//` slash strokes and an "EARN YOUR CMSN" tagline in **both** of its two stacked colorway panels (black-bg/white-ink on top, white-bg/black-ink on bottom). This does not change the outcome — slash and tagline pixels were identified and excluded from every CMSN measurement below exactly as instructed — but the file's actual contents differ from the brief's description, and that should be confirmed with Dre before Phase 3B.

The reference contains **two colorway panels of the same artwork** (rows 0–559 black-bg, rows 565–1023 white-bg). All primary measurements in this spec (§C–H) were taken from the **white-background/black-ink panel** (cleaner threshold separation). The black-background panel was subsequently cross-checked — see §M — and confirms the same underlying design at a slightly different render scale, with no material geometry discrepancy.

## B. Coordinate System

- Cap height = **1000.00 units** (normalized), mapped from the measured 109px cap-to-baseline pixel span.
- Baseline: **Y = 0** — source pixel row 276 (panel-local) / row 841 (absolute image row).
- Cap line: **Y = 1000** — source pixel row 168 (panel-local) / row 733 (absolute image row).
- Scale factor: 1000 / 109 = **9.174311926605505 units/px** (used, unrounded, for every conversion below; only the reported results are rounded to 2 decimals).
- X-axis: pixel columns are absolute image columns throughout (no horizontal crop was applied), so panel-local and absolute X are identical.

## C. Global Geometry

| # | Measurement | Value | Class |
|---|---|---|---|
| 1 | Source image width | 1536 px | MEASURED |
| 2 | Source image height | 1024 px | MEASURED |
| 3 | CMSN artwork bbox width | 823 px → **7550.46 u** | MEASURED |
| 4 | CMSN artwork bbox height | 109 px → **1000.00 u** | MEASURED |
| 5 | Normalized cap height | 1000.00 u | DEFINITION |
| 6 | Normalized wordmark width | 7550.46 u | MEASURED |
| 7 | Width : height ratio | 7.5505 | MEASURED |
| 8 | Baseline | Y=0 (px row 841 absolute) | MEASURED |
| 9 | Cap line | Y=1000 (px row 733 absolute) | MEASURED |
| 10 | Dominant primary stroke thickness | 19 px → **174.31 u** | MEASURED |
| 11 | Stroke : cap-height ratio | 0.1743 (17.43%) | MEASURED |
| 12 | Horizontal visual center (bbox midpoint) | x=673 px | MEASURED |
| 12b | Horizontal visual center (ink-mass centroid) | x=681.97 px, y=221.29 px (panel-local) | MEASURED |
| 13 | Individual glyph bounding boxes | see §D–G | MEASURED |
| 14 | Total occupied ink area (C+M+S+N) | 33,645 px² → **2,831,832.34 u²** | MEASURED |
| 15 | Negative-space characteristics | see per-glyph sections; qualitative summary below | INFERRED |

**Tagline and slashes excluded:** 15 small components (the "EARN YOUR CMSN" tagline glyphs, panel-local y≈324–339, height≈15–16px) and 2 tall components (the slash strokes, panel-local x≈1111–1317, y≈119–306, height≈188px — nearly 1.7× the CMSN cap height) were identified by connected-component analysis and excluded from every global and per-glyph measurement above and below.

**Negative-space summary (INFERRED, qualitative):** C's aperture (the open right side) is the largest single counter, followed by M's two flanking triangular counters either side of the center V, S's two bowl counters (upper opens right, lower opens left, near-mirror sizes), and N's two triangular counters flanking its diagonal. No sub-pixel negative-space area was computed per counter; only bounding envelopes are reported per glyph.

## D. C Specification

| Measurement | Value | Class |
|---|---|---|
| Total width | 176 px → **1614.68 u** | MEASURED |
| Total height | 109 px → **1000.00 u** | MEASURED |
| Width:height ratio | 1.6147 | MEASURED |
| Primary stroke thickness | 19 px → **174.31 u** (stable across rows 200–244) | MEASURED |
| Top horizontal extent (cap line, y=168) | x 294–437 (144px → 1321.10u) | MEASURED |
| Bottom horizontal extent (baseline, y=276) | x 291–437 (147px → 1348.62u) | MEASURED |
| Left outer curvature (top arm) | circle fit: center≈(360.37,141.77) r=81.14px→**744.39u**, residual RMS 0.28px, max 0.52px | INFERRED (high confidence — sub-pixel residual) |
| Left outer curvature (bottom arm) | circle fit: center≈(358.71,302.89) r=82.92px→**760.70u**, residual RMS 0.43px | INFERRED (high confidence) |
| Left inner curvature | not independently fit this pass | NOT MEASURED |
| Upper terminal position | y=168 (cap line), x294–437 | MEASURED |
| Lower terminal position | y=276 (baseline), x291–437 | MEASURED |
| Aperture width (opening, stem-to-rightmost) | ≈437−280 = 157px → **1440.37u** | INFERRED (interpretation of "aperture width") |
| Aperture height (transition row to transition row) | row 187 → row 258 = 71px → **651.38u** | MEASURED transition rows / INFERRED as the definition of aperture height |
| Terminal thickness (flat-cap depth before curve begins) | ≈16–17px → ~147–156u | INFERRED (boundary estimated from curve-onset) |
| Transition points | upper: row 187 (x jumps 429→293); lower: row 258 (x jumps 291→429) | MEASURED |
| Outer radius/radii | top 81.14px (744.39u), bottom 82.92px (760.70u) — 2.2% apart | INFERRED |
| Inner radius/radii | not computed | NOT MEASURED |
| Optical overshoot | none — ink stays exactly within cap line/baseline, no overshoot | MEASURED |
| Symmetry | top/bottom terminal widths 144 vs 147 (~2%), curve radii 81.14 vs 82.92 (~2.2%) — vertically symmetric within raster measurement tolerance | MEASURED/INFERRED |

The approved C is a wide, flat-terminal, open geometric form — not a classical circular-bowl C. Its left wall is a straight vertical run (19px, rows 200–244) with rounding confined to the top and bottom corners.

## E. M Specification

| Measurement | Value | Class |
|---|---|---|
| Total width | 187 px → **1715.60 u** | MEASURED |
| Total height | 109 px → **1000.00 u** | MEASURED |
| Width:height ratio | 1.7156 | MEASURED |
| Left stem thickness | 19 px → **174.31 u**, constant full height | MEASURED |
| Right stem thickness | 19 px → **174.31 u**, constant full height | MEASURED |
| Left stem position | x 473–491 (relative 0–18) | MEASURED |
| Right stem position | x 641–659 (relative 168–186) | MEASURED |
| Upper-left anchor | (473, 168) | MEASURED |
| Upper-right anchor | (659, 168) | MEASURED |
| Center-V apex (inner edges first touch) | row 239 → depth 71px from cap line → **651.38u** | MEASURED transition row |
| Center-V apex (outer edges fully converge / tip) | row 258 → depth 90px from cap line → **825.69u** | MEASURED transition row |
| Center-V depth (reported range, definition-dependent) | 651.38u – 825.69u | INFERRED (which row is "the" apex is an interpretation choice) |
| Center-V width (at widest visible merged point, row 240) | 52px → **477.06u** | MEASURED |
| Left diagonal angle from vertical | outer edge 46.33°, inner edge 46.65° (avg ≈46.5°) | MEASURED (linear regression, rows 196–238) |
| Right diagonal angle from vertical | outer edge 46.70°, inner edge 46.89° (avg ≈46.8°) | MEASURED (linear regression) |
| Diagonal perpendicular stroke thickness (derived) | ≈18.64px → **171.05u** | INFERRED (angle-projection from 27px horizontal cross-section) |
| Internal negative-space width (inner stem edge to inner stem edge, at cap line) | 641−491 = 150px → **1375.99u**, closing to 0 at the V apex | MEASURED |
| Diagonal/stem intersections | both diagonals originate at their stem's top-inner corner — left ≈(491,168), right ≈(641,168) | MEASURED/INFERRED (corner coincidence; the two features overlap at the very top rows, separating into independently visible runs only from row 195) |
| Symmetry | stem widths identical (19px both sides); diagonal angles within 0.3–0.5° of mirror match | MEASURED — symmetric about vertical centerline within tolerance |

The approved M has a genuinely wide stance (stems 150px apart at the inner edge, vs. an 187px total width) with a controlled, mid-depth center trough — not a shallow, condensed M. A significant measurement pitfall is documented here: naive row-by-row scanning at the very top and bottom rows initially misread stem width as growing up to 46px, because the diagonal overlaps and merges with the stem for the first ~27 rows before separating into an independently visible run at row 195. The true, constant stem width (19px) was confirmed from the ~80 rows (195–276) where the stem is unambiguously isolated.

## F. S Specification

| Measurement | Value | Class |
|---|---|---|
| Total width | 202 px → **1853.21 u** | MEASURED |
| Total height | 109 px → **1000.00 u** | MEASURED |
| Width:height ratio | 1.8532 | MEASURED |
| Primary stroke thickness | 19 px → **174.31 u** (upper wall rows 190–210 min=19; lower wall rows 238–250 min=19) | MEASURED |
| Upper section span | rows 168–212 (45 rows) → **412.84u** | MEASURED |
| Lower section span | rows 232–276 (45 rows) → **412.84u** — exactly matches upper | MEASURED |
| Upper terminal position | y=168, x724–891 (168px → 1541.28u) | MEASURED |
| Lower terminal position | y=276, x690–858 (169px → 1550.45u) | MEASURED |
| Center transition (spine) span | rows 213–231, centered exactly on row 222 = the glyph's exact vertical midpoint | MEASURED |
| Center horizontal extent (spine) | roughly x699–722 (top of spine) sweeping to x857–880 (bottom of spine) | MEASURED |
| Upper horizontal extent (bowl wall) | x696–723 approx | MEASURED |
| Lower horizontal extent (bowl wall) | x856–883 approx | MEASURED |
| Upper curvature/radius | not independently circle-fit this pass | NOT MEASURED |
| Lower curvature/radius | not independently circle-fit this pass | NOT MEASURED |
| Internal negative spaces | two bowl counters (upper opens right, lower opens left); envelope only, not area-integrated | INFERRED |
| Transition geometry (spine angle from vertical) | 48.09° (linear regression, left edge, rows 213–231) | MEASURED |
| Symmetry | terminal widths 168 vs 169 (~0.6% apart); section spans identical (45 vs 45 rows); spine exactly centered — strong 180° rotational symmetry | MEASURED (high confidence) |

The approved S is an independent glyph with **no connection to N** — confirmed structurally: every row of S's bounding box (168–276) contains ink only within S's own 690–891 column range, with the nearest S pixel to N's leftmost pixel being the ordinary 31px inter-letter gap (§H), not a shared or touching stroke. The S is built from two hook-shaped bowls (upper opening right, lower opening left) joined by a single diagonal spine crossing through the exact vertical center of the glyph — a clean, sleek, geometric S with strong rotational symmetry, matching the brief's description.

## G. N Specification

| Measurement | Value | Class |
|---|---|---|
| Total width | 163 px → **1495.41 u** | MEASURED |
| Total height | 109 px → **1000.00 u** | MEASURED |
| Width:height ratio | 1.4954 | MEASURED |
| Left stem thickness | 19 px → **174.31 u**, constant full height | MEASURED |
| Right stem thickness | 19 px → **174.31 u**, constant full height | MEASURED |
| Left stem position | x 922–940 (relative 0–18) | MEASURED |
| Right stem position | x 1066–1084 (relative 144–162) | MEASURED |
| Diagonal thickness (horizontal cross-section) | 32–34px, median 33px → **302.75u** | MEASURED |
| Diagonal thickness (perpendicular, derived) | ≈19.28px → **176.91u** | INFERRED (angle-projection) |
| Diagonal starting coordinate | ≈(940, 168) — top-inner corner of left stem | MEASURED/INFERRED (corner coincidence; independently visible only from row 190) |
| Diagonal ending coordinate | ≈(1066, 276) — bottom-inner corner of right stem | MEASURED/INFERRED (independently visible only through row 255) |
| Diagonal angle from vertical | left edge 54.24°, right edge 54.02° (avg ≈54.1°) | MEASURED (linear regression, rows 190–255) |
| Internal negative-space geometry | two triangular counters flanking the diagonal (upper-right, lower-left) | INFERRED, qualitative |
| Stem/diagonal intersections | diagonal meets left stem at its top-inner corner and right stem at its bottom-inner corner — exact corner-to-corner construction | MEASURED/INFERRED |
| Symmetry | left/right stem widths identical (19px); consistent with 180°-rotational symmetry (not left-right mirror symmetry, which a true N never has) | MEASURED |

N remains fully independent — confirmed the same way as S: no shared pixels, no touching stroke, ordinary 31px gap to S on its left (§H). Note the same top/bottom corner-overlap measurement pitfall documented for M applies here (diagonal merges visually with each stem for the first/last ~22 rows); the reported constant 19px stem width is drawn from the ~65 rows (190–255) where the diagonal is unambiguously separated from both stems.

## H. Spacing Specification

| Pair | Bounding-box gap | Nearest-path distance | Gap % cap height | Gap % stroke thickness | Optical interpretation |
|---|---|---|---|---|---|
| C → M | 36px → **330.28u** | 36.00px → 330.28u | 33.03% | 189.47% | Widest gap of the three |
| M → S | 31px → **284.40u** | 31.02px → 284.55u | 28.44% | 163.16% | Matches S→N exactly |
| S → N | 31px → **284.40u** | 31.00px → 284.40u | 28.44% | 163.16% | Matches M→S exactly |

Spacing is **not uniform**: C→M is ~16% wider than the other two gaps, which are identical to within measurement noise (0.02px). INFERRED interpretation: C's open aperture reads as visually "lighter" on its right side than M's solid stem, so the wider C→M gap likely compensates optically for that difference in apparent density — consistent with the brief's instruction not to assume equal spacing.

## I. Slash Master Reference

Source: `public/brand/cmsn-slashes-dark.svg` (unchanged; SHA-256 `9845d5b83c5e7a2f42a8b7802ed47d051f94d2a2ee4847fd5c28dcd0fc3903cd`).

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 78 104" fill="none">
  <g stroke="#FAFAF8" stroke-width="13" stroke-linecap="butt">
    <path d="M8 96 L32 8"/>
    <path d="M42 96 L66 8"/>
  </g>
</svg>
```

| Property | Value | Class |
|---|---|---|
| viewBox | `0 0 78 104` | EXACT (vector source) |
| Path 1 | `M8 96 L32 8` | EXACT |
| Path 2 | `M42 96 L66 8` | EXACT |
| Stroke width | 13 units | EXACT |
| Stroke linecap | butt | EXACT |
| Intrinsic width | 78 units (viewBox); ink spans x 8–66 (58u) | EXACT |
| Intrinsic height | 104 units (viewBox); ink spans y 8–96 (88u) | EXACT |
| Slash angle from vertical | 15.24° (dx24 / dy88) | EXACT |
| Slash-to-slash centerline spacing | 34 units, constant top and bottom (parallel lines) | EXACT |

This geometry is vector source data — every value above is exact, with no measurement uncertainty, no MEASURED/INFERRED distinction needed. It was read directly from the file, not re-derived from any raster image, and was not modified in any way during this phase.

## J. Pending Lockup Calibration (Phase 3B — not decided here)

The following relationships between the slash master and the reconstructed CMSN lettering are explicitly **not decided** in this phase:

- Slash height relative to CMSN cap height — **PENDING LOCKUP CALIBRATION**
- Slash width relative to CMSN width — **PENDING LOCKUP CALIBRATION**
- Vertical alignment of the slash relative to CMSN's cap line/baseline — **PENDING LOCKUP CALIBRATION**
- Top overshoot (how far the slash extends above the CMSN cap line) — **PENDING LOCKUP CALIBRATION**
- Bottom overshoot (how far the slash extends below the CMSN baseline) — **PENDING LOCKUP CALIBRATION**
- N-to-slash gap — **PENDING LOCKUP CALIBRATION**

Reference note only (not a decision): in the approved PNG's own illustrative rendering, the slash artwork shown is ≈188px tall against a 109px CMSN cap height (≈1.72×) — but per the brief, that PNG rendering is not the authoritative slash source and this ratio is not adopted here. It is recorded only as context for whoever performs the Phase 3B calibration.

## K. Measurement Confidence

| Category | Confidence | Notes |
|---|---|---|
| All four glyph bounding boxes | HIGH (MEASURED) | Stable within ±1px across threshold sweep 60–200 (of 255) |
| Cap line / baseline | HIGH (MEASURED) | Identical y0/y1 across all four glyphs, exact pixel match |
| Primary stroke thickness (19px) | HIGH (MEASURED) | Confirmed independently in C, M (both stems), S (both walls), N (both stems) — same value every time |
| Straight stem/wall positions (M, N) | HIGH (MEASURED) | Constant to the pixel across dozens of isolated rows |
| Diagonal angles (M, N, S spine) | HIGH (MEASURED) | Linear regression across 18–65 sample rows per diagonal, R² not computed but residual pattern visually linear |
| C/S curve radii | MEDIUM-HIGH (INFERRED) | Circle-fit residual RMS 0.28–0.43px — excellent fit quality, but a fit is still an interpretation, not a direct reading |
| Aperture/apex "depth" single-number definitions (C, M) | MEDIUM (INFERRED) | The transition rows themselves are exactly measured; which row counts as "the" boundary is a judgment call, reported as a range |
| Letter spacing (bbox gap, nearest-distance) | HIGH (MEASURED) | Two independent methods agree to within 0.02px |
| Negative-space areas per counter | LOW (INFERRED / not computed) | Only bounding envelopes described; no sub-pixel area integration performed |
| C inner curvature, S upper/lower bowl radii | NOT MEASURED | Not fit this pass; flagged as open work for Phase 3B if needed |

## L. Tolerances

Starting tolerances for eventual reconstruction, as specified:

| Category | Tolerance |
|---|---|
| Primary outer geometry | ±0.50% of cap height |
| Stroke thickness | ±0.25% of cap height |
| Character width | ±0.50% |
| Internal structural coordinates | ±0.50% of cap height |
| Letter spacing | ±0.50% of cap height |
| Final slash geometry | ZERO deviation from canonical slash master |
| Future slash scale (once approved) | ±0.25% |
| Future slash position (once approved) | ±0.25% |

**Documented limitation — do not silently loosen:** ±0.50% of cap height = ±5 units = ±0.545px at this source resolution. The threshold-sensitivity sweep (§K) showed that:
- **Straight edges** (M/N stems, C's flat stem region, S's wall regions) hold to **0px** variation across the full threshold range tested — comfortably inside every tolerance above.
- **Curved edges** (C's top/bottom arm curves, S's bowl curves) shifted by **up to 2px** across the same threshold range — equivalent to **~1.83% of cap height**, more than 3× the ±0.50% target tolerance for primary outer geometry.

This means any Phase 3B reconstruction of C's and S's curved boundaries cannot honestly claim ±0.50% conformance to *this* raster source using simple threshold-based measurement — the anti-aliasing band itself is wider than the tolerance. Achieving ±0.50% on curved boundaries would require either a higher-resolution source reference or sub-pixel edge estimation from the anti-aliasing gradient (not performed in this pass). Flagging this now rather than reporting a false-precision number.

## M. Cross-Validation — Black-Background Colorway Panel

The reference PNG's second panel (rows 0–559, white ink on black background) was measured independently, using the same connected-component + row-run methodology, to check whether it represents the same underlying design as the white-bg panel measured in §C–H, per the brief's "one geometry, two colorways" requirement (see original Phase 3A instructions §17).

**Panel bounding boxes (black-bg panel, absolute image coordinates):**

| Glyph | x0 | y0 | x1 | y1 | Width px | Height px |
|---|---|---|---|---|---|---|
| C | 257 | 222 | 435 | 334 | 179 | 113 |
| M | 472 | 222/223* | 662 | 334 | 191 | 112–113* |
| S | 694 | 222 | 900 | 334 | 207 | 113 |
| N | 932 | 222 | 1100 | 334 | 169 | 113 |

\* M's raw component scan returned y0=223 (1px later than C/S/N's y0=222); treated as anti-aliasing noise, not a real 1px height difference — see the row-level check below.

**Cap height for this panel:** 113px (vs. 109px for the white-bg panel) — the black-bg artwork is rendered **≈3.67% larger** in absolute pixels. This is a render-scale difference between the two independently-exported panels, not a claim about the underlying vector design.

| Check | Black-bg panel | White-bg panel | Delta | Assessment |
|---|---|---|---|---|
| Primary stroke thickness | 20px (17.70% of cap height) | 19px (17.43% of cap height) | 0.27 pt | Consistent with uniform ~3.67% scale-up (19×1.0367≈19.7→20) |
| C→M spacing (% cap height) | 32.74% | 33.03% | 0.29 pt | Matches closely |
| M→S spacing (% cap height) | 28.32% | 28.44% | 0.12 pt | Matches closely |
| S→N spacing (% cap height) | 28.32% | 28.44% | 0.12 pt | Matches closely |
| N width:height ratio | 1.4956 | 1.4954 | 0.01% | Essentially identical |
| S width:height ratio | 1.8319 | 1.8532 | 1.15% | Close, within measurement noise |
| M width:height ratio | 1.6903 | 1.7156 | 1.48% | Within documented anti-aliasing tolerance (§L) |
| C width:height ratio | 1.5841 | 1.6147 | 1.90% | Largest divergence found — see note below |

**One artifact caught and corrected during this check:** reading the S terminal width directly at row y0 (222) in the black-bg panel initially returned an anomalous 34px-wide run (`(867,900)`) instead of the expected ~170–180px flat terminal. Inspecting row-by-row confirmed this was a single-row anti-aliasing edge effect — row 222 catches only the tip of the terminal's rounded corner crossing the threshold, while row 223 shows the full flat terminal (`(724,900)`, 177px), consistent with the white-bg panel's pattern. This is now documented as an example of the general "measure at the boundary row with care" caution already noted for M and N in §E/§G.

**Conclusion:** the black-background panel is the **same underlying letterform design** as the white-background panel — matching stroke system (both scale from the same ~17.4–17.7% stroke-to-cap-height ratio), matching relative letter spacing (within 0.3 percentage points on every pair), and near-identical N proportions (0.01% apart). C and M show a small (1.5–1.9%) width:height divergence between panels, within the range already documented in §L as inherent to threshold-based measurement of curved/diagonal raster boundaries across two independently-rasterized exports — not evidence of a second, materially different design. **Recommendation for Phase 3B:** continue treating the white-bg panel (§C–H) as primary; the black-bg panel serves as a confirmatory cross-check only, given its slightly lower measurement precision (the row-222 artifact above) and the small residual proportion drift on C and M.

## N. Phase 3B Correction Log

This section documents corrections made during the Phase 3B correction pass, following an audit of the initial Phase 3B vector reconstruction. **Original Phase 3A values are preserved unchanged in their original locations above (§H, §F) — nothing in this section overwrites them.** This log supersedes those values only for the specific purpose of vector reconstruction, with full derivation shown.

### N.1 — Wordmark inter-letter gaps (corrected)

**Problem found:** §H's gap values (`bboxGapPx`: 36/31/31, computed as `next.x0 − prev.x1`) use a different pixel-counting convention than the width values used everywhere else in this spec (`x1 − x0 + 1`, continuous-coordinate convention). These two conventions do not compose: summing the four glyph widths and three original gaps gives 826px, but the raster's actual, directly-measured C-to-N span is 823px.

**Proof of the corrected convention**, using `gap = next.x0 − (prev.x1 + 1)`:

```
gap_CM = 473 − (437+1) = 35px
gap_MS = 690 − (659+1) = 30px
gap_SN = 922 − (891+1) = 30px

Check: C(176) + 35 + M(187) + 30 + S(202) + 30 + N(163) = 823px
Raster's true span: N.x1(1084) − C.x0(262) + 1 = 823px
823 = 823 — exact match.
```

| | Original (§H, superseded for assembly) | Corrected |
|---|---|---|
| C→M | 36px / 330.28u | **35px / 321.10u** |
| M→S | 31px / 284.40u | **30px / 275.23u** |
| S→N | 31px / 284.40u | **30px / 275.23u** |

**Wordmark width impact:**

| | Assembled width | vs. target (7550.46u) |
|---|---|---|
| Before correction | 7577.98u | +27.52u (+2.75% cap height) |
| After correction | 7550.46u | −0.0004u (−0.00004% cap height) |

Applied to `CMSN-WORDMARK-NOSLASH.svg`.

### N.2 — S bottom terminal (corrected)

**Problem found:** the Phase 3B *construction* (not this spec) had mirrored the top terminal's measured anchor (168px) onto the bottom terminal instead of using the bottom terminal's own independent measurement.

**Independent re-measurement:** raster run at baseline (y=276): `[690,858]` → continuous width = 858+1−690 = **169px**. This already matched `glyphs.S.lowerTerminal.widthPx` (169) recorded in §F — the spec was correct; only the SVG construction had used the wrong value.

| | Constructed width | Deviation from target (1550.46u) |
|---|---|---|
| Before correction | 168px / 1541.28u | −9.17u (−0.92% cap height) |
| After correction | 169px / 1550.46u | ~0.00u |

Applied to `CMSN-GLYPH-S.svg`.

### N.3 — N diagonal (re-evaluated, unchanged)

No geometry was changed. Root-cause analysis: comparing the constructed centerline (stem-centerline to stem-centerline) against the raster's actual measured centerline at 7 independent rows shows residuals from +1.67px to −2.03px that **cross zero** (not a one-directional bias), RMS ≈1.5px (~1.4% of cap height). This means the construction closely tracks the true centerline path despite differing from Phase 3A's edge-slope-regression angle (54.13°) by 1.25° as an abstract angle metric. Conclusion: the 1.25° figure reflects a difference in *measurement methodology* (edge-slope regression over a row range that excludes the corner/merge zones), not a meaningful silhouette-fidelity problem. Retained as-is.

### N.4 — M vertex (re-evaluated, retained as derived)

No geometry was changed; the vertex remains explicitly labeled **DERIVED — NOT DIRECTLY MEASURED**. The same row-by-row method applied to N was applied to M's left diagonal (6 rows): residuals were **consistently +3.9 to +4.6px**, a systematic bias unlike N's (~4.2px average, ~4.3% of cap height). An alternative vertex, fit directly to the measured centerline data, lands at approximately (92.89, 83.63) — versus the original derived (93.5, 80.5) — with diagonal start points at the very top landing near x≈4.93 and x≈181.75, **not** at the stem centerlines (9.5 / 177.5).

This is real, evidence-based, and only partially resolvable without a further design decision: pinning the diagonal's start to the (locked) stem centerline while adopting the fitted vertex only reduces the residual to ~2.9px, *and* worsens the separately-reported diagonal-angle deviation (46.22° would become ≈44.92°, a larger miss against the 46.65° measured target than today). Fully resolving it requires either moving a locked endpoint or adding new corner-curve geometry at the stem/diagonal junction (comparable to C's corners) — neither of which was requested or authorized in this pass. **Flagged as an open decision, not resolved unilaterally.**

### N.5 — C and S curvature

No changes made beyond the N.2 endpoint correction (which has negligible effect on the adjoining corner's control point, itself untouched). No evidence was found indicating C's or S's other curve control points fail to correspond with the raster; per instruction, curves are refined only when doing so materially improves correspondence.
