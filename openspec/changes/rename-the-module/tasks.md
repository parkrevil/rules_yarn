## 1. Plan

- [x] 1.1 Before any code, a reviewer without this conversation reviews the
  plan. Verified: each finding is checked against documentation or source
  and recorded here with its outcome.
  - 2026-11-19: no blocker. The approach was checked against Bazel 9.2.0 and
    8.3.0 source and documentation, publish-to-bcr v1.5.0 and ccv `7318e2f`.
    The reviewer also ran a scratch probe: a generated repository loading
    `@<host module>//` builds with the host as root and as a dependency,
    under both Bazel versions.
  - Should-fixes, all taken after checking each one:
    - The wiki is regenerated before the branch is pushed. The staleness
      hook runs at `pre-push` (`.pre-commit-config.yaml:30-36`) and in CI.
    - The reviewer sees the change before anything is committed.
    - `tag.yaml` is dispatched once after the merge, so "writes no tag" has a
      recorded run.
    - The tag is lightweight. ccv keys tags by the ref's own hash
      (`ccv.go:91-94`), and an annotated tag's ref points at a tag object.
    - `install_scenarios.sh` gets canonical names from
      `bazel mod dump_repo_mapping` instead of carrying the literal, which
      the design had put under "known limit".
    - The `str(Label())` alternative is rejected for the reason that holds
      (one mechanism), not for a misread of `module.md`.
    - The pull-request title is cited from the path the workflow runs
      (`main.ts:86-90` at `f9cfe7a`), not the deprecated app's.
    - The release-notes check runs in a throwaway clone, because the step
      creates tag `v0.0.0-ci`, which matches `release.yml`'s `v*.*.*`
      trigger.
  - Nits taken:
    - The migration note adds `--override_module` and the changed canonical
      names and paths.
    - `yarn/BUILD.bazel`'s `render_main_repo_name` gets a row, which also
      strengthens the case against `repo_name`.
    - Cross-references are fixed; the `Label.mdx` citation is pinned to
      commit `6bc0fe5`.
    - The lockfiles are expected unchanged.
    - The notes check also covers the module sentence.
    - The `node_modules.bzl` docstring names the module.
    - The two CI scripts get a red step.
  - Not taken:
    - Suggesting `bazel_dep(..., repo_name = "rules_yarn")` in the
      migration note. It would be a claim no test here backs.
    - Moving "Installation under the module name" to `yarn-dependencies`.
      `yarn-execution` holds the module-level requirements (public API
      surface, declared Bazel compatibility, published API reference). The
      scenario checks the module name, not install behaviour.

## 2. Tests first

- [x] 2.1 `e2e/smoke` and `tests/bcr` depend on `parkrevil_rules_yarn`: the
  `bazel_dep`, the override's `module_name`, and the `@…//` labels in
  `MODULE.bazel` and `BUILD.bazel`. Verified red: `bazel build //...` in
  each fails because the module the override points at is named
  `rules_yarn`. Record the error.
  - 2026-11-19 red: both roots fail computing the main repository mapping:
    "the MODULE.bazel file of parkrevil_rules_yarn@_ declares a different name (rules_yarn)".
- [x] 2.2 `e2e/install` (`MODULE.bazel`, `provider_root.bzl`) gets the same
  edits. Verified red: `bazel build //...` fails for the same reason.
  Record the error.
  - 2026-11-19 red: the same error.
- [x] 2.3 Update the consumer module that `tools/ci/minimum_bazel.sh` and
  `tools/ci/install_scenarios.sh` generate, and its labels, to the new name.
  `install_scenarios.sh` also stops hard-coding `rules_yarn++yarn+npm` and
  reads the name from `bazel mod dump_repo_mapping ''` (design Decision 6).
  Verified red: each script fails for the same reason as 2.1.
  - 2026-11-19 red: `minimum_bazel.sh` (Bazel 8.3.0) fails with the same
    error. `install_scenarios.sh` stops at "cannot build the Bazel-managed
    Node.js", because it discards Bazel's output. Its generated module,
    rebuilt by hand, gives the same error.
