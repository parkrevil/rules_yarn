## 1. Plan

- [x] 1.1 Before any code, a reviewer without this conversation reviews the
  plan. Verified: each finding is checked against documentation or source
  and recorded here with its outcome.
  - 2026-11-20. The reviewer checked against sources and against runs in a
    scratch directory: `rules_bazel_integration_test` 0.37.1, Bazel 9.2.0, and
    bazel-contrib/.github v7.7.0.
  - **Blocker, taken.** Depending on `rules_bazel_integration_test` brings
    `cgrindel_bazel_starlib` 0.28.0. It registers a toolchain whose repository
    symlinks the host's `git` and fails without one
    (`tools/git/local_git.bzl:24-26`, `MODULE.bazel:10-11`; rechecked here
    from the BCR archive). The reviewer measured a root `bazel build //...`
    fetching it, plus Go's, buildifier's and rules_multitool's toolchains.
    The lock gained 56 registry hashes and Go's SDK list, so 2.1's claim
    about the lock diff was false.
    - Put to the user, who said to judge by need, not by rules.
    - Judged by need, the tool gives an `sh_test` with two environment
      variables and a glob helper. It costs the above in every root build.
    - So the pattern is followed without the dependency (design, Decision 2).
  - Should-fixes, all taken after checking each one:
    - The `integration_tests` suite is tagged `manual` itself. `manual` does
      not exclude a test a suite lists by name (`tags.html:104-106` at 9.2.0,
      rechecked here).
    - Setup that crossed targets is listed per case: the proxy registry for
      429 and 613, the `proxy` file for 635, and Yarn's cache for 653. The
      reviewer measured that `lock` alone fills Yarn's cache.
    - Each negative assertion gets a red that shows the planted files are
      reached in the new layout: 220, 413, 429 and 433 (tasks 3.1, 3.5, 3.7).
    - `$TEST_TMPDIR` sits under the user's home on Linux, so an ancestor
      `.yarnrc.yml` could reach Yarn run on its own. The runners check for
      one and stop. The reviewer also counted `tests/install/yarnrc_yarn_test`
      as exposed. Measured, it is not, so it is left as it is (design,
      Decision 7).
    - Decision 8 gives the reason each check stays where it is, judged by
      need. It also covers the pre-commit, wiki and Bazel-version steps.
    - Task 4.1 expects `git grep tools/ci` to find the records in unarchived
      changes: `close-the-verification-gate`, `gate-the-generated-wiki` and
      `rename-the-module`.
    - The floor step also runs `bazel run //:yarn -- --version`, the one way
      into the launcher's `BUILD_WORKING_DIRECTORY` branch
      (`yarn_binary.sh.tpl:41-43`). `minimum_bazel.sh` took that branch.
  - Nits, all taken:
    - `common --deleted_packages`.
    - Runners copy `_main` only.
    - 413 drops its `.cache/bazelisk` exception.
    - The floor step uses `--test_tag_filters=-block-network`.
    - AGENTS.md says the child keeps no lockfile.
    - `all_files` and `local_repository_files` are visible to
      `//:__subpackages__` only.
    - `env_inherit = []` is moot without the tool's macro: the targets
      inherit nothing.

## 2. The pin, the parent's files, and the first target on both platforms

