---
type: operations
title: Releasing and publishing
description: How a release is cut and offered to the Bazel Central Registry — the .bcr templates, the archive the repository builds rather than taking from GitHub, the module the registry presubmit runs, and what is still missing before a first publication.
tags: [release, registry, bcr, distribution, bzlmod]
sources:
  - id: openwiki-source-d3c2a83adfd3b7d09ba44bdc
    resource: repo://.bcr/config.yml
  - id: openwiki-source-331f6f4a0b2380f0979a754b
    resource: repo://.bcr/metadata.template.json
  - id: openwiki-source-a996efa61d56b86aea305719
    resource: repo://.bcr/presubmit.yml
  - id: openwiki-source-ae6030fc095fa5ef42eeec52
    resource: repo://.bcr/source.template.json
  - id: openwiki-source-3c099d9af7cba6b30d6eaf07
    resource: repo://.gitattributes
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-70ab0363e4be6caa7ada8f8a
    resource: repo://.github/workflows/publish.yaml
  - id: openwiki-source-38d051cbfe080f7c7cfd32b8
    resource: repo://.github/workflows/release_docs.sh
  - id: openwiki-source-dbe15c01c777baeb41e77f3c
    resource: repo://.github/workflows/release_prep.sh
  - id: openwiki-source-4d1d392666be6dfdd7a91a2e
    resource: repo://.github/workflows/release.yml
  - id: openwiki-source-685d1e99022c20c7bfd21b06
    resource: repo://.github/workflows/tag.yaml
  - id: openwiki-source-bc52b7fdf1f189e434bbea21
    resource: repo://e2e/smoke/.bazelrc
  - id: openwiki-source-d92bdd4d3d554717b6869e2d
    resource: repo://MODULE.bazel
  - id: openwiki-source-63ce3ef0151d26335584ed2e
    resource: repo://openspec/changes/archive/2026-10-02-publish-to-the-registry/design.md
  - id: openwiki-source-b270a5545803bfbe1ddaeeb8
    resource: repo://openspec/changes/automate-releases/design.md
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
  - id: openwiki-source-01bd775b2b199eca72dcc70e
    resource: repo://tests/bcr/.bazelrc
  - id: openwiki-source-9396675ac7636781156cad60
    resource: repo://tests/bcr/MODULE.bazel
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
generated: { by: "claude-code", at: "2026-10-08T09:37:10.868Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-08T09:37:10.868Z
---

# Releasing and publishing

Nothing is published yet. A consumer today adds a non-registry override, and
because an override only takes effect in the root module, a module that
depends on `rules_yarn` cannot pass it on — every root module downstream has
to repeat it. Removing that is what this apparatus exists for.

Everything below is in place; the token publishing needs is set. What has
been exercised and what only a first release will show is said where it
matters.

## What tags a release

`.github/workflows/tag.yaml`, as in `bazel-contrib/rules-template`, runs daily
at 15:00 UTC and whenever it is dispatched, on `main` only and one run at a
time. `smlx/ccv` works out the next version from the Conventional Commits
since the last tag — a `feat` a minor version, a `fix` a patch, a breaking
change a major one, anything else none, and `v0.1.0` while there is no tag.
For a minor or patch version the workflow pushes the tag and calls
`release.yml` with it, because a tag pushed with the workflow token starts no
run of its own. A major version it reports and leaves to a person, whose
pushed tag starts `release.yml` directly; the template's way, where `ccv`
pushes every tag, would leave an unreleased major tag behind. Until that tag
is pushed no minor or patch release is cut either, since `ccv` ranks the
breaking commit first. The daily run
does nothing within two weeks of the last tag. A CI job works out the same
version on every push without writing a tag.

## What a tag sets off

`.github/workflows/release.yml`, started by a pushed `v*.*.*` tag or called by
`tag.yaml`, runs three jobs in sequence.

The first calls the reusable release workflow from `bazel-contrib/.github`.
That workflow runs the repository's tests, then calls
`.github/workflows/release_prep.sh` — a path it hard-codes, deliberately, so
the script that prepares a release is attestable from the repository rather
than supplied when the workflow is dispatched. The script builds the archive
with `git archive`, computes its digest, has `release_docs.sh` build the
archive of the public API's documentation beside it, and prints the release
notes, which the workflow puts on the GitHub release along with both
archives.

`release_docs.sh` follows the registry's recipe (`docs/stardoc.md` of the
Bazel Central Registry): it builds every `starlark_doc_extract` target — one
per public `.bzl` file — in an output base of its own and archives that
`bazel-bin` as `rules_yarn-<tag>.docs.tar.gz`, writing nothing to standard
output, which is the release notes. The workflow's `rules_yarn-*.tar.gz`
uploads it, and its attestation step attests every uploaded file.

