#!/usr/bin/env bash
# Proves that running Yarn with `--version` needs no network, which is the one
# thing the other launcher tests cannot prove: the only way to show a command
# does not use the network is to take the network away.
#
# That takes a sandbox which honours the `block-network` tag. Where the sandbox
# does not block — Bazel falls back to `processwrapper-sandbox` on some
# machines — this test fails rather than passing quietly, because a run that
# could have reached the network has not shown anything.

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
expected=$2

if "$BASH" -c 'exec 3<>/dev/tcp/1.1.1.1/443' 2>/dev/null; then
  fail "this test can reach the network, so it cannot show that Yarn does not need it; run it where the sandbox honours the block-network tag"
fi

project="$TEST_TMPDIR/project"
mkdir -p "$project"
cat >"$project/package.json" <<JSON
{
  "name": "project",
  "packageManager": "yarn@$expected"
}
JSON
: >"$project/yarn.lock"
cp -R "$project" "$TEST_TMPDIR/project-before"

version="$(cd "$project" && "$yarn" --version)"

[[ "$version" == "$expected" ]] || fail "expected version $expected, got '$version'"
diff -r "$TEST_TMPDIR/project-before" "$project" || fail "running --version with no network changed the project files"
echo "PASS"