- [x] 2.4 Extend the "Build the release archives" step in `ci.yml`. The notes
  must name `parkrevil_rules_yarn` in the `bazel_dep` and in `module_name`.
  Leaving out the lines holding `rules_yarn-` (archive name, prefix, URL),
  they must not contain `rules_yarn` as a standalone word. Verified red: the
  step's commands, run in a throwaway clone against today's
  `release_prep.sh`, fail on the new check. A throwaway clone, because the
  step creates tag `v0.0.0-ci`, which matches `release.yml`'s trigger.
  - 2026-11-19 red: in a throwaway clone of HEAD, the step fails on
    `grep -qF 'bazel_dep(name = "parkrevil_rules_yarn"'`. Today's notes name
    `rules_yarn` in both `bazel_dep`s, in `module_name` and in the sentence
    "`rules_yarn` declares that". No tag is left in the checkout.

## 3. Rename

- [x] 3.1 Set `module(name = "parkrevil_rules_yarn")` in `MODULE.bazel`.
  Verified green: `e2e/smoke` and `tests/bcr` build and test, and
  `minimum_bazel.sh` passes. Verified red, for the stated reason:
  `e2e/install` and `install_scenarios.sh` fail because the generated
  repository cannot resolve `@rules_yarn`. Record the error.
  - 2026-11-19: `e2e/smoke` passes 2/2 and `tests/bcr` 1/1;
    `minimum_bazel.sh` passes on Bazel 8.3.0. Red: `e2e/install` and every
    `install_scenarios.sh` case that loads the install fail with "No
    repository visible as '@rules_yarn' from repository
    '@@parkrevil_rules_yarn++yarn+npm'".
