# CMSN Custom Lettering — Provenance Record

This is a factual development record. It makes no legal claims about copyright or trademark ownership.

1. The approved PNG (`CMSN-horizontal-approved-reference.png`, frozen copy of the file supplied in Downloads as `brand source approved-reference CMSN-horizontal-approved-reference.png`) was supplied as the visual reference for the CMSN custom lettering (the C, M, S, N glyphs).
2. **Correction to the originating brief:** the brief describing this reference stated the slash symbol had been intentionally removed from the file. On inspection, the supplied PNG in fact contains rendered `//` slash strokes and an "EARN YOUR CMSN" tagline in both of its two colorway panels (black-background/white-ink and white-background/black-ink). This is documented as a discrepancy, not silently corrected — see `CMSN-GEOMETRY-SPEC.md` §A and the note in this repository's chat record. It does not change how this phase proceeded: the slash pixels and tagline pixels present in the file were identified and excluded from every CMSN glyph measurement, exactly as they would have been had the file truly omitted them.
3. The slash symbol's authoritative source is the existing canonical vector file `public/brand/cmsn-slashes-dark.svg`, not any pixels in the reference PNG. The PNG's own slash rendering was not measured, traced, or used as a geometry source anywhere in this phase.
4. No commercial font is being adopted as the CMSN wordmark.
5. No font file is being incorporated into the custom lettering.
6. Phase 3A performs measurement and documentation only. No CMSN vector lettering was constructed.
7. Final vector geometry for C, M, S, and N will be deliberately constructed during a later, separately approved phase (Phase 3B or later), using the measurements recorded here as a reference specification — not as an automated conversion.
8. Automated bitmap tracing (Illustrator Image Trace, autotrace, OCR-derived fonts, or any third-party font-matching/tracing service) is prohibited as the production method and was not used at any point in this phase. All measurements were produced by direct pixel-boundary analysis (thresholding, connected-component labeling, row-run profiling, and least-squares curve fitting for reported radii/angles), performed and reviewed manually — not run through an automatic vectorizer.
9. The previous A1/A2/A3/D1/D2/D3 exploration geometry, and the F1/F2/F3 connected-S/N constructions from the prior "Final Construction Round 1" phase, are rejected as production geometry and were not reused, referenced, or blended into any measurement in this phase.
10. The approved S is independent from N in the reference artwork. No connection, ligature, or interlock between S and N was found in the measured reference, and none was assumed or introduced during measurement.

**Measurement date:** 2026-08-25
**Performed by:** Claude (Claude Code), at Dre's direction, in `~/Documents/DreDayLabs/Projects/cmsn` on branch `claude/cmsn-ios-fitness-app-yozz0i`.
