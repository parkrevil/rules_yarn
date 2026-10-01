#!/usr/bin/env bash
# Checks that the Yarn target built from the public rules_yarn API reports the
# selected version without usable host tools. Whether it needs the network is
# yarn_offline_test's question, because only a sandbox that blocks the network
# can answer it.

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

yarn="$(rlocation "$1")"
[[ -x "$yarn" ]] || fail "cannot find the Yarn launcher $1"

host_tools="$TEST_TMPDIR/host tools"
marker="$TEST_TMPDIR/host-tool-used"
mkdir -p "$host_tools"
cat >"$host_tools/node" <<'TOOL'
#!/bin/sh
echo "$0" >>"$HOST_TOOL_MARKER"
exit 97
TOOL
chmod +x "$host_tools/node"
cp "$host_tools/node" "$host_tools/yarn"
cp "$host_tools/node" "$host_tools/corepack"

version="$(HOST_TOOL_MARKER="$marker" PATH="$host_tools:/usr/bin:/bin" "$yarn" --version)"

[[ "$version" == "4.18.0" ]] || fail "expected version 4.18.0, got '$version'"
[[ ! -e "$marker" ]] || fail "a host tool was used: $(cat "$marker")"
echo "PASS"
