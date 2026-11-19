## Why

The registry will not take the module as `rules_yarn`. Reviewing
bazelbuild/bazel-central-registry#10979, a registry maintainer asked for a user
prefix on 2026-11-18, because an unprefixed `rules_*` name reads as the
canonical Yarn ruleset. That name can be revisited if the project gains
community momentum. Until the module is renamed, it cannot reach the registry.

## What Changes

- **BREAKING** The Bazel module is renamed from `rules_yarn` to
  `parkrevil_rules_yarn`. A consumer depends on it with
  `bazel_dep(name = "parkrevil_rules_yarn", ...)` and loads its files as
  `@parkrevil_rules_yarn//yarn:...`. Release 0.1.0, published on GitHub only,
  stays `rules_yarn`.
- Where the ruleset refers to its own files, it uses relative labels.
  The two exceptions are a file loaded from inside a repository the `yarn`
  extension generates, and the `BUILD.bazel` written there. A relative label
  there names the generated repository, so they use the new module name.
- Every consumer of the module in this repository moves to the new name:
  `e2e/smoke`, `e2e/install`, `tests/bcr` and the scenario scripts in
  `tools/ci/`. So do the release notes that `release_prep.sh` prints and the
  README's setup and override examples. The README also gets a migration note
  for 0.1.0 users.
- Two defects the change review found are fixed here, at the user's
  direction, so they ship with the rename. A release now refuses an annotated
  tag, which ccv cannot see. `tools/ci/install_scenarios.sh` prints Bazel's
  output when a setup command fails.
- Unchanged: the GitHub repository `parkrevil/rules_yarn`, the release archive
  names and prefixes derived from it, and `rules_yarn` as the project's name in
  prose.
- The first release under the new name is v0.2.0, pushed by hand after the
  change merges. `tag.yaml` leaves a breaking change's major version to a person.
  The registry entry it produces replaces #10979, which is then closed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `yarn-execution`: adds a requirement stating the module name a consumer
  depends on and that installed dependencies resolve the ruleset's files under
  it.

## Impact

- `MODULE.bazel` (module name) and `tests/bcr/MODULE.bazel`. The three roots'
  `MODULE.bazel.lock` files are regenerated; none names the module, so they
  are expected unchanged.
- `yarn/private/install/node_modules.bzl` and
  `yarn/private/install/repository.bzl` (labels resolved from a generated
  repository); doc examples in `yarn/extensions.bzl` and
  `yarn/private/yarn_binary.bzl`, which reach the published API docs.
- `e2e/smoke/`, `e2e/install/`, `tests/bcr/`, `tools/ci/minimum_bazel.sh`,
  `tools/ci/install_scenarios.sh`.
- `README.md`, `.github/workflows/release_prep.sh`, `.github/workflows/ci.yml`
  (release-notes check), and the dependency wording in `.bazelrc` and
  `tests/bcr/yarn_version_test.sh`.
- `.github/workflows/release.yml` (the lightweight-tag job) and
  `.github/workflows/tag.yaml` (the major-version notice).
- `openwiki/`: its claims cite files this change edits, so it is regenerated.
- External: a new registry pull request for `parkrevil_rules_yarn@0.2.0`, and
  #10979 closed.
