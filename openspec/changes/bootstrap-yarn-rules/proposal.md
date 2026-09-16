## Why

The repository contains agent tooling but no Bazel module or executable rules. Establish a small, reproducible Yarn execution foundation before designing dependency installation or JavaScript build integration.

## What Changes

- Add a Bzlmod ruleset skeleton following Bazel's deployment guidance and the applicable structure of `bazel-contrib/rules-template`.
- Provide a version-pinned, integrity-checked Yarn distribution and a public executable rule backed by the existing `rules_nodejs` toolchains.
- Add a separate consumer example, focused tests, and documentation for configuring and invoking Yarn.
- Keep dependency installation, lockfile translation, PnP/node_modules integration, and BCR publication outside this first implementation.

## Capabilities

### New Capabilities

- `yarn-execution`: Configure a pinned Yarn distribution through Bzlmod and invoke it through a Bazel executable target without a system Node.js or Yarn installation.

### Modified Capabilities

None.

## Impact

- New `MODULE.bazel`, Bazel configuration, `yarn/` public and private Starlark files, tests, and an independent `e2e/` consumer module.
- New dependencies on `rules_nodejs` and the minimal testing/runfiles/documentation dependencies required by the implementation.
- No existing runtime API or specification changes. Agent tooling remains intact.
- Planning baseline: Bazel 9.2.0, Yarn 4.18.0, and rules_nodejs 6.7.6, verified against upstream releases on 2026-09-15; compatibility remains to be tested.
