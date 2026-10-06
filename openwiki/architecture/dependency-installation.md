---
type: architecture
title: Installing a project's dependencies
description: How yarn.install turns a project's yarn.lock into Bazel artifacts — the pin file, one integrity-checked repository per tarball, a layout repository rule whose driver runs the pinned Yarn offline against a loopback server, per-package archives unpacked by actions, the provider consumers read, and what is refused or not claimed.
tags: [yarn-install, repository-rule, module-extension, integrity, isolation, node-modules]
verified:
  - by: openwiki/0.5.1
    at: 2026-10-06T12:28:08.929Z
sources:
  - id: openwiki-source-6baa3bd517a8e6434ec03836
    resource: repo://e2e/install/BUILD.bazel
  - id: openwiki-source-9c4e78980d8d26ff68f9e119
    resource: repo://e2e/install/provider_root.bzl
  - id: openwiki-source-d92bdd4d3d554717b6869e2d
    resource: repo://MODULE.bazel
  - id: openwiki-source-03662065236e6ed9cea07f6b
    resource: repo://openspec/changes/archive/2026-10-05-extract-packages-from-tarballs/design.md
  - id: openwiki-source-73fd324955f975c877a99db0
    resource: repo://openspec/changes/archive/2026-10-05-extract-packages-from-tarballs/tasks.md
  - id: openwiki-source-60333732fb171617af73e98d
    resource: repo://openspec/changes/archive/2026-10-05-install-yarn-dependencies/design.md
  - id: openwiki-source-8fb8a65196be59b25e803b94
    resource: repo://openspec/changes/archive/2026-10-05-install-yarn-dependencies/tasks.md
  - id: openwiki-source-c23074b1ef135ae03bb87264
    resource: repo://openspec/changes/per-package-targets/design.md
  - id: openwiki-source-576d200b82f104a1111379ae
    resource: repo://openspec/changes/per-package-targets/tasks.md
  - id: openwiki-source-3a9d47c216ac83ae687d3e65
    resource: repo://tests/install/driver_test.js
  - id: openwiki-source-186e1eeea778492c4f3de07f
    resource: repo://tests/install/extract_test.js
  - id: openwiki-source-e2f407b8e02db47e00a29b1f
    resource: repo://tests/install/layout_test.js
  - id: openwiki-source-bb76665a0173e3c463c3f320
    resource: repo://tests/install/sources_test.js
  - id: openwiki-source-de9ac9bca103f5df1400a559
    resource: repo://tests/install/watched_test.js
  - id: openwiki-source-3acfc65272985ab92f4e511f
    resource: repo://tests/install/yarnrc_test.js
  - id: openwiki-source-ca84f08526069556e5f272aa
    resource: repo://tests/install/yarnrc_yarn_test.js
  - id: openwiki-source-4030dc4bcad5a09c915b98fb
    resource: repo://tools/ci/install_scenarios.sh
  - id: openwiki-source-e8d8326f8a04a478f4895424
    resource: repo://yarn/private/extensions.bzl
  - id: openwiki-source-0a3b1034f06d7d11f2f65afd
    resource: repo://yarn/private/install/archive.js
  - id: openwiki-source-c1e215f3cfa9ac9fdb59b5b5
    resource: repo://yarn/private/install/check.js
  - id: openwiki-source-f15dca4e7dc723999f735b3f
    resource: repo://yarn/private/install/conditions.js
  - id: openwiki-source-fa80dfa9d053206fdf5a7f9e
    resource: repo://yarn/private/install/driver.js
  - id: openwiki-source-5b97d2d7fb6db0ae06724904
    resource: repo://yarn/private/install/extract.js
  - id: openwiki-source-7a214e1441b92687e338af66
    resource: repo://yarn/private/install/layout.js
  - id: openwiki-source-9e1e67b90ea3e259fedb1f39
    resource: repo://yarn/private/install/node_modules.bzl
  - id: openwiki-source-f178751c97048e9fbd3613dd
    resource: repo://yarn/private/install/pin.cjs
  - id: openwiki-source-6da6376cacb3a4c5f3725a78
    resource: repo://yarn/private/install/repository.bzl
  - id: openwiki-source-9496e4d2064ef23f84cb2a45
    resource: repo://yarn/private/install/sources.js
  - id: openwiki-source-4ea75ec50617436e212f308e
    resource: repo://yarn/private/install/syml.js
  - id: openwiki-source-bf79b2e0e01f2ead3871382e
    resource: repo://yarn/private/install/tarball.bzl
  - id: openwiki-source-17487a07a18559614bffff8e
    resource: repo://yarn/private/install/yarnrc.js
  - id: openwiki-source-60f4d0e18953b7fc477fc496
    resource: repo://yarn/providers.bzl
