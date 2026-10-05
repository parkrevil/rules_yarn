#!/usr/bin/env bash
# Runs a Node.js test file with Node's built-in test runner, on the Node.js
# the build uses. The ruleset's programs depend on one npm package, js-yaml,
# which the ruleset fetches by integrity and the tests that read YAML are given
# (the third argument); the tests comparing with Yarn are also given Yarn.

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
# A third argument is js-yaml's index.js, which the YAML-reading tests load
# from JS_YAML.
if [[ $# -ge 3 ]]; then
  JS_YAML="$(rlocation "$3")"
  [[ -f "$JS_YAML" ]] || { echo >&2 "cannot find js-yaml at $3"; exit 1; }
  export JS_YAML
fi
# A fourth is the pinned Yarn's entry point, which the tests comparing with
# Yarn itself run from YARN_JS.
if [[ $# -ge 4 ]]; then
  YARN_JS="$(rlocation "$4")"
  [[ -f "$YARN_JS" ]] || { echo >&2 "cannot find Yarn at $4"; exit 1; }
  export YARN_JS
fi
exec "$node" --test --test-reporter=spec "$test_file"
