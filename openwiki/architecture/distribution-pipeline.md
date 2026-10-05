---
type: architecture
title: Yarn distribution pipeline
description: How rules_yarn turns a version string in MODULE.bazel into a Bazel target, covering tag collection and version selection in the module extension, the integrity-checked download in the repository rule, and the filegroup it generates.
tags: [module-extension, repository-rule, bzlmod, integrity, version-selection]
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
generated: { by: "claude-code", at: "2026-10-04T12:22:38.266Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-04T18:04:16.838Z
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
| Which versions may be requested at all | `yarn/private/versions.bzl` | URL template, digest table, and each version's cache version |

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
`os_dependent = False` and `arch_dependent = False`, and its metadata is marked
reproducible. Nothing about the host changes which repositories it defines;
an install repository does depend on the host, which is why that repository,
unlike this one, is not marked reproducible.

## The same extension creates installs

The `yarn` extension has a second tag class, `install`, for installing a
project's locked dependencies; [Installing a project's
dependencies](dependency-installation.md) covers it. Its part here is small.
`select_installs` accepts install tags only from the root module, requires
their names to be distinct and different from every distribution's, and
requires the distribution each names to exist. Each selected install then
names the Yarn it runs by repository, and takes from `versions.bzl` the cache
version recorded beside that Yarn's digest — the number Yarn's lockfile cache
key starts with — so a lockfile written for another Yarn is refused.

## What the extension tells Bazel about itself

Alongside reproducibility, the extension reports which repositories the root
module asked it to create — distributions and installs alike. Bazel checks
that report against the root module's
`use_repo` line, and `bazel mod tidy` writes the line from it — so a consumer
who forgets `use_repo(yarn, "yarn")` can have it filled in rather than having
to work out the name.

The report is split in two, regular and development-only, because Bazel keeps
those apart and a repository has to appear in the list matching how the root
module declared the extension. `root_repositories` makes that split with
`module_ctx.is_dev_dependency`, considering only the root module's tags — a
repository a dependency asked for is not a direct dependency of the root — and
counting a repository declared both ways as regular.

The split is not a nicety. This repository's own root module declares the
extension with `dev_dependency = True`, so reporting every root declaration as
regular fails its build outright, with Bazel refusing a non-empty regular list
when the root has no regular usage.

What the report does not change is the error a consumer sees when `use_repo` is
missing: that is still Bazel's own "no repository visible as `@yarn`", raised
before the report is consulted.

## Failure behavior

Every selection failure aborts extension evaluation with a message naming the
offending module (the root module is described as such; others by name and
version). Download failures are Bazel's own: a digest mismatch fails the fetch
rather than producing a repository with unexpected contents.

## Tests that hold this

`tests/extensions/extensions_tests.bzl` covers both halves with hand-built
module and tag structs. For selection: default naming, duplicate identical
declarations, root beating a dependency, closest-dependency-wins when the root
is silent, ignored declarations escaping validation, root-only custom names,
and the three failure messages verbatim. For installs: a root install
selected, and the four refusals — an install in a dependency, a repeated
name, a name a distribution has, an unknown distribution. For the report: a regular
declaration, a development-only one, the same repository declared both ways, a
declaration by a dependency rather than the root, a declaration for a
repository the extension did not create, and the same repository declared
twice, and an install reported like a distribution.

`tests/repositories/repositories_tests.bzl` drives the repository
implementation against a mock context, asserting the call order (`download` then
`file`), the exact keyword arguments passed to `download`, the generated BUILD
content, and the reproducibility metadata. A second test asserts every recorded
version carries a digest with a recognized hash prefix and that the URL template
expands as expected.