- [x] 3.2 Point `yarn/private/install/node_modules.bzl` (its `load`, both
  `Label` defaults and the docstring's repository) and the `BUILD.bazel`
  that `repository.bzl` writes at `@parkrevil_rules_yarn` (design
  Decision 2). Verified green: `e2e/install` builds and tests, and
  `install_scenarios.sh` passes, pin target included.
  - 2026-11-19: `e2e/install` passes 7/7. `install_scenarios.sh` passes
    39/39, "First pin" included, as does the "no such target
    '@@$npm_repo//…'" case, whose name now comes from
    `dump_repo_mapping`.
- [x] 3.3 Update the doc examples in `yarn/extensions.bzl` and
  `yarn/private/yarn_binary.bzl`. Verified: `//tests/docs/...` passes, and
  `grep -rn '@rules_yarn' yarn/` prints nothing.
  - 2026-11-19: `//tests/docs:docs_test` passes, and the grep prints
    nothing. The docs archive built in 3.4 renders
    `@parkrevil_rules_yarn//yarn:defs.bzl`, as Decision 3's `yarn/BUILD.bazel`
    row expects.
- [x] 3.4 Update the `bazel_dep`, `module_name` and module sentence in the
  notes `release_prep.sh` prints. Verified green: the 2.4 check passes in a
  throwaway clone.
  - 2026-11-19: in a throwaway clone carrying the working tree, the step
    passes. The notes name `parkrevil_rules_yarn` in both `bazel_dep`s, in
    `module_name` and in the compatibility sentence. `rules_yarn` is left
    only in `strip_prefix`, the URL and the SHA line. No tag is left in the
    checkout.
- [x] 3.5 Update `README.md` by design Decision 3's table, with version
  0.2.0. Add a migration note for 0.1.0: the `bazel_dep` name, the
  override's `module_name` (in an `--override_module` flag too), the
  `@rules_yarn//` labels, and the fact that canonical repository names and
  paths derived from them change. Verified: each remaining `rules_yarn` in
  README matches a "stays" row. Record the list.
  - 2026-11-19, what remains after the change review's edits: line 3
    (project); 43-44 (archive prefix and URL); 61, 63, 68, 71 (the migration
    note, which names the 0.1.0 module on purpose; Decision 3's README row
    now says so); 173 (docs archive); 181 (the `version` attribute row,
    project prose that mirrors `yarn/private/extensions.bzl`).
- [x] 3.6 Run `bazel mod deps --lockfile_mode=update` in the root,
  `e2e/smoke` and `e2e/install`. No lock names the module, so the expected
  diff is empty. Record what it is. Verified: each root builds under its own
  `--lockfile_mode=error`.
  - 2026-11-19: `bazel mod deps --lockfile_mode=update` exits 0 in all
    three roots, and the lock diff is empty. Each root then resolves under
    its own `--lockfile_mode=error`.
- [x] 3.7 Run `grep -rn rules_yarn` across the tree, excluding
  `openspec/changes/archive/`, `openwiki/` and lockfiles. Verified: every
  hit falls under a "stays" row of design Decision 3's table. Record any
  file the table missed with its verdict.
  - 2026-11-19: the table missed `.bazelrc:1`. "Modules that depend on
    rules_yarn" is a dependency on the module, so it now names
    `parkrevil_rules_yarn`; "developing rules_yarn" stays (project). The
    table is corrected. Every other hit falls under a "stays" row: `.bcr/`,
    `ci.yml`, `release.yml`, `release_prep.sh` PREFIX/ARCHIVE and
    `.gitignore` (repository); `AGENTS.md`, comments, docstrings and error
    messages in `yarn/`, `e2e/`, `tests/` and `tools/ci/` (project); README
    as in 3.5.

## 4. Gate, before any commit

- [x] 4.1 Run `bazel build //... && bazel test //...` in the root,
  `e2e/smoke`, `e2e/install` and `tests/bcr`, plus
  `tools/ci/install_scenarios.sh`, `tools/ci/minimum_bazel.sh`, the
  pre-commit hooks and `openspec validate --all --strict`. Verified: each
  passes. Record the result.
  - 2026-11-19, all pass:
    - Root: build, and 41/41 tests.
    - `e2e/smoke` 2/2, `e2e/install` 7/7, `tests/bcr` 1/1.
    - `install_scenarios.sh` 39/39; `minimum_bazel.sh` on Bazel 8.3.0.
    - pre-commit. Buildifier re-sorted the loads in `e2e/smoke/BUILD.bazel`
      and `tests/bcr/BUILD.bazel`, since `@parkrevil_rules_yarn` sorts before
      `@rules_shell`, and both roots passed again.
    - `openspec validate --all --strict`: 5/5.
- [x] 4.2 Regenerate the wiki (`openwiki --update`). Verified:
  `tools/hooks/openwiki_staleness.sh` passes.
  - 2026-11-19: two update runs.
    - The first covered the seven pages whose claims cite files this change
      edits.
    - The second moved three quickstart evidence spans and rechecked one
      publishing claim. README reflows made during the first run had shifted
      the lines they cite.
    - `openwiki_staleness.sh` passes, and the pre-commit hooks pass again.
- [x] 4.3 A reviewer without this conversation reviews the uncommitted
  change. Verified: each finding is checked against documentation or a
  failing test, and recorded with its outcome.
  - 2026-11-19: no blocker. The reviewer reran every root, the scenarios
    (39/39) and `e2e/install` under Bazel 8.3.0 (6/6). It replayed the
    notes checks against HEAD (fail), the working tree (pass) and a reverted
    sentence (fail). It also checked the published docs, the wiki and the
    citations. Each finding below was checked and taken.
  - Should-fixes:
    - `tests/bcr/yarn_version_test.sh` said "a module that depends on
      rules_yarn"; it now names the module, and the table row is updated.
      `repository.bzl`'s "an upgrade of rules_yarn" stays as project prose
      (recorded). The wiki's "private to rules_yarn", which means the
      module's repository, now names the module.
    - The rollback was missing a step: a revert leaves the `feat!` commit
      counting, so a person still pushes a tag. The design says so now.
    - Two defects outside this change are reported in the design, each
      needing its own change. Nothing tells the person pushing a major tag
      that it must be lightweight. `install_scenarios.sh` discards Bazel's
      output when building Node.js.
  - Nits:
    - Re-recorded 3.5's README line numbers.
    - Fixed design's task reference (2.4).
    - The README and wiki wording now says the registry asked for a user
      prefix and no more.
    - The new canonical-name lookup keeps Bazel's stderr and prints it on
      failure, shown by a simulated failure.
    - 5.2 says why the "Registry entry" scenario has no red step.
    - Reflowed the README paragraph.
    - Added `.bazelrc` to the proposal's Impact.
  - After the fixes:
    - A third wiki run moved the README spans the reflow shifted.
      `openwiki_staleness.sh` passes.
    - `tests/bcr` 1/1, `install_scenarios.sh` 39/39, pre-commit and
      `openspec validate --strict` pass.
- [x] 4.4 At the user's direction, fix the review's two outside defects here
  (design Decisions 7 and 8). First: `release.yml` refuses an annotated tag;
  `tag.yaml`'s major-version notice and the README say to push a lightweight
  one. Verified: the step's commands exit 1 for `git/git` `v2.47.0`
  (annotated), 0 for `v0.1.0` (lightweight) and 1 for a missing tag.
  - 2026-11-19 red: `release.yml` had no check (`git grep` finds none before
    the change), so an annotated tag would release. Green: the three runs
    above.
- [x] 4.5 Second, `install_scenarios.sh` prints Bazel's output on every
  failure path of its setup, and asks for `output_base` and `bazel-bin` once.
  Verified: a fake `b` that fails at each of `build`, `info`, `cquery` and
  `mod` in turn shows Bazel's error, then the script's message.
  - 2026-11-19 red: the `build` failure printed only "cannot build the
    Bazel-managed Node.js". A `cquery` failure passed the Node.js check
    silently, because `[ -x ]` accepts the output-base directory. Green: all
    four now print the simulated Bazel error before stopping. With no
    failure, setup passes.
  - 2026-11-19, after the second review: the same rule now covers the 17
    `|| die "…$(tail …)"` sites in the cases, through `fail_with` and
    `last_log` (design Decision 8). Red: with HEAD's script, a `lock` that
    failed after an earlier `pin` printed the stale `pin.log`. Green: it
    prints `lock.log`.
- [x] 4.6 Re-run the gate for 4.4 and 4.5: 4.1's set (all four roots,
  `install_scenarios.sh`, `minimum_bazel.sh`, pre-commit with actionlint,
  `openspec validate`), the wiki (4.2), and a reviewer without this
  conversation for the additions. Verified: each passes, and each review
  finding is checked and recorded.
  - 2026-11-19, second review: no blocker. The reviewer:
    - built the pinned ccv and showed it computing `v1.0.0 major` behind an
      annotated tag and `v0.2.1 patch` behind a lightweight one;
    - checked the job against GitHub's documentation (default `bash -e`,
      permissions downgraded in a called workflow, the caller's `github`
      context, preinstalled `gh`, `needs` on a reusable-workflow job);
    - ran the scenarios (39/39).
  - Every finding was checked and taken:
    - Should-fix: the cases' 17 stopping points also print the whole log of
      the step that failed. Eleven of them could have printed a stale log.
    - Should-fix: corrected the verdict table's line numbers.
    - Should-fix: the given command is `git tag --no-sign`, since
      `tag.gpgSign` makes a plain `git tag` annotated (checked here on git
      2.43). The error gives the delete commands, and the README lists
      `-u`, `-m` and `-F` as well.
    - Nits: the exit-code order; the job's first GitHub run recorded as a
      known limit and in 5.2; the ccv run recorded in Decision 7;
      `release.yml`'s header names its addition; the setup comment narrowed.
  - After the fixes:
    - `install_scenarios.sh` 39/39; all four roots; `minimum_bazel.sh`;
      pre-commit with actionlint; `openspec validate --all --strict`.
    - A fifth wiki run, after which `openwiki_staleness.sh` passes.
