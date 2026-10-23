#!/usr/bin/env bash
# Verify coaching/TOS.md against the hash stored in coaching/hash.sha256.
set -euo pipefail

cd "$(dirname "$0")/coaching"
shasum -a 256 -c hash.sha256
