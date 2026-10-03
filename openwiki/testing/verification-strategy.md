---
type: testing
title: Verification strategy
description: The four test layers that hold the ruleset's guarantees — Starlark unit tests over version selection, analysis tests over the rule, shell tests that execute the launcher and the real Yarn CLI, and a separate consumer module that exercises only the public API.
tags: [testing, rules-testing, analysis-test, sh-test, e2e]
sources:
  - id: openwiki-source-a4bd6b79c62e34a3dbb09576
    resource: repo://.bazelignore
  - id: openwiki-source-a996efa61d56b86aea305719
    resource: repo://.bcr/presubmit.yml
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
  - id: openwiki-source-30a0b6b2b81e4795cac4f928
    resource: repo://e2e/smoke/yarn_version_test.sh
  - id: openwiki-source-01bd775b2b199eca72dcc70e
    resource: repo://tests/bcr/.bazelrc
  - id: openwiki-source-fc991def903a3901c3cc2810
    resource: repo://tests/bcr/BUILD.bazel
  - id: openwiki-source-9396675ac7636781156cad60
    resource: repo://tests/bcr/MODULE.bazel
  - id: openwiki-source-42fff598a74b8a8cf6e6de47
    resource: repo://tests/extensions/extensions_tests.bzl
  - id: openwiki-source-2786bbb2f5598011b27e9081
    resource: repo://tests/launcher/BUILD.bazel
  - id: openwiki-source-8a52f3cc97aa21919ea82129
    resource: repo://tests/launcher/launcher_test.sh
  - id: openwiki-source-d066155d67929b81ea0f151f
    resource: repo://tests/launcher/yarn_cli_test.sh
  - id: openwiki-source-26c30b7d6e8e08696306b1d2
    resource: repo://tests/launcher/yarn_offline_test.sh
  - id: openwiki-source-ca621fdd9c1fe509f3bed92e
    resource: repo://tests/repositories/repositories_tests.bzl
  - id: openwiki-source-8128c9332cc7d75bca4dc18e
    resource: repo://tests/yarn_binary/BUILD.bazel
  - id: openwiki-source-eb3dcfac0b874f311a6353ac
    resource: repo://tests/yarn_binary/yarn_binary_tests.bzl
  - id: openwiki-source-d0cac2a9da6e4ff2f6a238cf
    resource: repo://tools/ci/minimum_bazel.sh
  - id: openwiki-source-f62aa9ed7021af1727946d31
    resource: repo://tools/hooks/openwiki_staleness_test.sh
  - id: openwiki-source-c344118095552b0e155044aa
    resource: repo://tools/hooks/protect_generated_test.sh
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
generated: { by: "claude-code", at: "2026-10-03T09:23:19.545Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-03T09:50:46.826Z
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

The report the extension gives Bazel is tested the same way, with a fake
`module_ctx` whose `is_dev_dependency` reads a flag off the tag: a regular
declaration, a development-only one, the same repository declared both ways, a
declaration by a dependency rather than the root, one naming a repository the
extension did not create, and a duplicate.

The repository rule is tested the same way too, against a mock context that
records each call, so the suite can assert call order and exact arguments
rather than inspecting a fetched directory.

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

## Layer 3a — the one thing only a blocked network can show

That Yarn needs no network for `--version` cannot be shown by running it where
the network is there. So it is its own target, `yarn_offline_test`, in both
consumer-facing roots: tagged `block-network`, it first asserts the network
really is unreachable and fails if it is not, then runs `--version` and checks
the project is unchanged.

Nothing else depends on that tag. The tests above assert things that hold
whether or not the sandbox blocks anything, and they used to share a target
with this assertion — so one unavailable capability took three unrelated
checks down with it. Separating them means a run that cannot block the network
loses exactly the one check it cannot make.

## Layer 4 — the two consumer modules

Consumption through a module boundary cannot be observed from inside the module
being consumed, so there are modules outside it. There are two, because they
answer different questions.

`e2e/smoke` depends on the ruleset the way a consumer does, uses only the
public API, and pins a lockfile under `--lockfile_mode=error`. It checks one
configuration thoroughly.

`tests/bcr` is what the Bazel Central Registry's presubmit runs. It keeps no
lockfile, because that presubmit resolves it under several Bazel versions. It
is deliberately minimal — build a Yarn target through the public API and run
it — since its job is to show the published module works as a dependency, not
to re-run this suite.

The repository root excludes both from its own package discovery through
`.bazelignore`, so each is built and tested by its own invocation in its own
directory rather than being swept into `//...`.

## On top: what runs without being asked

`.github/workflows/ci.yml` runs on every push and pull request, over Linux and
macOS:

- **build and test** — all three roots, on both platforms. This is where the
  platform claim stops being a claim.
- **oldest supported Bazel** — `tools/ci/minimum_bazel.sh` builds a throwaway
  consumer module under the floor `MODULE.bazel` declares and runs its Yarn
  target. It reads the floor and the Yarn version out of the repository, so
  the check cannot drift from what is declared. The repository's own roots
  cannot answer this: their lockfiles are written by a newer Bazel and both
  set `--lockfile_mode=error`, so an older Bazel fails on the lockfile before
  reaching the ruleset.
- **checks** — the pre-commit hooks, which cover Buildifier, the file-hygiene
  hooks and `openspec validate --all --strict`; the contract tables of both
  harness hooks, the generated-file guard's and the wiki staleness gate's; and
  the staleness gate itself.

The two contract tables are the layer for code that has no Bazel target. Both
hooks are shell scripts the harness runs, not things the build produces, so
each has a plain test script naming every decision it is supposed to make —
forty cases for the guard, fifty-six rows for the staleness gate, in both
cases mostly refusals, because for a guard the dangerous mistake is clearing
something it never checked. The staleness gate's table also injects failures
into the commands the gate depends on, so a command that does its work and
then fails is shown to be a refusal rather than a pass.

The first run of this workflow found two defects no local run could have:
a GNU-only `find` flag the macOS runner rejected, and a Linux runner where
Bazel fell back to a sandbox that does not honour `block-network`.
