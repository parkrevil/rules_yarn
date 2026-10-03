---
type: operations
title: Version pinning and lockfiles
description: Every pinned input in the repository, where each is declared, how a new Yarn version and its digest are added, and how lockfile enforcement differs between the root module and the consumer smoke module.
tags: [pinning, lockfile, bzlmod, integrity, maintenance]
sources:
  - id: openwiki-source-61e437e4689f6b29dc54938b
    resource: repo://.bazelrc
  - id: openwiki-source-a996efa61d56b86aea305719
    resource: repo://.bcr/presubmit.yml
  - id: openwiki-source-8037e2358a2c4f9b2c722a11
    resource: repo://AGENTS.md
  - id: openwiki-source-bc52b7fdf1f189e434bbea21
    resource: repo://e2e/smoke/.bazelrc
  - id: openwiki-source-549241bca0b004f1752341b2
    resource: repo://e2e/smoke/.bazelversion
  - id: openwiki-source-e27756e3a61ff66626b48e05
    resource: repo://e2e/smoke/MODULE.bazel
  - id: openwiki-source-d92bdd4d3d554717b6869e2d
    resource: repo://MODULE.bazel
  - id: openwiki-source-01bd775b2b199eca72dcc70e
    resource: repo://tests/bcr/.bazelrc
  - id: openwiki-source-847ceba95f7fcfa239c5f25b
    resource: repo://yarn/private/versions.bzl
generated: { by: "claude-code", at: "2026-10-03T03:12:21.393Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-03T03:35:17.537Z
---

# Version pinning and lockfiles

Nothing in this repository resolves a version at build time from whatever is
newest. Every external input is named exactly once, and the places it is named
are few enough to list.

## Where pins live

| File | Pins |
| --- | --- |
| `MODULE.bazel` | Bazel module dependencies and their versions, plus the Node.js version used for development and the Yarn version used by the ruleset's own tests |
| `MODULE.bazel.lock` | the resolved graph and the registry file hashes behind it |
| `.bazelversion` | the Bazel release |
| `yarn/private/versions.bzl` | every Yarn version the ruleset can fetch, with its integrity digest |
| `e2e/smoke/MODULE.bazel`, `e2e/smoke/MODULE.bazel.lock`, `e2e/smoke/.bazelversion` | the same, for the consumer module |
| `tests/bcr/MODULE.bazel` | the same, for the module the registry presubmit runs — no lock, for the reason below |

`MODULE.bazel` also declares `bazel_compatibility = [">=8.3.0"]`, which pins
the other direction: not what this repository depends on, but the oldest Bazel
a consumer may bring. Below it Bazel refuses the module while resolving,
naming the ruleset, rather than failing inside it.

The two other modules are separate Bazel modules with their own roots. Each
depends on the ruleset through a non-registry override pointing at the
repository root, which is why each has its own module file rather than
participating in the root module's resolution.

## The Yarn digest table

`versions.bzl` holds two things: a URL template parameterized by version, and a
map from version to Subresource Integrity digest. Adding a version means adding
one entry to that map. The file's own comment records where a digest may be
checked against an upstream record — the `bin/yarn.js` file of the
`@yarnpkg/cli-dist` package on the npm registry, or the hash recorded for that
version in Corepack's configuration — because the bundle is served from the
same location Corepack uses.

A version absent from this map cannot be requested: the module extension rejects
it during evaluation, before any network access. A digest that does not match
what the URL serves fails the fetch. Between them there is no path by which a
build silently gets a different Yarn than the one named.

## Lockfile enforcement is declared per module root

Each root states its own mode, because Bazel reads the `.bazelrc` of the
module root it was invoked in and one root's setting does not reach another.
A root that states nothing gets Bazel's default, `update`, which rewrites a
stale lock without reporting anything — or writes one where none was wanted.

| Root | Mode | Why |
| --- | --- | --- |
| the repository | `error` | the committed lock is authoritative for every checkout |
| `e2e/smoke` | `error` | the same, for the configuration it checks |
| `tests/bcr` | `off` | the registry presubmit resolves it under several Bazel versions, and a lock written by one fails under another |

`tests/bcr` keeps no lockfile at all. It had one briefly — Bazel's default
wrote it and a commit carried it in, while the documentation said the module
kept none — which is why that root now states `off` rather than relying on
nobody running Bazel there.

## Changing a pin

Refreshing the locks after a dependency change is two invocations, one per
root that keeps a lock:

```shell
bazel mod deps --lockfile_mode=update
```

Run it in the repository root and in `e2e/smoke/`, and commit both locks.
`tests/bcr` has nothing to refresh. The error mode makes a forgotten refresh
fail loudly on the next build rather than producing a drifted checkout.

## Development-only pins

The Node.js toolchain registration, the test-only Yarn distribution, the
platforms module and the testing framework are all declared as development
dependencies of the root module: they are needed to build and test the ruleset,
not to consume it. A consumer supplies its own Node.js toolchain and declares its
own Yarn version.
