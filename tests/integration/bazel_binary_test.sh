#!/usr/bin/env bash
# Requires the Bazel binary the nested-Bazel tests run to be the version in
# .bazelversion, so that a bump of one cannot leave the other behind.
#
# Usage: bazel_binary_test.sh <rlocation of the binary> <rlocation of .bazelversion>

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

bazel="$(rlocation "$1")"
[[ -x "$bazel" ]] || fail "cannot find the Bazel binary $1"
version_file="$(rlocation "$2")"
[[ -f "$version_file" ]] || fail "cannot find $2"

want=$(head -1 "$version_file")
# The client answers --version itself, without starting a server.
reported=$("$bazel" --version) || fail "the Bazel binary did not report its version"
[[ "$reported" == "bazel $want" ]] || fail "the Bazel binary reports '$reported', but .bazelversion says $want"
echo "PASS: the Bazel binary reports $want, as .bazelversion says"
