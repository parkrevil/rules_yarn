#!/usr/bin/env bash
# yarn.install building packages from their tarballs: plain ones at build time,
# and every tarball shape bsdtar and Yarn extract differently from an archive
# that holds Yarn's tree.
#
# Usage: install_tarballs_test.sh <rlocation of the Bazel binary> <of Node.js>
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

echo "# building packages from their tarballs"

# How the install recorded each package: "tarball", "archive", or nothing.
source_of() { "$node" -e '
const layout = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const p = layout.packages.find((x) => x.path.startsWith(`node_modules/.store/${process.argv[2]}-npm-`));
console.log(p ? (p.tarball ? "tarball" : "archive") : "");' "$output_base/external/$npm_repo/layout.json" "$1"; }
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
lock && pin || fail_with "$last_log" "locking and pinning the tarball shapes failed"
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

consumer_finish
