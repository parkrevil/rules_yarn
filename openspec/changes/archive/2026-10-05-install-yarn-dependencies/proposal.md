## Why

The ruleset delivers the Yarn CLI and nothing a Yarn project can build with.
A consumer can `bazel run` a pinned Yarn, but its dependencies are installed by
Yarn outside Bazel, into a working tree Bazel does not track, so no Bazel
target can depend on them. A Yarn project cannot be built or tested by Bazel
with this ruleset, which is what an enterprise adopting it needs.

Letting Yarn install inside a repository rule looks sufficient and is not.
Measured with the pinned Yarn 4.18.0:

- A lockfile `checksum` is the SHA-512 of the zip Yarn writes into its own
  cache, not of the npm tarball, and the lockfile records no tarball URL or
  tarball digest.
- For `esbuild@0.25.0`, 25 of the lockfile's 27 entries — the per-platform
  native binaries — carry no checksum at all, and Yarn's `Cache.ts` accepts a
  package that is conditional, or whose lockfile entry has no checksum, without
  checking it. The packages most worth checking are the ones Yarn does not.
- Yarn's packages arrive through Yarn's own HTTP client, outside Bazel's
  downloader, so none of Bazel's repository cache, `--distdir`, downloader
  configuration or credential helpers apply — the mechanisms an enterprise uses
  for mirrors, proxies and offline CI.

And a `node_modules` tree cannot be handed to Bazel as it stands. Measured on
Bazel 9.2: a glob over it fails the whole package on a file name containing
`:` and drops `.bin` symlinks; a single directory artifact copies directory
symlinks into duplicates and fails outright on a symlink cycle.

## What Changes

This is the first of three changes that together let Bazel build and test a
Yarn project: **install** (this one), then **run** — a project's scripts and
Node programs as Bazel actions and tests, with packages linked into the
consumer's source packages — then **build** — declared outputs Bazel caches and
other targets consume. Each later change gets its own plan.

In this change, a `yarn.install` tag on the existing `yarn` extension, and:

- **A pin file.** The ruleset generates and the consumer commits a JSON file
  recording, for every `npm:` entry in `yarn.lock` on every platform, the
  tarball URL and the registry's SHA-512 integrity — the arrangement
  `rules_jvm_external` uses with `maven_install.json`. `bazel run
  @<name>//:pin` regenerates it, asking the registry through the pinned Yarn so
  that the project's registry, scope and authentication settings apply.
- **Bazel fetches every package.** One repository per pinned tarball, fetched
  with `repository_ctx.download` and its integrity, so every byte from the
  registry is checked by Bazel and Bazel's caches and downloader settings apply.
- **Yarn computes the layout and nothing else.** The pinned Yarn runs on the
  Bazel-managed Node.js with its registry pointed at a loopback server that
  serves only the already-verified tarballs, so Yarn resolves peer
  dependencies, applies patches — including the built-in compatibility patch
  every TypeScript project's lockfile names — and lays packages out with its
  isolated `pnpm` linker, without reaching the network. Its configuration is
  isolated from the host, and dependency builds never run.
- **Bazel artifacts that keep the layout.** Each installed package becomes a
  directory artifact built by an action, and each link between packages a
  symlink artifact Bazel never dereferences, so names with `:`, `.bin` links,
  shared packages and cycles all survive, and each package is cached on its
  own.

## Capabilities

### New Capabilities

- `yarn-dependencies`: installing a Yarn project's locked dependencies as Bazel
  artifacts.

### Modified Capabilities

- `yarn-execution`: the declared support boundary now distinguishes running the
  CLI, which still carries no Bazel guarantees, from installing dependencies,
  which does, and states what installing does not yet cover.

## Impact

- `yarn/private/extensions.bzl`: the `install` tag class and its arbitration.
- New `yarn/private/install/`: the package and layout repository rules, the
  rules that turn them into artifacts, and the Node.js programs they run —
  the loopback server and Yarn driver, the pin generator, and the archive
  writer and reader.
- `MODULE.bazel`: a regular use of `rules_nodejs`'s `node` extension for the
  per-platform Node.js repositories the repository rules run.
- New consumer module `e2e/install/`, a lock-bearing root.
- `tools/ci/install_scenarios.sh` for what only a fresh consumer can show.
- `README.md`, the public docstrings, `AGENTS.md`'s list of roots, CI, the wiki.
- No change to `yarn_binary` or `yarn.distribution`.
