#!/usr/bin/env bash
# yarn.install and the host: host node, yarn and corepack go unused, the host
# user's home is left as it was, and the project's plugins and network
# settings do not reach the install.
#
# Usage: install_host_test.sh <rlocation of the Bazel binary> <of Node.js>
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

echo "# the host"

mkdir -p "$work/fakebin"
for tool in node yarn corepack; do cp "$fixtures/poison.sh" "$work/fakebin/$tool" || die "copying the poison failed"; done
touch_pins
# The poisoned PATH goes to the repository rules only: on some hosts the
# Bazel client itself is a Node.js script, which a poisoned node would stop
# before the install could show anything. The install's repository rule hands
# its driver no environment at all, so what this guards is the rule itself
# running a tool by name; a driver that ran `node` by name would get the
# system's default PATH rather than this one, and this case would not see it.
b build @npm//:node_modules --repo_env=PATH="$work/fakebin:$PATH" >"$work/build.log" 2>&1
record $? "No host installation: node, yarn and corepack on PATH fail, and installation succeeds"

# Nothing in the home may change, in what it holds or in its metadata.
digest() { "$node" "$fixtures/tree_digest.js" "$work/home"; }
before=$(digest)
touch_pins
build
status=$?
after=$(digest)
[ "$status" = 0 ] && [ -n "$before" ] && [ "$before" = "$after" ]
record $? "Host global folder: installation leaves the host user's home, its Yarn global folder included, as it was"

start_registry "$work/proxy"
touch "$work/proxy/proxy"
proxy=$(cat "$work/proxy/port")
mkdir -p "$work/project-plugin" && cp "$marker_plugin" "$work/project-plugin/" || die "copying the marker plugin failed"
yarnrc "plugins:
  - path: $work/project-plugin/marker_plugin.cjs
httpProxy: \"http://127.0.0.1:$proxy\"
httpsProxy: \"http://127.0.0.1:$proxy\"
networkSettings:
  \"evil.example\":
    enableNetwork: true
"
touch_pins
build && [ ! -e "$work/project-plugin/plugin-loaded" ] && [ ! -s "$work/proxy/requests" ]
record $? "Plugins and network settings in the project's configuration: the plugin is not loaded, the proxy sees nothing"
yarnrc

consumer_finish
