#!/usr/bin/env bash
# Hash coaching/TOS.md and store the result in coaching/hash.sha256.
set -euo pipefail

cd "$(dirname "$0")/coaching"
shasum -a 256 TOS.md > hash.sha256
cat hash.sha256
