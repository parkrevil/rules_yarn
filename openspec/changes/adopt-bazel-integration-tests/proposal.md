## Why

Two scripts in `tools/ci/` test the ruleset as a consumer meets it:
`install_scenarios.sh` covers `yarn.install`'s fetching, pinning, refusals and
isolation from the host, and `minimum_bazel.sh` covers the oldest supported
Bazel. Only a Bazel run from outside can show these things. But the scripts
run outside the Bazel test graph, and they live in `tools/ci/`, where
AGENTS.md says tests do not belong ("tests in `tests/`").

`install_scenarios.sh` is one 657-line script. Its 39 cases run in sequence
on one consumer, and later cases depend on what earlier ones left behind.
7 of the cases test Yarn rather than this ruleset. Its header says each case
is a scenario "of the install spec that names this script", but no spec names
it.

Rulesets test this with nested-Bazel integration tests declared as Bazel test
targets. bazel-contrib's `rules_bazel_integration_test` states the pattern;
rules_go's `go_bazel_test` writes it for itself. The user asked for these tests
to follow that convention before v0.2.0 ships, and to weigh each piece by need.

## What Changes

- The consumer-side tests become Bazel test targets under `tests/integration/`,
  written to `rules_bazel_integration_test`'s pattern as plain `sh_test`s.
  `bazel test //tests/integration:integration_tests` runs them. The tool is
  not a dependency: it would give a thin `sh_test` wrapper, and would cost
  56 modules and toolchain repositories in every root build, one a symlink to
  the host's `git` (design, Decision 2).
- They run a Bazel binary this repository pins by version and SHA-256.
- `install_scenarios.sh`'s 32 cases about `yarn.install` are split into 7
  targets by concern: fetching, tarballs, per-dependency targets, refusals, the
  pin file, the host, and Bazel's downloader. Each target starts from a fresh
  consumer, so a case depends only on cases in its own target.
- Its 7 cases about Yarn's own behavior, which design decisions rest on,
  become an ordinary `sh_test`. It runs the root module's Bazel-managed Yarn,
  with no nested Bazel.
- `minimum_bazel.sh` goes. Its consumer is what `e2e/smoke` already is, so
  the floor job runs `e2e/smoke`'s tests under the floor Bazel, as it already
  runs `e2e/install`'s. Consumer folders under each Bazel version is the
  convention bazel-contrib's reusable test workflow follows.
- A test checks that the pinned Bazel binary reports `.bazelversion`'s
  version.
- `tools/ci/` is removed. The local registry and the fixtures move under
  `tests/`.
- CI runs the integration suite in place of `install_scenarios.sh`. AGENTS.md's
  before-commit gate and its pin list name the new suite and pins.
- No consumer-visible change. The Bazel binaries are dev dependencies, which a
  module depending on this one does not see.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This changes how behavior is verified, not the behavior, so the change
sets `skip_specs: true`.

## Impact

- New: `tests/integration/` (targets, runners, a child workspace, a shared
  runner library), `tests/fixture_registry/` (the local registry and the
  fixtures shared with the Yarn-behavior test), `tests/install/yarn_behavior_test.sh`,
  and a root `BUILD.bazel`.
- `MODULE.bazel`: the Bazel 9.2.0 binary for four platforms, as dev
  `http_file` repositories. `MODULE.bazel.lock` does not change, since a root
  module's repository rules are not recorded there.
- `yarn/BUILD.bazel`, `yarn/private/BUILD.bazel` and
  `yarn/private/install/BUILD.bazel` each get an `all_files` filegroup, so a
  child workspace can see the ruleset.
- `.bazelrc` gains `--deleted_packages` for the child workspace, and
  `.bazelignore` the `bazel-*` links Bazel would leave in it.
- `.github/workflows/ci.yml` and `AGENTS.md`. The README names neither script.
- Removed: `tools/ci/install_scenarios.sh`, `tools/ci/minimum_bazel.sh`,
  `tools/ci/fixture_registry.js`, `tools/ci/fixtures/`.
- `openwiki/`: its claims cite the removed scripts, so it is regenerated.
