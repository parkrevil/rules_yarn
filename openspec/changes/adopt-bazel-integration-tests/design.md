## Context

See proposal.md for why. Four facts shape the approach.

- **What the scripts do.**
  - `tools/ci/install_scenarios.sh` builds one consumer module with a
    `local_path_override` onto the checkout and starts `fixture_registry.js`
    on 127.0.0.1.
  - It plants a hostile host. A `HOME`, the directory above the output root,
    and the output root itself each hold a `.yarnrc.yml` pointing at a closed
    port. Beside each is a file under the install's former configuration
    name, which loads a marker plugin.
  - It then runs the host's `bazel` through 39 cases in one sequence, on one
    consumer. In CI that step took 2 m 30 s on Linux and 4 m 11 s on macOS
    (run 44515306415).
  - `tools/ci/minimum_bazel.sh` writes a consumer that builds a `yarn_binary`,
    runs it with `bazel run`, and checks its version. It runs under
    `USE_BAZEL_VERSION=<floor>` through the runner's Bazelisk.
  - The same CI job already runs `e2e/install`'s tests at the floor, with
    `--lockfile_mode=off`, by setting `USE_BAZEL_VERSION` in that folder.
- **The convention for Bazel versions.** bazel-contrib's reusable test
  workflow (`bazel-contrib/.github/.github/workflows/bazel.yaml` at v7.7.0)
  runs `bazel test` in a list of `folders` across a list of `bazelversions`.
  The defaults are `.bazelversion` and 8.0.0. Rulesets check a version floor
  by running their consumer folders under each Bazel version.
