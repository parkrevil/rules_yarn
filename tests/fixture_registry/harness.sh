# What the tests that run Yarn against the fixture registry share: a scratch
# directory, a hostile host planted in it, the registry, the files a Yarn
# project is made of, and the case bookkeeping. tests/integration/consumer.sh
# builds the nested-Bazel consumer on it; tests/install/yarn_behavior_test.sh
# runs Yarn on its own on it.
#
# A test sources this after the runfiles library and calls
#
#   harness_setup <rlocation of Node.js>
#
# then its cases, each ending in `record $? "<what it shows>"`, and ends with
# harness_finish, whose status is the test's. A test that needs more cleaned up
# defines harness_before_cleanup. yarnrc and project write into the test's `$ws`
# and point at its `$port`, which the test sets.

# The cases test statuses themselves; a failing step must not end the test.
set +e

failures=0
cases=0
pids=()

die() {
  echo >&2 "${0##*/}: $*"
  exit 2
}
# Stops the test after a step it depends on failed, printing that step's whole
# log first.
fail_with() {
  cat >&2 "$1"
  die "$2"
}

record() {
  local ok=$1 what=$2
  cases=$((cases + 1))
  if [ "$ok" = 0 ]; then
    printf 'ok    %s\n' "$what"
  else
    printf 'FAIL  %s\n' "$what"
    [ -f "$work/build.log" ] && sed 's/^/        /' "$work/build.log"
    [ -f "$work/build.err" ] && sed 's/^/        /' "$work/build.err"
    failures=$((failures + 1))
  fi
  # Each case starts with no output of its own, so that a failure never shows
  # another case's.
  rm -f "$work/build.log" "$work/build.err"
}

harness_cleanup() {
  declare -F harness_before_cleanup >/dev/null && harness_before_cleanup
  # Written so, an empty array is not an unbound variable under bash 3.2's set -u.
  for pid in ${pids[@]+"${pids[@]}"}; do kill "$pid" 2>/dev/null; done
  chmod -R u+w "$work" 2>/dev/null
  rm -rf "$work"
}

harness_setup() {
  node=$(rlocation "$1")
  [ -x "$node" ] || die "cannot find Node.js $1"
  # The library's own data.
  registry=$(rlocation _main/tests/fixture_registry/fixture_registry.js)
  [ -f "$registry" ] || die "cannot find the fixture registry"
  marker_plugin=$(rlocation _main/tests/fixture_registry/fixtures/marker_plugin.cjs)
  [ -f "$marker_plugin" ] || die "cannot find the marker plugin"
  # Under /tmp, not the test's TEST_TMPDIR, which on Linux sits under the user's
  # own home, where a ~/.yarnrc.yml would reach Yarn run on its own (see
  # check_ancestors). linux-sandbox gives each test a /tmp of its own, and
  # darwin-sandbox lets a test write to /tmp. A no-sandbox test uses the host's
  # /tmp, which the EXIT trap cleans unless the test is killed outright.
  work=$(mktemp -d /tmp/rules_yarn_test.XXXXXX) || die "cannot make a scratch directory under /tmp"
  trap harness_cleanup EXIT
  mkdir -p "$work/tmp" "$work/home" "$work/ancestor" || die "mkdir $work failed"
}

# Yarn run on its own reads a .yarnrc.yml in every directory above its project,
# by the physical path it runs in. Only the planted ones may be there: a file
# above the scratch directory would reach the cases that run Yarn on its own,
# and they would measure the host's settings. This stops the test instead,
# naming the file. Run it before plant_host.
check_ancestors() {
  local dir name
  dir=$(cd "$1" && pwd -P) || die "cannot find $1"
  while [ "$dir" != / ]; do
    dir=$(dirname "$dir")
    for name in .yarnrc.yml .rules-yarn-install.yml; do
      [ ! -e "$dir/$name" ] || die "$dir/$name is above the test's scratch directory, where Yarn would read it; move it away to run this test"
    done
  done
}

# The hostile host. Each directory given gets a .yarnrc.yml pointing the
# registry at a closed port, and, under the name the install's own
# configuration once had, a file that also loads a marker plugin, which leaves
# $work/ancestor/plugin-loaded if Yarn loads it. The planted HOME's Yarn global
# folder (folderUtils.getDefaultGlobalFolder) gets something in it, so that a
# write there shows as a change.
plant_host() {
  cp "$marker_plugin" "$work/ancestor/" || die "copying the marker plugin failed"
  local dir
  for dir in "$@"; do
    mkdir -p "$dir" || die "mkdir $dir failed"
    printf 'npmRegistryServer: "http://127.0.0.1:9"\n' >"$dir/.yarnrc.yml" || die "writing $dir/.yarnrc.yml failed"
    printf 'npmRegistryServer: "http://127.0.0.1:9"\nplugins:\n  - path: %s\n' "$work/ancestor/marker_plugin.cjs" \
      >"$dir/.rules-yarn-install.yml" || die "writing $dir/.rules-yarn-install.yml failed"
  done
  mkdir -p "$work/home/.yarn/berry/cache" && printf 'host\n' >"$work/home/.yarn/berry/cache/seed" || die "seeding the host's global folder failed"
}

# Starts a registry whose state directory is $1; see fixture_registry.js for
# the control files it reads there.
start_registry() {
  local state=$1
  mkdir -p "$state" || die "mkdir $state failed"
  "$node" "$registry" "$state" &
  pids+=($!)
  for _ in $(seq 1 100); do
    [ -s "$state/port" ] && return 0
    sleep 0.1
  done
  die "the fixture registry did not start"
}

# The project's .yarnrc.yml, pointing at the registry on $port, with any extra
# settings given; and its package.json, with the dependencies given.
yarnrc() {
  printf 'npmRegistryServer: "http://127.0.0.1:%s"\nunsafeHttpWhitelist: ["127.0.0.1"]\n%s' "$port" "${1:-}" >"$ws/.yarnrc.yml"
}
project() {
  printf '{\n  "name": "scenario",\n  "packageManager": "yarn@4.18.0",\n  "dependencies": {%s}\n}\n' "$1" >"$ws/package.json"
}

log_has() { grep -qF -- "$1" "$work/build.log"; }
# Rewrites a file through Node, so that the edit is the same on every host.
edit() { "$node" -e "const fs = require('fs'); const f = process.argv[1]; fs.writeFileSync(f, (${2})(fs.readFileSync(f, 'utf8')));" "$1" || die "editing $1 failed"; }

# The summary; its status is the test's.
harness_finish() {
  echo
  echo "cases: $cases  failures: $failures"
  [ "$failures" -eq 0 ]
}