- [x] 4.7 Fold everything into the branch's single commit (`63c354b`,
  unpushed) by amending it; done 2026-11-19. With the user's go-ahead, push. Verified: every
  CI job passes, wiki staleness included. Record the run id.
  - 2026-11-19: `7f97d0f` pushed as `rename-the-module`. CI run 44515306415
    passed every job: checks with the wiki staleness gate, next release,
    both platforms' build and test, and the oldest supported Bazel.

## 5. Release

- [x] 5.1 With the user's go-ahead, merge to main as a `feat!:` commit with
  a `BREAKING CHANGE:` footer, push, and dispatch `tag.yaml` once. Verified
  from the recorded runs: CI's next-release job and `tag.yaml` both compute
  v1.0.0 (major), and `tag.yaml` writes no tag.
  - 2026-11-20:
    - main was fast-forwarded to `7f97d0f`, the `feat!:` commit with its
      `BREAKING CHANGE:` footer.
    - CI run 44603575185's next-release job computed `VERSION: v1.0.0`,
      `TYPE: major`.
    - `tag.yaml`, dispatched once on main (run 44603596162), computed v1.0.0.
      "Leave a major version to a person" ran, "Tag a minor or patch
      version" and the release were skipped, and `git ls-remote --tags`
      shows no v1.0.0.
