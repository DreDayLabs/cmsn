# Revision 02 — vector PDF exports

Six vector PDFs of the approved identity, one per active asset. Generated
2026-09-19 from the SVG masters in the parent directory.

| File | Page size | Contents |
| --- | --- | --- |
| `cmsn-horizontal-positive.pdf` | 250.11 × 48.34 mm | CMSN// lockup, black on transparent |
| `cmsn-horizontal-reversed.pdf` | 250.11 × 48.34 mm | CMSN// lockup, white on transparent |
| `cmsn-wordmark-positive.pdf` | 250.11 × 56.13 mm | CMSN wordmark, black |
| `cmsn-wordmark-reversed.pdf` | 250.11 × 56.13 mm | CMSN wordmark, white |
| `cmsn-symbol-positive.pdf` | 59.94 × 77.64 mm | Standalone `//`, black |
| `cmsn-symbol-reversed.pdf` | 59.94 × 77.64 mm | Standalone `//`, white |

The lockup and wordmark pages carry the approved 220-unit clear space inside
the page box. The symbol pages are the tight ink box, matching the exact-size
placement files in `apparel/collection-01/` — add clear space when placing.

Page sizes land within 0.05% of their nominal targets (250 mm and 60 mm wide);
the difference is PDF point rounding, not geometry drift.

## What these are good for

Most vendors take a vector PDF. Illustrator, CorelDRAW and embroidery
digitising software all open these as editable paths. Use them for print,
transfer, and as the artwork handed to a digitiser.

## What is still missing

**Native `.ai` and `.eps` masters do not exist for Revision 02.** Any vendor
who specifically requires native Illustrator files is still blocked.

The Revision 01 natives under `brand/exports/` are superseded and must not be
sent — `brand/guidelines/IDENTITY-AUTHORITY.md` rejects the extended and
stacked treatments they contain.

Producing the natives needs Illustrator itself. Adobe's hosted vector export
only converts *from* an `.ai` source, so it cannot author one; the attempt on
2026-09-14 failed with `AXError.cannotComplete` locally and HTTP 429 on the
hosted path. Opening any SVG in the parent directory and saving as `.ai` /
`.eps` closes this out.

## Verification

Each PDF was checked for embedded raster images (zero in all six) and its
drawing operations counted against the source SVG's path segments. Geometry
was previously verified against `../revision-spec.json` to a maximum deviation
of 0.000062 cap-height units.

```
cmsn-horizontal-positive.pdf   raster=0  pdf_ops=80  svg_segments=75  VECTOR
cmsn-horizontal-reversed.pdf   raster=0  pdf_ops=80  svg_segments=75  VECTOR
cmsn-symbol-positive.pdf       raster=0  pdf_ops=10  svg_segments=8   VECTOR
cmsn-symbol-reversed.pdf       raster=0  pdf_ops=10  svg_segments=8   VECTOR
cmsn-wordmark-positive.pdf     raster=0  pdf_ops=70  svg_segments=67  VECTOR
cmsn-wordmark-reversed.pdf     raster=0  pdf_ops=70  svg_segments=67  VECTOR
```

Operation counts exceed segment counts because path closures compile to their
own operators. No physical print or sew-out proof is claimed.

## SHA-256

```
eae04464bd9e811a0f87e7981d77e7b2fbb699aeff5fc9f3fc9586292d40c526  cmsn-horizontal-positive.pdf
2608ee93e0a777863ea4102fdf2044edf1d763e8833c98bc97243ac6818b85d1  cmsn-horizontal-reversed.pdf
4d198bcb3ec9e58f154544bfc68c731e636f3e6b8cf3866adc5230fa566f5ec1  cmsn-symbol-positive.pdf
96cea14963187c055159cc1d913bc4c436d4af73d9ceaa1e0df1ebe807e76ff4  cmsn-symbol-reversed.pdf
0fa9e0cfaccdbf64b3febe4f45becdd55e83864eb73795d7da439bbc071866d1  cmsn-wordmark-positive.pdf
6544d255f31109ce3d49b5213c6f61a298fe796e33f712a4b94304a321c2460a  cmsn-wordmark-reversed.pdf
```
