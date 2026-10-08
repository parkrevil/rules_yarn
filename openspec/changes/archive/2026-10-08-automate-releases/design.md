## Context

`release.yml` runs on a pushed `v*.*.*` tag and calls
`bazel-contrib/.github`'s `release_ruleset.yaml` (v7.7.0), then `publish.yaml`,
which calls `publish-to-bcr` v1.5.0 with `draft: true`. `release_prep.sh` is
what `release_ruleset.yaml` runs to build the archives and the notes.

## Evidence

**The template.** `bazel-contrib/rules-template` at `cb8787e7`:
- `tag.yaml` runs on `schedule` (`0 15 * * *`) and `workflow_dispatch`; on the
  schedule it skips when `git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*'`
  finds a tag under 1209600 s old ("a trade-off between making too many
  releases, which overwhelms BCR maintainers ..., and releasing too
  infrequently"); it runs `smlx/ccv@v0.10.0` with `fetch-depth: 0` and calls
  `./.github/workflows/release.yaml` with `new-tag-version` when `new-tag` is
  `true` and `new-tag-version-type` is not `major`.
- `release.yaml` takes `workflow_call` with `tag_name` and `publish_token` as
  well as tag pushes, calls `release_ruleset.yaml@v7.7.0` with `draft: true`
  "to support immutable GitHub releases", then `publish.yaml`, then a
  `finalize` job running `softprops/action-gh-release` v3.0.1 on the tag.
- `publish.yaml` says modules under personal accounts should keep
  `draft: true`, which this repository's does.

**`smlx/ccv` v0.10.0** (`7318e2f2`, `ccv.go`, `entrypoint.sh`,
`action.yaml`): with no tag in the repository it answers `v0.1.0` of type
`minor`; otherwise it walks back to the latest tag and bumps the major version
for `feat!:`, `fix!:` or `BREAKING CHANGE: `, the minor for `feat:` and the
patch for `fix:`, scopes allowed; other types bump nothing, and an existing
tag gives `new-tag=false`. It pushes the tag with `git push --tags` when
`write-tag` is true (the default), and outputs `new-tag`,
`new-tag-version` and `new-tag-version-type`. The README shows `write-tag:
false` for a read-only check.

**Why the tag workflow calls the release itself.** GitHub's documentation
(`data/reusables/actions/actions-do-not-trigger-workflows.md` in github/docs,
`24a7a1dc`): "events triggered by the `GITHUB_TOKEN` will not create a new
workflow run", `workflow_dispatch` and `repository_dispatch` excepted, so by
that documentation a tag pushed by a workflow would not start `release.yml`.
Passing secrets on: `jobs.<job_id>.secrets.inherit` "pass[es] all the calling
workflow's secrets to the called workflow" (`workflow-syntax.md`,
`c67a9362`).

**What `release_ruleset.yaml` passes.** At v7.7.0 it checks out
`inputs.tag_name` and runs `.github/workflows/release_prep.sh ${{
inputs.tag_name || github.ref_name }}`; in a run started by `tag.yaml`,
`GITHUB_REF_NAME` is `main`.

**This repository.** Immutable releases are off
(`GET /repos/parkrevil/rules_yarn/immutable-releases`: `enabled: false`);
`BCR_PUBLISH_TOKEN` is set; commits are checked by `commitizen` at
commit-msg.

## Decisions

**Follow the template's three workflows**, every action pinned by commit:
`actions/checkout` v7.0.1 as the repository pins it, `smlx/ccv` v0.10.0 at
`7318e2f2`, `softprops/action-gh-release` v3.0.1 at `718ea10b` (the commit its
annotated tag points to). `release.yml` gains `workflow_call`, `draft: true`
and `finalize`: with immutable releases off a draft is not required, but a
release then stays a draft until the registry entry has been offered, instead
of appearing published before it, and turning immutable releases on later
needs no change. action-gh-release v3.0.1 reuses the draft for the tag and,
with `draft` omitted, publishes it.

**Major versions stay a person's decision, and leave no tag.** The template
lets `ccv` push every tag and then skips releasing a major one, which leaves
that tag behind unreleased — a tag nothing will release, and the latest tag
for the two-week check and the next bump. Here `ccv` runs with `write-tag:
false`, and `tag.yaml` pushes the tag itself for a minor or patch version
only; for a major one it reports the version, and a person pushing that tag
starts `release.yml`.

