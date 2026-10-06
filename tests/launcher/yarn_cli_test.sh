#!/usr/bin/env bash
# Tests the yarn_binary launcher with the real Yarn distribution: selected
# version, unusable host tools, project yarnPath, invalid commands, and
# unchanged project files. None of these needs the network blocked. Proving
# that `--version` needs no network is yarn_offline_test's job, because that
# one can only be proved in a sandbox that blocks it.

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
host_tool="$(rlocation "$2")"
[[ -x "$host_tool" ]] || fail "cannot find the host tool stand-in $2"
# A project whose .yarnrc.yml points yarnPath at a script that would print
# "redirected" and fail, found through its package.json.
yarn_path_project="$(dirname "$(rlocation "$3")")"
[[ -f "$yarn_path_project/redirect.cjs" && -f "$yarn_path_project/.yarnrc.yml" ]] || fail "cannot find the yarnPath project $3"

out="$TEST_TMPDIR/stdout"
err="$TEST_TMPDIR/stderr"

test_version_without_usable_host_tools() {
  local host_tools="$TEST_TMPDIR/host tools"
  local marker="$TEST_TMPDIR/host-tool-used"
  mkdir -p "$host_tools"
  for tool in node yarn corepack; do
    cp "$host_tool" "$host_tools/$tool"
  done

  HOST_TOOL_MARKER="$marker" PATH="$host_tools:/usr/bin:/bin" "$yarn" --version >"$out" 2>"$err"

  [[ "$(cat "$out")" == "4.18.0" ]] || fail "expected version 4.18.0, got '$(cat "$out")'"
  [[ ! -e "$marker" ]] || fail "a host tool was used: $(cat "$marker")"
}

test_project_yarn_path_is_ignored_and_files_are_unchanged() {
  local project="$TEST_TMPDIR/project"
  # Copied with links followed, so the project is plain files Yarn could write.
  cp -RL "$yarn_path_project" "$project"
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

test_version_without_usable_host_tools
test_project_yarn_path_is_ignored_and_files_are_unchanged
test_invalid_command_reports_failure
echo "PASS"
