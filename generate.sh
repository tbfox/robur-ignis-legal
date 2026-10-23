#!/usr/bin/env bash
# For each folder in agreements/, hash version.txt + TOS.md together and store the result in hash.sha256.
set -euo pipefail

cd "$(dirname "$0")/agreements"
for dir in */; do
  dir=${dir%/}
  cat "$dir/version.txt" "$dir/TOS.md" | shasum -a 256 | cut -d' ' -f1 > "$dir/hash.sha256"
  echo "$dir: $(cat "$dir/hash.sha256")"
done
