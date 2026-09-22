---
type: concept
title: Public API surface
description: What consumers of rules_yarn may depend on — the yarn_binary rule, the yarn module extension, and the repository they produce — and the load-visibility boundary that keeps everything else internal.
tags: [public-api, starlark, visibility, bzl-library, consumer-contract]
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T15:40:20.833Z
sources:
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
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
  - id: openwiki-source-77af9b38275467de97821b41
    resource: repo://yarn/private/repositories.bzl
  - id: openwiki-source-d9081795909674dafc7044aa
    resource: repo://yarn/private/yarn_binary.bzl
generated: { by: "claude-code", at: "2026-09-21T15:40:20.833Z" }
---

# Public API surface

The ruleset exposes two symbols and one generated repository. Everything else is
an implementation detail, and that statement is enforced by the build rather
than by convention.

## The surface

| Entry point | Symbol | What a consumer does with it |
| --- | --- | --- |
| `@rules_yarn//yarn:defs.bzl` | `yarn_binary` | declares a runnable Yarn target in a `BUILD.bazel` file |
| `@rules_yarn//yarn:extensions.bzl` | `yarn` | declares which Yarn version to fetch, in `MODULE.bazel` |
| the extension's repository | `@yarn` | the label passed to `yarn_binary`'s `yarn` attribute |

Both `.bzl` files are thin: each loads the private implementation and rebinds
it under a public name. That indirection is the seam — the implementation can
move or change shape inside `yarn/private/` without changing the label a
consumer loads.

The public files carry the consumer-facing documentation. The extension file
documents the `MODULE.bazel` snippet; the rule and tag class carry `doc` strings
describing attributes, repository naming, and the guarantees and non-guarantees
of running Yarn this way.

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

## Dependency description

Each public file has a matching `bzl_library` target declaring its transitive
`.bzl` dependencies — `defs` depends on the private rule library, `extensions`
on the private extension library, which in turn depends on the repository and
version libraries. These targets are publicly visible and exist so downstream
tooling can describe the Starlark dependency graph.

## What is deliberately not public

The version table, the URL template, the repository rule, the module extension
implementation, the rule implementation, and the launcher template are all
internal. A consumer cannot read the supported version list from Starlark or
instantiate the repository rule directly; the supported set is reachable only by
declaring a version and being told whether it is accepted.

## Stability consequences

Because the entry point is a rule attribute taking a label — not a toolchain
type — a consumer's `BUILD.bazel` names the distribution explicitly. Changing
that shape would be a breaking change to every consumer, which is the main
reason the public surface is kept this small.
