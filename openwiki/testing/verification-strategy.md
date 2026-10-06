---
type: testing
title: Verification strategy
description: The test layers that hold the ruleset's guarantees — Starlark unit tests over selection, analysis tests over the rule, shell tests that execute the launcher and the real Yarn CLI, Node.js tests of the install driver's programs, consumer modules that use only the public API, and a scenario script that installs from a local registry in a hostile host.
tags: [testing, rules-testing, analysis-test, sh-test, e2e]
sources:
  - id: openwiki-source-a4bd6b79c62e34a3dbb09576
    resource: repo://.bazelignore
  - id: openwiki-source-a996efa61d56b86aea305719
    resource: repo://.bcr/presubmit.yml
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-6baa3bd517a8e6434ec03836
    resource: repo://e2e/install/BUILD.bazel
  - id: openwiki-source-8f322198adc8ed03086b9d4d
    resource: repo://e2e/install/installed_test.sh
  - id: openwiki-source-9166404a3cbd4408b80101ce
    resource: repo://e2e/smoke/BUILD.bazel
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
  - id: openwiki-source-42fff598a74b8a8cf6e6de47
    resource: repo://tests/extensions/extensions_tests.bzl
  - id: openwiki-source-225340f64cde50bf1db88e14
    resource: repo://tests/install/BUILD.bazel
  - id: openwiki-source-186e1eeea778492c4f3de07f
    resource: repo://tests/install/extract_test.js
  - id: openwiki-source-515ecb9fb76cac4da668ba48
    resource: repo://tests/install/node_test.sh
  - id: openwiki-source-bb76665a0173e3c463c3f320
    resource: repo://tests/install/sources_test.js
  - id: openwiki-source-ca84f08526069556e5f272aa
    resource: repo://tests/install/yarnrc_yarn_test.js
  - id: openwiki-source-2786bbb2f5598011b27e9081
    resource: repo://tests/launcher/BUILD.bazel
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
  - id: openwiki-source-06ff1bab713011478aa79fbf
    resource: repo://tools/ci/fixture_registry.js
  - id: openwiki-source-4030dc4bcad5a09c915b98fb
    resource: repo://tools/ci/install_scenarios.sh
  - id: openwiki-source-d0cac2a9da6e4ff2f6a238cf
    resource: repo://tools/ci/minimum_bazel.sh
  - id: openwiki-source-f62aa9ed7021af1727946d31
    resource: repo://tools/hooks/openwiki_staleness_test.sh
  - id: openwiki-source-c344118095552b0e155044aa
    resource: repo://tools/hooks/protect_generated_test.sh
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
generated: { by: "claude-code", at: "2026-10-05T14:22:28.209Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-05T14:54:48.275Z
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

A second test drives the real Yarn distribution. It plants fake `node`, `yarn`
and `corepack` executables on `PATH` that record any invocation and exit
non-zero, then asserts the selected version is printed and the marker file never
appears — the direct evidence that no host tool participates. It also creates a
project whose configuration redirects Yarn elsewhere and asserts both that the
redirect is ignored and that the project files are unchanged afterwards.

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
| `layout_test` | links and `.bin` entries derived from Yarn's package map, compared with the links Yarn itself wrote for two captured projects |
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
deliberately broken copy of the tree.

`tests/bcr` is what the Bazel Central Registry's presubmit runs. It keeps no
lockfile, because that presubmit resolves it under several Bazel versions. It
is deliberately minimal — build a Yarn target through the public API and run
it — since its job is to show the published module works as a dependency, not
to re-run this suite.

The repository root excludes all three from its own package discovery through
`.bazelignore`, so each is built and tested by its own invocation in its own
directory rather than being swept into `//...`.

## Layer 5 — what only a fresh consumer in a hostile host can show

Fetching, pinning, refetching and isolation from the host cannot be shown
from inside a module that has already fetched. `tools/ci/install_scenarios.sh`
builds a throwaway consumer against a local registry,
`tools/ci/fixture_registry.js`, that builds its fixture packages in memory — a
scoped one, platform packages, one whose tarball holds a link — so no case
depends on a public registry. Every case runs with a `.yarnrc.yml` pointing the
registry at a closed port, and a configuration under the install's former file
name loading a marker plugin, in the Bazel client's home, above the output
root and in it.

Its thirty-five cases cover the first pin; the host's platform package and a
scoped package; that nothing changed installs nothing; that a lockfile change
and a pin-only change install again, and a new version is installed; named
architectures; integrity, checksum, out-of-date lockfile and link refusals; a
poisoned `node`, `yarn` and `corepack` first on the `PATH` repository rules see; the host home, its Yarn
global folder included, unchanged in content and metadata; a project plugin
not loaded and a project proxy seeing nothing; a malformed and a missing pin
file repaired through `:pin`; a cold fetch with the registry blocked; and
credentials from a credential helper; and a `.yarnrc.yml` Yarn cannot read,
refused because Yarn rejects the settings the install would carry. Two cases
cover building packages from their tarballs: plain packages are extracted at
build time with no archive kept, and nine tarballs shaped the way some registry
tarballs are — directories without an execute bit, a mode-0000 file, a hard
link, a contiguous file, an absolute path, a `./package/` prefix, a `..`
entry, a FIFO, and, where the filesystem keeps case apart, names differing
only by case — each install Yarn's tree, the first two from their tarballs and
the rest from archives. On a filesystem that folds case Yarn itself cannot lay
out that last package, so it is left out there.

The last eleven are the measurements the design rests on, kept as tests rather
than as notes: a dependency cycle and a file named `col:on.js` used from a
sandboxed action; what `packageExtensions` records in the lockfile; the cache
key Yarn writes; what `yarn npm info` answers for a missing version; a changed
checksum on a patched entry; Yarn run on its own loading a project's plugin,
and a plugin named in a file above the project under the rc name it is given;
a per-host proxy outliving `enableNetwork: false`; the architecture sets
refused through the environment; an install from the host's global cache with
the registry refusing everything; and the lockfile's checksum being the digest
of Yarn's cache archive, not of the tarball the pin records. The change's task
list maps each paragraph of the design's evidence to the test that reproduces
it, and lists the few facts read from Yarn's source instead. Executables it puts in the host's way are
checked-in fixtures, copied rather than written. Two reviews found assertions
in it that could pass after a failure; each was fixed and then broken on
purpose to see it fail.

A measurement, not a test, sits beside it: a 717-entry project installed and
used, recorded in the change's task list with its times and sizes.

## On top: what runs without being asked

`.github/workflows/ci.yml` runs on every push and pull request, over Linux and
macOS:

- **build and test** — all four roots and the install scenarios, on both
  platforms. This is where the platform claim stops being a claim.
- **oldest supported Bazel** — `tools/ci/minimum_bazel.sh` builds a throwaway
  consumer module under the floor `MODULE.bazel` declares and runs its Yarn
  target. It reads the floor and the Yarn version out of the repository, so
  the check cannot drift from what is declared. The repository's own roots
  cannot answer this: their lockfiles are written by a newer Bazel and both
  set `--lockfile_mode=error`, so an older Bazel fails on the lockfile before
  reaching the ruleset. The same job installs `e2e/install` at the floor with
  the lock off, as a consumer resolving from scratch would.
- **checks** — the pre-commit hooks, which cover Buildifier, the file-hygiene
  hooks and `openspec validate --all --strict`; the contract tables of both
  harness hooks, the generated-file guard's and the wiki staleness gate's; and
  the staleness gate itself.

The two contract tables are the layer for code that has no Bazel target. Both
hooks are shell scripts the harness runs, not things the build produces, so
each has a plain test script naming every decision it is supposed to make —
forty cases for the guard, fifty-six rows for the staleness gate, in both
cases mostly refusals, because for a guard the dangerous mistake is clearing
something it never checked. The staleness gate's table also injects failures
into the commands the gate depends on, so a command that does its work and
then fails is shown to be a refusal rather than a pass.

The first run of this workflow found two defects no local run could have:
a GNU-only `find` flag the macOS runner rejected, and a Linux runner where
Bazel fell back to a sandbox that does not honour `block-network`.
