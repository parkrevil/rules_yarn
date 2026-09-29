## 1. The floor check

- [x] 1.1 Add `tools/ci/minimum_bazel.sh`, deriving the Bazel floor from `MODULE.bazel` and the Yarn version from `yarn/private/versions.bzl` so the check cannot drift from what the ruleset declares; verify it passes at the declared floor and fails below it, by exit code rather than by output.
  - 2026-09-29: it reads `8.3.0` from `bazel_compatibility` and `4.18.0` from the version table. At the floor it exits 0 and prints `PASS: Bazel 8.3.0 builds and runs the Yarn target, reporting 4.18.0`. At 8.2.1 it exits 48, on Bazel's own `Bazel version 8.2.1 is not compatible with module "rules_yarn@_"`. A gate that has never failed is not known to be a gate.

## 2. The workflow

- [x] 2.1 Add `.github/workflows/ci.yml` with a build-and-test job over both roots on Linux and macOS, a job at the declared Bazel floor, and a checks job; verify every step it runs passes locally first.
  - 2026-09-29: root `bazel build //...` and `bazel test //...` pass 22 tests; `e2e/smoke` passes 1; `pre-commit run --all-files` passes every hook and modifies nothing; `tools/hooks/protect_generated_test.sh` passes 40 of 40; `tools/ci/minimum_bazel.sh` passes. The only steps not exercised locally are the GitHub-specific ones — checkout, the two setup actions, and the macOS runner.
- [x] 2.2 Pin every action to a commit with its tag in a comment; verify each SHA by resolving it from the tag rather than copying it.
  - 2026-09-29: `actions/checkout` v7.0.1 `3d3c42e5…`, `actions/setup-node` v7.0.0 `82076278…`, `actions/setup-python` v7.0.0 `5fda3b95…`, each resolved from its tag. A first draft carried an invented `setup-python` SHA and an unverified `setup-node` tag comment; both were replaced after checking. `openspec` 1.13.0 and `pre-commit` 4.6.2 match the versions this repository is developed against.
- [x] 2.3 Establish that no Bazel setup action is needed; verify against the runner image contents rather than assuming.
  - 2026-09-29: the `actions/runner-images` Ubuntu 24.04 manifest lists `Bazel 9.2.0` and `Bazelisk 1.28.1`, so `bazel` on the runner is Bazelisk and `.bazelversion` decides the version. The floor job overrides it through `USE_BAZEL_VERSION`, which Bazelisk reads.
- [x] 2.4 Correct the tag comment on the pinned `actions/checkout` in the OpenWiki workflow.
  - 2026-09-29: the pinned commit resolves to tag `v4.3.1`; the comment said `v4`. The same workflow's `actions/setup-node` pin is three majors behind, which is left to its own change rather than folded into a comment fix.

## 3. macOS

- [x] 3.1 Check what can be checked locally before asking a runner: that the ruleset analyses for macOS and emits a sensible launcher.
  - 2026-09-29: from a throwaway module defining `@platforms//os:osx` platforms for both CPUs, `bazel build --platforms=//:macos_arm64 //:yarn` and the x86_64 equivalent both succeed. The launcher carries `#!/bin/bash` and resolves `rules_nodejs++node+nodejs_darwin_arm64/bin/nodejs/bin/node`, so the darwin Node.js toolchain and the macOS shell toolchain both resolve. Execution cannot be checked from Linux.
- [ ] 3.2 Record what the macOS job reports on the first run, and act on it there rather than guessing now.

## 4. Gate

- [x] 4.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`.
  - 2026-09-29: root `bazel test //...` passed 22 tests, `e2e/smoke` passed 1, `pre-commit run --all-files` passed every hook and modified nothing, `openspec validate --all --strict` passed.
- [x] 4.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - 2026-09-29, one blocker and three should-fixes, all upheld and all fixed.
    - **Blocker.** The `checks` job installed `openspec@1.13.0`, which does not exist: `openspec` on npm is an unrelated placeholder at 0.0.0 from 2019. The CLI this repository uses is `@fission-ai/openspec`, confirmed by resolving the local binary to `.../node_modules/@fission-ai/openspec/bin/openspec.js`, and `@fission-ai/openspec@1.13.0` does exist. The job would have failed on the first push. Fixed.
    - **Should-fix.** The design predicted the two `block-network` tests might fail on macOS because network blocking is a Linux sandbox feature. Wrong, and it was a guess where the change's own standard asks for a measurement. Bazel's `DarwinSandboxedSpawnRunner` derives `allowNetworkForThisSpawn` from `Spawns.requiresNetwork(spawn, ...)`, the same call Linux makes, and writes a deny rule into the Seatbelt profile when it is false — read from Bazel's source at lines 225-281. The design now records the correction and the citation.
    - **Should-fix.** The floor script discarded Bazel's stderr on the run step, so a failure there would reach CI as an exit code with no diagnostic. The redirect is gone.
    - **Should-fix.** The "no Bazel setup action" decision cited only the Ubuntu manifest while the workflow also targets macOS. The macOS arm64 manifest lists Bazel 9.2.0 and Bazelisk 1.29.0; the design now cites both.
    - **Latent gap, recorded not fixed.** The `okf-validate` pre-commit hook shells out to `uv`, which the runner images do not carry. It never runs today because no `.okf/` directory exists, so `checks` passes for want of anything to check. Recorded in design.md; retiring that tooling is its own change.
    - The reviewer independently confirmed all four pinned action SHAs against their tags, `pre-commit==4.6.2` on PyPI, the YAML's structure and semantics, the script's fail-closed parsing and its `trap` cleanup, and that the jobs cover what AGENTS.md's gate requires across both build roots.
