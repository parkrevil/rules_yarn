## Context

`yarn.install` lays a project's packages out with the pinned Yarn inside a
repository rule, packs each store package Yarn wrote into an archive in the
install repository, and unpacks each archive into a directory artifact in a
build action (`yarn/private/install/driver.js`, `node_modules.bzl`). The
registry tarball of every `npm:` entry is already fetched by Bazel, by its
pinned integrity, into a repository of its own (`tarball.bzl`).

## Evidence

**What `rules_js` does.** At commit `0a0b62de` (2026-10-01), `npm_import.bzl`
downloads a package's tarball with `repository_ctx.download` and extracts only
its `package.json` in the repository, unless the package has patches,
lifecycle hooks or `extract_full_archive`; the package's source is then the
tarball itself. `npm_package_store.bzl` declares a directory artifact and fills
it with one action running the `tar.bzl` bsdtar toolchain with `--extract
--no-same-owner --no-same-permissions --strip-components 1`, mnemonic
`NpmPackageExtract`. It uses `tar.bzl` 0.10.4 from its `MODULE.bazel`.

**`tar.bzl` on the registry.** The Bazel Central Registry has 0.10.9 as its
latest version, nothing yanked; its `source.json` pins the archive by
`sha256-ijt4EgUQli/HS1d6qvUkElN8+8JciKWWo3W9QJ5muYo=`, and its `MODULE.bazel`
registers `@bsd_tar_toolchains//:all` and depends on `bazel_features` 1.34.0,
`bazel_lib` 3.0.0, `bazel_skylib` 1.4.1, `gawk` 5.3.2.bcr.3 and `platforms`
0.0.11.

**What Yarn lays out for an `npm:` package, against bsdtar.** On the 717-entry
project, an independent review ran `tar.bzl`'s pinned bsdtar (3.8.1, the
`tar_linux_amd64` binary whose SHA-256 `tar/toolchain/versions.bzl` records)
with `rules_js`'s flags and compared its output with what Yarn laid out —
paths, kinds and file SHA-256, directories included: all 576 store packages
Yarn installed from a plain `npm:` resolution matched, and so did all 75
peer-dependency instances, each under the tarball its `package.json` names.
The other store packages are 4 patched packages and 77 stubs Yarn writes for
other platforms' packages (`{"name": …, "mocked": true}`), whose tarballs are
not fetched. Bazel makes every output file executable, so the executable bit
is not part of the comparison.

**Where bsdtar and Yarn part.** The same review found tarball shapes where they
do. `pngjs@5.0.0`, a real registry package, has directory entries without an
execute bit (`drw-rw-rw-`); bsdtar with `--no-same-permissions` leaves them
unreadable, and Yarn's extraction (`extractArchiveTo` in the 4.18.0 bundle)
makes every directory 0755. `rules_js` meets the same package and runs `chmod
-R a+X` after extracting (`npm_import.bzl`). On crafted tarballs, Yarn's
tgz-to-zip conversion skips hard links, contiguous files, FIFOs, absolute
paths and `..` entries and strips a leading `./`, where bsdtar creates the hard
link, contiguous file and FIFO, writes an absolute path under the top
directory, keeps a `./package/` prefix and refuses `..` with an error. A file of
mode 0000, which bsdtar keeps and Yarn makes 0644, holds the same bytes once
the normalisation below makes it readable. Duplicate entries (last wins), empty
directories, pax and GNU long names and a file outside the top directory come
out the same.

**`tar.bzl`'s toolchain.** At v0.10.9 (`00abfca5`), the toolchain type is
`@tar.bzl//tar/toolchain:type` (`tar/toolchain/BUILD`, and `tar_lib.toolchain_type`
in `tar/private/tar.bzl`), its info is `TarInfo` with `binary` and
`default_env` — the environment to set for reproducible results
(`tar/toolchain/toolchain.bzl`) — and prebuilt toolchains exist for Linux and
macOS on x86-64 and ARM64 (`tar/toolchain/platforms.bzl`).

**`tar.bzl`'s repositories for a repository rule.** `tar/extensions.bzl` at
v0.10.9 (`create_repositories`) creates `bsd_tar_toolchains_<platform>` for
each of `darwin_amd64`, `darwin_arm64`, `linux_amd64` and `linux_arm64`, each
exposing `:tar`; `rules_js` brings them in with `use_repo` (`MODULE.bazel`) and
calls `@bsd_tar_toolchains_<platform>//:tar` from `npm_import.bzl`. Those
platform names are the ones the install already maps the host to for Node.js
(`repository.bzl`, `_host`). All four binaries are bsdtar 3.8.1
(`tar/toolchain/versions.bzl`), downloaded from
`github.com/hermeticbuild/bsdtar-prebuilt` by integrity. The toolchain runs
bsdtar with a UTF-8 locale, `LC_ALL` set by `utf8_environment.bzl`.

