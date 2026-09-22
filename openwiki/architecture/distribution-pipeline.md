---
type: architecture
title: Yarn distribution pipeline
description: How rules_yarn turns a version string in MODULE.bazel into a Bazel target, covering tag collection and version selection in the module extension, the integrity-checked download in the repository rule, and the filegroup it generates.
tags: [module-extension, repository-rule, bzlmod, integrity, version-selection]
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T10:11:59.468Z
sources:
  - id: openwiki-source-42fff598a74b8a8cf6e6de47
    resource: repo://tests/extensions/extensions_tests.bzl
  - id: openwiki-source-ca621fdd9c1fe509f3bed92e
    resource: repo://tests/repositories/repositories_tests.bzl
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
  - id: openwiki-source-77af9b38275467de97821b41
    resource: repo://yarn/private/repositories.bzl
  - id: openwiki-source-847ceba95f7fcfa239c5f25b
    resource: repo://yarn/private/versions.bzl
generated: { by: "claude-code", at: "2026-09-21T10:11:59.468Z" }
---

# Yarn distribution pipeline

The pipeline answers one question: which exact Yarn bundle does a build get, and
how is it proven to be that bundle? It runs entirely in Bazel's external
dependency phase, before any target is analyzed, and it has three stages —
selection, download, exposure.

## Responsibility split

| Stage | Owner | Output |
| --- | --- | --- |
| Which version, under which repository name | `yarn/private/extensions.bzl` | a name → version map |
| Fetching and verifying the bundle | `yarn/private/repositories.bzl` | `yarn.js` plus a generated `BUILD.bazel` |
| Which versions may be requested at all | `yarn/private/versions.bzl` | URL template and digest table |

The three files are private: each declares `visibility(["//tests/...", "//yarn/..."])`,
so only the ruleset's own packages and its tests can load them.

## Stage 1 — selection

`select_distributions` walks `module_ctx.modules`. Bazel supplies that list in
breadth-first order starting at the root module, and the function exploits that
ordering directly: the first module to claim a repository name fixes its
version, and later modules claiming the same name are skipped. The practical
consequence is that the root module's choice always beats a dependency's, and
between two dependencies the one closer to the root wins.

Four rules are enforced while walking, each with a dedicated failure message:

- **Naming.** A module other than the root may not use a repository name other
  than `yarn`. This is Bazel's documented module-extension guidance — a
  dependency that names repositories can collide with a sibling that does the
  same — and it is enforced before anything else in the loop.
- **Internal conflict.** Two `yarn.distribution` tags in the *deciding* module
  that name the same repository with different versions are an error rather than
  a silent last-wins. The check is scoped to the module currently deciding, so
  it never fires on declarations that were already skipped.
- **Supported version.** A requested version must appear in the digest table.
  The failure lists the supported versions, and it happens during extension
  evaluation — no network access is attempted for an unknown version.
- **Ignored declarations are not validated.** A losing declaration is skipped
  before the version check, so a dependency asking for a version this ruleset
  does not know about does not break a build whose root module already decided.

The function takes its failure handler as a parameter (`_fail`), which is what
lets the unit tests drive every branch and assert the exact message without
aborting the test run.

## Stage 2 — download

For each selected entry the extension instantiates the `yarn_distribution`
repository rule with a URL built from the template and the digest recorded for
that version. The rule's implementation is deliberately small: one
`repository_ctx.download` into `yarn.js`, then one generated `BUILD.bazel`.

Both attributes are mandatory, so a repository of this type cannot exist without
a digest. The digest is a Subresource Integrity string; the URL attribute is a
list, so several mirrors serving the identical bundle can be supplied, and Bazel
tries them in order.

The implementation returns `repository_ctx.repo_metadata(reproducible = True)`.
That marks the fetched contents as safe to cache across workspaces, which is
true here precisely because the output is pinned by digest rather than by
whatever the URL happens to serve today.

## Stage 3 — exposure

The generated `BUILD.bazel` contains a single publicly visible `filegroup` named
`yarn` wrapping `yarn.js`. Under the default repository name that target is
addressed as `@yarn`, which is the label a consumer passes to `yarn_binary`. No
rule or provider is generated — the distribution is just a file that something
else knows how to run.

Because the bundle is platform-independent JavaScript, the extension declares
`os_dependent = False` and `arch_dependent = False` and returns
`module_ctx.extension_metadata(reproducible = True)`. There is nothing about the
host that could change what this extension produces.

## Failure behavior

Every selection failure aborts extension evaluation with a message naming the
offending module (the root module is described as such; others by name and
version). Download failures are Bazel's own: a digest mismatch fails the fetch
rather than producing a repository with unexpected contents.

## Tests that hold this

`tests/extensions/extensions_tests.bzl` covers selection with hand-built module
and tag structs — default naming, duplicate identical declarations, root beating
a dependency, closest-dependency-wins when the root is silent, ignored
declarations escaping validation, root-only custom names, and the three failure
messages verbatim.

`tests/repositories/repositories_tests.bzl` drives the repository
implementation against a mock context, asserting the call order (`download` then
`file`), the exact keyword arguments passed to `download`, the generated BUILD
content, and the reproducibility metadata. A second test asserts every recorded
version carries a digest with a recognized hash prefix and that the URL template
expands as expected.
