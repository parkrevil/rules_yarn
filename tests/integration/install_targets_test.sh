#!/usr/bin/env bash
# yarn.install's targets, one per direct dependency: building one builds only
# its package's directory, a package in a cycle brings the other, a scope's
# target holds its packages, and a sandboxed action can use a cycle's links.
#
# Usage: install_targets_test.sh <rlocation of the Bazel binary> <of Node.js>
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

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "@fx/other": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "cyc-a": "1.0.0"'
lock && pin || fail_with "$last_log" "locking and pinning the project failed"

echo "# a target per direct dependency"

# The store packages bazel-bin holds, by name, after the outputs were removed
# and one target was built.
built_alone() {
  b clean >"$work/clean.log" 2>&1 || return 1
  b build "$1" >"$work/build.log" 2>&1 || return 1
  ls "$(built)/.store" | sed 's/-npm-.*//' | LC_ALL=C sort | paste -sd, -
}
[ "$(built_alone @npm//:node_modules/left)" = "left" ]
record $? "Only the dependency's packages are built: building one direct dependency's target builds its package's directory and no other's"
[ "$(built_alone @npm//:node_modules/cyc-a)" = "cyc-a,cyc-b" ] \
  && [ "$(NODE_PATH="$(built)" "$node" -p 'const fs = require("fs"); const a = require("cyc-a"); a.other() + require(require.resolve("cyc-b", {paths: [fs.realpathSync(require.resolve("cyc-a"))]})).other()' 2>/dev/null)" = "ba" ]
record $? "Dependency cycle: the target of a package in a cycle holds both packages, and requiring it succeeds"
[ "$(built_alone @npm//:node_modules/@fx)" = "@fx-other,@fx-scoped" ]
record $? "Scope: the scope's target holds both of its packages"

echo
echo "# a cycle in a sandboxed action"

# Two packages that link to each other, used from a sandboxed action: each
# store package's own node_modules holds a link to the other, and a file with a
# colon in its name survives.
cp "$fixtures/cycle_probe.js" "$ws/" || die "copying the cycle probe failed"
cat >>"$ws/BUILD.bazel" <<'BUILD'

genrule(
    name = "cycle",
    srcs = [
        "cycle_probe.js",
        "@npm//:node_modules",
    ],
    outs = ["cycle.txt"],
    cmd = "$(execpath @nodejs//:node_bin) $(execpath cycle_probe.js) $(execpaths @npm//:node_modules) $@",
    tools = ["@nodejs//:node_bin"],
)
BUILD
# The host's own sandbox, named: `sandboxed` also names processwrapper-sandbox,
# which Bazel falls back to where the real one cannot run (SandboxModule.java
# at 9.2.0, lines 288-345), and would hide a sandbox that does not run nested.
case "$(uname)" in
  Linux) sandbox=linux-sandbox ;;
  Darwin) sandbox=darwin-sandbox ;;
  *) die "no sandbox is known for $(uname)" ;;
esac
b build //:cycle --spawn_strategy="$sandbox" >"$work/build.log" 2>&1
cycled=$?
links_ok=1
for pair in "cyc-a:cyc-b" "cyc-b:cyc-a"; do
  from=${pair%%:*} to=${pair##*:}
  target=$(readlink "$(ls -d "$(built)"/.store/"$from"-npm-*/node_modules/"$to")" 2>/dev/null)
  # The link is relative: ../../<slug>/package, inside .store.
  case "$target" in ../../"$to"-npm-*/package) ;; *) links_ok=0 ;; esac
done
[ "$cycled" = 0 ] && [ "$links_ok" = 1 ] && [ "$(cat "$bazel_bin/cycle.txt")" = "b a colon true" ]
record $? "A dependency cycle: each store package links to the other, and a sandboxed action reads both links, requires through them and reads col:on.js"

consumer_finish