**One action, two toolchains.** Bazel's automatic exec groups give each
toolchain its own execution platform; an action that runs programs from two
toolchains needs a custom `exec_group` holding both toolchain types
(`site/en/extending/auto-exec-groups.md` at 8.3.0 and 9.2.0, "When should I use
a custom exec_group?").

**Where Yarn puts a package.** The `pnpm` linker writes a package to
`node_modules/.store/<slugifyLocator(locator)>/package` (`PnpmLinker.ts`).
`structUtils.slugifyLocator` at the 4.18.0 tag joins `slugifyIdent` —
`@<scope>-<name>` or `<name>` — the protocol without its colon followed by
`-<semver.valid(selector)>` when that is not null, and the first ten hex
characters of the locator hash. `makeIdent` hashes `scope` and `name`, and
`makeLocator` hashes the ident hash and the reference — the lockfile's
`resolution` after the name, `::` parameters included — each with
`hashUtils.makeHash`: the SHA-512, in hex, of its string arguments
concatenated, a null one left out. The store root is the `pnpmStoreFolder`
setting, `node_modules/.store` by default; the install neither carries it from
the project nor sets it, so the default holds.

## Goals / Non-Goals

**Goals:** keep no uncompressed copy of a package the build can extract from
its pinned tarball; keep what Yarn laid out as the definition of the tree.

**Non-goals:** changing what is installed, how it is laid out, or the
provider's fields; per-package targets, which are the next change.

## Decisions

### Decision: extract with `tar.bzl`, as `rules_js` does

The build action runs the `tar.bzl` bsdtar toolchain with the flags
`rules_js` uses. A Node.js extractor of our own would be a tar reader the
project has to get right; bsdtar is maintained, prebuilt per platform, and is
what the reference ruleset trusts for the same tarballs.

### Decision: each store package's source, decided by comparing

Whether a store package is built from a tarball is decided in the repository
rule, by doing what the build action will do and comparing the result with
what Yarn laid out, as `rules_js` extracts in its repository rule where it has
to (`npm_import.bzl`, with `@bsd_tar_toolchains_<platform>//:tar`):

1. Name a candidate tarball: for an `npm:` resolution the install fetched, the
   store path computed as Yarn computes it (above); for a peer-dependency
   instance, the `npm:` resolution its `package.json` names, if fetched.
   Anything else — patched packages, stubs — has no candidate.
2. Refuse the candidate if two of the tarball's entries (`bsdtar -t`) differ
   only by case or Unicode normalisation: a host whose filesystem folds them,
   as macOS's APFS does by default, would extract one file where an executor
   that does not would extract two, and the decision must hold wherever the
   action runs.
3. Extract the candidate with the host's bsdtar from `tar.bzl`, with the flags
   and the locale the action uses, into a scratch directory, then normalise
   it in place: every directory readable and traversable, every file
   readable — the bits Yarn's extraction leaves set — before anything reads
   it, a failed extraction included.
4. If the scratch tree's entries — paths, kinds, file SHA-256 — equal Yarn's
   tree for that package, the package is built from the tarball and its
   manifest is recorded; otherwise, or if bsdtar fails, it is archived as now.
   The scratch tree is deleted either way.

The driver first runs the host's bsdtar with `--version` and reports a failure
to run, rather than letting every package fall back to an archive unseen.

Extraction, normalisation, the manifest and the comparison are one module,
`yarn/private/install/extract.js`, which the driver runs for the decision and
the build action runs for the check, so both apply the same code; it has unit
tests of its own. Normalisation only adds read and traverse bits, and modes
are not compared, so it cannot make different contents equal.

So every tarball shape above that bsdtar and Yarn treat differently becomes an
archived package, not a failed build; only a package Yarn installs and bsdtar
reproduces exactly is extracted at build time. The repository rule pays one
extraction per candidate for the decision and keeps nothing of it.

### Decision: the build action extracts, normalises and checks

The build action runs `extract.js`: bsdtar with the same flags and locale, the
same normalisation, and a comparison with the recorded manifest,
failing and naming the package on any difference. It runs in a custom
`exec_group` holding the `rules_nodejs` toolchain, whose Node.js runs the
checking program, and the `tar.bzl` toolchain, whose bsdtar it spawns. The
decision above makes a difference here unexpected — it would take the exec
platform's bsdtar behaving differently from the host's — and the check makes
it a failure rather than a different tree.

Bazel's validation actions (the `_validation` output group) would also run a
check, and are not used: the documentation at Bazel 8.3.0 and 9.2.0
(`site/en/extending/rules.md`, "Validation Actions") says a target's
validation actions do not run when it is depended upon as a tool, as an
implicit dependency, or in the exec configuration — exactly how the next
change's actions may take the installed tree.

### Decision: links are still refused from Yarn's tree

The driver walks every package Yarn laid out, to write its manifest or its
archive, and refuses a symbolic link there with the message it gives now, so a
tarball holding one is refused before bsdtar ever sees it.

### Decision: layout contract version 2

`layout.json` records each package as `{path, archive}` or `{path, tarball,
manifest}`, the tarball named by its resolution; the version moves to 2. The
provider is unchanged.

## Risks / Trade-offs

- Extraction runs in a build action, as unpacking does now; a cold build pays
  for gunzip in place of reading an uncompressed archive.
- `tar.bzl` and its dependencies join the module graph of every consumer;
  resolved at Bazel 8.3.0 with rules_yarn's other dependencies, that adds
  `tar.bzl` and `gawk` and changes no other version. The registry applies a
  generated `module_dot_bazel_version.patch` to `tar.bzl`'s archive.
- The decision extracts every candidate once in the repository rule; the
  review measured all 635 of the 717-entry project's tarballs extracted,
  normalised and hashed in 4.1 s on a local disk with a warm cache. Each is
  deleted before the next, so the scratch space stays one package.
- The fetch now downloads the host's bsdtar from `tar.bzl`'s pinned URL, by
  integrity, through Bazel's downloader; a consumer with a downloader
  configuration or a mirror sees one more host.
- The disk figures to compare are the install repository, the tarball
  repositories and the built tree together, before and after.
