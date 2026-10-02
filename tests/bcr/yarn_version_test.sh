#!/usr/bin/env bash
# The whole of what the registry presubmit checks: a module that depends on
# rules_yarn can build a Yarn target through the public API and run it.

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

yarn="$(rlocation "$1")"
expected=$2

[[ -x "$yarn" ]] || { echo >&2 "FAIL: cannot find the Yarn launcher $1"; exit 1; }

version="$("$yarn" --version)"
[[ "$version" == "$expected" ]] || { echo >&2 "FAIL: expected Yarn $expected, got '$version'"; exit 1; }
echo "PASS"
