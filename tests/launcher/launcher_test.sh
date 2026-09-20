#!/usr/bin/env bash
# Tests how the yarn_binary launcher passes arguments, output streams, exit
# status, environment, and working directory to the Yarn entry point, using a
# probe entry point in place of Yarn.

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

probe="$(rlocation "$1")"
[[ -x "$probe" ]] || fail "cannot find the probe launcher $1"

out="$TEST_TMPDIR/stdout"
err="$TEST_TMPDIR/stderr"

expect_stderr_line() {
  grep -qxF -- "$1" "$err" || fail "stderr lacks line '$1'; stderr was: $(cat "$err")"
}

test_arguments_and_streams() {
  local -a args=(
    "with space"
    '$HOME'
    '*'
    '"double quoted"'
    "single'quote"
    'semi;colon && echo injected'
    $'new\nline'
    ''
    '--flag=value'
  )
  "$probe" "${args[@]}" >"$out" 2>"$err"

  printf '%s\0' "${args[@]}" >"$TEST_TMPDIR/expected_stdout"
  cmp -s "$out" "$TEST_TMPDIR/expected_stdout" || fail "arguments or stdout differ from the input arguments"
  expect_stderr_line "YARN_IGNORE_PATH=1"
  expect_stderr_line "YARN_ENABLE_TELEMETRY=0"
}

test_launcher_settings_override_caller_environment() {
  YARN_IGNORE_PATH=0 YARN_ENABLE_TELEMETRY=1 "$probe" >"$out" 2>"$err"

  expect_stderr_line "YARN_IGNORE_PATH=1"
  expect_stderr_line "YARN_ENABLE_TELEMETRY=0"
}

test_exit_status() {
  local status=0
  ARGV_PROBE_EXIT_CODE=7 "$probe" >"$out" 2>"$err" || status=$?

  [[ "$status" -eq 7 ]] || fail "expected exit status 7, got $status"
}

test_direct_invocation_keeps_working_directory() {
  local dir="$TEST_TMPDIR/direct"
  mkdir -p "$dir"
  (cd "$dir" && unset BUILD_WORKING_DIRECTORY && "$probe") >"$out" 2>"$err"

  expect_stderr_line "cwd=$(cd "$dir" && pwd -P)"
}

test_bazel_run_uses_build_working_directory() {
  local start="$TEST_TMPDIR/start"
  local caller="$TEST_TMPDIR/caller dir"
  mkdir -p "$start" "$caller"
  (cd "$start" && BUILD_WORKING_DIRECTORY="$caller" "$probe") >"$out" 2>"$err"

  expect_stderr_line "cwd=$(cd "$caller" && pwd -P)"
}

test_relative_runfiles_paths_survive_directory_change() {
  local caller="$TEST_TMPDIR/relative caller"
  mkdir -p "$caller"
  (cd "$RUNFILES_DIR" && RUNFILES_DIR=. BUILD_WORKING_DIRECTORY="$caller" "$probe" relative) >"$out" 2>"$err"

  printf '%s\0' relative >"$TEST_TMPDIR/expected_stdout"
  cmp -s "$out" "$TEST_TMPDIR/expected_stdout" || fail "probe did not run with relative runfiles paths"
  expect_stderr_line "cwd=$(cd "$caller" && pwd -P)"
}

test_manifest_only_runfiles_lookup() {
  # Bazel stages a runfiles tree for tests but no manifest, so write one in the
  # documented format: each line maps a runfiles-root path to a real path.
  local manifest="$TEST_TMPDIR/MANIFEST"
  (
    cd "$RUNFILES_DIR"
    find . \( -type f -o -type l \) -printf '%P\n' | sort
  ) | while read -r entry; do
    printf '%s %s\n' "$entry" "$RUNFILES_DIR/$entry"
  done >"$manifest"
  grep -q "^bazel_tools/tools/bash/runfiles/runfiles.bash " "$manifest" || fail "generated manifest lacks the runfiles library"
  [[ ! -e "$probe.runfiles" ]] || fail "$probe.runfiles exists, so the lookup would not be manifest-only"
  (unset RUNFILES_DIR JAVA_RUNFILES TEST_SRCDIR && RUNFILES_MANIFEST_FILE="$manifest" "$probe" manifest) >"$out" 2>"$err"

  printf '%s\0' manifest >"$TEST_TMPDIR/expected_stdout"
  cmp -s "$out" "$TEST_TMPDIR/expected_stdout" || fail "probe did not run with manifest-only runfiles lookup"
}

test_arguments_and_streams
test_launcher_settings_override_caller_environment
test_exit_status
test_direct_invocation_keeps_working_directory
test_bazel_run_uses_build_working_directory
test_relative_runfiles_paths_survive_directory_change
test_manifest_only_runfiles_lookup
echo "PASS"
