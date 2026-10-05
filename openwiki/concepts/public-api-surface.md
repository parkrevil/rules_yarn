---
type: concept
title: Public API surface
description: What consumers of rules_yarn may depend on — the yarn_binary rule, the yarn module extension, and the repository they produce — and the load-visibility boundary that keeps everything else internal.
tags: [public-api, starlark, visibility, bzl-library, consumer-contract]
sources:
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
  - id: openwiki-source-d92bdd4d3d554717b6869e2d
    resource: repo://MODULE.bazel
  - id: openwiki-source-b24cb6f741eb257166e5a139
    resource: repo://yarn/BUILD.bazel
  - id: openwiki-source-044df30840b4f85a8f7d705c
    resource: repo://yarn/defs.bzl
  - id: openwiki-source-0cac83747c9667016d88977f
    resource: repo://yarn/extensions.bzl
  - id: openwiki-source-389aae0621c075486ee3c083
    resource: repo://yarn/private/BUILD.bazel
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
  - id: openwiki-source-9e1e67b90ea3e259fedb1f39
    resource: repo://yarn/private/install/node_modules.bzl
  - id: openwiki-source-6da6376cacb3a4c5f3725a78
    resource: repo://yarn/private/install/repository.bzl
  - id: openwiki-source-77af9b38275467de97821b41
    resource: repo://yarn/private/repositories.bzl
  - id: openwiki-source-d9081795909674dafc7044aa
    resource: repo://yarn/private/yarn_binary.bzl
  - id: openwiki-source-60f4d0e18953b7fc477fc496
    resource: repo://yarn/providers.bzl
generated: { by: "claude-code", at: "2026-10-04T12:22:38.266Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-04T18:04:16.838Z
---

# Public API surface

The ruleset exposes three symbols and two kinds of generated repository.
Everything else is an implementation detail, and that statement is enforced by
the build rather than by convention.

## The surface

| Entry point | Symbol | What a consumer does with it |
| --- | --- | --- |
| `@rules_yarn//yarn:defs.bzl` | `yarn_binary` | declares a runnable Yarn target in a `BUILD.bazel` file |
| `@rules_yarn//yarn:extensions.bzl` | `yarn` | declares which Yarn version to fetch (`yarn.distribution`) and which projects to install (`yarn.install`), in `MODULE.bazel` |
| `@rules_yarn//yarn:providers.bzl` | `YarnNodeModulesInfo` | reads an installed tree from a rule of its own |
| a distribution repository | `@yarn` | the label passed to `yarn_binary`'s `yarn` attribute |
| an install repository | `@<name>//:node_modules`, `@<name>//:pin` | the installed tree as artifacts, carrying `YarnNodeModulesInfo`; the command that writes the pin file |

`defs.bzl` and `extensions.bzl` are thin: each loads the private
implementation and rebinds it under a public name. That indirection is the seam — the implementation can
move or change shape inside `yarn/private/` without changing the label a
consumer loads.

`providers.bzl` is different: it defines the provider itself rather than
rebinding one. A provider's identity is the file that defines it, so a
provider defined in a private file could not be named by a consumer's rule at
all; defining it in the public directory is what makes the installed tree
usable from outside.

The public files carry the consumer-facing documentation. The extension file
documents the `MODULE.bazel` snippets for a distribution and an install; the
rule and both tag classes carry `doc` strings describing attributes,
repository naming, and the guarantees and non-guarantees of each.

## The boundary

Three mechanisms keep `yarn/private/` private, and they operate at different
layers:

- **Load visibility.** Every private `.bzl` file declares
  `visibility(["//tests/...", "//yarn/..."])`. Bazel enforces this by default;
  a package outside those patterns that tries to load one fails during loading
  with a `.bzl` load visibility violation, not at analysis or run time.
- **Target visibility.** Only the two `bzl_library` targets that back a public
  file — the extension and the rule — are exposed to `//yarn`. The repository
  and version libraries declare no visibility at all, so they stay private to
  `//yarn/private` and are reachable only from inside that package; the launcher
  template is exported privately as well.
- **Package layout.** The public directory contains no implementation, so there
  is nothing in it to depend on accidentally.

One private file has to be loaded from outside the ruleset: the rule an install
repository instantiates, `node_modules.bzl`, which declares
`visibility("private")`. A generated repository is not a package of the
ruleset, so no load-visibility list could admit it without admitting every
consumer. Instead each install repository holds a symlink to the file at its
own root and loads it from its own root package — a load from the same
package, which private visibility allows. A consumer's package loading it is
still refused.

## Dependency description

Each public file has a matching `bzl_library` target declaring its transitive
`.bzl` dependencies — `defs` depends on the private rule library, `extensions`
on the private extension library, which in turn depends on the repository and
version libraries and the two install repository rules; `providers` has no
dependencies. These targets are publicly visible and exist so downstream
tooling can describe the Starlark dependency graph.

## What is deliberately not public

The version table, the URL template, the repository rules, the module
extension implementation, the rule implementations, the install driver and its
modules, and the launcher template are all internal. A consumer cannot read the supported version list from Starlark or
instantiate the repository rule directly; the supported set is reachable only by
declaring a version and being told whether it is accepted.

## What the consumer has to bring

Two things, and the module says both so a consumer is told rather than left to
find out.

`MODULE.bazel` declares `bazel_compatibility = [">=8.3.0"]`. Below that, Bazel
refuses the module while resolving the graph, naming this ruleset and the
version it needs; without the declaration the same consumer would instead hit
a Starlark error inside a private file of a ruleset they did not write, about
an API they never called. The floor is where `repository_ctx.repo_metadata`
arrives, which the repository rule uses.

A Node.js runtime toolchain, from `rules_nodejs`, has to be registered. The
rule takes the runtime from `@rules_nodejs//nodejs:runtime_toolchain_type` and
fails analysis if the resolved toolchain carries only a host path. An install
unpacks its packages with actions on `@rules_nodejs//nodejs:toolchain_type`,
the exec toolchain, and refuses a host-path toolchain the same way. The install
repository itself runs before toolchain resolution exists, so it takes Node.js
from the four per-platform repositories `rules_nodejs` creates for its default
toolchain, which `rules_yarn` names itself.

## Stability consequences

Because the entry point is a rule attribute taking a label — not a toolchain
type — a consumer's `BUILD.bazel` names the distribution explicitly. Changing
that shape would be a breaking change to every consumer, which is the main
reason the public surface is kept this small.
