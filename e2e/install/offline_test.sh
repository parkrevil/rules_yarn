#!/usr/bin/env bash
# Shows the installed tree needs no network: the test fails rather than passes
# quietly where the sandbox does not block it.

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

fail() {
  echo >&2 "FAIL: $*"
  exit 1
}

node="$(rlocation "$1")"
shift
nm=
for f in "$@"; do
  # The repository's own node_modules, not a workspace's.
  [[ "$f" =~ ^[^/]+/node_modules/is-number$ ]] && nm="$(dirname "$(rlocation "$f")")"
done
[[ -n "$nm" ]] || fail "cannot find the installed node_modules"

if "$BASH" -c 'exec 3<>/dev/tcp/1.1.1.1/443' 2>/dev/null; then
  fail "this test can reach the network, so it cannot show the tree does not need it; run it where the sandbox honours block-network"
fi

[[ "$(NODE_PATH="$nm" "$node" -e 'console.log(require("is-number")(5))')" == "true" ]] || fail "requiring is-number offline failed"
echo "PASS"
