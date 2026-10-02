## 1. Read the official path first

- [x] 1.1 Establish how a ruleset is published from the registry's own documentation and from a real current entry, not from memory; record what each decision rests on.
  - 2026-10-01: read `bazelbuild/bazel-central-registry`'s `README.md` and `docs/README.md`, and `bazel-contrib/publish-to-bcr`'s `README.md` and `templates/README.md`. Then read the live entry `modules/rules_shell/0.8.0/` — its `MODULE.bazel`, `source.json` and `presubmit.yml` — and the upstream repository at tag `v0.8.0`: `MODULE.bazel`, `.bcr/`, `tests/bcr/`, `.github/workflows/`.
  - What that settled, each against a source: the repository keeps a placeholder version and the entry's real version arrives as `module_dot_bazel_version.patch` (`source.json` of that entry); the archive is built by the repository because the registry checks a GitHub archive URL for stability (`docs/README.md`, Validations); a test module may use `local_path_override` (`docs/README.md`, Test module); `release_prep.sh`'s path is hard-coded by the reusable workflow, deliberately, for attestation (`release_ruleset.yaml@v7.7.0`, comment at the `release_prep_command` input).

## 2. The module and its registry files

- [x] 2.1 Add the placeholder version to `module()`; verify both existing roots still build and test.
- [x] 2.2 Add `.bcr/metadata.template.json`, `source.template.json`, `presubmit.yml` and `config.yml`; verify each parses and the maintainer identity is the real one rather than a template value.
  - 2026-10-01: all four parse. `github_user_id` is 6592422, read from `gh api users/parkrevil`, not guessed.
- [x] 2.3 Pin the reusable workflows to versions resolved from their repositories rather than copied from another ruleset.
  - 2026-10-01: `bazel-contrib/.github@v7.7.0` and `bazel-contrib/publish-to-bcr@v1.5.0`, both the newest tags those repositories list. `rules_shell` pins `v7.2.2` and `v1.1.0`; copying those would have pinned two-year-old automation.

## 3. The registry's test module

- [x] 3.1 Add `tests/bcr/`, separate from `e2e/smoke` and without a lockfile; verify it passes under every Bazel version the presubmit matrix names.
  - 2026-10-01: `bazel test //...` in `tests/bcr` passes under Bazel 9.2.0 and, with `USE_BAZEL_VERSION=8.3.0`, under 8.3.0 — the two lines in the matrix.
- [x] 3.2 Keep the new module out of the root's package discovery; verify the root build, which broke without it.
  - 2026-10-01: before the change, `bazel build //...` in the root failed — it walked into `tests/bcr/bazel-bcr/...`, the convenience symlink left by running Bazel there, and tried to load `@rules_python`. `.bazelignore` now lists `tests/bcr/` beside `e2e/`, and the root builds and passes 23 tests.

## 4. The release

- [x] 4.1 Add `release_prep.sh` and the release workflow; verify the script by running it against a tag and inspecting what it produced, rather than reading it.
  - 2026-10-01: run with `GITHUB_REF_NAME=v0.0.0-test`, it produced `rules_yarn-v0.0.0-test.tar.gz` with prefix `rules_yarn-0.0.0-test/` and printed release notes carrying the `bazel_dep` snippet, an `archive_override` with the computed integrity, and the archive's SHA-256.
  - A first attempt archived a tag created before the new files were committed, so `tests/bcr` was absent from it — a fault in how it was checked, not in the script. Re-checked against the staged tree with `git write-tree`, `tests/bcr` is present.
- [x] 4.2 Keep the development tooling out of the published archive; verify by composition, not by intent.
  - 2026-10-01: without `.gitattributes` the archive held 241 files, 110 of them `.agents/`, `.claude/`, `openspec/` and `openwiki/`. With it, 54 files and 316 KB, including `yarn/`, both test modules, `e2e/smoke`, `AGENTS.md`, `README.md`, `LICENSE` and `.bcr/`. A stray archive from the first run had been staged; `.gitignore` now covers `rules_yarn-*.tar.gz` so a local run cannot repeat it.
- [x] 4.3 Add the publish workflow calling the registry's reusable one.

## 5. Documentation

- [x] 5.1 Rewrite README's installation section to lead with the registry form, and say plainly that the module is not there yet and what to do until it is; verify the override snippet matches what a release actually produces.
  - 2026-10-01: the `archive_override` snippet uses the same prefix and URL shape `release_prep.sh` emits. The section also states why publishing matters: an override only takes effect in the root module, so a dependent cannot pass it on.
- [x] 5.2 Add `CONTRIBUTING.md` and `SECURITY.md` stating what this repository actually requires and actually protects, not boilerplate.
- [x] 5.3 Bring AGENTS.md up to date: a third build root and a third set of pins exist, and the platform claim is no longer Linux-only.
  - 2026-10-01: the gate now names all three roots, the pin list includes `tests/bcr/MODULE.bazel` and says why that module keeps no lockfile, and the header says Linux and macOS — which CI has now shown.

## 6. Gate

- [x] 6.1 Run the repository's pre-commit gate and the build gate across all three roots.
  - 2026-10-02: `buildifier -lint=warn -r .` reported nothing; the root passed 23 tests, `e2e/smoke` 2, `tests/bcr` 1; `tools/ci/minimum_bazel.sh` exited 0; `tools/hooks/protect_generated_test.sh` passed 40 of 40; `pre-commit run --all-files` passed its ten hooks; `openspec validate --all --strict` passed 3 items.
- [x] 6.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - 2026-10-02: no blockers. One should-fix, upheld and fixed; two nits.
    - **Should-fix, fixed.** `publish.yaml` set `draft: false`, copied from the ruleset this one was modelled on without checking why the default is otherwise. The reusable workflow states the reason at v1.5.0: the registry auto-approves a pull request when its author marks a draft ready for review, which is the way around an author not being able to approve their own. This repository does not set `author_name`, so the author is the person who pushed the tag — a human, not a bot — and opening the request ready gives up that path. The input is removed and the reason recorded beside it.
    - The reviewer did not take the archive contract on trust: it committed the tree to a scratch repository, tagged `v0.1.0`, ran `release_prep.sh` for real, and compared the archive it produced against what `source.template.json` substitutes to. Both matched, and it cross-checked the shape against the live `rules_shell@0.8.0` entry.
    - It also went past the model ruleset to the automation's source, finding `create-entry.ts:199-211` in `publish-to-bcr`, which detects the `0.0.0` placeholder and generates the version patch. That turns an inference drawn from one entry into a read of the code that produces it.
    - It extracted the built archive and confirmed `tests/bcr/../..` lands on the extracted root, ran that module under both Bazel versions in the matrix, and checked the platform names against the live presubmit of the model ruleset.
    - **Nit, accepted.** README's lead snippet alone will not resolve until the module is in the registry; a reader has to continue to the section below it. That is the deliberate ordering the proposal argues for.
    - **Nit, acted on.** These two boxes were unchecked when the review ran; they now carry the runs above.

## 7. Left to whoever publishes

- [ ] 7.1 Create a `BCR_PUBLISH_TOKEN` secret that can push to the registry fork and open pull requests, and decide whether the maintainer email in `.bcr/metadata.template.json` is the address to publish.
  - 2026-10-02: the fork this task also asked for already exists — `parkrevil/bazel-central-registry`, a fork of `bazelbuild/bazel-central-registry` — so only the secret remains. `gh secret list` for this repository is empty.
- [ ] 7.2 Tag a version. The release workflow builds the archive and calls the publish workflow, which opens the registry pull request.