The release is created as a draft. The second job calls the registry's own
publishing workflow from `bazel-contrib/publish-to-bcr`, which reads the
templates under `.bcr/`, forms a registry entry for the tag, uploads the
attestations to the draft, and opens a pull request against the Bazel Central
Registry from a fork. The third, `finalize`, publishes the draft. A publish
that fails leaves the release a draft; `publish.yaml` can be dispatched again
with the release run's id, since a draft's files cannot be fetched by URL.
The secret reaches every job as `BCR_PUBLISH_TOKEN`, passed on with `secrets:
inherit`.

## Why the archive is built here

GitHub generates a source archive for every tag, and the registry checks that
a GitHub archive URL is stable. The generated ones are not, so the repository
builds its own and attaches it to the release — the same arrangement
`rules_shell` uses.

The prefix inside the archive is `rules_yarn-<version>`, matching what a
generated archive would have had, so a consumer can move between the two
without changing `strip_prefix`.

`.gitattributes` decides what the archive carries. The agent tooling, the
OpenSpec planning record and the generated wiki are marked `export-ignore`:
they are how the repository is developed, not what a consumer builds against.
What remains is the ruleset, its tests and the registry's test module, both
consumer examples — `e2e/smoke` and `e2e/install` — the documentation and the
licence.

## The `.bcr` templates

Four files, the set the publishing automation reads.

| File | What it carries |
| --- | --- |
| `metadata.template.json` | Homepage, maintainers with their numeric GitHub ids, the repository. The version list is filled by the automation. |
| `source.template.json` | Where the archive is, what prefix to strip, and, as `docs_url`, where the documentation archive is, written with the `{OWNER}`, `{REPO}`, `{VERSION}` and `{TAG}` placeholders the automation substitutes. |
| `presubmit.yml` | What the registry runs to check the entry. |
| `config.yml` | That this repository publishes one module, at its root. |

`{VERSION}` is the tag without its leading `v` and `{TAG}` is the whole tag, so
`source.template.json` resolves to the prefix and filename `release_prep.sh`
produces. That correspondence was checked by running the script against a tag
and comparing, not by reading both and assuming. For the documentation archive
CI checks it on every push: the `checks` job runs `release_prep.sh` under a
tag of its own and requires the release notes, the source archive, a
documentation archive holding each public file's binary proto, and a
`docs_url` naming that archive. That the release uploads it and the registry
renders it is shown only by a published release.

## The version placeholder

`MODULE.bazel` declares `version = "0.0.0"`. The registry entry needs the real
version, and the publishing automation supplies it as a generated patch over
the released archive — it recognises the placeholder and writes a patch that
replaces it. So the repository never carries the version of the release being
cut, and no step has to stamp one in.

## What the registry runs

`presubmit.yml` points at `tests/bcr`, a module whose whole job is to show
that a module depending on `rules_yarn` can build a Yarn target through the
public API and run it. The registry extracts the archive, and `tests/bcr`
depends on the module under test with `local_path_override(path = "../..")`,
which lands on the extracted root.

It is separate from `e2e/smoke` for one reason: `e2e/smoke` pins a lockfile
and sets `--lockfile_mode=error`, which is right for checking one
configuration and wrong for a presubmit that runs several Bazel versions. So
`tests/bcr` has its own `.bazelrc` setting `--lockfile_mode=off` and keeps no
lockfile, resolving from scratch every time.

The matrix is Linux and macOS, the platforms this ruleset claims, across
Bazel 8.x and 9.x — the declared floor and the line it is developed on. Both
were run against `tests/bcr` before being written down.

It is deliberately small. The presubmit's job is to show the published module
works as a dependency, not to re-run this repository's suite, and a test
depending on sandbox capabilities the registry's machines may not have would
fail for reasons that say nothing about the module.

## Before a first publication

The `BCR_PUBLISH_TOKEN` secret, a token that can push to the registry fork
and open pull requests, is set, and the fork it pushes to, named in
`publish.yaml`, exists.

The maintainer email in `metadata.template.json` was the other open item. The
registry emails maintainers when a release fails, so it has to be an address
that receives mail, and it becomes public with the entry. The maintainer chose
the personal address now recorded there.

`publish.yaml` leaves the pull request as a draft, which is the automation's
default. The registry auto-approves an entry when its author marks a draft
ready for review, which is how an author gets around not being able to approve
their own; opening it ready, as rulesets publishing under a bot account do,
gives that up.

## What publishing does not change

Being in a registry makes the ruleset dependable — pinnable, and usable
through a dependency rather than only from a root module — but changes nothing
about what it does. A Yarn command run through `yarn_binary` still gets no
caching, sandboxing or dependency-installation guarantees from Bazel; those
come only from `yarn.install`, which only a root module may declare. Windows
is still unsupported, and the version table still records one Yarn version.