generated: { by: "claude-code", at: "2026-10-06T12:28:08.929Z" }
---

# Installing a project's dependencies

`yarn.install` answers a different question from the distribution pipeline:
not which Yarn a build gets, but which packages a Yarn project's lockfile
installs, and how each is proven to be the package the lockfile names. It runs
in Bazel's external dependency phase like the distribution does, and ends in
ordinary build actions.

The shape is four steps: pin, fetch, lay out, unpack. Bazel does every
download; Yarn does only the layout, offline; the result is one artifact per
package.

## Responsibility split

| Step | Owner | Output |
| --- | --- | --- |
| Which installs exist, one repository per pinned tarball | `yarn/private/extensions.bzl` | `yarn_tarball` repositories and one `yarn_install_repository` per install |
| Fetching one tarball by its pinned integrity | `yarn/private/install/tarball.bzl` | `package.tgz` |
| Checking the project and laying it out | `yarn/private/install/repository.bzl` and `driver.js` | `layout.json`, one archive per package, a generated `BUILD.bazel` |
| Turning the layout into artifacts | `yarn/private/install/node_modules.bzl` | one directory artifact per package, one symlink artifact per link |
| Writing the pin file | `yarn/private/install/pin.cjs`, run as `@<name>//:pin` | the project's pin file |

## Step 1 — the pin file

Yarn's lockfile records a checksum for most packages, but it is a checksum of
Yarn's own cache archive, not of the registry tarball, and it is absent for
the conditional packages Yarn treats as optional builds. So the lockfile alone cannot tell Bazel's
downloader what bytes to expect. The pin file does: for every `npm:` entry of
the lockfile, a tarball URL and a SHA-512 integrity.

`bazel run @<name>//:pin` writes it. It runs the pinned Yarn's
`yarn npm info … --fields name,version,dist --json` in the developer's
checkout, a hundred locators per call, so the project's registry, scopes and
credentials apply exactly as they do to `yarn install`. Because `yarn npm info`
answers a version that does not exist with the latest one, an answer whose name
and version do not match the request is not accepted. The integrity is the
registry's published SHA-512; only a package whose registry publishes none is
downloaded and its bytes hashed, and the target names such packages. The file
is written sorted, as version 1.

That is trust on first download: the digest is whatever the registry
published when the developer pinned, recorded and reviewed in version control,
as npm and pnpm lockfiles record theirs.

The pin target is a `yarn_binary` whose entry point is `pin.cjs`, generated in
the install's own repository, so it exists even when the install cannot.

## Step 2 — one repository per tarball

The extension reads the pin file with `module_ctx.read`, so changing it re-runs
the extension, and creates one `yarn_tarball` repository per pin. Each does a
single `repository_ctx.download` with the pinned integrity. That puts every
package through Bazel's downloader: the repository cache, `--distdir`,
`--downloader_config` and credential helpers all apply, and a
digest that does not match fails the fetch. These repositories are marked
reproducible, which is true because their content is fixed by digest.

A pin file that is missing, empty or not a pin file yields no tarball
repositories rather than an error at this stage; the install repository
reports what is wrong, and its pin target still works. The extension watches
the file, so writing it re-runs the extension.

## Step 3 — checking and laying out

The install repository stages the project's declared inputs — the root
`package.json`, `yarn.lock`, each workspace's `package.json`, each patch file,
the optional `.yarnrc.yml` — each through `repository_ctx.watch`, so changing
any of them installs again. It also watches the driver and every module the
driver loads, because changing only JavaScript in a rules_yarn upgrade must
reinstall too, and `repository_ctx.path` alone does not watch a file; a test
checks that list against what the driver actually loads. Bazel's whole
environment is removed before the driver runs.

The driver runs twice.

**Plan.** It reads the lockfile and the carried settings, checks the project
and the pins, and chooses which tarballs to fetch. Every check reports through
a list of errors rather than throwing, because a throw would fail the
repository and take the pin target that repairs it down too. It refuses, by
name: a Yarn 1 lockfile; a `packageManager` naming
another Yarn; any resolution other than `npm:`, `patch:` on an `npm:` package,
or `workspace:`; an entry carrying its own archive URL; a workspace or patch
file the declaration does not list; and a pin file that is malformed or does
not match the lockfile, each with the command that fixes it — and conditions
it cannot parse, or a manifest or lockfile whose shape the checks cannot
handle, are reported the same way. The driver's entry point turns anything
either step throws into a reported error too, so the pin target survives
whatever the project holds.