- [x] 2.1 `http_file` repositories, as dev dependencies, for Bazel 9.2.0 on
  linux-x86_64, linux-arm64, darwin-x86_64 and darwin-arm64. Record each URL
  and its published SHA-256, and run `bazel mod deps --lockfile_mode=update`.
  Verified:
  - each URL and its `.sha256` resolve;
  - the root builds under `--lockfile_mode=error`;
  - the lock diff adds the four repositories and nothing else.
  - 2026-11-20, all four:
    - Each URL answers 200, and its `.sha256` holds the digest pinned:

      | Platform | SHA-256 |
      | --- | --- |
      | darwin-arm64 | `dd466352a3e4d3581b8898740ee1ff208866ccbe25f8d367c5dcb950219587e6` |
      | darwin-x86_64 | `14c9bcb01303b38192e0e2895051c1bcf19bf89d7e416f5aeeeb48b6b624cfbf` |
      | linux-arm64 | `049dd21f40ad979db11c3ee68c96a42ce75f1185e69ac61ab20de1501427a410` |
      | linux-x86_64 | `7668a95db1250f12c40407251e4e203b4ec8bf39bc495d2f485b2d8c99048694` |

      Each URL is `https://github.com/bazelbuild/bazel/releases/download/9.2.0/bazel-9.2.0-<platform>`.
    - The lock diff is empty. A root module's `use_repo_rule` repositories
      are not recorded in the lockfile, so "adds the four repositories"
      was wrong in a harmless way.
    - `bazel build //...` passes under the root's `--lockfile_mode=error`.
    - The repository rule's `dev_dependency` exists at both 8.3.0 and 9.2.0
      (`ModuleFileGlobals.java`, `repo_rule_proxy`, line 849 and line 846).
      8.3.0 matters because the floor job evaluates this `MODULE.bazel` as a
      dependency.
- [x] 2.2 `bazel_binary_test`. Red: pointed at a binary that reports another
  version, it fails naming both versions. Green: the host's 9.2.0 binary
  reports `.bazelversion`'s version.
  - 2026-11-20. Red: pointed at a file saying 9.1.0, it failed with
    "FAIL: the Bazel binary reports 'bazel 9.2.0', but .bazelversion says
    9.1.0".
  - Green: "PASS: the Bazel binary reports 9.2.0, as .bazelversion says".
  - It is `manual` but not `exclusive`. It starts no server, so nothing
    needs it to run alone. Design Decision 6 is corrected to say so.
- [x] 2.3 The parent's files, and `consumer.sh`:
  - A root `BUILD.bazel` with `local_repository_files`.
  - `all_files` in `yarn`, `yarn/private` and `yarn/private/install`.
  - `common --deleted_packages` in `.bazelrc`.
  - `tests/integration/install_consumer/`.
  - `tests/fixture_registry/`, by `git mv` of the registry and the fixtures,
    with the registry's header updated.
  - `consumer.sh`, from `install_scenarios.sh`'s setup and helpers, plus the
    ancestor check.

  Verified:
  - the root's `bazel build //...` and `bazel test //...` pass;
  - `bazel query //...` names no package under the child workspace;
  - the ancestor check is shown red with a `.yarnrc.yml` planted above the
    scratch directory, naming it.
  - 2026-11-20, all three:
    - The root's build passes, and `bazel test //...` passes 42 of 42:
      the 41 it had, and `yarn_behavior_test`.
    - `bazel query //tests/integration/install_consumer/...` answers "no
      targets found beneath".
    - Red: `$work/.yarnrc.yml` written before the check stops
      `install_tarballs_test` in 1.1 s with "…/work/.yarnrc.yml is above the
      test's scratch directory, where Yarn would read it; this test cannot run
      on a host that keeps one there". The path it names sits under
      `~/.cache/bazel/…/sandbox/…`, which is why the check exists.
  - The shared steps went to two libraries, not one.
    `tests/fixture_registry/harness.sh` holds what the Yarn-behavior test
    shares too: the case bookkeeping, the hostile host, the registries and
    the ancestor check. `tests/integration/consumer.sh` holds the nested
    Bazel's steps.
  - Registry-only fixtures stay with the registry: `tool_cli.js`, which a
    fixture package serves, and `marker_plugin.cjs`, which both test kinds
    plant. The fixtures only the integration tests use went to
    `tests/integration/fixtures/`. Every moved file's header now names its
    new user.
