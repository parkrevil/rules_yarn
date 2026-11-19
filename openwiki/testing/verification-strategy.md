---
type: testing
title: Verification strategy
description: The test layers that hold the ruleset's guarantees — Starlark unit tests over selection, analysis tests over the rule, shell tests that execute the launcher and the real Yarn CLI, Node.js tests of the install driver's programs, consumer modules that use only the public API, nested-Bazel tests that install from a local registry in a hostile host, and a test of the Yarn behavior the install's design rests on.
tags: [testing, rules-testing, analysis-test, sh-test, e2e]
sources:
  - id: openwiki-source-a4bd6b79c62e34a3dbb09576
    resource: repo://.bazelignore
  - id: openwiki-source-61e437e4689f6b29dc54938b
    resource: repo://.bazelrc
  - id: openwiki-source-a996efa61d56b86aea305719
    resource: repo://.bcr/presubmit.yml
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-59d9ddc709e90a3c0e34a2d0
    resource: repo://BUILD.bazel
  - id: openwiki-source-6baa3bd517a8e6434ec03836
    resource: repo://e2e/install/BUILD.bazel
  - id: openwiki-source-8f322198adc8ed03086b9d4d
    resource: repo://e2e/install/installed_test.sh
  - id: openwiki-source-d159ea9440fc4640c297be62
    resource: repo://e2e/install/part_test.sh
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
  - id: openwiki-source-bf3f205da02e00511cb718fc
    resource: repo://e2e/smoke/host_tool.sh
  - id: openwiki-source-30a0b6b2b81e4795cac4f928
    resource: repo://e2e/smoke/yarn_version_test.sh
  - id: openwiki-source-73fd324955f975c877a99db0
    resource: repo://openspec/changes/archive/2026-10-05-extract-packages-from-tarballs/tasks.md
  - id: openwiki-source-60333732fb171617af73e98d
    resource: repo://openspec/changes/archive/2026-10-05-install-yarn-dependencies/design.md
  - id: openwiki-source-8fb8a65196be59b25e803b94
    resource: repo://openspec/changes/archive/2026-10-05-install-yarn-dependencies/tasks.md
  - id: openwiki-source-01bd775b2b199eca72dcc70e
    resource: repo://tests/bcr/.bazelrc
  - id: openwiki-source-fc991def903a3901c3cc2810
    resource: repo://tests/bcr/BUILD.bazel
  - id: openwiki-source-9396675ac7636781156cad60
    resource: repo://tests/bcr/MODULE.bazel
  - id: openwiki-source-82caa9f3eab4a43e183311bb
    resource: repo://tests/docs/BUILD.bazel
  - id: openwiki-source-a8aba4c9b8a07e5ed3cadfbc
    resource: repo://tests/docs/docs_test.js
  - id: openwiki-source-42fff598a74b8a8cf6e6de47
    resource: repo://tests/extensions/extensions_tests.bzl
  - id: openwiki-source-cbb7c78690cd64711a0bd498
    resource: repo://tests/fixture_registry/harness.sh
  - id: openwiki-source-225340f64cde50bf1db88e14
    resource: repo://tests/install/BUILD.bazel
  - id: openwiki-source-186e1eeea778492c4f3de07f
    resource: repo://tests/install/extract_test.js
  - id: openwiki-source-e2f407b8e02db47e00a29b1f
    resource: repo://tests/install/layout_test.js
  - id: openwiki-source-515ecb9fb76cac4da668ba48
    resource: repo://tests/install/node_test.sh
  - id: openwiki-source-bb76665a0173e3c463c3f320
    resource: repo://tests/install/sources_test.js
  - id: openwiki-source-6f81bc5575accb64cf886747
    resource: repo://tests/install/yarn_behavior_test.sh
  - id: openwiki-source-ca84f08526069556e5f272aa
    resource: repo://tests/install/yarnrc_yarn_test.js
  - id: openwiki-source-dbc74d28193fcb310b3e1626
    resource: repo://tests/integration/BUILD.bazel
  - id: openwiki-source-93582a2f2259eee3ad262a36
    resource: repo://tests/integration/consumer.sh
  - id: openwiki-source-d38c9b970d1bda57d9bd1209
    resource: repo://tests/integration/fixtures/cycle_probe.js
  - id: openwiki-source-bfe00a88896432bdfb87d372
    resource: repo://tests/integration/install_consumer/MODULE.bazel
  - id: openwiki-source-bbb5bcd1f33855c01068e6e3
    resource: repo://tests/integration/install_refusals_test.sh
  - id: openwiki-source-0ecae0a713b810a3bd4ff8b3
    resource: repo://tests/integration/install_tarballs_test.sh
  - id: openwiki-source-24cd100d0b69e38c82893ab4
    resource: repo://tests/integration/install_targets_test.sh
  - id: openwiki-source-2786bbb2f5598011b27e9081
    resource: repo://tests/launcher/BUILD.bazel
  - id: openwiki-source-8de250de58da6ab4a8a00c9f
    resource: repo://tests/launcher/host_tool.sh
  - id: openwiki-source-8a52f3cc97aa21919ea82129
    resource: repo://tests/launcher/launcher_test.sh
  - id: openwiki-source-d066155d67929b81ea0f151f
    resource: repo://tests/launcher/yarn_cli_test.sh
  - id: openwiki-source-26c30b7d6e8e08696306b1d2
    resource: repo://tests/launcher/yarn_offline_test.sh
  - id: openwiki-source-ca621fdd9c1fe509f3bed92e
    resource: repo://tests/repositories/repositories_tests.bzl
  - id: openwiki-source-8128c9332cc7d75bca4dc18e
    resource: repo://tests/yarn_binary/BUILD.bazel
  - id: openwiki-source-eb3dcfac0b874f311a6353ac
    resource: repo://tests/yarn_binary/yarn_binary_tests.bzl
  - id: openwiki-source-b556aad9e4bffdbb4dc7c367
    resource: repo://tools/hooks/fixtures/failing_tool.sh
  - id: openwiki-source-f62aa9ed7021af1727946d31
    resource: repo://tools/hooks/openwiki_staleness_test.sh
  - id: openwiki-source-c344118095552b0e155044aa
    resource: repo://tools/hooks/protect_generated_test.sh
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
generated: { by: "claude-code", at: "2026-11-19T19:25:05.306Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-11-19T19:35:30.372Z
---

# Verification strategy

Each guarantee the ruleset makes is held by the cheapest layer that can actually
observe it. The layers differ in what they can see, so they are not
interchangeable.

## Layer 1 — Starlark unit tests over selection

Version selection is a pure function of the module graph, so it is tested as
one. `select_distributions` takes its failure handler as a parameter, and the
tests pass a list's `append` in place of `fail`, which makes every rejection
path observable: the returned value, and the exact message, without aborting
the test.

The module graph itself is faked with plain structs mirroring the shape Bazel
supplies — `is_root`, `name`, `version`, and `tags.distribution` and
`tags.install`. This is what
lets the suite cover orderings that would otherwise require building real module
graphs: root versus dependency, near dependency versus far one, duplicate
declarations, and declarations that lost and therefore escape validation. Install
selection is tested the same way: a root install selected, and refused in a
dependency, under a repeated name, under a distribution's name, or naming an
unknown distribution.

The report the extension gives Bazel is tested the same way, with a fake
`module_ctx` whose `is_dev_dependency` reads a flag off the tag: a regular
declaration, a development-only one, the same repository declared both ways, a
declaration by a dependency rather than the root, one naming a repository the
extension did not create, and a duplicate.

The repository rule is tested the same way too, against a mock context that
records each call, so the suite can assert call order and exact arguments
rather than inspecting a fetched directory.

## Layer 2 — analysis tests over the rule

`yarn_binary` is examined without executing anything: the declared executable,
the default outputs, the runfiles contents, and the template action's
substitution keys and values. One test asserts the launcher's runfiles contain
the Bash runfiles library; another builds an entry point that is a `filegroup`
with `data` and asserts the resource reaches the launcher's runfiles.

The host-path rejection is tested by configuration rather than by mocking: the
package defines a constraint, a platform carrying it, and a Node.js toolchain
that names only a host path. The analysis test requests that platform and
asserts the expected analysis failure. The toolchain is registered as a
development dependency of the root module, so it never affects a consumer.

## Layer 3 — executing the launcher

Behavior that only exists at run time is tested by running the launcher.

A probe entry point stands in for Yarn and reports what it received. Against it
the suite checks argument fidelity for spaces, quotes, globs, semicolons,
newlines and empty strings; that the launcher's forced environment overrides the
caller's; exit-status propagation; the working-directory rule in both directions;
that relative runfiles paths survive the directory change; and a manifest-only
runfiles lookup performed with the runfiles directory removed from the
environment.

A second test drives the real Yarn distribution. It copies a checked-in
stand-in, `host_tool.sh`, onto `PATH` as `node`, `yarn` and `corepack`; the
stand-in records any invocation and exits non-zero, and the test asserts the
selected version is printed and the marker file never appears — the direct
evidence that no host tool participates. It also copies a checked-in project
whose configuration redirects Yarn to a script of its own and asserts both
that the redirect is ignored and that the project files are unchanged
afterwards. Neither test writes a script: AGENTS.md keeps the launcher
template the only generated one.

## Layer 3a — the one thing only a blocked network can show

That Yarn needs no network for `--version` cannot be shown by running it where
the network is there. So it is its own target, `yarn_offline_test`, in both
consumer-facing roots: tagged `block-network`, it first asserts the network
really is unreachable and fails if it is not, then runs `--version` and checks
the project is unchanged.

Nothing else depends on that tag. The tests above assert things that hold
whether or not the sandbox blocks anything, and they used to share a target
with this assertion — so one unavailable capability took three unrelated
checks down with it. Separating them means a run that cannot block the network
loses exactly the one check it cannot make.

## Layer 3b — the install driver's programs

`yarn.install` does most of its work in Node.js programs that a repository rule
runs, which no Starlark test can execute. Each has a test file under
`tests/install/`, run by `node_test.sh` with Node's built-in runner on the
Bazel-managed Node.js, and given what it needs as `NAME=<runfiles path>`
arguments: js-yaml, fetched by integrity as the driver gets it, the pinned
Yarn, or the host's bsdtar from `tar.bzl`.

| Test | What it holds |
| --- | --- |
| `archive_test` | the archive format: round trips, byte-identical packing regardless of listing order, refused links, malformed archives, name collisions |
| `lockfile_test` | the lockfile read as Yarn reads it, and its shape checks |
| `check_test` | the project and pin checks, one refusal at a time, and the tarball paths Yarn requests |
| `conditions_test` | condition evaluation and which tarballs a host fetches, including the patch-source case a large project found |
| `layout_test` | links and `.bin` entries derived from Yarn's package map, compared with the links Yarn itself wrote for two captured projects; each direct dependency's store packages and `.bin` entries, through cycles, scopes and workspaces; a link a target name cannot hold refused |
| `yarnrc_test` | which settings are carried, and the YAML cases reviews found, each stating what Yarn reads |
| `yarnrc_yarn_test` | the pinned Yarn's own effective configuration: the same carried values from the project's file and from the file the driver writes |
| `driver_test` | the plan step reporting every unreadable input instead of throwing |
| `sources_test` | the store path Yarn gives an `npm:` resolution, against the store paths Yarn wrote for two captured projects, and each store package's candidate tarball |
| `extract_test` | extracting with the host's bsdtar, normalising, the manifest and its comparison, case and Unicode-normalisation collisions, and the build action's check failing on a manifest that is not the tarball's |
| `watched_test` | the repository rule watching every module the driver loads |

`yarnrc_yarn_test` is the one that asks Yarn rather than a port of it. Every
other comparison with Yarn — the YAML reading, the condition grammar — rests on
code read at the pinned tag; this one runs `yarn config get` for each carried
setting and each of the install's own settings, with the driver's own files
and environment, and compares what Yarn reports for the project's file with
what it reports for the files the driver writes. A failing Yarn run never
counts as agreement, and each case states what Yarn should make of it. For
the documents Yarn fails on, it requires Yarn to fail on the carried part read
alone, which is the check the driver makes at every install.

`tests/install:yarn_behavior_test` measures Yarn rather than the ruleset: the
seven things Yarn does on its own that the install's design rests on — the
cache key it writes, what `yarn npm info` answers for a missing version, a
project's plugin loaded, a plugin named under a given rc name above the
project loaded, a per-host proxy outliving `enableNetwork: false`, the
architecture sets refused through the environment, and an install from the
host's global cache with the registry refusing everything. It runs the pinned
Yarn through a `yarn_binary` launcher, as `bazel run` would in a consumer, in a
project under the hostile host described below, and needs no Bazel of its own.

`tests/docs:docs_test`, on the same runner, reads the text protos Bazel's
`starlark_doc_extract` extracts from the three public `.bzl` files and requires
a non-empty doc string on every rule, extension, tag class, provider,
attribute and field, and the public names to be present, and fails on an
entry of a kind it does not know; it compares nothing else, since the rule's
output is not stable across Bazel versions. It failed with one field's doc
string emptied.

## Layer 4 — the consumer modules

Consumption through a module boundary cannot be observed from inside the module
being consumed, so there are modules outside it. There are three, because they
answer different questions.

`e2e/smoke` depends on the ruleset the way a consumer does, uses only the
public API, and pins a lockfile under `--lockfile_mode=error`. It checks one
configuration thoroughly.

`e2e/install` installs a real project with `yarn.install`: a patched package
through `resolutions`, Yarn's built-in TypeScript patch, a package with
platform-specific binaries that asks to be built, two workspaces with a React
peer dependency, and a `packageExtensions` entry. Its tests check the installed
tree from runfiles — versions, the patch applied, peers, the host's platform
package only, no build script run, workspaces kept apart — then again in a
sandbox that blocks the network, and run an action that finds a package
through `YarnNodeModulesInfo`'s root. Each assertion was shown failing on a
deliberately broken copy of the tree. Three more tests take only one direct
dependency's target — the patched `is-number`, a workspace's peer-dependency
instance of `react-dom`, and `typescript` with its `.bin/tsc` — and check that
their runfiles hold exactly the store packages it reaches, and a provider test
resolves a workspace's `is-number` through its target's root; they failed
with the whole tree in place of the part, and with the install's root in
place of the workspace's.

`tests/bcr` is what the Bazel Central Registry's presubmit runs. It keeps no
lockfile, because that presubmit resolves it under several Bazel versions. It
is deliberately minimal — build a Yarn target through the public API and run
it — since its job is to show the published module works as a dependency, not
to re-run this suite.

The repository root excludes all three from its own package discovery through
`.bazelignore`, so each is built and tested by its own invocation in its own
directory rather than being swept into `//...`. The floor job runs `e2e/smoke`
and `e2e/install` again under the oldest Bazel `MODULE.bazel` accepts — the
folders-by-Bazel-version arrangement of bazel-contrib's reusable test workflow.

## Layer 5 — what only a fresh consumer in a hostile host can show

Fetching, pinning, refetching and isolation from the host cannot be shown
from inside a module that has already fetched. The tests in
`tests/integration/` each run a Bazel of their own, inside the test, on a
fresh copy of a consumer, the child workspace `install_consumer/`. That
Bazel is the 9.2.0 binary `MODULE.bazel` pins by digest, not one found on the
host (see Version pinning). The layout follows `rules_bazel_integration_test`'s
pattern without that module as a dependency:

- the child is in `--deleted_packages`, so the root's `//...` does not load
  it, and its files are globbed as the tests' data;
- the root's `local_repository_files` gathers each ruleset package's
  `all_files`, so the child's `local_path_override(path = "../../..")` finds
  the ruleset in the copy;
- the tests are `exclusive`, `manual` and `requires-network`, and the
  `integration_tests` suite that lists them is `manual` too, so neither the
  root's `//...` nor the release workflow runs them. CI runs the suite;
- `install_targets_test` is also `no-sandbox`, because one of its cases runs
  an action in the nested Bazel's own sandbox, and on macOS a sandbox does not
  nest: inside the outer `darwin-sandbox`, the nested Bazel registered no
  `darwin-sandbox` strategy at all (CI run 44596357423). The other six keep
  the outer sandbox.

Each test copies the runfiles tree's `_main` into a `mktemp` directory under
`/tmp` and works there, never in the runfiles, whose links lead into the
source tree. The scratch directory is under `/tmp` because Yarn run on its own
reads a `.yarnrc.yml` in every directory above its project, and the test's own
temporary directory sits under the user's home on Linux; before planting
anything, `harness.sh` stops the test if any directory above the scratch
directory holds one. The nested Bazel runs under `env -i`, with
`--nosystem_rc --nohome_rc` and an output root in the scratch directory.

`tests/fixture_registry/fixture_registry.js` serves fixture packages it builds
in memory — a scoped one, platform packages, one whose tarball holds a link —
so no case depends on a public registry. The host is hostile: the nested
Bazel's home, the directory above its output root and the output root itself
each hold a `.yarnrc.yml` pointing the registry at a closed port, and a file
under the install's former configuration name that loads a marker plugin.
Every test ends with the case that the marker was never left.

The tests ask Bazel for the install repository's canonical name with
`bazel mod dump_repo_mapping ''`, because the format is not an API, and use
it to find the installed tree and to match Bazel's "no such target". Every
Bazel command whose failure stops a test keeps its output in a log that
`fail_with` prints in full; locking, pinning and building record which log
they wrote, so when a chain of them stops, the failing step's log is printed.

| Test | Cases |
| --- | --- |
| `install_fetching_test` | the first pin; the host's platform package only, under the planted configuration; a scoped package; nothing changed installs nothing; a lockfile change and a pin-only change install again; a new version is installed; named architectures |
| `install_tarballs_test` | plain packages extracted at build time with no archive kept; nine tarballs shaped the way some registry tarballs are — directories without an execute bit, a mode-0000 file, a hard link, a contiguous file, an absolute path, a `./package/` prefix, a `..` entry, a FIFO, and, where the filesystem keeps case apart, names differing only by case — each installing Yarn's tree, the first two from their tarballs and the rest from archives |
| `install_targets_test` | building one dependency's target builds only its package's directory; a cycle held whole by one package's target; a scope's target holding both its packages; a dependency cycle and a file named `col:on.js` used from an action in the host's own sandbox |
| `install_refusals_test` | integrity, checksum, unreadable-configuration, out-of-date-lockfile and link refusals; no dependency's target after a failed install; `packageExtensions` and the immutable install; a changed checksum on a patched entry |
| `install_pin_file_test` | a malformed and a missing pin file repaired through `:pin`; the lockfile's checksum being the digest of Yarn's cache archive, not of the tarball the pin records |
| `install_host_test` | a poisoned `node`, `yarn` and `corepack` first on the `PATH` repository rules see; the host home, its Yarn global folder included, unchanged in content and metadata; a project plugin not loaded and a project proxy seeing nothing |
| `install_downloader_test` | a cold fetch from the repository cache with the registry blocked; credentials from a credential helper |

On a filesystem that folds case Yarn itself cannot lay out the case-differing
package, so it is left out there. The cycle case names the host's sandbox —
`linux-sandbox` or `darwin-sandbox` — because `sandboxed` would fall back to
processwrapper-sandbox where the real one cannot run; its program is the
checked-in `tests/integration/fixtures/cycle_probe.js`. Executables the tests
put in the host's way are checked-in fixtures, copied rather than written.

These cases were once one script, `tools/ci/install_scenarios.sh`, whose
thirty-nine cases ran in sequence on one consumer. They were split by concern so
that each test starts from its own consumer and fails alone, and each test was
shown to fail with one thing it checks broken in the ruleset or a fixture. The
change's task list records each break and its output.

A measurement, not a test, sits beside them: a 717-entry project installed and
used, recorded in the install change's task list with its times and sizes.

## On top: what runs without being asked

`.github/workflows/ci.yml` runs on every push and pull request, over Linux and
macOS:

- **build and test** — all four roots and the nested-Bazel suite, on both
  platforms. This is where the platform claim stops being a claim.
- **oldest supported Bazel** — reads the floor from `bazel_compatibility` in
  `MODULE.bazel` and exports it as `USE_BAZEL_VERSION`. Under it, `e2e/smoke`
  and `e2e/install` are tested with the lock off, as a consumer resolving from
  scratch would, leaving out the `block-network` tests, which need the sandbox
  adjustment the build-and-test job makes. `e2e/smoke`'s Yarn target is also
  run with `bazel run`, the one way into the launcher's
  `BUILD_WORKING_DIRECTORY` branch, and must report the version the module
  asks for; the step runs under `bash` with `pipefail`, so a failed run fails
  it. The repository's own roots cannot be tested at the floor as they are:
  their lockfiles are written by a newer Bazel and set `--lockfile_mode=error`.
- **next release** — `smlx/ccv` with `write-tag: false`, which writes to the
  job summary the version `tag.yaml` would give the next release, so a change
  in how commits are written shows before the schedule acts on it.
- **checks** — the pre-commit hooks, which cover Buildifier, `actionlint` over
  every workflow, the file-hygiene hooks and `openspec validate --all
  --strict`; the contract tables of both
  harness hooks, the generated-file guard's and the wiki staleness gate's; the
  staleness gate itself; and `release_prep.sh` run under a tag of its own,
  requiring the release notes, the source archive, the documentation archive
  with each public file's binary proto, and a `docs_url` naming it.

The two contract tables are the layer for code that has no Bazel target. Both
hooks are shell scripts the harness runs, not things the build produces, so
each has a plain test script naming every decision it is supposed to make —
forty cases for the guard, fifty-six rows for the staleness gate, in both
cases mostly refusals, because for a guard the dangerous mistake is clearing
something it never checked. The staleness gate's table also injects failures
into the commands the gate depends on, so a command that does its work and
then fails is shown to be a refusal rather than a pass; the failing command
is a checked-in wrapper, `tools/hooks/fixtures/failing_tool.sh`, told the
real tool and one of four named moments to fail at.

The first run of this workflow found two defects no local run could have:
a GNU-only `find` flag the macOS runner rejected, and a Linux runner where
Bazel fell back to a sandbox that does not honour `block-network`.