**Install.** It copies the staged project into a scratch directory, starts an
HTTP server on 127.0.0.1 that serves only the selected tarballs — at exactly the
paths Yarn requests, a scope's `/` as `%2f` and the plain spelling Yarn retries
with — writes the only configuration Yarn will see, and runs the pinned Yarn on
the Bazel-managed Node.js with `install --immutable --mode=skip-build
--check-cache`. A request for anything not served fails the install naming it:
a metadata request means the lockfile does not resolve the project, a tarball
request means a package was not selected for fetching.

### Yarn sees nothing of the host

Yarn looks for its configuration file in the project, in every directory above
it, and in the home directory, and loads any plugin such a file names. The
driver points `HOME` at an empty directory of its own, and names the
configuration file through `YARN_RC_FILENAME` with a name drawn from 128 random
bits for each run. A fixed name would hide every `.yarnrc.yml`, but Yarn would
still look for the fixed name above the project, where it could be planted
with a plugin; a review demonstrated exactly that against an earlier version.

The environment is a fixed table: the Node.js directory as the whole `PATH`,
private global and cache folders, the global cache and the mirror off,
immutable installs, checksum mismatches thrown, the `pnpm` linker, scripts off,
telemetry off. The configuration file turns the network off except for
127.0.0.1, points the registry at the loopback server, and injects no
environment files.

### Four settings carried, nothing else

The project's `.yarnrc.yml` never reaches Yarn, because Yarn acts on it at
start-up in ways a fetch must not: it runs the plugins a file's top-level
`plugins` names, and its proxies and per-host network settings route past the
loopback-only gate. Some settings do shape a locked install — without a
project's `packageExtensions`, Yarn lays its packages out differently, and the
immutable install fails only when the difference reaches the lockfile — so
four are carried: `packageExtensions`, `enableTransparentWorkspaces`,
`defaultProtocol` and `compressionLevel`.

The ruleset does not interpret them. It keeps the project's document as Yarn
parsed it, removes every other top-level setting — keeping an `onConflict`
marker around the whole document if there is one — writes that back, and
checks that reading it back gives the same tree. Yarn reads that file from one
directory above the project and the install's own settings from a file in the
project, which is nearer and so decides wherever both speak; Yarn resolves the
carried settings itself. An earlier version resolved them and wrote the
result, and three reviews in a row found Yarn reading the result differently —
a marker around the whole document, `hardReset`, a dependency literally named
`onConflict`, nulls. A test now asks the pinned Yarn for each carried setting
from the project's file and from the two files, and requires the same answer.

Yarn also judges the carried settings at every install. Before installing,
the driver writes the carried part of the project's document in its own shape
to a directory of its own and asks Yarn for each carried setting there and in
the install's configuration; Yarn must accept the first, and both answers must
agree, or the install is refused with Yarn's output. A document Yarn cannot
read is therefore refused, not installed without its settings. A marker around
the whole document whose value is not a mapping is left out of the layered
file, where it would make Yarn drop the install's own settings too.

A carried setting holding `${` is refused: Yarn would fill it from an
environment the install does not share with the developer. The compression
level a lockfile's cache key must match is asked of Yarn under the install's
configuration, not computed.

Configuration outside the project — the developer's home configuration,
environment variables, plugins — is not read at all. Where it would change what
the lockfile records, the immutable install fails; where it would change only
the layout, it is not reproduced and not detected. `packageExtensions` is the
case that matters: Yarn records the dependencies an extension adds only in the
layout, so an extension the install did not see can leave the lockfile byte for
byte the same. That is why the project's own `packageExtensions` are carried
exactly, and checked by Yarn. The project's `nodeLinker` is not carried: the
layout is always Yarn's `pnpm` linker.

### YAML is read with Yarn's own parser

Yarn 4.18.0 reads both `yarn.lock` and `.yarnrc.yml` with `parseSyml`, which
loads text with js-yaml and the failsafe schema in JSON mode: every scalar a
string, a repeated key taking its last value. The ruleset reads both files the
same way — js-yaml 4.3.0, the version Yarn's own lockfile resolves at that tag,
fetched by `http_archive` with the registry's integrity, through a port of
`parseSyml` that refuses the Yarn 1 format.

