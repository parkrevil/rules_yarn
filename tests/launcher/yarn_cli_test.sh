#!/usr/bin/env bash
# Tests the yarn_binary launcher with the real Yarn distribution: selected
# version, unusable host tools, project yarnPath, invalid commands, unchanged
# project files, and no network access.

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

out="$TEST_TMPDIR/stdout"
err="$TEST_TMPDIR/stderr"

test_network_is_blocked() {
  if "$BASH" -c 'exec 3<>/dev/tcp/1.1.1.1/443' 2>/dev/null; then
    fail "the test can reach the network; run it in a sandbox that honors the block-network tag"
  fi
}

test_version_without_usable_host_tools() {
  local host_tools="$TEST_TMPDIR/host tools"
  local marker="$TEST_TMPDIR/host-tool-used"
  mkdir -p "$host_tools"
  cat >"$host_tools/node" <<'TOOL'
#!/bin/sh
echo "$0" >>"$HOST_TOOL_MARKER"
exit 97
TOOL
  chmod +x "$host_tools/node"
  cp "$host_tools/node" "$host_tools/yarn"
  cp "$host_tools/node" "$host_tools/corepack"

  HOST_TOOL_MARKER="$marker" PATH="$host_tools:/usr/bin:/bin" "$yarn" --version >"$out" 2>"$err"

  [[ "$(cat "$out")" == "4.18.0" ]] || fail "expected version 4.18.0, got '$(cat "$out")'"
  [[ ! -e "$marker" ]] || fail "a host tool was used: $(cat "$marker")"
}

test_project_yarn_path_is_ignored_and_files_are_unchanged() {
  local project="$TEST_TMPDIR/project"
  mkdir -p "$project"
  cat >"$project/package.json" <<'JSON'
{
  "name": "project",
  "packageManager": "yarn@4.18.0"
}
JSON
  cat >"$project/.yarnrc.yml" <<'YAML'
yarnPath: ./redirect.cjs
YAML
  cat >"$project/redirect.cjs" <<'JS'
console.log("redirected");
process.exit(3);
JS
  : >"$project/yarn.lock"
  cp -R "$project" "$TEST_TMPDIR/project-before"

  (cd "$project" && "$yarn" --version) >"$out" 2>"$err"

  [[ "$(cat "$out")" == "4.18.0" ]] || fail "expected version 4.18.0, got '$(cat "$out")'"
  diff -r "$TEST_TMPDIR/project-before" "$project" || fail "running --version changed the project files"
}

test_invalid_command_reports_failure() {
  local dir="$TEST_TMPDIR/no project"
  mkdir -p "$dir"
  local status=0
  (cd "$dir" && "$yarn" definitely-not-a-command) >"$out" 2>"$err" || status=$?

  [[ "$status" -eq 1 ]] || fail "expected exit status 1, got $status"
  grep -qF "No project found in $(cd "$dir" && pwd -P)" "$out" || fail "missing Yarn diagnostic; stdout was: $(cat "$out")"
}

test_network_is_blocked
test_version_without_usable_host_tools
test_project_yarn_path_is_ignored_and_files_are_unchanged
test_invalid_command_reports_failure
echo "PASS"