- [ ] 2.4 `install_targets_test`, first because it holds the case that needs
  the nested Bazel's own sandbox. Red and green as section 3 describes. Then,
  with the user's go-ahead, push and run CI on Linux and macOS.
  Verified: one of these happens, and the run id and which one are recorded.
  - Both platforms pass.
  - Or macOS shows that the sandbox does not nest. The targets then take
    `no-sandbox` (design, Risks) and pass.
  - 2026-11-20, locally:
    - Green: 5 of 5, in 35.8 s, the sandboxed case included. The nested
      Bazel ran inside the outer test's `linux-sandbox`.
    - Red: each direct dependency's target was made to return every package
      (`node_modules.bzl`, `files = part.files`). Three cases failed:
      "Only the dependency's packages are built", "Dependency cycle" and
      "Scope". The change was undone.
    - The Bazel test rebuilt after the change to the ruleset, because
      `//:local_repository_files` is a declared input.
  - Changed order: macOS is checked by the change's one push (5.4), not by an
    early push of its own. Each push needs the user's go-ahead, and all the
    cases were moved by then anyway. If macOS does not nest, the fix is a tag,
    and 5.4 records which happened.
  - 2026-11-20, CI run 44596357423: **macOS does not nest.**
    - `install_targets_test`'s cycle case failed on macOS with "'darwin-sandbox'
      was requested for explicit default strategies but no strategy with that
      identifier was registered".
    - The other six targets passed there, under the outer darwin-sandbox, and
      all seven passed on Linux.
    - Naming the sandbox is what showed it. Under `sandboxed` the case would
      have run on processwrapper-sandbox, which `SandboxModule` registers under
      that name and which the error lists as valid.
    - Fix: `install_targets_test` alone takes `no-sandbox`. Locally on Linux it
      passed, 5 of 5, with the test run `local` and the nested Bazel's
      `linux-sandbox` underneath. Its `/tmp` scratch directory was removed
      afterwards. The macOS result of the fix is 5.4's, and this task stays
      open until that run shows it.
    - The fix's review found no blocker. Taken: this task left open; "would
      have run" for "would have passed"; the Bazel lines that keep
      `no-sandbox` under `exclusive` cited in the design; and the `/tmp`
      leftover recorded as a known limit there and in `harness.sh`.

## 3. Moving the cases

Each target is written red first:

1. A deliberate break of one thing it checks, in the ruleset or a fixture,
   makes it fail. The failure names the case and prints the failing step's
   log.
2. The break is undone, and the target passes.
3. The record says what was broken and quotes the failure.

- [x] 3.1 `install_fetching_test`: 8 cases (design, Decision 4). Its own red
  for 220 makes the install honour a planted `.yarnrc.yml` above the project,
  and 220 must then fail.
  - Green: 9 of 9, the closing case included.
  - Red: the install's rc file took the default name (`rcFilename` returned
    `.yarnrc.yml`), and its own settings dropped `npmRegistryServer`. Yarn
    in the install then read the planted closed-port registry above it. 220
    and the six cases after it failed, in 804 s of Yarn retrying port 9. The
    first pin, which runs Yarn on its own, passed.
  - The red needs both edits, which says something about 220. The install's
    own file sets `npmRegistryServer` nearest the project, so the planted file
    cannot win while it does. That is the spec's scenario, "Configuration
    above the project", held by two guards.
- [x] 3.2 `install_tarballs_test`: 2 cases.
  - Green: 3 of 3.
  - Red: the driver never chose the tarball (`if (false && resolution && extract.decide(…))`).
    Both cases failed.
- [x] 3.3 `install_refusals_test`: 8 cases.
  - Green: 9 of 9.
  - Red: the driver's link refusal was skipped (`if (false && link)`). "Link
    inside a package: fetching fails and names the package and the link"
    failed, and nothing else did.
- [x] 3.4 `install_pin_file_test`: 4 cases.
  - Green: 5 of 5.
  - Red: a malformed pin file was read as empty. "Malformed pin file: the
    build says so…" failed, and so did "the repaired pin file says what it
    said before it was broken".