It began with readers of its own, compared against js-yaml on generated
documents. Every review still found YAML they read differently — an open quote
after an anchor, a comma and a quote in a plain scalar, a no-break space that
JavaScript's `trim` removes and YAML keeps — and in `.yarnrc.yml` such a
difference silently changes which settings are carried. Reading with the same
parser removes the class rather than another instance of it, and each case
found is now a test stating what Yarn reads.

### Which tarballs are fetched

Platform-specific packages are installed for the host unless
`supported_architectures` names others, with Yarn's meaning: `os`, `cpu` and
`libc` are independent sets, so two systems and two CPUs admit four
combinations. Conditions are evaluated by a port of the expression grammar Yarn
uses.

Every `npm:` entry is fetched except a conditional one that has no recorded
checksum, is reached only through optional dependencies, and is incompatible
with the architecture set. Yarn leaves out exactly those, and keeps their
checksums out of the lockfile for the same reason, so an entry with a checksum
is one Yarn fetches everywhere. A large-project measurement found the case
that rule exists for: the macOS-only `fsevents` is the source of Yarn's
built-in patch, not an optional dependency, and Yarn requested it on Linux.
Fetching a package Yarn ends up not needing costs a download; missing one it
needs fails loudly at the loopback server.

### The result of the layout

Yarn's `pnpm` linker writes a store of packages and a package map. The driver
derives from the map every store package, every link between them, every
`.bin` entry of the root's and workspaces' direct dependencies — each
manifest's `bin` read as Yarn's `Manifest.load` reads it — and the
workspace-to-workspace links it records but does not create. A package
containing a symbolic link is refused, naming it.

It also walks Yarn's links from each direct dependency of the root and of each
workspace that is a store package: its link, the store package it points at,
the links in that package's own `node_modules`, and so on, each store package
once, so a cycle — every store package even links to itself — ends where it
closes. Each such dependency is recorded with the store packages it reaches
and the `.bin` entries it was given, and each scope among them with its
dependencies. A link holding a character a Bazel target name cannot is
refused, naming it, because the dependency's target is named after its link;
so is a dependency name that is neither `name` nor `@scope/name`.

### Built from its tarball, or kept as an archive

Most store packages are byte for byte the registry tarball they came from, so
keeping a second, uncompressed copy of them would double the install's disk.
`rules_js` keeps the downloaded tarball and extracts it in a build action with
`tar.bzl`'s bsdtar; it extracts in the repository only what it must change.
The install does the same where it can show it is safe.

For each store package the driver names a candidate tarball — the `npm:`
resolution whose store path, computed as Yarn's `slugifyLocator` computes it,
is this package's, or for a peer-dependency instance the resolution its
`package.json` names — and then does what the build will do: it extracts the
tarball with the host's bsdtar from `tar.bzl`, with the same flags and locale,
makes every directory traversable and every file readable as Yarn's own
extraction leaves them, and compares the result with Yarn's tree, path by path
and file by SHA-256. A tarball holding two names that differ only by case or
Unicode normalisation is refused first, since a host that folds them would see
one file where an executor that does not sees two. If the trees are equal, the
package is built from its tarball and the driver records Yarn's tree as a
manifest; otherwise — a patched package, a stub for another platform, a
tarball bsdtar and Yarn extract differently — it keeps an archive of Yarn's
tree, as before. Extraction, normalisation, manifest and comparison live in one
module, `extract.js`, which the build action runs too. `layout.json`, version
3, records each package's source, the links, the `.bin` entries, each direct
dependency's reach and each scope, the architecture set and the Yarn and
Node.js versions.

The repository is not marked reproducible. Its contents depend on the host —
the platform packages chosen for it, the Node.js that ran — and it holds
absolute paths into the output base, so it must not be reused across
workspaces; the tarballs it was made from are cached on their own.

## Step 4 — unpacking into artifacts

The generated `BUILD.bazel` instantiates `yarn_node_modules`, which declares one
directory artifact per package and one symlink artifact per link and per
`.bin` entry. A package built from its tarball is filled by a `YarnExtract`
action, which runs `extract.js` to extract the pinned tarball, normalise it and
compare it with the recorded manifest, failing and naming the package if they
differ; it runs in a custom exec group holding both the Node.js and the
`tar.bzl` toolchains, as Bazel requires of an action using two toolchains. The
check is in the action rather than in a validation action because Bazel does
not run validation actions for a target used as a tool. An archived package is
filled by a `YarnUnpack` action running the archive program on the exec
Node.js toolchain. Each package is cached on its own, and using the tree needs
no network.

