#!/usr/bin/env bash
# Checks the target of one direct dependency: its runfiles hold exactly the
# store packages that dependency reaches, and the dependency works from them.
#
#   part_test.sh <node> <link> <store packages, comma-separated> <files...>
#
# <link> is the dependency's link relative to the repository, and each store
# package is named by its slug without the hash.

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
link="$2"
expected="$3"
shift 3
[[ -x "$node" ]] || fail "cannot find Node.js"

nm=
for f in "$@"; do
  [[ "$f" == */"$link" ]] && nm="$(dirname "$(rlocation "$f")")"
done
[[ -n "$nm" ]] || fail "the target holds no $link"
root="${nm%/"$(dirname "$link")"}"

# Every store package in the runfiles, by its slug without the hash.
stores="$(find "$root/node_modules/.store" -mindepth 1 -maxdepth 1 | sed 's|.*/||; s|-[0-9a-f]\{10\}$||' | LC_ALL=C sort | paste -sd, -)"
[[ "$stores" == "$expected" ]] || fail "the runfiles hold the store packages $stores, not $expected"

js() { NODE_PATH="$nm" "$node" -e "$1"; }
case "$link" in
  node_modules/is-number)
    # Patched, so built from its archive; packageExtensions gives it js-tokens.
    [[ "$(js 'console.log(require("is-number").patchedByRulesYarnTest === true)')" == "true" ]] || fail "is-number is not the patched one"
    js 'const fs = require("fs"); require(require.resolve("js-tokens", {paths: [fs.realpathSync(require.resolve("is-number"))]}))' \
      || fail "is-number cannot require js-tokens"
    ;;
  packages/app/node_modules/react-dom)
    # A peer-dependency instance, which resolves react through its own links.
    js 'const fs = require("fs"); require(require.resolve("react", {paths: [fs.realpathSync(require.resolve("react-dom"))]}))' \
      || fail "react-dom cannot require react"
    ;;
  node_modules/typescript)
    [[ "$(PATH="$(dirname "$node"):/usr/bin:/bin" "$nm/.bin/tsc" --version)" == "Version 5.6.3" ]] || fail ".bin/tsc does not run TypeScript 5.6.3"
    ;;
  *) fail "no check for $link" ;;
esac
