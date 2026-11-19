#!/usr/bin/env bash
# What yarn.install refuses, and how it says so: a changed integrity or
# checksum, configuration Yarn cannot read, a lockfile out of date, a link
# inside a package, a lockfile that lost a package extension's entry, and a
# changed checksum on a patched entry.
#
# Usage: install_refusals_test.sh <rlocation of the Bazel binary> <of Node.js>
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
lock && pin || fail_with "$last_log" "locking and pinning the project failed"

echo "# refusals"

cp "$ws/pins.json" "$work/pins.good"
# A digest no content has, so that the repository cache cannot answer for it
# and Bazel has to download the tarball and check it.
edit "$ws/pins.json" "(s) => { const p = JSON.parse(s); p.packages['left@npm:1.0.0'].integrity = 'sha512-' + Buffer.alloc(64, 7).toString('base64'); return JSON.stringify(p); }"
! build && log_has "left-1.0.0.tgz" && log_has "Checksum"
record $? "Integrity mismatch: fetching fails and names the package"
cp "$work/pins.good" "$ws/pins.json"

cp "$ws/yarn.lock" "$work/lock.good"
edit "$ws/yarn.lock" "(s) => s.replace(/(\"left@npm:1.0.0\":[\\s\\S]*?checksum: 10c0\\/)(.)/, (m, a, c) => a + (c === '0' ? '1' : '0'))"
! build && log_has "YN0018" && log_has "left@npm:1.0.0"
record $? "Checksum mismatch: fetching fails and names the package"
cp "$work/lock.good" "$ws/yarn.lock"

# A whole-document marker whose value Yarn cannot read: Yarn fails on the
# file, so the install refuses it rather than installing without its settings.
printf 'onConflict: reset\nvalue:\n' >"$ws/.yarnrc.yml"
touch_pins
! build && log_has "Yarn does not accept the settings this install carries from .yarnrc.yml"
record $? "Configuration Yarn cannot read: fetching fails, saying Yarn does not accept it"
# A failed install has no layout to name its dependencies' targets after.
! b build @npm//:node_modules/left >"$work/build.log" 2>&1 && log_has "no such target '@@$npm_repo//:node_modules/left'"
record $? "a failed install declares no dependency's target: Bazel reports no such target, and :node_modules says why"
yarnrc
touch_pins

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "linky": "1.0.0"'
! build && log_has "lockfile would have to be modified"
record $? "Lockfile out of date: fetching fails, saying the lockfile would have to change"

lock && pin || fail_with "$last_log" "locking and pinning the project with linky failed"
! build && log_has "linky" && log_has "alias.js is a link"
record $? "Link inside a package: fetching fails and names the package and the link"
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin && build || fail_with "$last_log" "restoring the project failed"

# Why packageExtensions is carried: the dependency an extension adds is
# recorded as a lockfile entry but not as a dependency of the extended
# package, and the immutable install refuses to lose the entry.
yarnrc 'packageExtensions:
  "left@*":
    dependencies:
      right: "1.0.0"
'
lock && pin || fail_with "$last_log" "locking and pinning with a package extension failed"
"$node" -e '
const lock = require("fs").readFileSync(process.argv[1], "utf8");
const left = /\n"left@npm:1\.0\.0":\n([\s\S]*?)\n\n/.exec(lock + "\n\n")[1];
const ok = lock.includes("\n\"right@npm:1.0.0\":") && !/right/.test(left);
if (!ok) console.error("yarn.lock does not record right@npm:1.0.0 as an entry apart from left");
process.exit(ok ? 0 : 1);' "$ws/yarn.lock" >"$work/build.err" 2>&1
recorded=$?
build
extended=$?
yarnrc
touch_pins
! build && log_has "YN0028"
dropped=$?
[ "$recorded" = 0 ] && [ "$extended" = 0 ] && [ "$dropped" = 0 ]
record $? "packageExtensions: the added dependency is an entry, not a dependency of left; installed with them, and without them the immutable install fails with YN0028"
lock && pin || fail_with "$last_log" "locking and pinning without the extension failed"

# A changed checksum on a patched entry is refused as one on a plain entry is.
mkdir -p "$ws/patches"
printf -- '--- a/index.js\n+++ b/index.js\n@@ -1 +1 @@\n-module.exports = %s;\n+module.exports = %s;\n' "'left'" "'patched'" >"$ws/patches/left.patch"
project '"left": "patch:left@npm%3A1.0.0#~/patches/left.patch", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "cyc-a": "1.0.0"'
patches_line='    patches = ["//:patches/left.patch"],\n'
edit "$ws/MODULE.bazel" "(s) => s.replace('    yarnrc = \"//:.yarnrc.yml\",\n', '    yarnrc = \"//:.yarnrc.yml\",\n$patches_line')"
grep -q 'patches = \["//:patches/left.patch"\]' "$ws/MODULE.bazel" || die "adding the patch to MODULE.bazel failed"
printf '\nexports_files(["patches/left.patch"])\n' >>"$ws/BUILD.bazel"
lock && pin && build && [ "$(cat "$(built)/left/index.js")" = "module.exports = 'patched';" ]
patched=$?
edit "$ws/yarn.lock" "(s) => s.replace(/(\"left@patch:[^\\n]*\":[\\s\\S]*?checksum: 10c0\\/)(.)/, (m, a, c) => a + (c === '0' ? '1' : '0'))"
! build && log_has "YN0018" && log_has "left@patch:"
refused=$?
[ "$patched" = 0 ] && [ "$refused" = 0 ]
record $? "Checksum mismatch on a patched entry: the patch applies, and a changed checksum for it is refused with YN0018"
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "cyc-a": "1.0.0"'
edit "$ws/MODULE.bazel" "(s) => s.replace('$patches_line', '')"
! grep -q 'patches = ' "$ws/MODULE.bazel" || die "removing the patch from MODULE.bazel failed"
lock && pin || fail_with "$last_log" "locking and pinning without the patch failed"

consumer_finish