- [x] 3.5 `install_host_test`: 3 cases, each with its own red:
  - 402 with the poisoned tools reached;
  - 413 with a write into the planted `HOME`, which must change the digest;
  - 429 with the project's plugin honoured.
  - Green: 4 of 4. 413 passes without the script's `.cache/bazelisk`
    exception.
  - Red for 402: the repository rule ran `repository_ctx.which("node") or
    node`. Under the poisoned `PATH`, 402 failed alone.
    - A first try, `which("node")` alone, failed the setup instead, since the
      test's `PATH` holds no node.
  - Red for 413: `$work/home/red` was written between the two digests. 413
    failed alone.
  - Red for 429: the driver carried the project's whole `.yarnrc.yml` instead
    of its carried settings. 429 failed alone.
    - A first try, adding `plugins` to `CARRIED`, failed the setup instead,
      with "Couldn't find a configuration settings named \"plugins\"".
- [x] 3.6 `install_downloader_test`: 2 cases.
  - Green: 3 of 3.
  - Red, in a fixture: `credential_helper.sh` answered a wrong token.
    "Credentials from a credential helper" failed.
  - Two ruleset edits were tried first, and neither is a red for this target:
    - A tarball fetched without integrity: Bazel refuses a plain-http URL
      without a checksum, so the setup failed.
    - A wrong `auth` on every download: the target passed, because the
      credential helper's header wins.
- [x] 3.7 `consumer.sh`'s closing case, "no install loaded the planted plugin",
  runs last in each target. Red: an install that honours the planted file
  makes it fail.
  - Red: `rcFilename` returned the former fixed name,
    `.rules-yarn-install.yml`. In `install_tarballs_test` the closing case
    failed and the two others passed.
- [x] 3.8 `//tests/install:yarn_behavior_test`: 7 cases, run through the root's
  `yarn_binary`, not `manual`, with the ancestor check. Verified: red with
  a planted ancestor `.yarnrc.yml`, and red with one thing it measures
  broken.
  - Green: 7 of 7, in 3.2 s.
  - Red for the ancestor check: the same message as 2.3's.
  - Red for a measurement: Yarn ran with `YARN_COMPRESSION_LEVEL=mixed`.
    "The cache key Yarn writes" failed, with "cacheKey by default found: 1;
    with mixed found: 0".
    - A first try, `YARN_ENABLE_GLOBAL_CACHE=false`, passed. Yarn's mirror
      writes the same zip into the global folder, so 635 holds either way.
- [x] 3.9 `integration_tests`, tagged `manual`, lists the 7 targets and
  `bazel_binary_test`. Verified:
  - The suite passes locally.
  - The case names it and `yarn_behavior_test` report are
    `install_scenarios.sh`'s 39, each once, besides the closing case each
    target repeats. The comparison is done by script, not by eye.
  - The root's `bazel test //... --test_tag_filters=-block-network`, as the
    release runs it, runs none of them.
  - 2026-11-20, all three:
    - 7 of 7 passed on the shared harness in 231 s, against the script's
      2 m 30 s on CI's Linux.
    - The script's 39 case names and those in the new runners, `consumer.sh`
      and `yarn_behavior_test.sh` are the same 39, each once, by `diff` of
      the sorted lists.
    - That command finds 41 test targets. `attr(tags, manual, …)` lists exactly
      the 8 of this suite.
  - The suite first had `exclusive` too, and ran only 7 tests. A suite's tags
    select among the tests it lists (`TestSuiteRule.java:41-66` at 9.2.0), and
    `bazel_binary_test` is not `exclusive`. Now it has `manual` alone, and
    `tests(//tests/integration:integration_tests)` names all 8 (design,
    Decision 6).

## 4. Removal and wiring

- [x] 4.1 Remove `tools/ci/`. Verified: `git grep tools/ci` finds only these
  records, which are left as written:
  - `openspec/changes/archive/`;
  - the unarchived changes `close-the-verification-gate`,
    `gate-the-generated-wiki` and `rename-the-module`;
  - `openwiki/`, until it is regenerated.
  - 2026-11-20: `tools/ci/` is gone. `git grep tools/ci` outside the archive
    and the wiki finds only `ci.yml` and `AGENTS.md`, which 4.2 and 4.3
    change, and the three unarchived changes named above.
