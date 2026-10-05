#!/usr/bin/env bash
# Checks the tree yarn.install produced for this project, by running the
# Bazel-managed Node.js against it from this test's runfiles.

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

node="$(rlocation "$1")"
shift
[[ -x "$node" ]] || fail "cannot find Node.js"
# The installed tree's files are passed one by one; its root is the directory
# holding the repository's own is-number link.
nm=
for f in "$@"; do
  # The repository's own node_modules, not a workspace's.
  [[ "$f" =~ ^[^/]+/node_modules/is-number$ ]] && nm="$(dirname "$(rlocation "$f")")"
done
[[ -n "$nm" && -d "$nm" ]] || fail "cannot find the installed node_modules"
root="$(dirname "$nm")"
js() { NODE_PATH="$nm" "$node" -e "$1"; }

# Installed version: the lockfile's.
[[ "$(js 'console.log(require("is-number/package.json").version)')" == "7.0.0" ]] || fail "is-number is not 7.0.0"

# Patch file: the project's patch is applied.
[[ "$(js 'console.log(require("is-number").patchedByRulesYarnTest === true)')" == "true" ]] || fail "the project's patch to is-number is not applied"

# Built-in patch: Yarn's TypeScript compatibility patch is applied.
grep -q pnpapi "$nm/typescript/lib/typescript.js" || fail "typescript is not the patched package the lockfile records"

# Executables: .bin/tsc runs typescript's tsc.
[[ "$(PATH="$(dirname "$node"):/usr/bin:/bin" "$nm/.bin/tsc" --version)" == "Version 5.6.3" ]] || fail ".bin/tsc does not run TypeScript 5.6.3"

# Build forced by metadata: esbuild is marked built, but its postinstall, which
# would replace bin/esbuild with the native binary, did not run.
[[ "$(head -c 19 "$nm/esbuild/bin/esbuild")" == "#!/usr/bin/env node" ]] || fail "esbuild's postinstall ran"

# Settings that shape the install: packageExtensions gave is-number js-tokens.
js 'const fs = require("fs"); require(require.resolve("js-tokens", {paths: [fs.realpathSync(require.resolve("is-number"))]}))' \
  || fail "is-number cannot require the js-tokens packageExtensions adds"

# Shared package: is-number and loose-envify resolve js-tokens to one instance.
shared="$(js '
const fs = require("fs");
const from = (p) => fs.realpathSync(require.resolve("js-tokens", {paths: [p]}));
const viaIsNumber = from(fs.realpathSync(require.resolve("is-number")));
const react = fs.realpathSync(require.resolve("react", {paths: ["'"$root"'/packages/app"]}));
const looseEnvify = fs.realpathSync(require.resolve("loose-envify", {paths: [react]}));
console.log(viaIsNumber === from(looseEnvify));
')" || fail "cannot resolve js-tokens through is-number and loose-envify"
[[ "$shared" == "true" ]] || fail "is-number and loose-envify resolve js-tokens to different instances"

# Workspace dependencies: each workspace's own dependencies are linked in that
# workspace's node_modules — not merely found further up — and the
# peer-dependency instance of react-dom sees the workspace's react.
lib_is_number="$("$node" -e '
const fs = require("fs"), path = require("path");
const link = path.join(process.argv[1], "node_modules", "is-number");
console.log(require(fs.realpathSync(link)).patchedByRulesYarnTest);
' "$root/packages/lib")" || fail "packages/lib/node_modules has no is-number"
[[ "$lib_is_number" == "true" ]] || fail "packages/lib's is-number is not the patched one"
peer="$("$node" -e '
const fs = require("fs");
const app = process.argv[1];
const react = fs.realpathSync(require.resolve("react", {paths: [app]}));
const dom = fs.realpathSync(require.resolve("react-dom", {paths: [app]}));
console.log(fs.realpathSync(require.resolve("react", {paths: [dom]})) === react);
' "$root/packages/app")" || fail "cannot resolve react through packages/app and react-dom"
[[ "$peer" == "true" ]] || fail "react-dom does not see the react packages/app depends on"

# Default architecture: the host's esbuild package holds its binary; another
# platform's holds only the stub package.json Yarn's pnpm linker writes for a
# package it leaves out.
"$node" -e '
const fs = require("fs"), path = require("path");
const store = path.join(process.argv[1], ".store");
const host = `@esbuild-${process.platform}-${process.arch}-npm-0.25.0-`;
const other = process.platform === "linux" ? "@esbuild-win32-x64-npm-0.25.0-" : "@esbuild-linux-x64-npm-0.25.0-";
const dir = (prefix) => path.join(store, fs.readdirSync(store).find((d) => d.startsWith(prefix)), "package");
if (!fs.readdirSync(dir(host)).includes("bin")) { console.error("the host package has no binary"); process.exit(1); }
if (JSON.stringify(fs.readdirSync(dir(other))) !== JSON.stringify(["package.json"])) { console.error("another platform package holds more than a stub"); process.exit(1); }
const stub = JSON.parse(fs.readFileSync(path.join(dir(other), "package.json"), "utf8"));
const expected = {name: process.platform === "linux" ? "@esbuild/win32-x64" : "@esbuild/linux-x64", mocked: true};
if (JSON.stringify(stub) !== JSON.stringify(expected)) { console.error(`the stub is ${JSON.stringify(stub)}, not ${JSON.stringify(expected)}`); process.exit(1); }
' "$nm" || fail "the platform packages are not the host's"

echo "PASS"
