---
type: operations
title: Version pinning and lockfiles
description: Every pinned input in the repository, where each is declared, how a new Yarn version and its digest are added, and how lockfile enforcement differs between the root module and the consumer smoke module.
tags: [pinning, lockfile, bzlmod, integrity, maintenance]
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T15:40:20.833Z
sources:
  - id: openwiki-source-61e437e4689f6b29dc54938b
    resource: repo://.bazelrc
  - id: openwiki-source-bc52b7fdf1f189e434bbea21
    resource: repo://e2e/smoke/.bazelrc
  - id: openwiki-source-549241bca0b004f1752341b2
    resource: repo://e2e/smoke/.bazelversion
  - id: openwiki-source-e27756e3a61ff66626b48e05
    resource: repo://e2e/smoke/MODULE.bazel
  - id: openwiki-source-d92bdd4d3d554717b6869e2d
    resource: repo://MODULE.bazel
  - id: openwiki-source-847ceba95f7fcfa239c5f25b
    resource: repo://yarn/private/versions.bzl
generated: { by: "claude-code", at: "2026-09-21T15:40:20.833Z" }
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

The consumer module is a second Bazel module with its own root. It depends on
the ruleset through a non-registry override pointing at the repository root,
which is why it has its own module file and its own lock rather than
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

The root `.bazelrc` sets `common --lockfile_mode=error`. In that mode Bazel
fails the build when anything consulted during resolution is missing from or
stale in the lockfile, instead of quietly updating it. The committed lock is
therefore authoritative for every checkout.

The consumer module carries the same setting in its own `.bazelrc`, so both
roots are guarded. It needs its own copy because Bazel reads the `.bazelrc` of
the module root it was invoked in: the repository root's setting does not reach
a separate module. Without that file the consumer module would fall back to the
default mode, which rewrites a stale lock without reporting anything.

## Changing a pin

Refreshing the locks after a dependency change is two invocations, one per
module root:

```shell
bazel mod deps --lockfile_mode=update
```

Run it in the repository root and in `e2e/smoke/`, and commit both locks. The
error mode makes a forgotten refresh fail loudly on the next build rather than
producing a drifted checkout.

## Development-only pins

The Node.js toolchain registration, the test-only Yarn distribution, the
platforms module and the testing framework are all declared as development
dependencies of the root module: they are needed to build and test the ruleset,
not to consume it. A consumer supplies its own Node.js toolchain and declares its
own Yarn version.
