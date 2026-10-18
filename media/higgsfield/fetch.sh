#!/usr/bin/env bash
# Restore any missing Higgsfield originals from the Higgsfield CDN using
# manifest.json, then verify every file against its recorded sha256.
#
# The files are normally checked out by Git LFS; use this when LFS content
# is unavailable (e.g. `git lfs pull` was skipped or the LFS quota ran out).
#
# Requires: curl, jq, sha256sum (or shasum on macOS).
set -euo pipefail

cd "$(dirname "$0")"

if command -v sha256sum >/dev/null; then
  sha() { sha256sum "$1" | cut -d' ' -f1; }
else
  sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

fail=0
while IFS=$'\t' read -r file url expected; do
  # An un-pulled LFS pointer is a tiny text file; treat it as missing.
  if [[ ! -s "$file" ]] || [[ $(wc -c <"$file") -lt 1024 ]]; then
    echo "fetching $file"
    mkdir -p "$(dirname "$file")"
    curl -fsSL -o "$file" "$url"
  fi
  if [[ $(sha "$file") != "$expected" ]]; then
    echo "checksum mismatch: $file" >&2
    fail=1
  fi
done < <(jq -r '.items[] | [.file, .url, .sha256] | @tsv' manifest.json)

if [[ $fail -ne 0 ]]; then
  exit 1
fi
echo "all $(jq '.count' manifest.json) files present and verified"
