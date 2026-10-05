#!/usr/bin/env bash
# What only a fresh consumer can show about yarn.install: fetching, pinning,
# refetching, and isolation from the host. Each scenario of the install spec
# that names this script is a case here.
#
# It builds one throwaway consumer module that depends on this checkout, and a
# local registry (fixture_registry.js) that serves small fixture packages, so
# nothing depends on a public registry. Every case runs in a hostile host: the
# Bazel client's HOME, the directory above the output root and the output root
# itself each hold a .yarnrc.yml pointing the registry at a closed port, and a
# file under the name the install's own configuration once had, which also
# loads a marker plugin. An install that read any of them could not fetch, or
# would leave the marker.
#
# The executables it puts in the host's way come from tools/ci/fixtures/, as
# copies; nothing here writes a script.
#
# Usage: tools/ci/install_scenarios.sh
set -uo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
work=$(mktemp -d)
ws="$work/ws"
failures=0
cases=0
pids=()

cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done
  (cd "$ws" 2>/dev/null && bazel --output_user_root="$work/obase" shutdown >/dev/null 2>&1)
  chmod -R u+w "$work" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

die() {
  echo >&2 "install_scenarios.sh: $*"
  exit 2
}

record() {
  local ok=$1 what=$2
  cases=$((cases + 1))
  if [ "$ok" = 0 ]; then
    printf 'ok    %s\n' "$what"
  else
    printf 'FAIL  %s\n' "$what"
    # The whole log: the temporary directory holding it goes at exit.
    [ -f "$work/build.log" ] && sed 's/^/        /' "$work/build.log"
    [ -f "$work/build.err" ] && sed 's/^/        /' "$work/build.err"
    failures=$((failures + 1))
  fi
  # Each case starts with no output of its own, so that a failure never shows
  # another case's.
  rm -f "$work/build.log" "$work/build.err"
}

# --- the hostile host -------------------------------------------------------

fixtures="$repo/tools/ci/fixtures"
mkdir -p "$work/home" "$work/obase" "$work/ancestor" "$ws" || die "mkdir failed"
cp "$fixtures/marker_plugin.cjs" "$work/ancestor/" || die "copying the marker plugin failed"
for dir in "$work/home" "$work" "$work/obase"; do
  printf 'npmRegistryServer: "http://127.0.0.1:9"\n' >"$dir/.yarnrc.yml" || die "writing $dir/.yarnrc.yml failed"
  printf 'npmRegistryServer: "http://127.0.0.1:9"\nplugins:\n  - path: %s\n' "$work/ancestor/marker_plugin.cjs" \
    >"$dir/.rules-yarn-install.yml" || die "writing $dir/.rules-yarn-install.yml failed"
done
# A host Yarn's global folder (folderUtils.getDefaultGlobalFolder), with
# something in it, so that a write there shows as a change.
mkdir -p "$work/home/.yarn/berry/cache" && printf 'host\n' >"$work/home/.yarn/berry/cache/seed" || die "seeding the host's global folder failed"

# Yarn takes its global folder from XDG_DATA_HOME when that is set
# (folderUtils.getDefaultGlobalFolder), and its settings from YARN_*
# variables; `bazel run` hands the client's environment to the target. So none
# of the host's reach the Yarn the cases run directly: its home is the one
# above, and nothing else.
unset XDG_DATA_HOME
for variable in $(compgen -e | grep '^YARN_'); do unset "$variable"; done

b() {
  (cd "$ws" && HOME="$work/home" bazel --output_user_root="$work/obase" "$@")
}

# --- the consumer -------------------------------------------------------------

cp "$repo/.bazelversion" "$ws/" || die "copying .bazelversion failed"
printf 'common --lockfile_mode=off\n' >"$ws/.bazelrc"
: >"$ws/pins.json"
: >"$ws/yarn.lock"

module() {
  cat >"$ws/MODULE.bazel" <<EOF
bazel_dep(name = "rules_yarn")
bazel_dep(name = "rules_nodejs", version = "6.7.5")

local_path_override(
    module_name = "rules_yarn",
    path = "$repo",
)

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "24.21.0")
use_repo(node, "nodejs")

yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
yarn.install(
    name = "npm",
    lockfile = "//:yarn.lock",
    package_json = "//:package.json",
    pins = "//:pins.json",
    yarnrc = "//:.yarnrc.yml",
    supported_architectures = $1,
)
use_repo(yarn, "npm", "yarn")
EOF
}
module "{}"
cat >"$ws/BUILD.bazel" <<'EOF'
load("@rules_yarn//yarn:defs.bzl", "yarn_binary")

exports_files([
    ".yarnrc.yml",
    "package.json",
    "pins.json",
    "yarn.lock",
])

yarn_binary(
    name = "yarn",
    yarn = "@yarn",
)
EOF

b build @nodejs//:node_bin >/dev/null 2>&1 || die "cannot build the Bazel-managed Node.js"
# The output base keeps a fetched repository; the execution root keeps only what
# the last build used.
node="$(b info output_base 2>/dev/null)/$(b cquery --output=files @nodejs//:node_bin 2>/dev/null | head -1)"
[ -x "$node" ] || die "cannot find the Bazel-managed Node.js"

start_registry() {
  local state=$1
  "$node" "$repo/tools/ci/fixture_registry.js" "$state" &
  pids+=($!)
  for _ in $(seq 1 100); do
    [ -s "$state/port" ] && return 0
    sleep 0.1
  done
  die "the fixture registry did not start"
}
start_registry "$work/registry"
port=$(cat "$work/registry/port")

yarnrc() {
  printf 'npmRegistryServer: "http://127.0.0.1:%s"\nunsafeHttpWhitelist: ["127.0.0.1"]\n%s' "$port" "${1:-}" >"$ws/.yarnrc.yml"
}
yarnrc

project() {
  printf '{\n  "name": "scenario",\n  "packageManager": "yarn@4.18.0",\n  "dependencies": {%s}\n}\n' "$1" >"$ws/package.json"
}

