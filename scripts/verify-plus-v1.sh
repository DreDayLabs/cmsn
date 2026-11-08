#!/bin/bash
# Run in regular macOS Terminal. No signing/profile edits and no upload.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
sim_id=${1:?Usage: scripts/verify-plus-v1.sh IOS_18_6_SIMULATOR_UDID}
audit_out=$(mktemp -d /private/tmp/cmsn-plus-v1-verify.XXXXXX)
printf 'Evidence: %s\n' "$audit_out"
trap 'audit_status=$?; printf "Verification stopped (exit %s). Logs: %s\n" "$audit_status" "$audit_out" >&2; tail -35 "$audit_out"/*.log >&2; exit "$audit_status"' ERR
git -C "$repo_root" rev-parse HEAD > "$audit_out/base-sha.txt"
git -C "$repo_root" diff --binary > "$audit_out/working.patch"
# Requires an existing dedicated iOS 18.6 simulator; does not create/reset/delete one.
xcrun simctl list devices available --json > "$audit_out/devices.json"
python3 - "$audit_out/devices.json" "$sim_id" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
match=[d for runtime,ds in p['devices'].items() if runtime.endswith('iOS-18-6') for d in ds if d['udid']==sys.argv[2] and d.get('isAvailable')]
if len(match)!=1:raise SystemExit('Choose an available dedicated iOS 18.6 simulator; do not use 26.5 for StoreKit.')
PY
xcodebuild build -project "$repo_root/ios/CMSNApp/CMSNApp.xcodeproj" -scheme CMSNApp -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$audit_out/release-dd" \
  CODE_SIGNING_ALLOWED=NO > "$audit_out/release.log" 2>&1
xcodebuild test -project "$repo_root/ios/CMSNApp/CMSNApp.xcodeproj" -scheme CMSNApp \
  -destination "platform=iOS Simulator,id=$sim_id" -parallel-testing-enabled NO \
  -derivedDataPath "$audit_out/test-dd" -resultBundlePath "$audit_out/unit.xcresult" > "$audit_out/unit.log" 2>&1
for audit_run in 1 2; do
  xcodebuild test -project "$repo_root/ios/CMSNApp/CMSNApp.xcodeproj" -scheme CMSNApp \
    -destination "platform=iOS Simulator,id=$sim_id" -parallel-testing-enabled NO \
    -only-testing:CMSNAppTests/StoreKitPurchaseFlowTests -derivedDataPath "$audit_out/test-dd" \
    -resultBundlePath "$audit_out/storekit-$audit_run.xcresult" > "$audit_out/storekit-$audit_run.log" 2>&1
done
printf 'Commands completed. Inspect counts/skips and perform UI/device acceptance: %s\n' "$audit_out"
