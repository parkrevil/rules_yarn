## Why

The repository contains agent tooling but no Bazel module or executable rules. Establish a small, reproducible Yarn execution foundation, built on current Bazel 9 and official ruleset patterns, before designing dependency installation or JavaScript build integration.

## What Changes

- Add a Bzlmod ruleset skeleton that follows Bazel's "Deploying Rules" guidance and the applicable parts of `bazel-contrib/rules-template`.
- Provide exact, integrity-checked Yarn distributions through a module extension whose repository naming follows Bazel's module extension best practices.
- Add a public `yarn_binary` executable rule that runs the selected Yarn distribution with the Node.js runtime toolchain from `rules_nodejs`.
- Add Starlark unit and analysis tests, launcher tests, an independent `e2e/smoke` consumer, and a README describing setup, public API, tested versions, and scope.
- Keep dependency installation, lockfile translation, PnP/node_modules integration, Bazel build actions that run Yarn, BCR publication, and non-Linux platforms outside this change.

## Capabilities

### New Capabilities

- `yarn-execution`: Configure an exact Yarn distribution through Bzlmod and run it through a Bazel executable target with a Bazel-managed Node.js runtime.

### Modified Capabilities

None.

## Impact

- New `MODULE.bazel`, `MODULE.bazel.lock`, `.bazelversion`, `.bazelrc`, `.bazelignore`, `.gitignore`, `README.md`, the `yarn/` public package, `yarn/private/`, `tests/`, and the independent `e2e/smoke` module.
- New dependencies: `rules_nodejs` 6.7.5, `rules_shell` 0.8.0, `bazel_skylib` 1.9.2, and the development-only `rules_testing` 0.9.0. `rules_nodejs` 6.7.6 is not published to the Bazel Central Registry; see design.md.
- Tested baseline: Bazel 9.2.0, Yarn 4.18.0, Node.js 24.21.0, Linux x86_64, checked against upstream sources on 2026-09-18.
- Agent tooling remains intact.
