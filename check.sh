#!/usr/bin/env bash
# For each folder in agreements/, verify version.txt + TOS.md against the hash stored in hash.sha256.
set -euo pipefail

cd "$(dirname "$0")/agreements"
failed=0
for dir in */; do
  dir=${dir%/}
  expected=$(cat "$dir/hash.sha256")
  actual=$(cat "$dir/version.txt" "$dir/TOS.md" | shasum -a 256 | cut -d' ' -f1)

  if [[ "$actual" == "$expected" ]]; then
    echo "OK: $dir"
  else
    echo "FAILED: $dir (expected $expected, got $actual)" >&2
    failed=1
  fi
done

exit $failed