lock() { b run //:yarn -- install --mode=update-lockfile >"$work/lock.log" 2>&1; }
pin() { b run @npm//:pin >"$work/pin.log" 2>&1; }
build() { b build @npm//:node_modules >"$work/build.log" 2>&1; }
built() { echo "$(b info bazel-bin 2>/dev/null)/external/rules_yarn++yarn+npm/node_modules"; }
layout_time() { "$node" -p 'require("fs").statSync(process.argv[1]).mtimeMs' "$(b info output_base 2>/dev/null)/external/rules_yarn++yarn+npm/layout.json" 2>/dev/null; }
store() { ls -d "$(built)"/.store/"$1"*/package 2>/dev/null | head -1; }
log_has() { grep -qF -- "$1" "$work/build.log"; }
# Rewrites a file through Node, so that the edit is the same on every host.
edit() { "$node" -e "const fs = require('fs'); const f = process.argv[1]; fs.writeFileSync(f, (${2})(fs.readFileSync(f, 'utf8')));" "$1" || die "editing $1 failed"; }
# Yarn's immutable check compares the lockfile's text, so no edit to it leaves
# an install valid; the pin file can be re-indented without changing what it
# says, which makes the install repository fetch again.
touch_pins() { edit "$ws/pins.json" "(s) => JSON.stringify(JSON.parse(s), null, s.startsWith('{\\n   \"') ? 2 : 3) + '\\n'"; }

# --- scenarios ------------------------------------------------------------------

echo "# pinning"

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0"'
lock || die "locking the project failed: $(tail -5 "$work/lock.log")"

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

module '{"os": ["linux", "darwin"], "cpu": ["x64", "arm64"]}'
build
missing=$?
for t in tool-linux-x64 tool-linux-arm64 tool-darwin-x64 tool-darwin-arm64; do
  [ -f "$(store "$t-npm")/binary.txt" ] || missing=1
done
[ "$missing" = 0 ]
record $? "Named architectures: two systems and two CPUs install all four combinations"
module "{}"

echo
echo "# building packages from their tarballs"

# How the install recorded each package: "tarball", "archive", or nothing.
source_of() { "$node" -e '
const layout = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const p = layout.packages.find((x) => x.path.startsWith(`node_modules/.store/${process.argv[2]}-npm-`));
console.log(p ? (p.tarball ? "tarball" : "archive") : "");' "$(b info output_base 2>/dev/null)/external/rules_yarn++yarn+npm/layout.json" "$1"; }
installed_files() { (cd "$(store "$1-npm")" && find . | LC_ALL=C sort | tr '\n' ' '); }

build
plain=$?
[ "$plain" = 0 ] && [ "$(source_of left)" = tarball ] && [ "$(source_of right)" = tarball ] && [ "$(source_of @fx-scoped)" = tarball ]
record $? "Package built from its tarball: plain packages are extracted at build time, and the install keeps no archive of them"

# On a filesystem that folds case — macOS's APFS by default — Yarn itself
# cannot lay out a package holding both README and readme (its link step fails
# with EEXIST), so that tarball is tried only where the filesystem keeps case
# apart.
printf 'x' >"$work/case-probe"
if [ -e "$work/CASE-PROBE" ]; then case_shape=; else case_shape=', "shape-case": "1.0.0"'; fi
case_tree_ok() {
  [ -z "$case_shape" ] || { [ "$(source_of shape-case)" = archive ] \
    && [ "$(cat "$(store shape-case-npm)/README")" = "upper" ] && [ "$(cat "$(store shape-case-npm)/readme")" = "lower" ]; }
}
shapes='"shape-dirmode": "1.0.0", "shape-mode0": "1.0.0", "shape-hardlink": "1.0.0", "shape-contiguous": "1.0.0", "shape-absolute": "1.0.0", "shape-dotslash": "1.0.0", "shape-dotdot": "1.0.0", "shape-fifo": "1.0.0"'"$case_shape"
project "\"left\": \"1.0.0\", \"@fx/scoped\": \"1.0.0\", \"tool\": \"1.0.0\", \"right\": \"2.0.0\", $shapes"
lock && pin || die "locking and pinning the tarball shapes failed: $(tail -20 "$work/pin.log")"
build
shaped=$?
{
  for shape in dirmode mode0; do echo "shape-$shape $(source_of "shape-$shape")"; done
  for shape in hardlink contiguous absolute dotslash dotdot fifo; do echo "shape-$shape $(source_of "shape-$shape")"; done
  echo "dirmode files: $(installed_files shape-dirmode)"
  echo "hardlink files: $(installed_files shape-hardlink)"
  [ -z "$case_shape" ] || echo "case files: $(installed_files shape-case)"
} >"$work/build.err"
expected_sources="shape-dirmode tarball
shape-mode0 tarball
shape-hardlink archive
shape-contiguous archive
shape-absolute archive
shape-dotslash archive
shape-dotdot archive
shape-fifo archive"
[ "$shaped" = 0 ] && [ "$(head -8 "$work/build.err")" = "$expected_sources" ] \
  && [ "$(cat "$(store shape-dirmode-npm)/lib/x.js")" = "module.exports = 'x';" ] \
  && [ "$(cat "$(store shape-mode0-npm)/secret.js")" = "module.exports = 's';" ] \
  && [ ! -e "$(store shape-hardlink-npm)/again.js" ] && [ ! -e "$(store shape-contiguous-npm)/contiguous.js" ] \
  && [ ! -e "$(store shape-fifo-npm)/pipe" ] && [ -f "$(store shape-dotslash-npm)/index.js" ] \
  && case_tree_ok
record $? "Tarballs bsdtar and Yarn extract differently: each installs Yarn's tree, from its tarball when normalising makes them equal, from an archive otherwise"
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin || die "locking and pinning without the tarball shapes failed: $(tail -20 "$work/pin.log")"

echo
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
yarnrc
touch_pins

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "linky": "1.0.0"'
! build && log_has "lockfile would have to be modified"
record $? "Lockfile out of date: fetching fails, saying the lockfile would have to change"

lock && pin || die "locking and pinning the project with linky failed: $(tail -20 "$work/pin.log")"
! build && log_has "linky" && log_has "alias.js is a link"
record $? "Link inside a package: fetching fails and names the package and the link"
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin && build || die "restoring the project failed: $(tail -20 "$work/build.log")"

echo
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

# Bazelisk keeps the Bazel binaries it downloads under HOME/.cache/bazelisk;
# nothing else in the home may change, in what it holds or in its metadata.
digest() { "$node" "$fixtures/tree_digest.js" "$work/home" .cache/bazelisk; }
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
mkdir -p "$work/project-plugin" && cp "$fixtures/marker_plugin.cjs" "$work/project-plugin/" || die "copying the marker plugin failed"
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

[ ! -e "$work/ancestor/plugin-loaded" ]
record $? "Configuration above the project under the install's former file name: no install so far loaded its plugin"

echo
echo "# repairing the pin file"

cp "$ws/pins.json" "$work/pins.good"
printf '{' >"$ws/pins.json"
! build && log_has "the pin file cannot be read as JSON" && pin && build
record $? "Malformed pin file: the build says so, and the pin target, still available, repairs it"
"$node" -e 'const [a, b] = process.argv.slice(1).map((f) => JSON.parse(require("fs").readFileSync(f, "utf8"))); process.exit(JSON.stringify(a) === JSON.stringify(b) ? 0 : 1)' "$ws/pins.json" "$work/pins.good"
record $? "the repaired pin file says what it said before it was broken"

rm "$ws/pins.json"
! build && log_has "the pin file does not exist" && pin && build
record $? "Missing pin file: the build says so, and the pin target, still available, writes it"

echo
echo "# Bazel's downloader"

b clean --expunge >"$work/clean.log" 2>&1 || die "bazel clean --expunge failed: $(tail -5 "$work/clean.log")"
printf 'block 127.0.0.1\n' >"$work/downloader.cfg"
before=$(wc -l <"$work/registry/requests")
b build @npm//:node_modules --downloader_config="$work/downloader.cfg" >"$work/build.log" 2>&1 \
  && [ "$(wc -l <"$work/registry/requests")" = "$before" ]
record $? "Cold fetch from the repository cache: with the registry blocked, a fresh output base installs"

# The token tools/ci/fixtures/credential_helper.sh answers with.
printf 'secret-token' >"$work/registry/require-auth"
b clean --expunge >"$work/clean.log" 2>&1 || die "bazel clean --expunge failed: $(tail -5 "$work/clean.log")"
! b build @npm//:node_modules --repository_cache="$work/cold-cache" >"$work/build.log" 2>&1
without=$?
b clean --expunge >"$work/clean.log" 2>&1 || die "bazel clean --expunge failed: $(tail -5 "$work/clean.log")"
b build @npm//:node_modules --repository_cache="$work/cold-cache-2" --credential_helper=127.0.0.1="$fixtures/credential_helper.sh" >"$work/build.log" 2>&1
with=$?
[ "$without" = 0 ] && [ "$with" = 0 ]
record $? "Credentials from a credential helper: fetching fails without the helper and succeeds with it"
rm -f "$work/registry/require-auth"

echo
echo "# the measurements design.md relies on"

# Two packages that link to each other, used from a sandboxed action: each
# store package's own node_modules holds a link to the other, and a file with a
# colon in its name survives.
project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0", "cyc-a": "1.0.0"'
lock && pin || die "locking and pinning the project with cyc-a failed: $(tail -20 "$work/pin.log")"
cat >>"$ws/BUILD.bazel" <<'EOF'

genrule(
    name = "cycle",
    srcs = ["@npm//:node_modules"],
    outs = ["cycle.txt"],
    cmd = "$(execpath @nodejs//:node_bin) -e '" +
          "const p = require(\"path\"), fs = require(\"fs\");" +
          "const root = p.dirname(process.argv.slice(1).find((f) => f.endsWith(\"/node_modules/cyc-a\")));" +
          "const a = require(p.resolve(root, \"cyc-a\"));" +
          "const b = require(require.resolve(\"cyc-b\", {paths: [require.resolve(p.resolve(root, \"cyc-a\"))]}));" +
          "const link = (from, to) => fs.readlinkSync(process.argv.slice(1).find((f) => f.includes(\"/.store/\" + from + \"-npm-\") && f.endsWith(\"/node_modules/\" + to)));" +
          "const back = link(\"cyc-a\", \"cyc-b\").includes(\"/cyc-b-npm-\") && link(\"cyc-b\", \"cyc-a\").includes(\"/cyc-a-npm-\");" +
          "fs.writeFileSync(process.argv[process.argv.length - 1], [a.other(), b.other(), require(p.resolve(root, \"cyc-a/col:on.js\")), back].join(\" \"));" +
          "' $(execpaths @npm//:node_modules) $@",
    tools = ["@nodejs//:node_bin"],
)
EOF
b build //:cycle --spawn_strategy=sandboxed >"$work/build.log" 2>&1
cycled=$?
links_ok=1
for pair in "cyc-a:cyc-b" "cyc-b:cyc-a"; do
  from=${pair%%:*} to=${pair##*:}
  target=$(readlink "$(ls -d "$(built)"/.store/"$from"-npm-*/node_modules/"$to")" 2>/dev/null)
  # The link is relative: ../../<slug>/package, inside .store.
  case "$target" in ../../"$to"-npm-*/package) ;; *) links_ok=0 ;; esac
done
[ "$cycled" = 0 ] && [ "$links_ok" = 1 ] && [ "$(cat "$(b info bazel-bin 2>/dev/null)/cycle.txt")" = "b a colon true" ]
record $? "A dependency cycle: each store package links to the other, and a sandboxed action reads both links, requires through them and reads col:on.js"

# Why packageExtensions is carried: the dependency an extension adds is
# recorded as a lockfile entry but not as a dependency of the extended
# package, and the immutable install refuses to lose the entry.
yarnrc 'packageExtensions:
  "left@*":
    dependencies:
      right: "1.0.0"
'
lock && pin || die "locking and pinning with a package extension failed: $(tail -20 "$work/pin.log")"
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
lock && pin || die "locking and pinning without the extension failed: $(tail -20 "$work/pin.log")"

# The cache key Yarn writes: the cache version, then c and the compression
# level, or nothing for mixed.
grep -q '^  cacheKey: 10c0$' "$ws/yarn.lock"
default_key=$?
yarnrc 'compressionLevel: mixed
'
lock || die "locking with compressionLevel mixed failed: $(tail -20 "$work/lock.log")"
grep -q '^  cacheKey: 10$' "$ws/yarn.lock"
mixed_key=$?
yarnrc
lock && pin || die "locking again without compressionLevel failed: $(tail -20 "$work/pin.log")"
printf 'cacheKey by default found: %s; with mixed found: %s\n' "$default_key" "$mixed_key" >"$work/build.log"
[ "$default_key" = 0 ] && [ "$mixed_key" = 0 ]
record $? "The cache key Yarn writes: 10c0 by default, 10 with compressionLevel mixed"

# Why the pin target checks every answer's name and version.
answer() { "$node" -e '
const lines = require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n");
const a = JSON.parse(lines[lines.length - 1]);
process.exit(a.name === process.argv[2] && a.version === process.argv[3] ? 0 : 1);' "$work/build.log" "$1" "$2"; }
info() { b run //:yarn -- npm info "$1" --fields name,version --json >"$work/build.log" 2>"$work/build.err"; }
info right@1.0.0 && answer right 1.0.0
exact=$?
info right@9.9.9 && answer right 2.0.0
missing=$?
info tagged@9.9.9 && answer tagged 1.0.0
tagged=$?
[ "$exact" = 0 ] && [ "$missing" = 0 ] && [ "$tagged" = 0 ]
record $? "yarn npm info answers an existing version with it, and one the registry does not have with the latest tag, not the highest version"

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
lock && pin || die "locking and pinning without the patch failed: $(tail -20 "$work/pin.log")"

# Why the project's file never reaches the install's Yarn: Yarn on its own
# loads the plugin the project's file names, and the one a configuration file
# above the project names under the rc name it is given; and a per-host
# networkSettings entry and a proxy in it stand against a global
# enableNetwork: false.
mkdir -p "$work/alone-plugin" && cp "$fixtures/marker_plugin.cjs" "$work/alone-plugin/" || die "copying the marker plugin failed"
yarnrc "plugins:
  - path: $work/alone-plugin/marker_plugin.cjs
"
b run //:yarn -- --version >"$work/build.log" 2>&1
loaded=$?
yarnrc
[ "$loaded" = 0 ] && [ -e "$work/alone-plugin/plugin-loaded" ]
record $? "Yarn run on its own loads the plugin the project's file names"

# This loads the plugin planted above the project, so it has to run after the
# case that requires no install to have loaded it.
[ ! -e "$work/ancestor/plugin-loaded" ] || die "the planted plugin had already been loaded"
YARN_RC_FILENAME=.rules-yarn-install.yml b run //:yarn -- --version >"$work/build.log" 2>&1
planted=$?
[ "$planted" = 0 ] && [ -e "$work/ancestor/plugin-loaded" ]
record $? "Yarn run on its own, given an rc name, loads the plugin a file of that name above the project names"

: >"$work/proxy/requests"
yarnrc "networkSettings:
  \"127.0.0.1\":
    enableNetwork: true
    httpProxy: \"http://127.0.0.1:$proxy\"
"
YARN_ENABLE_NETWORK=false b run //:yarn -- npm info left --fields version --json >"$work/build.log" 2>&1
yarnrc
[ -s "$work/proxy/requests" ]
record $? "Yarn run on its own with enableNetwork false still sends requests through a project's per-host networkSettings proxy"

# Why the architecture sets go in the install's own file.
# Yarn colours its output where it sees a CI, so the codes are taken out
# before the message is matched.
! YARN_SUPPORTED_ARCHITECTURES='{"os": ["linux"]}' b run //:yarn -- config get supportedArchitectures >"$work/build.err" 2>&1
refused=$?
"$node" -e 'const fs = require("fs"); fs.writeFileSync(process.argv[2], fs.readFileSync(process.argv[1], "utf8").replace(/\x1b\[[0-9;]*m/g, ""));' "$work/build.err" "$work/build.log"
[ "$refused" = 0 ] && log_has 'Object configuration settings "supportedArchitectures" must be an object in <environment>'
record $? "YARN_SUPPORTED_ARCHITECTURES cannot carry Yarn's architecture sets"

# Why the install gives Yarn private global and cache folders. Last, because
# it installs into the consumer's own directory.
b run //:yarn -- install >"$work/build.log" 2>&1 || die "a plain yarn install failed: $(tail -20 "$work/build.log")"
rm -rf "$ws/node_modules" "$ws/.pnp.cjs" "$ws/.pnp.loader.mjs" "$ws/.yarn/install-state.gz"
touch "$work/registry/proxy"
b run //:yarn -- install >"$work/build.log" 2>&1
offline=$?
rm -f "$work/registry/proxy"
# Yarn's own default links with Plug'n'Play, so the packages are in its
# global cache rather than in a node_modules.
[ "$offline" = 0 ] && ls "$work/home/.yarn/berry/cache"/left-npm-1.0.0-*.zip >/dev/null 2>&1
record $? "Yarn run on its own installs with the registry refusing everything, from the host's global cache"

# Why the pin file exists: the lockfile's checksum is the SHA-512 of Yarn's own
# cache archive, not of the registry's tarball, whose digest is the one pinned.
"$node" -e '
const fs = require("fs"), crypto = require("crypto");
const [lockFile, cacheDir, pinsFile, registry] = process.argv.slice(1);
const recorded = /"left@npm:1\.0\.0":[\s\S]*?checksum: 10c0\/([0-9a-f]{128})/.exec(fs.readFileSync(lockFile, "utf8"))[1];
const zip = fs.readdirSync(cacheDir).find((f) => /^left-npm-1\.0\.0-.*\.zip$/.test(f));
const zipDigest = crypto.createHash("sha512").update(fs.readFileSync(`${cacheDir}/${zip}`)).digest("hex");
const pinned = Buffer.from(JSON.parse(fs.readFileSync(pinsFile, "utf8")).packages["left@npm:1.0.0"].integrity.slice(7), "base64").toString("hex");
fetch(`${registry}/left/-/left-1.0.0.tgz`).then(async (r) => {
  if (!r.ok) { console.error(`the registry answered ${r.status}`); process.exit(1); }
  const tarballDigest = crypto.createHash("sha512").update(Buffer.from(await r.arrayBuffer())).digest("hex");
  const checks = {"the checksum is the digest of the archive": recorded === zipDigest, "the pin is the digest of the tarball": pinned === tarballDigest, "the checksum is not the digest of the tarball": recorded !== tarballDigest};
  for (const [what, ok] of Object.entries(checks)) if (!ok) console.error(`not so: ${what}`);
  process.exit(Object.values(checks).every(Boolean) ? 0 : 1);
});' "$ws/yarn.lock" "$work/home/.yarn/berry/cache" "$ws/pins.json" "http://127.0.0.1:$port" >"$work/build.log" 2>&1
record $? "The lockfile's checksum is the SHA-512 of Yarn's cache archive; the pin is the registry tarball's, which differs"

echo
echo "cases: $cases  failures: $failures"
[ "$failures" -eq 0 ]
