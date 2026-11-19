#!/usr/bin/env bash
# What Yarn does on its own, which yarn.install's design rests on, measured with
# the pinned Yarn against the fixture registry on a hostile host. Each case
# says which decision it backs. Yarn runs as `bazel run //:yarn` starts it in a
# consumer: through a yarn_binary launcher, in the project.
#
# Usage: yarn_behavior_test.sh <rlocation of a yarn_binary launcher> <of Node.js>

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
source "$(rlocation _main/tests/fixture_registry/harness.sh)" || { echo >&2 "cannot find harness.sh"; exit 2; }
yarn=$(rlocation "$1")
[ -x "$yarn" ] || die "cannot find the Yarn launcher $1"
harness_setup "$2"

ws="$work/project"
mkdir -p "$ws" || die "mkdir $ws failed"
check_ancestors "$ws"
plant_host "$work/home" "$work"
start_registry "$work/registry"
port=$(cat "$work/registry/port")
# A second registry that answers as a refusing proxy, recording every request.
start_registry "$work/proxy"
touch "$work/proxy/proxy"
proxy=$(cat "$work/proxy/port")

# Yarn in the project, with the planted HOME, and with none of the test's
# environment but what the launcher needs to find its runfiles.
y() { (cd "$ws" && env -i PATH="$PATH" HOME="$work/home" TMPDIR="$work/tmp" RUNFILES_DIR="$RUNFILES_DIR" "$@"); }
lock() { y "$yarn" install --mode=update-lockfile >"$work/lock.log" 2>&1; }

yarnrc
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock || fail_with "$work/lock.log" "locking the project failed"

echo "# the measurements design.md relies on"

# The cache key Yarn writes: the cache version, then c and the compression
# level, or nothing for mixed.
grep -q '^  cacheKey: 10c0$' "$ws/yarn.lock"
default_key=$?
yarnrc 'compressionLevel: mixed
'
lock || fail_with "$work/lock.log" "locking with compressionLevel mixed failed"
grep -q '^  cacheKey: 10$' "$ws/yarn.lock"
mixed_key=$?
yarnrc
lock || fail_with "$work/lock.log" "locking again without compressionLevel failed"
printf 'cacheKey by default found: %s; with mixed found: %s\n' "$default_key" "$mixed_key" >"$work/build.log"
[ "$default_key" = 0 ] && [ "$mixed_key" = 0 ]
record $? "The cache key Yarn writes: 10c0 by default, 10 with compressionLevel mixed"


# Why the pin target checks every answer's name and version.
answer() { "$node" -e '
const lines = require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n");
const a = JSON.parse(lines[lines.length - 1]);
process.exit(a.name === process.argv[2] && a.version === process.argv[3] ? 0 : 1);' "$work/build.log" "$1" "$2"; }
info() { y "$yarn" npm info "$1" --fields name,version --json >"$work/build.log" 2>"$work/build.err"; }
info right@1.0.0 && answer right 1.0.0
exact=$?
info right@9.9.9 && answer right 2.0.0
missing=$?
info tagged@9.9.9 && answer tagged 1.0.0
tagged=$?
[ "$exact" = 0 ] && [ "$missing" = 0 ] && [ "$tagged" = 0 ]
record $? "yarn npm info answers an existing version with it, and one the registry does not have with the latest tag, not the highest version"

# Why the project's file never reaches the install's Yarn: Yarn on its own
# loads the plugin the project's file names, and the one a configuration file
# above the project names under the rc name it is given; and a per-host
# networkSettings entry and a proxy in it stand against a global
# enableNetwork: false.
mkdir -p "$work/alone-plugin" && cp "$marker_plugin" "$work/alone-plugin/" || die "copying the marker plugin failed"
yarnrc "plugins:
  - path: $work/alone-plugin/marker_plugin.cjs
"
y "$yarn" --version >"$work/build.log" 2>&1
loaded=$?
yarnrc
[ "$loaded" = 0 ] && [ -e "$work/alone-plugin/plugin-loaded" ]
record $? "Yarn run on its own loads the plugin the project's file names"

# This loads the plugin planted above the project, so it has to run after the
# case that requires no install to have loaded it.
[ ! -e "$work/ancestor/plugin-loaded" ] || die "the planted plugin had already been loaded"
y YARN_RC_FILENAME=.rules-yarn-install.yml "$yarn" --version >"$work/build.log" 2>&1
planted=$?
[ "$planted" = 0 ] && [ -e "$work/ancestor/plugin-loaded" ]
record $? "Yarn run on its own, given an rc name, loads the plugin a file of that name above the project names"

: >"$work/proxy/requests"
yarnrc "networkSettings:
  \"127.0.0.1\":
    enableNetwork: true
    httpProxy: \"http://127.0.0.1:$proxy\"
"
y YARN_ENABLE_NETWORK=false "$yarn" npm info left --fields version --json >"$work/build.log" 2>&1
yarnrc
[ -s "$work/proxy/requests" ]
record $? "Yarn run on its own with enableNetwork false still sends requests through a project's per-host networkSettings proxy"

# Why the architecture sets go in the install's own file.
# Yarn colours its output where it sees a CI, so the codes are taken out
# before the message is matched, whatever the environment.
! y YARN_SUPPORTED_ARCHITECTURES='{"os": ["linux"]}' "$yarn" config get supportedArchitectures >"$work/build.err" 2>&1
refused=$?
"$node" -e 'const fs = require("fs"); fs.writeFileSync(process.argv[2], fs.readFileSync(process.argv[1], "utf8").replace(/\x1b\[[0-9;]*m/g, ""));' "$work/build.err" "$work/build.log"
[ "$refused" = 0 ] && log_has 'Object configuration settings "supportedArchitectures" must be an object in <environment>'
record $? "YARN_SUPPORTED_ARCHITECTURES cannot carry Yarn's architecture sets"

# Why the install gives Yarn private global and cache folders. Last, because
# it installs into the project itself.
y "$yarn" install >"$work/build.log" 2>&1 || fail_with "$work/build.log" "a plain yarn install failed"
rm -rf "$ws/node_modules" "$ws/.pnp.cjs" "$ws/.pnp.loader.mjs" "$ws/.yarn/install-state.gz"
touch "$work/registry/proxy"
y "$yarn" install >"$work/build.log" 2>&1
offline=$?
rm -f "$work/registry/proxy"
# Yarn's own default links with Plug'n'Play, so the packages are in its
# global cache rather than in a node_modules.
[ "$offline" = 0 ] && ls "$work/home/.yarn/berry/cache"/left-npm-1.0.0-*.zip >/dev/null 2>&1
record $? "Yarn run on its own installs with the registry refusing everything, from the host's global cache"

harness_finish
