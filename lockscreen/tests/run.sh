#!/usr/bin/env bash
# Runs every lock-crate-*.sh. Offscreen only: no test creates a session lock.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$here/../crate/common/fonts" ] || [ ! -d "$here/../crate/common/backgrounds" ]; then
    bash "$here/../build-assets.sh"
fi
status=0
for t in "$here"/lock-crate-*.sh; do
    bash "$t" || status=1
done
exit $status
