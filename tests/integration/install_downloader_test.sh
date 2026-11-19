#!/usr/bin/env bash
# yarn.install through Bazel's downloader: a fresh output base installs from
# the repository cache with the registry blocked, and a credential helper's
# token reaches the registry.
#
# Usage: install_downloader_test.sh <rlocation of the Bazel binary> <of Node.js>
#          <of install_consumer/MODULE.bazel>

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

# shellcheck disable=SC1090
source "$(rlocation _main/tests/integration/consumer.sh)" || { echo >&2 "cannot find consumer.sh"; exit 2; }
consumer_setup "$@"

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin && build || fail_with "$last_log" "locking, pinning and installing the project failed"

echo "# Bazel's downloader"

b clean --expunge >"$work/clean.log" 2>&1 || fail_with "$work/clean.log" "bazel clean --expunge failed"
printf 'block 127.0.0.1\n' >"$work/downloader.cfg"
before=$(wc -l <"$work/registry/requests")
b build @npm//:node_modules --downloader_config="$work/downloader.cfg" >"$work/build.log" 2>&1 \
  && [ "$(wc -l <"$work/registry/requests")" = "$before" ]
record $? "Cold fetch from the repository cache: with the registry blocked, a fresh output base installs"

# The token fixtures/credential_helper.sh answers with.
printf 'secret-token' >"$work/registry/require-auth"
b clean --expunge >"$work/clean.log" 2>&1 || fail_with "$work/clean.log" "bazel clean --expunge failed"
! b build @npm//:node_modules --repository_cache="$work/cold-cache" >"$work/build.log" 2>&1
without=$?
b clean --expunge >"$work/clean.log" 2>&1 || fail_with "$work/clean.log" "bazel clean --expunge failed"
b build @npm//:node_modules --repository_cache="$work/cold-cache-2" --credential_helper=127.0.0.1="$fixtures/credential_helper.sh" >"$work/build.log" 2>&1
with=$?
[ "$without" = 0 ] && [ "$with" = 0 ]
record $? "Credentials from a credential helper: fetching fails without the helper and succeeds with it"
rm -f "$work/registry/require-auth"

consumer_finish