- [x] 4.2 `ci.yml`:
  - `bazel test //tests/integration:integration_tests --test_output=errors`
    replaces the scenario step.
  - The floor job runs `e2e/smoke` beside `e2e/install`:
    `bazel test --lockfile_mode=off --test_tag_filters=-block-network //...`
    and `bazel run --lockfile_mode=off //:yarn -- --version`, checking the
    version.
  - The `minimum_bazel.sh` step goes.

  Verified:
  - actionlint passes.
  - The floor step is shown red in a local run of the same command, with a
    Bazel older than `bazel_compatibility`.
  - 2026-11-20:
    - actionlint passes.
    - The floor job's commands, run locally with the floor read the same
      way:
      - Under 8.3.0, `e2e/smoke`'s test passed, `bazel run //:yarn --
        --version` reported 4.18.0, and `e2e/install`'s 6 tests passed.
      - Under 8.2.1 they failed with "Bazel version 8.2.1 is not compatible
        with module \"parkrevil_rules_yarn@_\" (bazel_compatibility:
        [>=8.3.0])".
    - The floor job now exports the floor once, as `USE_BAZEL_VERSION`, for
      both folders.
    - `e2e/install`'s step now leaves out `block-network` tests by tag, not
      `//:offline_test` by name, the same filter as `e2e/smoke`'s, which has
      its own `block-network` test.
- [x] 4.3 `AGENTS.md`:
  - The before-commit gate names the integration suite in place of the script.
  - The pin list names the Bazel binary's `http_file` digests in `MODULE.bazel`
    and the child workspace's `MODULE.bazel`, which keeps no lockfile.

  Verified: every path and target it names exists.
  - 2026-11-20:
    - It names `tests/integration/` in the layout line.
    - Its pin list adds the child's `MODULE.bazel`, and the Bazel binary's
      digests in `MODULE.bazel`, which must move with `.bazelversion`.
    - It says the child keeps no lockfile.
    - The gate names `bazel test //tests/integration:integration_tests`.
    - Every path and target it names exists in the tree.
- [x] 4.4 Design Decision 8's table is rechecked against the final tree.
  Verified: `ci.yml` and `tools/` hold no other script-run check.
  - 2026-11-20:
    - Every `run:` in `ci.yml` is a Bazel command in a folder, a row of the
      table, or setup (installing OpenSpec, pre-commit and Node.js).
    - `tools/` now holds only `hooks/`, whose two tests are a row.

## 5. Gate, review, commit

- [x] 5.1 The gate passes:
  - `bazel build //... && bazel test //...` in the root, `e2e/smoke`,
    `e2e/install` and `tests/bcr`;
  - `bazel test //tests/integration:integration_tests`;
  - `e2e/smoke` and `e2e/install` under the floor, as the floor job runs them;
  - pre-commit;
  - `openspec validate --all --strict`.

  Record the suite's wall time against the script's.
  - 2026-11-20, after the review's fixes and buildifier's reordering of the
    child's `MODULE.bazel`:
    - The roots passed: `e2e/smoke` 2 of 2, `e2e/install` 7 of 7,
      `tests/bcr` 1 of 1, and the root 42 of 42.
    - The integration suite passed, 8 of 8, in 233 s of wall time. The
      script took 2 m 30 s on CI's Linux; nothing comparable was measured
      locally.
    - Under the floor, the floor job's commands passed (4.2).
    - pre-commit passed over all files, staged, with the staleness hook
      skipped until 5.2.
    - `openspec validate --all --strict`: 6 of 6.
