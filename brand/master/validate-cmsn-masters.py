#!/usr/bin/env python3
"""
validate-cmsn-masters.py

Lightweight, dependency-free validation for the CMSN canonical master system
(Phase 3C). Uses only the Python 3 standard library - no npm/pip install
required, per the "no large dependency" rule.

Checks:
  1. Expected master files exist (brand/master/).
  2. Every master SVG parses as valid XML.
  3. Expected viewBoxes match CMSN-MASTER-INTEGRITY.json.
  4. Geometry fingerprints match CMSN-MASTER-INTEGRITY.json exactly (zero drift).
  5. Protected reference file hashes (raster + slash master) match
     CMSN-MASTER-INTEGRITY.json exactly.
  6. The wordmark's glyph translate offsets reproduce the documented
     assembly contract (four glyph widths + three gaps) to within 0.01 unit.

Exit code 0 = all checks pass. Exit code 1 = one or more checks failed.

Usage:
    python3 brand/master/validate-cmsn-masters.py
    (run from the repository root, or pass --root <path>)
"""
import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def geometry_fingerprint(svg_path):
    """
    Deterministic geometry fingerprint. Extracts, in document order: the
    root viewBox, and for every <path> element (regardless of nesting under
    <g>), the cumulative geometry-affecting transform chain, the exact 'd'
    string, stroke-width, stroke-linecap, stroke-linejoin, fill, fill-rule.
    Comments, aria-label, role, id, class, and whitespace/formatting are
    excluded, so this hash is stable under cosmetic edits but changes on any
    geometry-affecting one.
    """
    tree = ET.parse(svg_path)
    root = tree.getroot()
    viewBox = root.get('viewBox', '')
    records = []

    def walk(el, transform_chain):
        tag = el.tag.split('}')[-1]
        if tag == 'g':
            t = el.get('transform', '')
            new_chain = transform_chain + ([t] if t else [])
            for child in el:
                walk(child, new_chain)
        elif tag == 'path':
            records.append({
                'transform_chain': transform_chain,
                'd': el.get('d', ''),
                'stroke-width': el.get('stroke-width', ''),
                'stroke-linecap': el.get('stroke-linecap', ''),
                'stroke-linejoin': el.get('stroke-linejoin', ''),
                'fill': el.get('fill', ''),
                'fill-rule': el.get('fill-rule', ''),
            })
        else:
            for child in el:
                walk(child, transform_chain)

    for child in root:
        walk(child, [])

    canonical = json.dumps({'viewBox': viewBox, 'paths': records}, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def file_sha256(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default='.', help='Repository root (default: current directory)')
    args = ap.parse_args()
    root = Path(args.root).resolve()

    failures = []
    passes = []

    integrity_path = root / 'brand/master/CMSN-MASTER-INTEGRITY.json'
    if not integrity_path.exists():
        print(f"FAIL: integrity file not found: {integrity_path}")
        sys.exit(1)
    integrity = json.loads(integrity_path.read_text())

    # 1. Expected files exist
    expected_files = [m['masterFile'] for m in integrity['masters']] + \
                      [integrity['protectedFiles']['approvedReference']['path'],
                       integrity['protectedFiles']['slashMaster']['path']]
    for rel in expected_files:
        p = root / rel
        if p.exists():
            passes.append(f"file exists: {rel}")
        else:
            failures.append(f"MISSING FILE: {rel}")

    # 2 & 3 & 4. SVG parses, viewBox matches, geometry fingerprint matches
    for m in integrity['masters']:
        p = root / m['masterFile']
        if not p.exists():
            continue
        try:
            tree = ET.parse(p)
            passes.append(f"valid XML: {m['masterFile']}")
        except ET.ParseError as e:
            failures.append(f"INVALID XML: {m['masterFile']} ({e})")
            continue

        root_el = tree.getroot()
        actual_vb = root_el.get('viewBox', '')
        if actual_vb == m['viewBox']:
            passes.append(f"viewBox matches: {m['masterFile']}")
        else:
            failures.append(f"VIEWBOX MISMATCH: {m['masterFile']} expected={m['viewBox']!r} actual={actual_vb!r}")

        actual_fp = geometry_fingerprint(p)
        if actual_fp == m['geometryFingerprint']:
            passes.append(f"geometry fingerprint matches (zero drift): {m['masterFile']}")
        else:
            failures.append(
                f"GEOMETRY DRIFT DETECTED: {m['masterFile']}\n"
                f"    expected: {m['geometryFingerprint']}\n"
                f"    actual:   {actual_fp}"
            )

    # 5. Protected file hashes
    for key, info in integrity['protectedFiles'].items():
        p = root / info['path']
        if not p.exists():
            failures.append(f"MISSING PROTECTED FILE: {info['path']}")
            continue
        actual = file_sha256(p)
        if actual == info['sha256']:
            passes.append(f"protected file hash matches: {info['path']}")
        else:
            failures.append(
                f"PROTECTED FILE CHANGED: {info['path']}\n"
                f"    expected sha256: {info['sha256']}\n"
                f"    actual sha256:   {actual}"
            )

    # 6. Wordmark assembly contract
    wm_path = root / integrity['wordmarkAssemblyCheck']['masterFile']
    if wm_path.exists():
        content = wm_path.read_text()
        offsets = [float(x) for x in re.findall(r'translate\(([\d.]+),', content)]
        expected_offsets = integrity['wordmarkAssemblyCheck']['expectedOffsets']
        ok = len(offsets) == len(expected_offsets) and all(
            abs(a - b) < 0.01 for a, b in zip(offsets, expected_offsets)
        )
        if ok:
            passes.append("wordmark assembly offsets match documented contract")
        else:
            failures.append(f"WORDMARK ASSEMBLY MISMATCH: expected {expected_offsets}, found {offsets}")
    else:
        failures.append(f"MISSING WORDMARK: {integrity['wordmarkAssemblyCheck']['masterFile']}")

    print(f"\n{'='*60}")
    print(f"CMSN Master Validation — {len(passes)} passed, {len(failures)} failed")
    print('='*60)
    for p in passes:
        print(f"  OK   {p}")
    for f in failures:
        print(f"  FAIL {f}")
    print('='*60)

    if failures:
        print("\nRESULT: VALIDATION FAILED")
        sys.exit(1)
    else:
        print("\nRESULT: ALL CHECKS PASSED")
        sys.exit(0)


if __name__ == '__main__':
    main()
