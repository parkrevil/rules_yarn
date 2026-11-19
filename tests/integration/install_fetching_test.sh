#!/usr/bin/env bash
# yarn.install fetching and fetching again: the first pin, the host's platform
# package, a scoped package, a second build that installs nothing, and the
# lockfile, pin and architecture changes that do install again.
#
# Usage: install_fetching_test.sh <rlocation of the Bazel binary> <of Node.js>
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

echo "# pinning"

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0"'
lock || fail_with "$last_log" "locking the project failed"

pin
pinned=$?
[ "$pinned" = 0 ] && "$node" -e '
const pins = require(process.argv[1]).packages;
const want = ["left@npm:1.0.0", "@fx/scoped@npm:1.0.0", "tool@npm:1.0.0", "tool-linux-x64@npm:1.0.0", "tool-linux-arm64@npm:1.0.0", "tool-darwin-x64@npm:1.0.0", "tool-darwin-arm64@npm:1.0.0"];
process.exit(want.every((r) => pins[r] && pins[r].integrity.startsWith("sha512-")) && Object.keys(pins).length === want.length ? 0 : 1);
' "$ws/pins.json"
record $? "First pin: from an empty file, the pin target records every npm: entry, every platform's included"

echo
echo "# installing"

build
status=$?
host_tool="tool-$("$node" -p 'process.platform')-$("$node" -p 'process.arch')"
other_tool=tool-linux-x64
[ "$host_tool" = tool-linux-x64 ] && other_tool=tool-darwin-arm64
[ "$status" = 0 ] && [ -f "$(store "$host_tool-npm")/binary.txt" ] && [ ! -e "$(store "$other_tool-npm")/binary.txt" ] && [ -L "$(built)/.bin/fx-tool" ]
record $? "Configuration above the project, and Default architecture: the build succeeds with the host's platform package only"

[ "$(cat "$(store @fx-scoped-npm)/index.js")" = "module.exports = 'scoped';" ]
record $? "a scoped package installs, served at the spelling Yarn requests"

echo
echo "# fetching again"

t1=$(layout_time)
build
again=$?
t2=$(layout_time)
[ "$again" = 0 ] && [ -n "$t1" ] && [ "$t1" = "$t2" ]
record $? "Nothing changed: a second build installs nothing again"

cp "$ws/yarn.lock" "$work/lock.saved"
edit "$ws/yarn.lock" "(s) => '# changed\\n' + s"
! build && log_has "would have been modified"
changed=$?
cp "$work/lock.saved" "$ws/yarn.lock"
sleep 1
build && t3=$(layout_time) && [ "$t3" != "$t2" ]
restored=$?
[ "$changed" = 0 ] && [ "$restored" = 0 ]
record $? "a lockfile change is noticed: Yarn judges the changed file, and restoring it installs again"

sleep 1
touch_pins
build && t4=$(layout_time) && [ "$t4" != "$t3" ]
record $? "a pin-only change installs again"

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "1.0.0"'
lock && pin && build && [ "$(cat "$(store right-npm-1.0.0)/index.js")" = "module.exports = 'right 1';" ]
first=$?
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin && build && [ "$(cat "$(store right-npm-2.0.0)/index.js")" = "module.exports = 'right 2';" ]
second=$?
[ "$first" = 0 ] && [ "$second" = 0 ]
record $? "Lockfile changed: the next build installs the new version"

echo
echo "# architectures"

architectures '{"os": ["linux", "darwin"], "cpu": ["x64", "arm64"]}'
build
missing=$?
for t in tool-linux-x64 tool-linux-arm64 tool-darwin-x64 tool-darwin-arm64; do
  [ -f "$(store "$t-npm")/binary.txt" ] || missing=1
done
[ "$missing" = 0 ]
record $? "Named architectures: two systems and two CPUs install all four combinations"
architectures "{}"

consumer_finish
