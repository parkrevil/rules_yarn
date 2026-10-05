---
type: quickstart
title: Quickstart
description: What rules_yarn is and is not, and which page answers each common task — depending on it, adding a Yarn version, changing the launcher, running the tests, cutting a release, following the contributor workflow.
tags: [quickstart, navigation, bazel, yarn]
sources:
  - id: openwiki-source-a4bd6b79c62e34a3dbb09576
    resource: repo://.bazelignore
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-8037e2358a2c4f9b2c722a11
    resource: repo://AGENTS.md
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
  - id: openwiki-source-e27756e3a61ff66626b48e05
    resource: repo://e2e/smoke/MODULE.bazel
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
  - id: openwiki-source-d9081795909674dafc7044aa
    resource: repo://yarn/private/yarn_binary.bzl
  - id: openwiki-source-c20b05d8b903795173b9a3b2
    resource: repo://yarn/private/yarn_binary.sh.tpl
generated: { by: "claude-code", at: "2026-10-04T12:22:38.266Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-05T14:22:28.209Z
---

# Quickstart

`rules_yarn` delivers one exact Yarn version to a Bazel workspace and runs it
with a Bazel-managed Node.js runtime, so nobody needs Node.js, Yarn or Corepack
installed. It also installs a Yarn project's locked dependencies as Bazel
artifacts, every registry package fetched by Bazel with a pinned integrity. Linux and macOS are supported; the launcher is a Bash script and the
shell toolchain points at Bash on both, so Windows would need work the ruleset
does not do.

The two halves make different promises. `yarn_binary` runs the Yarn CLI and
nothing more: a command run through it gets no caching, sandboxing or
dependency-installation guarantees from Bazel. `yarn.install` is the part with
guarantees — integrity-checked fetching through Bazel's downloader, exactly the
lockfile's versions, an offline layout isolated from the host, no dependency
build scripts, one artifact per package. Running the project's own scripts and
builds as Bazel actions is not provided yet.

## Task routing

| I want to… | Open |
| --- | --- |
| depend on the ruleset and declare a Yarn target | [Public API surface](concepts/public-api-surface.md) |
| install a project's dependencies, or understand how that works | [Installing a project's dependencies](architecture/dependency-installation.md) |
| understand how a version string becomes `@yarn` | [Yarn distribution pipeline](architecture/distribution-pipeline.md) |
| add or change a supported Yarn version | [Version pinning and lockfiles](operations/version-pinning.md) |
| change how Yarn is launched, or debug a run | [Launcher and execution model](architecture/launcher-execution.md) |
| know which test layer covers a behavior | [Verification strategy](testing/verification-strategy.md) |
| cut a release or publish to the registry | [Releasing and publishing](operations/publishing.md) |
| make a change to this repository | [Development workflow](workflows/development-workflow.md) |

## The shape of a consumer

Two declarations in `MODULE.bazel` — a dependency on the ruleset plus a Node.js
toolchain, and a Yarn version through the `yarn` module extension — and one
`yarn_binary` target naming the resulting repository. Then `bazel run` the
target; arguments after `--` reach Yarn unchanged, and Yarn runs in the
directory Bazel was invoked from.

Bazel 8.3.0 or newer. The ruleset declares that, so an older Bazel is turned
away while the module graph resolves rather than failing somewhere inside the
ruleset.

The ruleset is not in the Bazel Central Registry yet, so until it is, a
consumer adds a non-registry override next to the `bazel_dep` — an
`archive_override` on a release archive, whose integrity value is in that
release's notes, or `git_override`, or `local_path_override`. An override only
takes effect in the root module, so a module depending on `rules_yarn` cannot
pass it on and every root module downstream has to repeat it. That is what
publishing removes, and the apparatus for it is already in place.

`e2e/smoke` is a working consumer that uses only the public API, and
`e2e/install` one that installs a real project with `yarn.install`.

## Four build roots

The repository root, `e2e/smoke`, `e2e/install` and `tests/bcr` are separate
Bazel modules, and the root excludes the other three from package discovery.
Building or testing everything means four invocations, one in each directory,
plus the install scenario script — which is also what CI does, on Linux and
macOS.
