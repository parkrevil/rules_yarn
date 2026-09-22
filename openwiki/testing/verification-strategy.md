---
type: testing
title: Verification strategy
description: The four test layers that hold the ruleset's guarantees — Starlark unit tests over version selection, analysis tests over the rule, shell tests that execute the launcher and the real Yarn CLI, and a separate consumer module that exercises only the public API.
tags: [testing, rules-testing, analysis-test, sh-test, e2e]
sources:
  - id: openwiki-source-a4bd6b79c62e34a3dbb09576
    resource: repo://.bazelignore
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
  - id: openwiki-source-30a0b6b2b81e4795cac4f928
    resource: repo://e2e/smoke/yarn_version_test.sh
  - id: openwiki-source-42fff598a74b8a8cf6e6de47
    resource: repo://tests/extensions/extensions_tests.bzl
  - id: openwiki-source-2786bbb2f5598011b27e9081
    resource: repo://tests/launcher/BUILD.bazel
  - id: openwiki-source-8a52f3cc97aa21919ea82129
    resource: repo://tests/launcher/launcher_test.sh
  - id: openwiki-source-d066155d67929b81ea0f151f
    resource: repo://tests/launcher/yarn_cli_test.sh
  - id: openwiki-source-ca621fdd9c1fe509f3bed92e
    resource: repo://tests/repositories/repositories_tests.bzl
  - id: openwiki-source-8128c9332cc7d75bca4dc18e
    resource: repo://tests/yarn_binary/BUILD.bazel
  - id: openwiki-source-eb3dcfac0b874f311a6353ac
    resource: repo://tests/yarn_binary/yarn_binary_tests.bzl
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
generated: { by: "claude-code", at: "2026-09-21T10:11:59.468Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T15:40:20.833Z
---

# Verification strategy

Each guarantee the ruleset makes is held by the cheapest layer that can actually
observe it. The layers differ in what they can see, so they are not
interchangeable.

## Layer 1 — Starlark unit tests over selection

Version selection is a pure function of the module graph, so it is tested as
one. `select_distributions` takes its failure handler as a parameter, and the
tests pass a list's `append` in place of `fail`, which makes every rejection
path observable: the returned value, and the exact message, without aborting
the test.

The module graph itself is faked with plain structs mirroring the shape Bazel
supplies — `is_root`, `name`, `version`, and `tags.distribution`. This is what
lets the suite cover orderings that would otherwise require building real module
graphs: root versus dependency, near dependency versus far one, duplicate
declarations, and declarations that lost and therefore escape validation.

The repository rule is tested the same way, against a mock context that records
each call, so the suite can assert call order and exact arguments rather than
inspecting a fetched directory.

## Layer 2 — analysis tests over the rule

`yarn_binary` is examined without executing anything: the declared executable,
the default outputs, the runfiles contents, and the template action's
substitution keys and values. One test asserts the launcher's runfiles contain
the Bash runfiles library; another builds an entry point that is a `filegroup`
with `data` and asserts the resource reaches the launcher's runfiles.

The host-path rejection is tested by configuration rather than by mocking: the
package defines a constraint, a platform carrying it, and a Node.js toolchain
that names only a host path. The analysis test requests that platform and
asserts the expected analysis failure. The toolchain is registered as a
development dependency of the root module, so it never affects a consumer.

## Layer 3 — executing the launcher

Behavior that only exists at run time is tested by running the launcher.

A probe entry point stands in for Yarn and reports what it received. Against it
the suite checks argument fidelity for spaces, quotes, globs, semicolons,
newlines and empty strings; that the launcher's forced environment overrides the
caller's; exit-status propagation; the working-directory rule in both directions;
that relative runfiles paths survive the directory change; and a manifest-only
runfiles lookup performed with the runfiles directory removed from the
environment.

A second test drives the real Yarn distribution. It plants fake `node`, `yarn`
and `corepack` executables on `PATH` that record any invocation and exit
non-zero, then asserts the selected version is printed and the marker file never
appears — the direct evidence that no host tool participates. It also creates a
project whose configuration redirects Yarn elsewhere and asserts both that the
redirect is ignored and that the project files are unchanged afterwards.

Both Yarn-executing tests are tagged so the sandbox blocks network access, and
each begins by asserting the network really is unreachable, so the test fails
loudly rather than passing for the wrong reason in an environment that does not
honor the tag.

## Layer 4 — the consumer module

`e2e/smoke` is a separate Bazel module that depends on the ruleset the way a
consumer does and uses only the public API. It exists because consumption
through a module boundary cannot be observed from inside the module being
consumed.

The repository root excludes `e2e/` from its own package discovery, so the
consumer module is built and tested by a second invocation in its own directory
rather than being swept into `//...`.
