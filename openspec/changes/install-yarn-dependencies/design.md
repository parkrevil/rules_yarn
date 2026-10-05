## Context

A Yarn project's dependencies have to become Bazel artifacts before Bazel can
run or build anything in that project. This change makes them so.

The first version of this plan let Yarn install inside a repository rule and
trusted the lockfile's checksums. An adversarial review showed, and the
measurements below confirm, that it would have let unverified bytes in and
could not hand the result to Bazel faithfully. Every decision here rests on a
recorded run, Yarn 4.18.0's source, or the source of the pinned Bazel and
`rules_nodejs`.

## Evidence

Each measured fact below that the design relies on is reproduced by a test in
the repository; tasks.md (1.1) names it. The facts read from Yarn's source are
said to be, and tasks.md lists them; the design relies on none of them alone.
The measurements of alternatives not taken, what Bazel refuses as an
artifact, are recorded runs.

All runs used the pinned Yarn 4.18.0 (`yarn.js` matching the SHA-256 in
`yarn/private/versions.bzl`) on the `rules_nodejs` 6.7.5 Linux x64 Node.js.

**What a lockfile checksum covers.** For `is-number@7.0.0` the lockfile records
`checksum: 10c0/b4686d0d3053146095ccd45346461bc8e53b80aeb7671cc52a4de02dbbf7dc0d1d2a986e2fe4ae206984b4d34ef37e8b795ebc4f4295c978373e6575e295d811`.
`sha512sum .yarn/cache/is-number-npm-7.0.0-060086935c-b4686d0d30.zip` prints
the same digest. The registry's `dist.integrity` for the tarball is
`sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==`,
which the downloaded tarball reproduces. The lockfile holds neither the tarball
URL nor its digest.

**What Yarn does not check.** A project depending on `esbuild@0.25.0` gets a
lockfile with 27 entries; 25 carry `conditions:` and no `checksum:`. In
`packages/yarnpkg-core/sources/Cache.ts` at `@yarnpkg/cli/4.18.0`,
`validateFile` returns `{isValid: true, hash: null}` for a package in
`unstablePackages` (the conditional ones, from `Project.ts`), accepts any
digest when the lockfile records none, and switches to `update` when the
recorded cache key differs from Yarn's — unless `--check-cache` is given.

**What Yarn reads.** `Configuration.findRcFiles` walks from the working
directory to the filesystem root reading `.yarnrc.yml`, and — read from
`Configuration.find`, not reproduced — Yarn also reads the home directory's. The file name comes from `YARN_RC_FILENAME` (matched without
regard to case in `getRcFilename`), so a different name hides every
`.yarnrc.yml` from that walk — but the walk then looks for that name in the
same directories, so a fixed one could be planted above the project ahead of
time, and Yarn would load any plugin it names. Review found this, running
Yarn 4.18.0's bundle: an ancestor file under the name the install then used
had its plugin executed. And with the registry refusing every request, a plain
`yarn install` succeeded from the host's global cache, where an earlier
install had left the packages.

**What stops builds.** `Project.install` returns before its build step when
`mode` is `skip-build`. Read from the same source: `enableScripts: false` alone
does not suffice, because `dependenciesMeta.built: true` overrides it.

**What a locked install asks the registry for.** A loopback HTTP server
serving only the 28 pinned tarballs of the `esbuild` + `is-number` +
`typescript@5.6.3` project, with Yarn's registry pointed at it, a cold cache,
`YARN_RC_FILENAME` changed and `HOME` replaced: `yarn install --immutable
--mode=skip-build` exited 0 having requested exactly the 4 tarballs the host
needed, and nothing else — no metadata. Yarn applied its built-in TypeScript
patch to the served base tarball. Changing one character of the recorded
checksum for `is-number@npm:7.0.0`, and separately for the patched
`typescript@patch:…`, made it fail with `YN0018 … The remote archive doesn't
match the expected checksum`, naming the entry.

