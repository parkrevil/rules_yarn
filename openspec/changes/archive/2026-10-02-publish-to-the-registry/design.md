## Context

See proposal.md — Why. Every decision here was taken from the registry's own
documentation and from a real, current registry entry, rather than from
memory: `rules_shell@0.8.0`, which this ruleset already depends on.

## Goals / Non-Goals

Goals:

- A consumer can depend on `rules_yarn` the way they depend on any other
  ruleset, and can pin a version.
- Nothing about the release is hand-made at release time.

Non-Goals:

- Widening what the ruleset does. See the proposal's out-of-scope section.
- Publishing. The two steps that need repository secrets and a pull request
  against a third-party repository are left to whoever holds those.

## Decisions

### `module()` keeps a placeholder version

`rules_shell`'s repository declares `version = "0.0.0"` at its released tag,
while its registry entry declares `0.8.0`; the difference is a
`module_dot_bazel_version.patch` listed in that entry's `source.json`.
`publish-to-bcr` generates that patch. So the version does not belong in the
repository, and stamping it at release time would be work the automation
already does.

### The release archive is built by the repository, not by GitHub

The registry validates that a GitHub source-archive URL is stable, and
GitHub's generated archives are not. `rules_shell` therefore publishes
`rules_shell-v0.8.0.tar.gz` as a release asset built with `git archive`.
`.github/workflows/release_prep.sh` does the same, with the prefix
`rules_yarn-<version>` so it matches what a generated archive would have had
and a consumer can move between the two without changing `strip_prefix`.

Its path is `.github/workflows/release_prep.sh` because the reusable workflow
hard-codes it — deliberately, so the script that prepares a release is
attestable from the repository rather than supplied at dispatch time.

### `.gitattributes` keeps development tooling out of the archive

The archive is what every consumer downloads and what the presubmit extracts.
Measured on the staged tree: without `export-ignore` it holds 241 files, of
which 110 are agent tooling, the OpenSpec planning record and the generated
wiki. With it, 54 files and 316 KB, still carrying the ruleset, both test
modules, the documentation and the licence.

`rules_shell` ships everything, having no `.gitattributes`. That is a
defensible default for a repository without this one's volume of tooling.

### The registry's test module is its own module

The registry documentation calls a test module "highly recommended", and says
it may depend on the module under test with `local_path_override` — which
settles a worry recorded in the bootstrap change's design, that a presubmit
would replace the override. It does not.

The worry's conclusion was right for a different reason. `e2e/smoke` pins a
lockfile and sets `--lockfile_mode=error`; the presubmit matrix runs several
Bazel versions, and a lockfile written by one of them fails under another. So
`tests/bcr` is separate and keeps no lockfile, resolving from scratch each
time. `rules_shell` does the same, with `tests/bcr` beside its own `e2e`.

It is also deliberately small — build the Yarn target through the public API
and run `--version`. The presubmit's job is to show the published module works
as a dependency, not to re-run this repository's test suite, and a test that
depends on sandbox capabilities the registry's machines may not have would
fail for reasons that say nothing about the module.

### The presubmit matrix

Linux and macOS, because those are the platforms the ruleset claims; Windows
is excluded because the launcher is a Bash script. Bazel `8.x` and `9.x`,
matching the declared floor and the line it is developed on. Both were run
locally against `tests/bcr` before being written down.

## Risks / Trade-offs

- [The workflows cannot be verified without a tag] → Everything under them
  was run: `release_prep.sh` against a tag, producing an archive whose
  contents were inspected; both reusable workflows pinned to versions
  resolved from their repositories; the test module run under both Bazel
  versions in the matrix. What remains is the release itself.
- [`registry_fork` names a fork that does not exist yet] → It is required by
  the reusable workflow and cannot be created from here. It is recorded in the
  tasks as a step for whoever publishes.
- [The maintainer's email address becomes public in the registry entry] →
  It is in `.bcr/metadata.template.json` because the registry emails
  maintainers when a release fails. Nothing is published yet, so it can be
  changed before the first submission.

## Migration Plan

For an existing consumer using `local_path_override`: none, that keeps
working. Once a version is in the registry, the override can be deleted.