- [x] 5.2 With the user's go-ahead, create the lightweight tag
  `git tag --no-sign v0.2.0 <merge sha>` (no `-a`, `-s`, `-u`, `-m` or `-F`)
  and push it. This is also the first run on GitHub of `release.yml`'s
  `lightweight-tag` job (design Decision 7). Verified:
  `git for-each-ref refs/tags/v0.2.0` reports `commit`. The recorded
  `release.yml` run built and finalized the release and opened the draft
  registry PR `parkrevil_rules_yarn@0.2.0`, which adds
  `modules/parkrevil_rules_yarn/0.2.0/`. Record the run id and PR URL. The
  "Registry entry" scenario has no test that can fail first: only a release
  run creates the entry. Its evidence is this recorded run, as for the
  existing "Registry link" scenario.
  - 2026-11-20:
    - **Where the tag went.** v0.2.0 is on `8aa3421`, not on this change's
      commit. adopt-bazel-integration-tests was merged after this change
      and before the tag, as its design planned, so the release carries both.
      `git for-each-ref refs/tags/v0.2.0` reports `commit`.
    - **Release run 44605072225 passed every job.** `lightweight-tag` passed
      on its first run on GitHub. The release's build, attestation and
      release jobs passed, then publish, then finalize.
    - **The release** is published, not a draft. It holds the source and
      documentation archives with their attestations, and those of
      `MODULE.bazel` and `source.json`.
    - **The registry PR** is https://github.com/bazelbuild/bazel-central-registry/pull/11941,
      `parkrevil_rules_yarn@0.2.0`, by parkrevil. It adds
      `modules/parkrevil_rules_yarn/0.2.0/` (`MODULE.bazel`,
      `attestations.json`, the version patch, `presubmit.yml`, `source.json`)
      and `modules/parkrevil_rules_yarn/metadata.json`.
- [x] 5.3 With the user's go-ahead, mark the new registry PR ready for
  review, and close bazelbuild/bazel-central-registry#10979 with a link to
  it. Verified: `gh pr view` shows each PR's state.
  - 2026-11-20: `gh pr view` shows #11941 open and not a draft. #10979 is
    closed, with the comment "Superseded by #11941, which publishes the
    module under the user-prefixed name `parkrevil_rules_yarn` as
    requested."
