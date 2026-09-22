---
type: quickstart
title: Quickstart
description: What rules_yarn is, and which page to open for the common tasks — consuming the ruleset, adding a Yarn version, changing the launcher, running the tests, and following the contributor workflow.
tags: [quickstart, navigation, bazel, yarn]
sources:
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
generated: { by: "claude-code", at: "2026-09-21T10:11:59.468Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T15:40:20.833Z
---

# Quickstart

`rules_yarn` delivers one exact Yarn version to a Bazel workspace and runs it
with a Bazel-managed Node.js runtime, so nobody needs Node.js, Yarn or Corepack
installed. Linux x86_64 is the supported platform; the launcher is a POSIX shell
script, so Windows would need work the ruleset does not do.

It delivers the Yarn CLI and nothing more. Yarn commands do not become Bazel
actions, so they get no caching, sandboxing or dependency-installation
guarantees from Bazel.

## Task routing

| I want to… | Open |
| --- | --- |
| depend on the ruleset and declare a Yarn target | [Public API surface](concepts/public-api-surface.md) |
| understand how a version string becomes `@yarn` | [Yarn distribution pipeline](architecture/distribution-pipeline.md) |
| add or change a supported Yarn version | [Version pinning and lockfiles](operations/version-pinning.md) |
| change how Yarn is launched, or debug a run | [Launcher and execution model](architecture/launcher-execution.md) |
| know which test layer covers a behavior | [Verification strategy](testing/verification-strategy.md) |
| make a change to this repository | [Development workflow](workflows/development-workflow.md) |

## The shape of a consumer

Two declarations in `MODULE.bazel` — a dependency on the ruleset plus a Node.js
toolchain, and a Yarn version through the `yarn` module extension — and one
`yarn_binary` target naming the resulting repository. Then `bazel run` the
target; arguments after `--` reach Yarn unchanged, and Yarn runs in the
directory Bazel was invoked from.

The ruleset is not published to a registry, so a consumer depends on it through
a non-registry override. `e2e/smoke` is a working example that uses only the
public API.

## Two build roots

The repository root and `e2e/smoke` are separate Bazel modules, and the root
excludes `e2e/` from package discovery. Building or testing everything means two
invocations, one in each directory.