The unpacker refuses an archive whose entries are not relative, repeat a path,
or would collide on a case-folding filesystem, and writes into an empty
directory only.

When a check fails, the same file instead instantiates `yarn_install_error`,
which fails analysis with every error found. So fetching does not fail —
`:pin` stays buildable — but anything depending on the install does, saying
why.

`node_modules.bzl` is private to rules_yarn, yet a generated repository has to
load it. Each install repository holds a symlink to it at its root and loads
it from its own root package, which Bazel's load visibility allows and a
consumer's package does not.

### A target per direct dependency

`yarn_node_modules` is also given each direct dependency's store packages and
`.bin` entries and each scope's dependencies, and returns, in a provider
private to `node_modules.bzl`, one part per dependency: a depset of its link,
its `.bin` entries and, for each store package it reaches, that package's
directory and the links in its own `node_modules` — one depset per store
package, shared by every part that reaches it — and one per scope, the union
of its dependencies' parts. The generated `BUILD` file declares a
`yarn_node_modules_part` target for each, named after the dependency's link or
the scope's directory, as `rules_js` names its `node_modules/<package>` and
`node_modules/@<scope>` targets: `:node_modules/react`, `:node_modules/@babel`,
`:packages/app/node_modules/react`. Since one rule declares every artifact,
packages that depend on each other are artifacts of one target, not targets
depending on each other, so a cycle needs none of the extra targets `rules_js`
uses to break one. Bazel runs only the actions of the files requested, so
building a dependency's target extracts or unpacks only the packages it
reaches. A dependency on another workspace gets no target, since those links
are not created.

## What a consumer reads

`@<name>//:node_modules` carries `YarnNodeModulesInfo`, defined in the public
`//yarn:providers.bzl` so its identity does not depend on a private file. It
holds the layout version, every artifact, the execution path of the tree's
`node_modules` directory — taken from a declared artifact's path, since the
artifacts live under the output directory — the workspace links, the
architecture set, and the Yarn and Node.js versions. A test in `e2e/install`
runs an action that finds a package through that path.

A dependency's or scope's target carries the same provider for its part:
`files` holds only that part, and `root` is the `node_modules` directory its
link or scope is in — a workspace's for a workspace's dependency — so the same
consumer, taking `files` as inputs and resolving from `root`, works on every
target; the layout version stays 1. Another `e2e/install` test resolves
`packages/lib`'s `is-number` that way.

## What is refused, and what is not claimed

Refused, each with its reason: resolution through `git:`, `exec:`, `file:`,
`link:`, `portal:` or a tarball URL; registries whose tarballs are not at the
conventional path; packages containing symbolic links; Yarn 1 lockfiles; a
carried setting that depends on the environment.
No dependency build script runs, whatever `dependenciesMeta`
says, because `skip-build` returns before the build step.

Not part of this change: running the project's scripts and builds as actions,
creating the workspace-to-workspace links, and running dependency builds.

Limits of the approach: for a 717-entry project, the install repository keeps
53 MB of archives — the patched packages and the stubs — and 4.8 MB of
manifests, beside the 501 MB tree; before packages were built from their
tarballs it kept 409 MB of archives. Deciding and extracting cost time
instead: fetching took 19.0 s rather than 11.7 s, and a cold build of the tree
8.1 s rather than 2.0 s. A package holding two names that differ only by
case cannot be installed on a filesystem that folds case: Yarn itself cannot
lay it out there, and the install reports Yarn's error.
A dependency's target cuts what is extracted, staged and hashed, not what is
fetched: analysing it analyses `:node_modules`, which names every pinned
tarball, so every tarball is downloaded. When the install fails, only
`:node_modules`, which reports why, and `:pin` exist, so a consumer depending
on a dependency's target sees Bazel's "no such target", as a scenario shows. On the 717-entry
project, building `:node_modules/react` wrote 3 store packages (339 KB) in
0.36 s, against 732 (425 MB) in 2.54 s for `:node_modules`; the generated
`BUILD` file grew from 403 KB to 476 KB, and analysis time did not change.
Installation runs on Linux and macOS, x86-64 and ARM64, and remote execution
is not established by any measurement.
