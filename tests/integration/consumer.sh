# What every test in tests/integration shares: a fresh consumer of this
# ruleset's yarn.install, built by a Bazel run inside the test, on the hostile
# host tests/fixture_registry/harness.sh plants, and the Bazel and Yarn steps
# the cases are made of.
#
# A runner sources this after the runfiles library, calls consumer_setup with
# its own arguments, runs its cases, and ends with consumer_finish, whose
# status is the test's:
#
#   consumer_setup <rlocation of the Bazel binary> <of Node.js> \
#     <of install_consumer/MODULE.bazel>
#
# The consumer is a copy, in the test's scratch directory, of the runfiles
# tree that holds both install_consumer/ and the ruleset's files, so its
# local_path_override (../../..) lands on the ruleset. The cases change the
# copy, never the runfiles, whose links lead into the source tree.
#
# The consumer's Bazel gets the planted HOME. That HOME, the directory above
# the output root, and the output root itself are the planted directories: an
# install that read any of their files could not fetch, or would load the
# marker plugin, which consumer_finish checks in every test.

# shellcheck disable=SC1090
source "$(rlocation _main/tests/fixture_registry/harness.sh)" || { echo >&2 "cannot find harness.sh"; exit 2; }

# The consumer's Bazel: in the consumer, with the planted HOME and an output
# root in the scratch directory, reading no rc file but the consumer's own, and
# with none of the test's environment, which a consumer would not have. Its
# server exits a minute after its last command, should a test die without
# shutting it down.
b() {
  (cd "$ws" && env -i PATH="$PATH" HOME="$work/home" TMPDIR="$work/tmp" \
    "$bazel" --nosystem_rc --nohome_rc --output_user_root="$work/obase" --max_idle_secs=60 "$@")
}

harness_before_cleanup() {
  [ -d "${ws:-}" ] && b shutdown >/dev/null 2>&1
}

# Each keeps its output in its own log and records which log that is, so when a
# chain of them stops, the log of the one that failed is the one printed.
last_log=
lock() { last_log="$work/lock.log"; b run //:yarn -- install --mode=update-lockfile >"$last_log" 2>&1; }
pin() { last_log="$work/pin.log"; b run @npm//:pin >"$last_log" 2>&1; }
build() { last_log="$work/build.log"; b build @npm//:node_modules >"$last_log" 2>&1; }
built() { echo "$bazel_bin/external/$npm_repo/node_modules"; }
layout_time() { "$node" -p 'require("fs").statSync(process.argv[1]).mtimeMs' "$output_base/external/$npm_repo/layout.json" 2>/dev/null; }
store() { ls -d "$(built)"/.store/"$1"*/package 2>/dev/null | head -1; }
# Yarn's immutable check compares the lockfile's text, so no edit to it leaves
# an install valid; the pin file can be re-indented without changing what it
# says, which makes the install repository fetch again.
touch_pins() { edit "$ws/pins.json" "(s) => JSON.stringify(JSON.parse(s), null, s.startsWith('{\\n   \"') ? 2 : 3) + '\\n'"; }
# Sets yarn.install's supported_architectures in the consumer's MODULE.bazel.
architectures() {
  edit "$ws/MODULE.bazel" "(s) => s.replace(/supported_architectures = .*,/, () => 'supported_architectures = $1,')"
  grep -qF "supported_architectures = $1," "$ws/MODULE.bazel" || die "setting supported_architectures to $1 failed"
}

consumer_setup() {
  bazel=$(rlocation "$1")
  [ -x "$bazel" ] || die "cannot find the Bazel binary $1"
  local consumer_module
  consumer_module=$(rlocation "$3")
  [ -f "$consumer_module" ] || die "cannot find the consumer $3"
  harness_setup "$2"

  # The runfiles tree's root: the consumer's MODULE.bazel is at
  # tests/integration/install_consumer/ under it.
  local root=${consumer_module%/tests/integration/install_consumer/MODULE.bazel}
  [ "$root" != "$consumer_module" ] || die "the consumer is not at tests/integration/install_consumer: $3"
  # Through a runfiles manifest the path would lead into the source tree, and
  # copying that would follow its bazel-* links.
  [ "${root##*/}" = _main ] || die "the consumer is not in a runfiles tree: $consumer_module"
  cp -RL "$root" "$work/src" || die "copying the consumer and the ruleset failed"
  ws="$work/src/tests/integration/install_consumer"
  fixtures="$work/src/tests/integration/fixtures"
  check_ancestors "$ws"
  plant_host "$work/home" "$work" "$work/obase"

  # Each command the setup depends on keeps its output in a log, which is printed
  # when the command fails, so a failure here says what Bazel said. Neither
  # value changes while the test runs, so each is asked for once.
  output_base=$(b info output_base 2>"$work/setup.log") || fail_with "$work/setup.log" "cannot find Bazel's output base"
  bazel_bin=$(b info bazel-bin 2>"$work/setup.log") || fail_with "$work/setup.log" "cannot find Bazel's bazel-bin"
  # The install repository's canonical name, under which Bazel reports its
  # targets and keeps its files. Its format is not an API, so Bazel is asked for
  # it (site/en/external/module.md: "use the `bazel mod dump_repo_mapping`
  # command").
  npm_repo=$(b mod dump_repo_mapping '' 2>"$work/setup.log" | "$node" -p 'JSON.parse(require("fs").readFileSync(0, "utf8")).npm ?? ""')
  [ -n "$npm_repo" ] || fail_with "$work/setup.log" "cannot find the install repository's canonical name"

  start_registry "$work/registry"
  port=$(cat "$work/registry/port")
  yarnrc
}

# The case every test ends with, then the summary; its status is the test's.
consumer_finish() {
  [ ! -e "$work/ancestor/plugin-loaded" ]
  record $? "Configuration above the project under the install's former file name: no install so far loaded its plugin"
  harness_finish
}