- [x] 5.2 Regenerate the wiki. Verified: `tools/hooks/openwiki_staleness.sh`
  passes.
  - 2026-11-20, after the review (5.3), so that its fixes could not stale the
    wiki again. Two update runs:
    - **The first** revised six pages: dependency installation, the public
      API surface, version pinning, the verification strategy, the
      development workflow and the quickstart. It retracted the claims about
      the removed scripts and added ones for the nested-Bazel tests, the
      Yarn-behavior test, the floor job and the pinned Bazel binary.
    - **The second** re-anchored five claims on three pages whose `ci.yml`
      spans had moved 17 lines with unchanged content. OpenWiki itself
      reported no issue for them, but the staleness gate recomputes spans.
  - `tools/hooks/openwiki_staleness.sh` exits 0.
- [x] 5.3 A reviewer without this conversation reviews the change. Verified:
  each finding is checked against documentation or a failing test and
  recorded here.
  - 2026-11-20, before the wiki run, so that fixes cannot stale it again. No
    blocker. The reviewer confirmed:
    - the 39 case names, and that the case lines differ only mechanically;
    - the setup each moved case needs;
    - the declared inputs, `.bazelrc` in the glob included;
    - the `set` interplay with the runfiles block;
    - the isolation;
    - the CI exports;
    - BSD portability of the commands used.
  - Should-fixes, all taken after checking each one:
    - **A root `//...` fetched the Bazel binary.** The `:bazel` alias was not
      `manual`, and analysing it fetches the binary. `bazel build --nobuild
      //tests/integration/...` analysed 2 targets. The alias is `manual`
      now, and the same command analyses 1, `:consumer`.
    - **`--spawn_strategy=sandboxed` could hide a sandbox that does not
      nest.** It also names processwrapper-sandbox, which Bazel falls back to
      (`SandboxModule.java:288-345` at 9.2.0, rechecked here). The cycle case
      now names `linux-sandbox` or `darwin-sandbox` by `uname`, so on macOS
      the 2.4 outcome can be told.
    - **Two "known limits" could be fixed, so they are.**
      - The scratch directory moved from `$TEST_TMPDIR`, under `~/.cache`, to
        `mktemp -d /tmp/…`, as the script had it. A developer's
        `~/.yarnrc.yml` no longer stops the root's `//...`.
      - `.bazelignore` lists the child's four `bazel-*` links. Red: with the
        links pointing at a directory holding a broken `BUILD.bazel`, the
        root's `bazel query //...` printed 13 errors. With the entries it
        printed none. The links were then removed.
    - **The floor step passed if both versions came out empty.** It had no
      pipefail and no check that `want` is set. Run under GitHub's `bash -e`
      with a `bazel run` of a missing target, the step's script exited 0.
      Under `bash -eo pipefail`, which `shell: bash` gives, it exited 1. The
      step now has `shell: bash` and `test -n "$want"`.
  - Nits, all taken:
    - The cleanup loop survives an empty `pids` under bash 3.2's `set -u`.
    - `consumer.sh` refuses a root that is not a runfiles `_main`.
    - `check_ancestors` walks the physical path, as Yarn does.
    - AGENTS.md's pin list names the `packageManager` version `harness.sh`
      writes.
    - `harness.sh`'s header says `yarnrc` and `project` use the caller's
      `$ws` and `$port`.
    - The nested Bazel runs with `--max_idle_secs=60`.
    - The proposal no longer lists `MODULE.bazel.lock` as changed.
    - Design Decision 2 says which inputs arrive by `$(rlocationpath)`.
  - After the fixes, the 7 targets, `bazel_binary_test` and
    `yarn_behavior_test` passed, 9 of 9 in 235 s. The cycle case ran under
    the named `linux-sandbox`.
- [ ] 5.4 One commit. With the user's go-ahead, push. Verified: every CI job
  passes on both platforms. Record the run id, and the suite's time in CI
  against the script's 2 m 30 s and 4 m 11 s.

## 6. Release order

- [ ] 6.1 With the user's go-ahead, merge `rename-the-module`, then this
  change, then tag v0.2.0 as `rename-the-module`'s tasks 5.x describe.
  Verified: the tagged commit holds both changes.
