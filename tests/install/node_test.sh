#!/usr/bin/env bash
# Runs a Node.js test file with Node's built-in test runner, on the Node.js
# the build uses. The ruleset's programs depend on one npm package, js-yaml,
# which the ruleset fetches by integrity; the tests that need it, Yarn or
# bsdtar are given them as NAME=<runfiles path> arguments.

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

node="$(rlocation "$1")"
test_file="$(rlocation "$2")"
[[ -x "$node" ]] || { echo >&2 "cannot find Node.js at $1"; exit 1; }
[[ -f "$test_file" ]] || { echo >&2 "cannot find the test file $2"; exit 1; }
# Every further argument is NAME=<runfiles path>: the file is found in the
# runfiles and its path exported as NAME, for the tests that need one — JS_YAML
# for js-yaml's index.js, YARN_JS for the pinned Yarn, BSDTAR for tar.bzl's
# bsdtar.
for binding in "${@:3}"; do
  name=${binding%%=*}
  file="$(rlocation "${binding#*=}")"
  [[ -e "$file" ]] || { echo >&2 "cannot find $name at ${binding#*=}"; exit 1; }
  export "$name=$file"
done
exec "$node" --test --test-reporter=spec "$test_file"
