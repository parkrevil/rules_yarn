## Why

AGENTS.md requires `bazel build //... && bazel test //...` to pass in both
build roots before every commit, and a reviewer to have seen the change.
Nothing enforces any of it. `.github/workflows/` holds one workflow, which
regenerates the wiki. The repository's own generated documentation already
says so: `openwiki/workflows/development-workflow.md` lists the build and test
gate under "What is not enforced".

Two things follow from having no gate. A commit that breaks either root is
found by whoever next runs the build by hand. And the ruleset's declared
support — Bazel 8.3.0 and up, and a platform claim that stops at Linux — rests
on runs recorded in change documents, which are a record of the past rather
than a check on the present.

## What Changes

- Add `.github/workflows/ci.yml`, running on push and pull request:
  - **build and test** on `ubuntu-latest` and `macos-latest`, over both build
    roots. macOS has never been run; this is the first time the claim is
    tested rather than assumed.
  - **oldest supported Bazel**: a consumer module resolving from scratch under
    the floor `MODULE.bazel` declares, built and run.
  - **checks**: the pre-commit hooks, which cover Buildifier and its linter,
    the file-hygiene hooks and `openspec validate --all --strict`, plus the
    generated-file guard's contract test.
- Add `tools/ci/minimum_bazel.sh`, which the floor job runs. The logic lives
  in the repository rather than in the workflow, so it can be run locally —
  and it was.
- Correct the tag comment on the pinned `actions/checkout` in the OpenWiki
  workflow: the commit is `v4.3.1`, and the comment said `v4`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Continuous integration checks the behavior the specification already
requires; it does not change what the ruleset does or what a consumer
observes. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- New `.github/workflows/ci.yml` and `tools/ci/minimum_bazel.sh`.
- One comment in `.github/workflows/openwiki-update.yml`.
- No Bazel target, no public API, and no pin is affected.
- Expect the macOS job to report something. Two tests assert that the sandbox
  blocks the network, which is a Linux sandbox feature; if macOS does not
  honour it they fail with their own message. That is the job doing its work,
  and it is left to report rather than guessed at in advance.
