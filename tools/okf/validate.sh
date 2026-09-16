#!/usr/bin/env bash
# Validate the hand-authored OKF bundle. Skips when the bundle does not exist yet.
# The generated openwiki/ bundle is owned and validated by OpenWiki, not here.
set -euo pipefail

bundle="${1:-.okf}"
[ -d "$bundle" ] || exit 0

exec uv run "$(dirname "$0")/okf_validate.py" "$bundle" --strict