**What the `pnpm` linker produces.** `node_modules/<name>` links to
`.store/<slug>/package`; each `.store/<slug>/node_modules/<dep>` is a link,
including a link to the package itself; and `node_modules/.package-map.json`
records every store package with its dependency links as data. Store entries
for other platforms exist, their `package` holding only a stub
`package.json` — `{"name": "@esbuild/win32-x64", "mocked": true}` — and no files.

**What the layout data holds for peers and workspaces.** In a project with
workspaces `a` and `b`, `a` depending on `b`, `react@18.3.1` and
`react-dom@18.3.1`: `.package-map.json` lists the peer-dependency instance as
its own store package, `.store/react-dom-virtual-1137ace24f/package`, whose
`react` link points at the store package `a` uses; each workspace appears under
its project-relative path (`../packages/a`) with its own links, including
`b: ../packages/b`. The lockfile holds no `virtual:` entries — Yarn computes
them at install time — so the layout cannot be derived from the lockfile alone.

**Executables.** The `pnpm` linker creates no `.bin` directory anywhere.
Each lockfile entry records its executables, as `bin:` with a name and a path
relative to the package (`tsc: bin/tsc` for `typescript`).

**What `yarn npm info` answers.** For `is-number@6.0.0` it returns version
6.0.0 and its tarball. For `is-number@6.9.99`, which does not exist, it
returns 7.0.0 — the latest — without an error.

**How platforms reach Yarn.** `YARN_SUPPORTED_ARCHITECTURES` set to a JSON
object fails with "Object configuration settings `supportedArchitectures` must
be an object in `<environment>`"; the setting has to come from a configuration
file.

**What the cache key is.** `Cache.getCacheKey` joins `CACHE_VERSION` — 10 at
4.18.0, overridable only through `YARN_CACHE_VERSION_OVERRIDE` — with `c<level>`
for the project's `compressionLevel`, or nothing for `mixed`. A lockfile's
`__metadata.cacheKey` therefore depends on the project's compression setting,
and forcing a level would make every lockfile written with another one
mismatch.

