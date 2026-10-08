## 1. Plan

- [x] 1.1 A reviewer without this conversation reviews the plan before code;
  each finding checked and recorded here.
  - 2026-10-08: no blocker; the evidence checked against the template,
    ccv's source, release_ruleset, publish-to-bcr v1.5.0 and
    action-gh-release v3.0.1, which publishes a reused draft when `draft` is
    omitted. Should-fixes, all taken: the secret reaching the publish job
    under every trigger (done by `secrets: inherit`, after `actionlint`
    rejected the template's fallback); a dispatched publish naming its
    release run; no tag left for a major version; `tag.yaml` on main only,
    one run at a time; the CI check a Linux job with full history; actions
    pinned by commit; `actionlint` pinned. Nits taken: the called workflow's
    real name, the 60-day schedule rule, the docs-based claim stated as such,
    the first run's `v0.1.0`, and `finalize`'s publication recorded in 3.4.

## 2. Change

- [x] 2.1 `release_prep.sh` takes the tag as `$1`; the CI release step passes
  it. Red: with `GITHUB_REF_NAME=main` and the tag as `$1`, the script before
  the change built `rules_yarn-main.tar.gz`; after it,
  `rules_yarn-v0.0.0-green.tar.gz`, its docs archive and the notes.
- [x] 2.2 `release.yml`: `workflow_call`, `draft: true`, `finalize`, secrets
  inherited; `publish.yaml` reads `BCR_PUBLISH_TOKEN` and its dispatch takes
  `release_artifacts_run_id`.
- [x] 2.3 `tag.yaml` as the template's, the tag written for minor and patch
  versions only, main only, one run at a time.
- [x] 2.4 CI: the read-only `ccv` job.
- [x] 2.5 Every workflow passes `actionlint`, through its official pre-commit
  hook at v1.7.12, pinned like the other hooks. Red: it rejected the
  `secrets.publish_token || secrets.BCR_PUBLISH_TOKEN` fallback in
  `publish.yaml` and `release.yml`.
- [x] 2.6 README and the publishing wiki page describe automatic releases.

## 3. Gate

- [ ] 3.1 Every root builds and tests; pre-commit; `openspec validate --all
  --strict`; CI on the branch, the read-only `ccv` check included.
- [x] 3.2 The wiki is regenerated and the staleness gate passes.
- [x] 3.3 A reviewer without this conversation reviews the change; each
  finding checked and recorded.
  - 2026-10-08: no blocker; `ccv` with `write-tag: false` still emits its
    outputs, the tag push authenticates with checkout's credentials, and the
    permissions, secrets, triggers and `finalize` were each checked against
    their sources. Should-fixes taken: that a breaking change holds every
    later release is stated in the design and README; dropping the
    template's pull request title check is recorded with why. Nits taken:
    the retry input names the right run; the next-release job reports
    instead of failing when `ccv` finds no tag behind the branch; the
    90-day artifact limit on a retry is stated. Left: a dispatch from
    another branch shows a run that did nothing, which is what its `if`
    says.
- [ ] 3.4 After the merge, `tag.yaml` dispatched once: the tag, the release
  with both archives published by `finalize`, and the registry pull request
  recorded.
