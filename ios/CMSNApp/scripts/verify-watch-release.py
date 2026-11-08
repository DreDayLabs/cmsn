#!/usr/bin/env python3
"""Verify Apple's two watch upload rejection conditions in a built watch .app."""
import plistlib
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
with (bundle / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleIdentifier'] == 'com.earnyourcmsn.app.watchkitapp'
assert 'UIBackgroundModes' not in info, 'watchOS must use WKBackgroundModes, not UIBackgroundModes'
assert 'workout-processing' in info.get('WKBackgroundModes', []), 'Preserve workout background execution'
primary = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {})
icons = primary.get('CFBundleIconFiles') or info.get('CFBundleIconFiles', [])
assert icons, 'Missing CFBundleIconFiles (ITMS-90391)'
for icon in icons:
    assert list(bundle.glob(f'{icon}*.png')), f'Missing icon PNG for {icon}'
assert info['CFBundleVersion'] == '3', 'Expected fixed release build 3'
print(f"PASS: {len(icons)} icon entries with bundled PNGs; WKBackgroundModes preserved; no UIBackgroundModes; version {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
