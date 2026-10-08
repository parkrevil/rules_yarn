## Why

A release needs a person to pick a version and push a tag: `release.yml`
starts only on a pushed `v*.*.*` tag. The official template for Bazel
rulesets, `bazel-contrib/rules-template` (commit `cb8787e7`, 2026-07-01),
tags releases itself: `.github/workflows/tag.yaml` derives the next version
from Conventional Commits with `smlx/ccv`, daily and on demand, and calls the
release and publish workflows. This repository already requires Conventional
Commits (the `commitizen` commit-msg hook) but has no such workflow.

`release_prep.sh` also reads the tag from `GITHUB_REF_NAME`, which is the tag
only when a tag push started the run; called from another workflow, it is
the branch, and the archive would be built from the wrong ref.

## What Changes

- `.github/workflows/tag.yaml`, as the template's: daily at 15:00 UTC and on
  `workflow_dispatch`; on the schedule it does nothing if the latest release
  tag is under two weeks old; `smlx/ccv` v0.10.0 writes the next tag when a
  `feat`, `fix` or breaking commit has landed since the last one, and the
  release workflow is called with it unless it is a major version.
- `release.yml` can be called with a tag, as well as started by a pushed
  one; it creates the release as a draft and publishes it after the registry
  entry is offered, as the template's does.
- `release_prep.sh` takes the tag as its first argument, as
  `release_ruleset.yaml` passes it and the template's script reads it.
- CI computes, read-only, the tag the next release would get, so the tagging
  action runs on every push without writing anything.

No behaviour of the ruleset changes, so no spec changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

`.github/workflows/`, README's release notes, the publishing wiki page.