**What a project's configuration does to Yarn.** With the project's file
staged where Yarn finds it, its settings merge with any nearer one — scalars
from the nearer file, `npmScopes` per scope and field. A review then showed,
against the pinned bundle, that a nearer `enableNetwork: false` does not undo
a project's other `networkSettings` entries (a host the project enables stays
enabled) or its proxies (`httpUtils.ts` checks the destination host, then sends
the request through whatever proxy is configured, without checking the proxy),
and that `Configuration.find` loads any plugin file that exists — by absolute
path too — and runs it before any command. Yarn's own gate blocks a plugin it
would have to download ("Request to 'https://example.com/evil.cjs' has been
blocked"), but not one already on disk. The project's file cannot safely reach
Yarn at all.

**What a locked install needs from it.** For a project whose `.yarnrc.yml`
declares `packageExtensions` adding `js-tokens@4.0.0` to `is-number`, the
lockfile records `js-tokens` as an entry but not as a dependency of
`is-number`; Yarn reapplies the extension at every install. Without the
project's file, `yarn install --immutable` failed with YN0028, proposing to
remove `js-tokens` from the lockfile. So some settings have to be carried.

**What Yarn's YAML reading is.** `parseSyml` in syml.ts reads both `yarn.lock`
and `.yarnrc.yml`: a file starting with the Yarn 1 lockfile header goes to an
older grammar, and anything else to js-yaml with `FAILSAFE_SCHEMA` and
`json: true` — every scalar a string, a repeated key taking its last value.
Yarn's own lockfile at the 4.18.0 tag resolves js-yaml to 4.3.0.

The ruleset first read both files with readers of its own, compared with
js-yaml on generated documents. Each review still found YAML they read
differently from Yarn — an open quote after an anchor or a tag, a comma and a
quote in a plain scalar outside a flow collection, a no-break space that
JavaScript's `trim` removes and YAML keeps — and in `.yarnrc.yml` a difference
changes which settings are carried, silently. A reader that agrees with
js-yaml on the documents a generator happens to write is not one that agrees
on every document. So the ruleset now reads both files with js-yaml 4.3.0
itself, fetched by `http_archive` with the integrity the npm registry
publishes (https://registry.npmjs.org/js-yaml/4.3.0), through `syml.js`, a
port of `parseSyml`; it refuses the Yarn 1 format, which it does not support.
What the ruleset reads is then what Yarn reads, by the same parser, and the
cases the reviews found are regression tests that state what Yarn reads.

**How conditions are evaluated.** `structUtils.isPackageCompatible` runs a
`conditions` string through tinylogic 2.0.0 (`grammar.pegjs`): `|`, `&` and
`^` fold left to right with no precedence, `!` and parentheses group, tokens
match `/(os|cpu|libc)=([a-z0-9_-]+)/`, and a dimension the architecture set
leaves open counts as true. The ruleset's port agreed with tinylogic itself on
50,000 random expressions. `Configuration.getSupportedArchitectures` treats
`os`, `cpu` and `libc` as independent sets, so naming Linux and macOS with x64
and arm64 admits Linux arm64. `Project.ts` disables a conditional package only
when it is in `optionalBuilds` — reached through optional dependencies — and
incompatible.

**What Yarn does with a link in a tarball.** `tgzUtils.convertToZip` writes a
`SymbolicLink` entry into the package's zip, so a package can carry links.

**What Bazel accepts as an artifact** (Bazel 9.2). A `glob` over an
external repository fails the whole package on a file named `col:on.js`, and
omits a `.bin` symlink. A directory artifact keeps `col:on.js` and file links,
but a consumer sees a directory symlink inside it as a copied directory, and a
symlink cycle fails the action ("Too many levels of symbolic links").
`ctx.actions.declare_symlink` at Bazel 8.3.0: "Bazel will never dereference
this symlink and will transfer it verbatim to sandboxes or remote executors";
it requires `--allow_unresolved_symlinks`, whose default in `CoreOptions` at
8.3.0 is `true`.

**That the chosen representation works**, at both Bazel 8.3.0 and 9.2.0 —
reproduced at 9.2.0 by the scenario "A dependency cycle" and at both versions,
without a cycle or a colon, by `e2e/install`; at 8.3.0 with them, a recorded
run: a rule declaring `node_modules/.store/a/package` and `.store/b/package` as
directory artifacts, and `node_modules/a`, `.store/a/node_modules/b`,
`.store/b/node_modules/b` and a cycle `.store/b/node_modules/a-cycle → a` as
`declare_symlink` artifacts, gave `require("a") === 42` both in a
`linux-sandbox` action and in a test's runfiles, and kept a file named
`col:on.js`.

## Decision: a pin file the consumer commits

Integrity for every registry package has to come from a checked-in record, and
the lockfile is not one. The ruleset generates a JSON pin file — format
version 1, recording for each `npm:` lockfile entry, keyed by its resolution,
the tarball URL and a SHA-512 integrity — and the consumer commits it beside
the lockfile. This is the arrangement `rules_jvm_external` uses with
`maven_install.json`.

`bazel run @<name>//:pin` writes it. It asks the registry through the pinned
Yarn — `yarn npm info <locator>… --fields name,version,dist --json`, which accepts
many locators per call — so the project's registry, scope and authentication
settings apply exactly as Yarn would apply them; it runs in the project, with
the developer's environment and the project's own configuration, like
`yarn install` itself. Because `yarn npm info` answers a version that does not
exist with the latest one, it refuses any answer whose name or version differs
from the lockfile entry. It records every platform's conditional packages,
because the lockfile does. It records the registry's published SHA-512
`dist.integrity` without downloading the tarball; only a package whose registry
publishes no SHA-512 integrity is downloaded, recorded with the SHA-512 of its
bytes and named in the output. Bazel's downloader checks every recorded digest
when the install fetches.

That is trust on first download, not registry-authenticated integrity: the
digest is whatever the registry published, or served, when the developer
pinned — recorded and reviewed in version control, as npm and pnpm lockfiles
record theirs. From then on nothing changes it silently.

The pin target lives in the install's repository and never depends on the pin
file being right, so it runs when the pins are stale or the file is missing
or empty — which is how a first pin is made: the consumer declares the install
and runs the target. The extension watches the pin file's path, so the file
appearing re-runs it.

## Decision: Bazel fetches every tarball

The extension reads the pin file with `module_ctx.read` and creates one
repository per pinned tarball, fetched with `repository_ctx.download` and its
`integrity`. Every byte from a registry is therefore checked by Bazel, kept in
the repository cache, and subject to `--distdir`,
`--downloader_config` and `--credential_helper`. A repository is
fetched only when something resolves it; the layout rule resolves only the
tarballs `selectTarballs` chooses (see Architectures).

## Decision: Yarn computes the layout, offline, from the ruleset's configuration

The layout — which instance of each package links where, with peer
dependencies resolved and patches applied — is Yarn's to compute;
reimplementing it would be reimplementing Yarn. A layout repository rule runs
a Node.js driver that:

1. reads the lockfile and the project's `.yarnrc.yml` as Yarn does, with
   the js-yaml Yarn uses (above);
2. refuses, naming what it refuses: a Yarn 1 lockfile; a `packageManager`
   naming another Yarn; any entry not resolved
   through `npm:`, `patch:` on an `npm:` package, or `workspace:`; an `npm:`
   entry with its own archive URL; a workspace or patch file not listed; a pin
   file that is malformed or differs from the lockfile. Resolutions are read
   with Yarn's own `LOCATOR_REGEX_STRICT`, `RANGE_REGEX`, `parseRange` (with
   Node's `querystring`, which Yarn uses) and `visitPatchPath` semantics — a
   patch path's flags end at its last `!`, `builtin<…>` must match whole, `~/`
   is project-relative, a relative path is relative to the workspace that
   declared it;
3. writes the only configuration Yarn sees, as two files under a
   `YARN_RC_FILENAME` drawn afresh for each run from 128 random bits, which no
   file placed above the project beforehand can carry. One directory above the
   project goes the carried file: the project's document as Yarn parsed it,
   with every top-level setting removed but `packageExtensions`,
   `enableTransparentWorkspaces`, `defaultProtocol` and `compressionLevel` —
   inside an `onConflict` marker if the whole document is wrapped in one, the
   marker kept — written back and refused unless reading it back gives the
   same tree. Yarn then resolves those settings itself; the ruleset does not
   interpret them. A first version resolved them itself and wrote the result:
   three reviews found it diverging from Yarn — a wrapper around the whole
   document, `hardReset`, a dependency literally named `onConflict`, nulls
   written as JSON — and `yarnrc_yarn_test.js` now asks the pinned Yarn,
   with `yarn config get`, for every carried setting from the project's file
   and from the two files the driver writes — its own settings file and
   environment included — over fifteen configurations covering each of
   those, and checks that the install's own settings stand in every one. The
   same check runs at every install: before installing, the driver has Yarn
   read the carried part of the project's document alone, in its own shape,
   and requires Yarn to accept it and to report each carried setting exactly
   as it reports it from the install's configuration. A marker around the
   whole document holding anything but a mapping is left out of the layered
   file — where Yarn accepts such a document it gives no settings — and where
   Yarn fails on it, the driver refuses the install with Yarn's error rather
   than installing without the settings. A sixth-round decision to install
   with defaults there was withdrawn: the seventh review showed a dropped
   `packageExtensions` entry can leave the lockfile byte for byte the same,
   because Yarn records an extension's dependencies nowhere but in the
   layout. A carried setting holding `${` is refused, because Yarn would fill
   it from an environment the install does not share. In the project itself
   goes the install's own file, nearer, so it decides wherever both speak,
   with the settings the install fixes:

| setting | value |
| --- | --- |
| `enableNetwork` | `false` |
| `networkSettings` | `{"127.0.0.1": {enableNetwork: true}}` |
| `npmRegistryServer` | the loopback address |
| `unsafeHttpWhitelist` | `["127.0.0.1"]` |
| `injectEnvironmentFiles` | `[]` |
| `supportedArchitectures` | from the declaration |

   Nothing else from the project's file reaches Yarn: no plugin — Yarn loads
   plugins only from a file's top-level `plugins`, which is removed — no
   proxy, no `networkSettings`, no `yarnPath`, no registry or scope. Nor does
   configuration outside the project: the developer's home configuration,
   environment variables, plugins. A setting from there that changes what the
   lockfile records makes the immutable install fail with YN0028; one whose
   effect the lockfile does not record — a `packageExtensions` entry in a home
   configuration, say — is not reproduced and not detected. That is a limit
   of the approach, which installs from the project's inputs alone. Before
   installing, the driver asks Yarn, under this configuration,
   for its compression level (`yarn config get compressionLevel`), and refuses
   a lockfile whose cache key is not the selected Yarn's `CACHE_VERSION`,
   recorded beside its digest in `versions.bzl`, joined with that level as
   `Cache.getCacheKey` does;
4. serves the selected tarballs from a loopback HTTP server bound to
   127.0.0.1 on a port the system assigns, at exactly the paths Yarn requests
   for each — `getLocatorUrl`'s spelling, with a scope's `/` encoded as `%2f`,
   and the plain `/` spelling Yarn retries with — and nothing else; a request
   for anything else is answered 404 and recorded, and the driver then fails
   naming it. A port that cannot be bound, or a Yarn that does not finish
   within the repository rule's timeout, fails the fetch;
5. runs the pinned Yarn on the Bazel-managed Node.js with
   `install --immutable --mode=skip-build --check-cache`, with the environment
   reduced to the table below;
6. reads `node_modules/.package-map.json` and writes `layout.json` and one
   archive per store package.

| variable | value | why |
| --- | --- | --- |
| `PATH` | the Node.js `bin` directory | no host `node`, `yarn` or `corepack` |
| `HOME` | inside the repository | |
| `YARN_RC_FILENAME` | `.rules-yarn-<32 random hex digits>.yml`, new each run | no `.yarnrc.yml`, nor any file planted under a predictable name, is read |
| `YARN_GLOBAL_FOLDER`, `YARN_CACHE_FOLDER` | inside the repository | |
| `YARN_ENABLE_GLOBAL_CACHE`, `YARN_ENABLE_MIRROR` | `false` | |
| `YARN_ENABLE_IMMUTABLE_INSTALLS` | `true` | a lockfile that would change fails |
| `YARN_CHECKSUM_BEHAVIOR` | `throw` | |
| `YARN_NODE_LINKER` | `pnpm` | the isolated layout below |
| `YARN_ENABLE_SCRIPTS` | `false` | beside `skip-build` |
| `YARN_ENABLE_HARDENED_MODE` | `false` | it queries registry metadata, which the loopback server does not serve |
| `YARN_ENABLE_TELEMETRY` | `false` | |
| `YARN_IGNORE_PATH` | `1` | |

`repository_ctx.execute` removes every other variable: at Bazel 8.3.0 an
`environment` value of `None` removes a variable ("The value can be `None` to
remove the environment variable", `StarlarkBaseExternalContext`), so the rule
passes `None` for each name in `repository_ctx.os.environ` outside the table.
That also removes `YARN_PLUGINS` and `YARN_CACHE_VERSION_OVERRIDE`.

`--check-cache` closes the cache-key `update` path in `Cache.ts`. The
conditional and checksum-less paths stay open inside Yarn, and are closed
before it: their bytes are the tarballs Bazel verified, the loopback server
serves nothing else, and Yarn's network gate refuses every other host — with
no project proxy or host exception left to route around it.

## Decision: packages as directory artifacts, links as symlink artifacts

Neither a glob nor one directory artifact can carry a `node_modules` tree. The
generated repository declares, through rules the ruleset provides:

- for each store package, an action that unpacks its archive into a directory
  artifact at `node_modules/.store/<slug>/package`. The archive is the
  ruleset's own format, read and written by its own Node.js programs, holding
  files, the executable bit and empty directories. It holds no links: a
  directory artifact cannot carry them faithfully, and a link is the one way an
  archive's contents could reach outside the directory they are unpacked into.
  A package whose tarball holds a link is refused, naming the package and the
  link. The reader checks every entry — relative paths, no NUL, no duplicate,
  no path that is both an entry and another's directory — before writing
  anything, writes only into an empty directory, refuses a name the filesystem
  folds into one already written instead of overwriting it, and gives every
  directory mode 0755 and every file 0644 or 0755;
- for each link the package map records, a symlink artifact from
  `ctx.actions.declare_symlink`, with the relative target Yarn used. The
  derivation reproduces, exactly, every symlink Yarn's `pnpm` linker wrote for
  the recorded fixtures (56 for the `esbuild`/`typescript` project, 16 for the
  workspaces project);
- for each executable a direct dependency of the root or of a workspace
  declares in its `package.json` `bin`, a symlink artifact at
  `<owner>/node_modules/.bin/<name>`; the `pnpm` linker makes none, so the
  ruleset does;
- a `node_modules` target whose files and runfiles are all of them.

A link whose target is inside the generated repository has the same relative
path in a sandbox and in runfiles, because the whole tree lives in one
repository; that was measured for Linux, at both Bazel versions. macOS is
covered by CI. Remote execution is not established by any measurement here
and is not claimed. At scale, task 3.7 recorded a project of 717 lockfile
entries: 732 store packages, 2,234 links and 11 `.bin` entries, built in 2 s
from 2,978 actions,
with the archives (409 MB) and the unpacked tree (501 MB) each about the size
of a `node_modules` — the install costs roughly twice its disk.

## Decision: the contract with the next change

`layout.json` is versioned (version 1) and records what the next change needs
and must check: every store package and its archive, every link, every `.bin`
entry, the workspace-to-workspace links this change does not create, the
architecture set it installed for, and the Yarn and Node.js versions it ran.
The generated repository exposes the same through a provider on its
`node_modules` target. Peer-dependency instances are distinct store packages,
so their identity is a store path.

## Decision: Node.js identity

A repository rule cannot use toolchain resolution. `rules_nodejs` 6.7.5 creates
`nodejs_linux_amd64`, `nodejs_linux_arm64`, `nodejs_darwin_amd64` and
`nodejs_darwin_arm64` (its generated `BUILD.bazel` declares
`alias(name = "node_bin", actual = "bin/nodejs/bin/node")`), and its own
`MODULE.bazel` calls `node.toolchain()`, so they always exist, at the version of
the root-most declaration of the default toolchain. `rules_yarn` uses the
`node` extension as a regular dependency, brings those four into scope, and the
repository rules pick one by `repository_ctx.os` — `linux` or `mac os x`
mapped to `linux` or `darwin`, `amd64`/`x86_64` and `aarch64`/`arm64` mapped
to `amd64` and `arm64` — failing on any other host and naming it.

That is the default toolchain's Node.js, not necessarily the one a later
action resolves: `rules_nodejs` arbitrates versions per repository name, and a
consumer may register other names. `layout.json` records the version, and the
next change checks it. A differently named toolchain for installation is not
supported here.

## Decision: architectures

`supported_architectures` is Yarn's `supportedArchitectures` as it is: lists
under `os`, `cpu` and `libc`, each a set of its own, `current` meaning the
host's; empty means Yarn's default, the host. It is written into the
configuration the driver writes, because Yarn refuses an object-valued setting
from the environment. `selectTarballs` chooses what to fetch: every `npm:`
entry except a conditional one that has no recorded checksum, that every
dependent marks optional, and that is incompatible with the set. Yarn leaves
out exactly the conditional packages in `optionalBuilds`, and `Cache.ts` keeps
the checksum of exactly those out of the lockfile, so a conditional entry with a
checksum is one Yarn fetches everywhere. The large-project measurement found
the case: `fsevents@npm:2.3.3` is darwin-only, but it is the source of Yarn's
built-in `compat/fsevents` patch rather than an optional dependency, so its
entry keeps a checksum and Yarn requested it on Linux; the first version of the
rule, which looked only at optional edges, left it out and the install failed
with the loopback server refusing it. A package fetched and not needed costs a
download; one needed and not fetched fails the install when the loopback server
refuses it, as that case did.

## Decision: workspaces

Each workspace's dependencies are installed; its `package.json` is staged at
its project-relative path. Linking one workspace into another's `node_modules`
is not done here: the target is a source directory in the main repository, and
the relative path from an external repository to it differs between a sandbox
(`external/<repo>/…`) and runfiles (`<repo>/…`). `layout.json` records those
links, and the next change, which links packages into the consumer's own source
packages, creates them.

## Decision: inputs and refetching

The declaration names `package_json`, `lockfile`, `pins`, an optional `yarnrc`,
`workspaces` and `patches` as labels, and `supported_architectures`. The
extension reads `pins` with `module_ctx.read`, so a pin-file change re-runs the
extension; the layout rule stages each input through `repository_ctx.path`
and `repository_ctx.watch`, so a change to any of them refetches it. It also
watches the driver and every module the driver loads: `path` alone does not
make Bazel watch a file, and the large-project measurement showed a changed
driver leaving the old install in place. Task 2.5 tests a lockfile change and a
pin-only change.

## Decision: authority

Only the root module declares installs. Repository names are distinct, and
distinct from distributions'. An install names the distribution it runs —
`yarn` by default — and the extension refuses a name it did not create. Install
repositories are reported to Bazel as distributions are, so `bazel mod tidy`
maintains `use_repo`.

## Known limits

These are what this approach does not do, not work set aside.

- **Dependency builds.** Packages that need their `postinstall` or a native
  build install unbuilt. Running a build is running arbitrary code with tools
  and inputs Bazel must declare, which is a rule, not a fetch.
- **Protocols.** `git:`, `exec:`, `file:`, `link:`, `portal:`, tarball URLs and
  `npm:` entries carrying their own archive URL are refused. The last matters
  for a registry that serves tarballs from somewhere other than the
  conventional path: Yarn then records the URL in the resolution and fetches it
  directly, and the loopback server cannot stand in for another host.
- **Links inside a package** are refused.
- **Settings.** Only the four carried settings, from the project's own
  `.yarnrc.yml`, reach Yarn. Plugins never load during installation, and
  configuration outside the project is not read. What either would have
  changed in the lockfile makes the immutable install fail; what it would
  have changed only in the layout is not reproduced and not detected.
- **Plug'n'Play.** The layout is always isolated `node_modules`. A project
  that requires packages it does not declare fails where it would under Yarn's
  own `pnpm` linker; `packageExtensions` is Yarn's fix, and it is carried.
- **Fetching** is Bazel's downloader's job; a private registry's credentials
  reach it through a credential helper.

## Testing

| Scenario | Where |
| --- | --- |
| Install in a dependency, Duplicate name, Unknown distribution | extension unit tests |
| Stale pin file, Unsupported protocol, Yarn 1 lockfile, Different Yarn, Patch file (unlisted), Workspace not listed, Configuration that cannot be read | driver unit tests (Node.js) against fixture lockfiles and configurations |
| File names Bazel labels cannot hold, Link inside a package (refusal) | archive unit tests |
| Installed version, Built-in patch, Offline use, File names Bazel labels cannot hold, Executables, Shared package, Workspace dependencies, Default architecture, Build forced by metadata, Settings that shape the install, Patch file (listed) | `e2e/install/` consumer module, real Yarn and Bazel |
| Integrity mismatch, Cold fetch from the repository cache, Credentials from a credential helper, Regenerating the pin file, First pin, Lockfile out of date, Checksum mismatch, Named architectures, No host installation, Configuration above the project, Host global folder, Plugins and network settings in the project's configuration, Link inside a package (real tarball), Lockfile changed, Nothing changed | `tools/ci/install_scenarios.sh`, each case a fresh consumer |
| Consumer reads the usage guide | review of `README.md` against the scenario |

The scenario script serves fixture tarballs from a local server it starts, so
it does not depend on a public registry's availability, and covers the
credential-helper case with a server that requires credentials. CI runs
`e2e/install` as a fourth build root on Linux and macOS, and the scenario
script on both. Each test is run red first against an implementation missing
what it tests, and the red output is recorded in tasks.md, which names the
exceptions — a reader written before its tests — and what checked them
instead.
