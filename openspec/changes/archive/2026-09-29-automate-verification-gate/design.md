## Context

See proposal.md — Why. The gate already exists in prose; this gives it a
machine.

## Goals / Non-Goals

Goals:

- Everything the workflow runs can be run locally, so a contributor sees what
  CI will say before pushing.
- Every version the workflow depends on is pinned to a commit, with the tag it
  belongs to written beside it and checked rather than assumed.
- The macOS claim stops being an assumption.

Non-Goals:

- Caching or speed. A ruleset with 23 tests does not need a cache, and a cache
  that goes stale hides breakage.
- Release or publication steps. Nothing is published yet.
- Upgrading the OpenWiki workflow's own dependencies. Its `actions/setup-node`
  pin is three majors behind, which is worth its own change; correcting a
  comment is not the place to do it.

## Decisions

### No Bazel setup action

Both GitHub runner images ship Bazelisk as `bazel` — the Ubuntu 24.04
manifest lists Bazel 9.2.0 and Bazelisk 1.28.1, and the macOS arm64 manifest
lists Bazel 9.2.0 and Bazelisk 1.29.0 — so `.bazelversion` already decides the
version on both. A setup action would be a pinned dependency that changes nothing, and
the floor job overrides the version through `USE_BAZEL_VERSION`, which
Bazelisk reads directly.

### The floor job is a script, not workflow steps

`tools/ci/minimum_bazel.sh` builds a throwaway consumer module with a local
override onto the repository and runs its Yarn target. It derives both the
Bazel floor and the Yarn version from the repository — the floor from
`bazel_compatibility` in `MODULE.bazel`, the version from
`yarn/private/versions.bzl` — so the check cannot drift from what the ruleset
declares.

It has to be a consumer rather than one of the repository's own roots. Both
roots set `--lockfile_mode=error` and their lockfiles are written by the Bazel
in `.bazelversion`, so an older Bazel fails on the lockfile long before it
reaches the ruleset. A consumer resolving from scratch keeps no lockfile and
exercises the path a consumer actually takes.

Keeping it in the repository means it runs locally, and it did: at the
declared floor it exits 0 and reports the expected Yarn version, and one
version below the floor it exits non-zero on Bazel's own compatibility error.
A gate that has never failed is not known to be a gate.

### `pre-commit run --all-files` rather than a list of steps

The hook list is already the repository's definition of what must hold, and
duplicating it in the workflow would let the two drift. One step runs
Buildifier, its linter, the file-hygiene hooks and
`openspec validate --all --strict`.

The guard's contract test runs as its own step, because it is harness tooling
with no Bazel target and is not a pre-commit hook.

### macOS is a matrix entry

Cross-platform analysis was checked locally first, by building the launcher
for `@platforms//os:osx` with both CPUs from a throwaway module: it resolves
the darwin Node.js toolchain and the macOS shell toolchain and emits a
launcher with `#!/bin/bash`. So macOS is not expected to fail at analysis.

Execution is what CI answers.

An earlier draft of this design predicted that the two tests tagged
`block-network` would fail on macOS, on the reasoning that network blocking is
a Linux sandbox feature. That was a guess and it is wrong. Bazel's macOS
sandbox runner computes `allowNetworkForThisSpawn` from
`Spawns.requiresNetwork(spawn, ...)` — the same call Linux makes — and writes
a deny rule into the Seatbelt profile when the result is false
(`DarwinSandboxedSpawnRunner.java:225-281`). The tag is honoured on macOS, so
those two tests are expected to pass there like any other.

Nothing is changed in advance either way. `fail-fast: false` keeps the Linux
result visible whatever macOS reports, and task 3.2 records what the first run
actually says rather than what this document expects.

### A gap this workflow does not close

`.pre-commit-config.yaml`'s `okf-validate` hook runs `tools/okf/validate.sh`,
which shells out to `uv`. The hook is filtered to `^\.okf/`, no such directory
exists, and the runner images do not carry `uv`, so today the `checks` job
passes because the hook never runs. If an `.okf/` bundle were ever added the
job would break on a missing tool. The repository has no reason to hold an OKF
bundle and the retirement of that tooling is its own change; this is recorded
so the failure would not be a surprise.

### Pins

Every action is pinned to a commit with its tag in a comment, and each SHA was
resolved from the tag rather than copied: `actions/checkout` v7.0.1,
`actions/setup-node` v7.0.0, `actions/setup-python` v7.0.0. The OpenSpec CLI
and `pre-commit` are pinned to the versions this repository is developed
against, 1.13.0 and 4.6.2.

The CLI's package is `@fission-ai/openspec`, not `openspec`. A first draft
installed the latter, which is an unrelated placeholder last published in
2019 at 0.0.0 — the job would have failed on a 404 at the first push. The
package a command comes from is not guessable from the command's name, and
this one was guessed.

`permissions: contents: read`, because nothing in this workflow writes.

## Risks / Trade-offs

- [The workflow itself cannot be verified without pushing] → Every step it
  runs was run locally: both build roots, `pre-commit run --all-files`, the
  guard contract test, and the floor script in both directions. What remains
  unverified is GitHub's acceptance of the file and the macOS runner, and
  neither can be settled from here. The first push settles both.
- [Pinned tool versions go stale] → They are visible in one file with their
  tags beside them, which is the condition for noticing.
- [`push` with no branch filter runs on every branch] → For a repository with
  one contributor that is the point; a gate that only runs on the default
  branch reports after the fact.

## Migration Plan

None. The workflow takes effect on the next push.