- **The convention for nested Bazel**, as bazel-contrib's
  `rules_bazel_integration_test` 0.37.1 states it. (Archive digest
  `sha256-6ew1u3CjQM4TqFtYPo3RNm+N3p/KcLix+R4BFDEtVwE=`, checked against the
  download and BCR's `source.json`.)
  - A nested-Bazel test is an `sh_test` that hands a runner a Bazel binary
    and a child workspace (`bazel_integration_test.bzl:174-186`,
    `integration_test_wrapper.sh:53-54`).
  - It is tagged `exclusive` and `manual` (`integration_test_utils.bzl:59-62`),
    and is collected in a `test_suite`, which is tagged too (README, lines
    193-200).
  - The child workspace is kept from the parent's package walk with
    `--deleted_packages`, and its files are globbed without `bazel-*`
    (`integration_test_utils.bzl:50-53`).
  - The parent's files reach it through a `local_repository_files` filegroup
    and per-package `all_files` (README, "Integration Tests That Depend Upon
    The Parent Workspace").
  - rules_go's `go_bazel_test`, and rules_python's own tool before this one,
    are rulesets writing the same pattern themselves.
- **What the spikes and the plan review measured.**
  - **A nested Bazel works inside the test sandbox on Linux.** In a scratch
    module on this Linux host, an `sh_test` ran a nested Bazel 9.2.0, pinned
    by `http_file` with its SHA-256. Inside the outer test's `linux-sandbox`,
    the nested Bazel built and ran this ruleset's Yarn target (16.9 s), and
    built a genrule with `--spawn_strategy=linux-sandbox` (10.8 s). Whether
    the macOS sandbox nests is not known; see Risks.
  - **A child directory's `bazel-*` symlink breaks the root.** With a child
    directory in `--deleted_packages`, a root's `bazel query //...` still
    walks that child's `bazel-bin` symlink and fails on what it finds there.
  - **Depending on the tool costs every root build.** The plan reviewer
    added `rules_bazel_integration_test` 0.37.1 as a `dev_dependency` to a
    copy of this repository and built `//...`. The build fetched toolchain
    repositories it had not fetched before:
    - `bazel_starlib_git_toolchains`, which symlinks the host's `git` and
      fails without one (`cgrindel_bazel_starlib` 0.28.0,
      `tools/git/local_git.bzl:24-26`, registered in its `MODULE.bazel:10-11`);
    - Go's toolchains;
    - buildifier's toolchains;
    - rules_multitool's.

    The lock gained 56 registry hashes and Go's SDK list.

## Goals / Non-Goals

**Goals:**

- Every check the two scripts make stays. Each becomes a Bazel test target in
  `tests/`, or a run of an existing consumer folder under the floor Bazel.
- Each integration target starts from its own fresh consumer, and no case
  depends on another target's cases.
- The Bazel the integration tests run is pinned by version and digest, and
  their inputs are declared, so a cached result is a result for the current
  ruleset.

**Non-Goals:**

- `e2e/smoke`, `e2e/install` and `tests/bcr` stay build roots that CI runs
  directly, in `.bazelignore`. Developers run Bazel in them, and the second
  spike shows that the root would walk the `bazel-*` symlinks this leaves.
- No new behavior, and no case added or dropped.
- CI is not moved onto `bazel-contrib/.github`'s `bazel.yaml`. Its own jobs
  carry the Linux sandbox adjustment and the per-folder steps, and moving
  them is not needed for any of this.

## Decisions

### 1. The floor is checked in the consumer folders, under the floor Bazel

`minimum_bazel.sh` goes. Its consumer is what `e2e/smoke` already is: a
`yarn_binary` on `@yarn` and `yarn_version_test`. The floor job runs
`e2e/smoke`'s tests under `USE_BAZEL_VERSION=<floor>` with
`--lockfile_mode=off --test_tag_filters=-block-network`, as it already does
for `e2e/install`. It reads the floor from `bazel_compatibility` in
`MODULE.bazel` the same way.

It also runs `bazel run //:yarn -- --version` there, because `bazel run` is
the one way into the launcher's `BUILD_WORKING_DIRECTORY` branch
(`yarn_binary.sh.tpl:41-43`). The script took that branch, and `e2e/smoke`'s
test does not.

Alternative: a nested-Bazel test under a pinned Bazel 8.3.0. It would need a
consumer of its own, since `e2e/smoke` cannot be a child workspace (see
Non-Goals), and it would check less than the two folders do.

### 2. The pattern, without the tool as a dependency

The integration targets are `rules_shell` `sh_test`s written to the
convention above. The tool itself is not a dependency, because it costs more
than it gives:

| | |
| --- | --- |
| What it would give | an `sh_test` with two environment variables, and a glob helper |
| What this change would not use from it | the Bazel downloader (no digest, see below) and the scratch-copy script (it copies the child alone, and the copy here has to hold the parent too) |
| What it costs | 56 modules in the root's graph. Toolchain repositories every root build fetches, one of them a symlink to the host's `git` (Context, last bullet). Go's SDK list in the lock. |

Each target's `sh_test` takes these as `data`:

- the Bazel binary;
- Node.js;
- the child workspace's files;
- `//:local_repository_files`;
- the fixtures, and through `consumer.sh`'s `deps` the registry's.

The binary, Node.js and the child's `MODULE.bazel` reach the runner as
`$(rlocationpath)` arguments. The rest it finds by their place beside those,
or by `rlocation` of a fixed path.

A list comprehension in `tests/integration/BUILD.bazel` declares the 7 targets
the same way. No macro is needed for one file's use.

The Bazel binary is 9.2.0, fetched with `http_file` for linux-x86_64,
linux-arm64, darwin-x86_64 and darwin-arm64, each pinned by the SHA-256 Bazel
publishes beside it; tasks.md records the URLs and digests. An `alias` with
`select()` on `@platforms` picks the host's binary. The tool's own
`bazel_binaries` extension is not an option either way. It downloads Bazelisk
with no digest (`bazel_binaries.bzl:12-22`), and leaves Bazelisk to download
Bazel while the test runs (`bazel_binaries_script.template`).

`bazel_binary_test` runs the pinned binary with `--version`, which the client
answers without a server, and requires `.bazelversion`'s version. Without it,
a bump of `.bazelversion` would leave the nested tests on the old Bazel
without anyone noticing.

Alternative: keeping the script, moved to `tests/`, as rules_jvm_external
keeps `tests/bazel_run_tests.sh`. A script stays outside the test graph: no
target to run, no result to cache, and one failure in setup ends every case.

### 3. Layout and names

| Path | Holds |
| --- | --- |
| `tests/integration/BUILD.bazel` | the Bazel binary's alias, `bazel_binary_test`, the 7 targets, the `integration_tests` suite |
| `tests/integration/consumer.sh` | the `sh_library` every runner sources: the scratch copy of the consumer, the nested Bazel's `b`, and the `lock`/`pin`/`build`/`built`/`store` steps `install_scenarios.sh` defines today |
| `tests/integration/install_consumer/` | the child workspace each target copies and changes. It keeps no lockfile (`--lockfile_mode=off`), as `tests/bcr` does. |
| `tests/integration/install_<concern>_test.sh` | one runner per target |
| `tests/integration/fixtures/` | the fixtures only these tests use: the poisoned tool, the credential helper, the cycle probe, the tree digest |
| `tests/fixture_registry/harness.sh` | the `sh_library` both test kinds build on: the case bookkeeping (`record`, `die`, `fail_with`), the hostile host, the registries, the ancestor check (Decision 7), and the project's files |
| `tests/fixture_registry/` | `fixture_registry.js`, with `tool_cli.js`, which a fixture package serves, and `marker_plugin.cjs`, which both test kinds plant |

The 7 targets:

- `install_fetching_test`
- `install_tarballs_test`
- `install_targets_test`
- `install_refusals_test`
- `install_pin_file_test`
- `install_host_test`
- `install_downloader_test`

`.bazelrc` gets `common --deleted_packages=tests/integration/install_consumer`.
`common` covers `fetch` and `mod` too, which the tool's README's `build` and
`query` lines leave out. The flag is Bazel 9.2.0's `PackageOptions.java`
(`deleted_packages`).

`.bazelignore` lists the four `bazel-*` links Bazel leaves in the child when
someone runs it there by hand. `--deleted_packages` deletes only the child's
own package, and the root would otherwise walk into the links and fail on what
they hold (the second spike).

The child reaches the ruleset through `local_path_override(path = "../../..")`.
The parent's files come from a root `BUILD.bazel` with `local_repository_files`,
plus an `all_files` filegroup in `yarn`, `yarn/private` and
`yarn/private/install`. All of these have `visibility = ["//:__subpackages__"]`.

Each runner copies `$RUNFILES_DIR/_main`, which holds both, into its scratch
directory and works there. The copy keeps the relative path resolving, and
leaves the Bazel binary, which lives outside `_main`, where it is. A test that
changed files in place would write through the runfiles links into the source
tree.

### 4. Which case goes where

The cases keep their assertions; only their home changes. Line numbers are
`install_scenarios.sh`'s at `7f97d0f`.

| Target | Cases (line) |
| --- | --- |
| `install_fetching_test` | First pin (209), Default architecture (220), scoped package (223), Nothing changed (233), lockfile change noticed (244), pin-only change (249), Lockfile changed (258), Named architectures (270) |
| `install_tarballs_test` | Package built from its tarball (286), tarball shapes (324) |
| `install_targets_test` | Only the dependency's packages (341), Dependency cycle (344), Scope (346), cycle in a sandboxed action (503) |
| `install_refusals_test` | Integrity mismatch (358), Checksum mismatch (364), Configuration Yarn cannot read (372), no target after a failed install (375), Lockfile out of date (381), Link inside a package (385), packageExtensions (528), patched entry's checksum (575) |
| `install_pin_file_test` | Malformed pin file (441), repaired pin unchanged (443), Missing pin file (447), lockfile checksum against the pin (653) |
| `install_host_test` | No host installation (402), Host global folder (413), Plugins and network settings (429) |
| `install_downloader_test` | Cold fetch from the repository cache (457), Credentials from a credential helper (468) |
| `//tests/install:yarn_behavior_test` | cache key (544), `yarn npm info` (559), plugin from the project's file (594), plugin above the project under an rc name (602), per-host proxy against `enableNetwork: false` (613), `YARN_SUPPORTED_ARCHITECTURES` (622), install from the host's global cache (635) |

Some cases rely on setup the script did elsewhere. Each target or test does
that setup itself:

- **429 and 613** need a second registry with the `proxy` control file, which
  the script started in its host section (415-417).
- **635** needs the first registry's `proxy` file (628).
- **653** needs Yarn's cache in the planted `HOME`. The plan reviewer showed,
  with Yarn 4.18.0 and Node.js 24.21.0 against the registry, that
  `install --mode=update-lockfile` alone writes `left-npm-1.0.0-…-10c0.zip`
  there. So `install_pin_file_test`'s own `lock` provides it.

"Configuration above the project under the install's former file name" (433)
asserts that no install so far loaded the planted plugin. Every target plants
it, so `consumer.sh` makes that the last case of every target.

Host Global folder (413) digests the whole planted `HOME`. The script left out
`.cache/bazelisk`, because the host's Bazelisk wrote there. With a pinned
binary nothing should write there, so the exception goes.

### 5. Yarn's own behavior is an ordinary test

The 7 cases in the last row run Yarn alone, as `bazel run //:yarn` did in the
consumer. Nothing in them needs a nested Bazel. So they become an `sh_test` in
`tests/install/`, beside the install's other tests. It runs the root's
`yarn_binary` on `@yarn` from runfiles, as `tests/launcher/yarn_cli_test.sh`
does. It runs against the two registries, with the planted files in its
scratch directory. It is not `manual`, so `bazel test //...` runs it, the
release runner included. It needs only the loopback registries.

### 6. Tags

The 7 targets are tagged `exclusive`, `manual` and `requires-network`
(`common/tags.html` in Bazel 9.2.0, lines 60 and 91-109):

- `exclusive`, because a nested Bazel is heavy;
- `manual`, to keep them out of `//...`;
- `requires-network`, since the nested Bazel fetches the registry's modules
  and Node.js.

Exclusive tests run sandboxed by default
(`incompatible_exclusive_test_sandboxed`), so the outer sandbox stays on; see
Risks for macOS.

`bazel_binary_test` is `manual` only. It fetches a Bazel binary, which
`//...` has no other use for, but it starts no server.

The `integration_tests` suite is tagged `manual` itself, for two reasons:

- `manual` does not keep out a test that a suite lists by name (`tags.html`,
  lines 104-106). Without the suite's own tag, the root's `bazel test //...`
  would run every nested Bazel, and so would the release workflow's
  `bazel test --test_tag_filters=-block-network //...`.
- A suite's tags also select among the tests it lists: only tests with every
  positive tag are included (`TestSuiteRule.java:41-66` at 9.2.0). So the
  suite carries no other tag. With `exclusive` too, it dropped
  `bazel_binary_test`, which was seen in a run that executed 7 of the 8.

### 7. Nothing of the real host reaches a case

- Every runner calls the nested Bazel with `--nosystem_rc --nohome_rc`
  (`BazelStartupOptionsModule.java` at 9.2.0), so the host's
  `/etc/bazel.bazelrc` cannot change a case.
  - It also sets an `--output_user_root` in its scratch directory and the
    planted `HOME`, as `b()` does today.
  - It runs under `env -i`, with only `PATH`, the planted `HOME` and a
    `TMPDIR` of its own.
  - `--max_idle_secs=60` lets its server exit should a test die without
    shutting it down.
- The scratch directory is made with `mktemp` under `/tmp`, as the script
  made it, not under `$TEST_TMPDIR`.
  - Yarn, running on its own, reads a `.yarnrc.yml` in every directory above
    the project. `$TEST_TMPDIR` sits under the user's own `~/.cache/bazel` on
    Linux, so a developer's `~/.yarnrc.yml` would reach `lock` and the
    Yarn-behavior cases.
  - `/tmp` works inside the sandbox: linux-sandbox gives each test a `/tmp`
    of its own, and darwin-sandbox lets a test write there.
- `harness.sh` still looks, before it plants anything, in every directory
  above the scratch directory's physical path for `.yarnrc.yml` or
  `.rules-yarn-install.yml`. If one exists, the test stops and names it.
  Only a `/tmp/.yarnrc.yml` or a `/.yarnrc.yml` could do that now.
- `tests/install/yarnrc_yarn_test`, which the plan review thought exposed in
  the same way, is not. It runs Yarn as the install does, under an rc name of
  its own (`yarnEnvironment` in `driver.js` sets `YARN_RC_FILENAME`), and
  Yarn then reads no `.yarnrc.yml` above the project. That was measured
  with the pinned Yarn: an ancestor's `npmRegistryServer` is read under the
  default name, and not under `.rules-yarn-test.yml`.

### 8. Where each check lives, judged by need

| Check | Where, and why |
| --- | --- |
| `install_scenarios.sh` | Bazel test targets (Decisions 2-5). Its cases need a nested Bazel or Yarn on a hostile host. As Bazel tests their inputs are declared and their results are cached, and each target fails alone. |
| `minimum_bazel.sh` | gone; `e2e/smoke` under the floor (Decision 1) |
| `e2e/smoke`, `e2e/install`, `tests/bcr` | consumer folders CI runs (Non-Goals) |
| floor step for `e2e/install` | stays, joined by `e2e/smoke` |
| `checks`: `release_prep.sh` under a tag, release-notes checks | stays in CI. It tests a workflow's script, in the environment the workflow runs it in, and needs `git` and a tag. |
| `tools/hooks/protect_generated_test.sh`, `tools/hooks/openwiki_staleness_test.sh` | stay. They test git hooks against a git repository, with the host's `git` and `jq` (`protect_generated_test.sh:19`), which a Bazel test may not take from the host. |
| "Run the pre-commit hooks", "Check the wiki still describes the repository" | stay. They check the repository's files as committed, not the ruleset's behavior. |
| "Report the Bazel version in use", "Report what sandbox the runner allows" | stay: diagnostics, not tests |
| `next-release`: the version `tag.yaml` would give, without writing a tag | stays: it runs the same Docker action `tag.yaml` runs, which only a workflow can |

## Risks / Trade-offs

- [Risk] macOS's sandbox may not nest. Then the nested Bazel's cycle case in
  `install_targets_test`, which names the host's sandbox
  (`--spawn_strategy=darwin-sandbox`), fails, or the whole run does.
  - It names it because `sandboxed` also names processwrapper-sandbox, which
    Bazel falls back to where the real one cannot run (`SandboxModule.java`
    at 9.2.0, lines 288-345). Under that name the case would pass without
    the sandbox it is about, and the outcome below could not be told.
  - CI runs it on both platforms at the change's push (task 2.4).
  - If macOS fails, the targets get `no-sandbox` (`common/tags.html:24`).
    That is the script's arrangement today: the nested Bazel's own sandbox is
    the only one. Tags cannot be `select()`ed, so it would apply on Linux too.
  - Either outcome is recorded.
- [Trade-off] CI will take longer than the script's 2 m 30 s and 4 m 11 s. Each
  of the 7 targets fetches its consumer's dependencies afresh, where the
  script fetched once, and `exclusive` runs them one at a time.
  - The time is measured and recorded. That is the price of independent
    cases.
- [Known limit] The child sees the ruleset through the packages
  `//:local_repository_files` names. Each package's `all_files` globs every
  file in it, so a new file is seen. A new package under `yarn/` is not seen
  until it is named there. A case that reaches it then fails, so no target
  passes with a wrong view. The release archive is built by `git archive`, not
  from these filegroups, so the gap is test-only.
- The child's `bazel-*` links and a developer's `~/.yarnrc.yml` were recorded
  here as known limits in an earlier draft. The change review showed both
  could be fixed, so they are: `.bazelignore` (Decision 3) and the scratch
  directory under `/tmp` (Decision 7).

## Migration Plan

This change branches from `rename-the-module`. It merges to main after that
change and before the v0.2.0 tag, so the release carries both. Rollback is
reverting this change's commit, which restores the scripts and the CI steps.