**Secrets by inheritance.** The template passes the token as a declared
`publish_token` with `secrets.publish_token || secrets.BCR_PUBLISH_TOKEN` for
the tag-push case; `actionlint` reports the second name as undefined, because
a workflow that declares its `workflow_call` secrets sees only those — and the
existing `publish.yaml` already had that expression. `tag.yaml` and
`release.yml` instead call with `secrets: inherit`, and the workflows read
`BCR_PUBLISH_TOKEN` under its own name, the same on a tag push, a call and a
dispatch.

**A retried publish names its release run.** `publish-to-bcr` takes the
release files and attestations from `release_artifacts_run_id`, by default
the current run; a dispatched retry has none, and the draft release's files
cannot be fetched by URL, as its own input documentation says. The dispatch
now asks for the release run's id.

**Main only, one run at a time.** `tag.yaml`'s job runs only on
`refs/heads/main`, and a `concurrency` group keeps a second run from tagging
the same commits.

**The tag comes from the caller.** `release_prep.sh` takes it as `$1`, the
way `release_ruleset.yaml` calls it; the CI step that builds the release
archives passes it the same way.

**The release's tests skip the network-blocking ones.** `release_ruleset.yaml`
re-runs `bazel test //...` on the tagged commit. In the first dispatched run
(37758860778) Bazel there used `processwrapper-sandbox`, which does not honour
the `block-network` tag, and `//tests/launcher:yarn_offline_test`, which
asserts that the network is blocked, was the one test of 41 to fail; on the
same runner image CI measured AppArmor refusing unprivileged user namespaces,
which the Linux sandbox needs, until it lowers that setting (run
37758005119). `ci.yml` lifts that restriction and runs
those tests on every push, so `release.yml` passes `bazel_test_command: bazel
test --test_tag_filters=-block-network //...`, the input the workflow offers
for it.

**A failed release can be run again** for its tag: `release.yml` also takes
`workflow_dispatch` with the tag, since the tag already exists and a tag pushed
by the workflow starts nothing.

**A read-only check on every push.** A CI job of its own — `ccv` is a Docker
action, so Linux only, and needs the full history and tags — runs it with
`write-tag: false` and writes the version the next release would get to the
job summary; it does not fail the run, since a branch that forked before
the first tag has no tag to start from, which `ccv` reports as an error.

**`actionlint` through its official pre-commit hook** (`rhysd/actionlint`
`.pre-commit-hooks.yaml` at v1.7.12), pinned by `rev` like the other hooks, so
pre-commit and CI's `checks` job lint every workflow.

## Risks / Trade-offs

- A commit that is not `feat`, `fix` or breaking releases nothing; `perf`,
  `refactor` and the like wait for the next one that is.
- Limit: the first real run is the proof that the chain works — tag, release,
  registry pull request. Until a run reaches the registry, only the read-only
  check and the local release build are shown.
- The registry pull request is still opened as a draft, which a person marks
  ready; `publish-to-bcr` explains that this is how the author's own approval
  is given.
- The first run tags `v0.1.0` whatever the commits are, since there is no
  tag yet.
- A breaking change holds every release after it: `ccv` gives a major
  version priority over a minor or patch one, and that version is left to a
  person, so the daily run reports it again until its tag is pushed — before
  1.0 too, where it is `v1.0.0`.
- The template also checks pull request titles
  (`conventional-commits.yaml`), for repositories that squash-merge; this one
  fast-forwards `main` and has `commitizen` check every message at
  commit-msg, so the check is not added. A message that bypasses the hook
  (`--no-verify`, an edit on github.com) and is not a `feat` or `fix` in form
  releases nothing; CI's next-release job shows that on the push that
  carries it.
- A publish retry takes the files from the run that built them through
  `publish-to-bcr`'s artifact download, which GitHub keeps 90 days; a later
  retry has none to take.
- A publish that fails leaves the release a draft; retrying `publish.yaml`
  with the id of the run that built the files — the Tag a release run, or the
  Release run for a pushed tag — then `finalize`'s publication by hand,
  finishes it.
- Limit: `smlx/ccv`'s image pins its Alpine base by digest but installs `go`
  and `git` with `apk` unpinned.
- GitHub disables a scheduled workflow after 60 days without repository
  activity; a dispatch still runs it.
