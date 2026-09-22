#!/usr/bin/env bash
# PostToolUse check: after a write inside the hand-authored OKF bundle, validate it.
# Exit 2 feeds the validator output back to the model so it can fix the document.
# Conformance errors only — pre-commit runs the same validator with --strict.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 0

payload=$(cat)
path=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' <<<"$payload")
command=$(jq -r '.tool_input.command // empty' <<<"$payload")

touches_bundle=0
case "$path" in
  *.okf/*) touches_bundle=1 ;;
esac
# Bash carries a command string instead of a path.
case "$command" in
  *.okf/*) touches_bundle=1 ;;
esac
[ "$touches_bundle" -eq 1 ] || exit 0
[ -d .okf ] || exit 0

out=$(uv run tools/okf/validate.py .okf 2>&1) && exit 0

printf 'OKF bundle is not conformant. Fix the document before continuing.\n%s\n' "$out" >&2
exit 2
