#!/usr/bin/env bash
# PostToolUse check: after a write inside the hand-authored OKF bundle, validate it.
# Exit 2 feeds the validator output back to the model so it can fix the document.
# Conformance errors only — pre-commit runs the same validator with --strict.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 0

path=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
case "$path" in
  */.okf/*.md) ;;
  *) exit 0 ;;
esac

out=$(uv run tools/okf/okf_validate.py .okf 2>&1) && exit 0

printf 'OKF bundle is not conformant. Fix the document before continuing.\n%s\n' "$out" >&2
exit 2
