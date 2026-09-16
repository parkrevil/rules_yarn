## Context

See [proposal.md](proposal.md) for motivation. The repository has no existing Bazel targets, runtime code, or main specifications. Existing agent configuration must be preserved. This document proposes an initial implementation; none of the runtime behavior has been verified yet.

Research covered Bazel's rules, module-extension, toolchain, deployment and testing documentation; `rules-template` module/extension/toolchain/CI files; `rules_cc` extensions; and `rules_nodejs` 6.7.6 extension and toolchain APIs. This is not an exhaustive audit of every official rule. Implementation must continue checking the applicable upstream patterns as required by AGENTS.md.

## Goals / Non-Goals

**Goals:** Separate tool acquisition from execution, expose a small public API, and prove the API from an independent Bzlmod consumer.

**Non-Goals:** Treating arbitrary Yarn commands as declared Bazel build actions, implementing a package resolver, changing consumer Yarn configuration, introducing a separate documentation platform, or publishing a release in this change. See the proposal for the functional scope.

## Decisions

### 1. Use the template as a reference, not a wholesale import

Create `MODULE.bazel` with module name `rules_yarn`, `.bazelversion`, minimal `.bazelrc`, public `yarn/defs.bzl` and `yarn/extensions.bzl`, private implementation files, tests, and a separate `e2e/smoke` module. Keep development-only dependencies marked as such. Use Buildifier and document the public API.

This adopts the template's separation of consumer and developer concerns without introducing its placeholder language, unrelated tools, or release automation before those are needed. Do not copy its string-sorted version selection: the template itself marks SemVer selection as unfinished. BCR publication and its credentials/workflows remain a later change; retain a consumer layout suitable for future BCR presubmit tests.

### 2. Resolve a pinned Yarn distribution through Bzlmod

Proposed configuration: `use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")`, a `yarn.distribution(name = "yarn_cli", version = "4.18.0")` tag, and `use_repo(yarn, "yarn_cli")`. The repository exports a single Yarn JavaScript entry point for use as `@yarn_cli//:yarn`.

Maintain checked-in version-to-URL-and-digest metadata, initially for the verified stable Yarn release. Fetch the official versioned standalone distribution with Bazel's download facilities and a mandatory digest. Validate versions before downloading. Deduplicate identical name/version declarations; reject conflicting declarations. This avoids hidden upgrades and does not need a custom SemVer resolver.

The distribution is platform-independent; the Node runtime is not. Do not create a duplicate platform matrix or an additional Yarn toolchain solely to carry this file. Do not discover installed Yarn or invoke global Corepack. Yarn's documentation supports versioned standalone distributions, while Corepack's global installation guidance is for ordinary developer environments.

### 3. Reuse the correct Node runtime toolchain

Expose `yarn_binary(name, yarn)` from `yarn/defs.bzl`. Its implementation consumes `@rules_nodejs//nodejs:runtime_toolchain_type`, because the result is an executable for the target platform. Use the supported `nodeinfo.node` file and reject a path-only, host-installed runtime. Include Node, Yarn, and launcher support files in `DefaultInfo` runfiles. Do not use deprecated `target_tool_path` or `tool_files` fields.

The consumer configures and registers an exact Node version through the public `rules_nodejs` extension. Verify the latest stable Node release's availability and Yarn compatibility when implementing, then record the exact tested version. No floating version selection occurs during builds. Build-action support, if added later, must instead use the execution toolchain type where appropriate.

### 4. Keep launcher behavior explicit

Generate an executable launcher with Bazel's documented runfiles lookup and repository-mapping support. For the initial POSIX launcher, forward arguments using an argument array and `exec`, never `eval` or a reassembled shell command. Preserve Yarn's streams and exit status. Use the caller's workspace working directory provided by Bazel for `bazel run`; retain the process working directory when invoked directly or from a test.

Prevent project `yarnPath` redirection from replacing the selected distribution using Yarn's documented `YARN_IGNORE_PATH` setting. Set `YARN_ENABLE_TELEMETRY=0` in the launcher to prevent Yarn telemetry from invalidating the offline version-check contract. Do not rewrite project files or claim that arbitrary user-invoked commands are hermetic. User-invoked installation and script behavior still belongs to Yarn.

Initial acceptance runs on Linux x86_64, matching the development environment; use portable runfiles handling and do not advertise macOS or Windows support until tested. Supporting Windows requires a suitable launcher and dedicated tests, not an implicit Bash dependency. This limits the first validation matrix rather than asserting cross-platform compatibility.

### 5. Verify behavior before expanding scope

Use focused Starlark tests for configuration errors and analysis/runfiles behavior, plus integration tests from `e2e/smoke` using a local module override. Verify the selected version with host Node/Yarn/Corepack absent, offline execution after fetch, argument boundaries, error propagation, integrity failure, and unchanged project files. Run both root and consumer build/test commands; root `//...` does not cover an independent module automatically.

Use the planning baseline Bazel 9.2.0, Yarn 4.18.0, and rules_nodejs 6.7.6, rechecking stable releases at implementation time. Record compatibility evidence rather than assuming independently current releases interoperate. OpenSpec strict validation checks these planning artifacts, not the runtime behavior.

## Risks / Trade-offs

- Latest upstream versions may not interoperate → verify the combination before declaring support; report conflicts instead of silently downgrading.
- Runfiles paths differ in external modules and manifest mode → use an upstream runfiles library and test an independent consumer and manifest lookup.
- Yarn commands can fetch dependencies, run scripts, and modify files → document that this change manages CLI delivery, not dependency execution or cache correctness.
- A broad upstream audit is incomplete → keep reference coverage explicit and check the specific APIs and patterns before implementation.

## Migration Plan

No existing consumers require migration. Add the module, acquisition and launcher pieces in task order, then verify the independent example. Do not publish or commit as part of planning. If a piece fails verification, leave it unadvertised until corrected; no existing API needs a compatibility bridge.

## References

- [Bazel rule deployment](https://bazel.build/rules/deploying), [rules and runfiles](https://bazel.build/extending/rules), [module extensions](https://bazel.build/external/extension), [toolchains](https://bazel.build/extending/toolchains), [testing](https://bazel.build/rules/testing).
- [rules-template](https://github.com/bazel-contrib/rules-template), [extension and version-selection TODO](https://github.com/bazel-contrib/rules-template/blob/main/mylang/extensions.bzl).
- [rules_cc module extensions](https://github.com/bazelbuild/rules_cc/blob/main/cc/extensions.bzl).
- [rules_nodejs 6.7.6 runtime/toolchain types](https://github.com/bazel-contrib/rules_nodejs/blob/v6.7.6/nodejs/BUILD.bazel), [toolchain providers](https://github.com/bazel-contrib/rules_nodejs/blob/v6.7.6/nodejs/toolchain.bzl), [Bzlmod extension](https://github.com/bazel-contrib/rules_nodejs/blob/v6.7.6/nodejs/extensions.bzl).
- [Yarn versioned distribution](https://yarnpkg.com/cli/set/version), [Yarn configuration](https://yarnpkg.com/configuration/yarnrc), [installation phases](https://yarnpkg.com/cli/install).
- Stable releases checked on 2026-09-15: [Bazel 9.2.0](https://github.com/bazelbuild/bazel/releases/tag/9.2.0), [Yarn 4.18.0](https://github.com/yarnpkg/berry/releases/tag/@yarnpkg/cli/4.18.0), [rules_nodejs 6.7.6](https://github.com/bazel-contrib/rules_nodejs/releases/tag/v6.7.6).
