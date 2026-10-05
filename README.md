# Yarn rules for [Bazel](https://bazel.build)

`rules_yarn` delivers an exact [Yarn](https://yarnpkg.com) version to a Bazel
workspace and runs it with a Bazel-managed Node.js runtime, so nobody needs
Node.js, Yarn, or Corepack installed to run Yarn. It also installs a Yarn
project's locked dependencies as Bazel artifacts, every registry package
fetched by Bazel with a pinned integrity.

## Installation

In `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_yarn", version = "0.1.0")
bazel_dep(name = "rules_nodejs", version = "6.7.5")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "24.21.0")

yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
use_repo(yarn, "yarn")
```

Bazel 8.3.0 or newer. `rules_yarn` declares that, so an older Bazel is turned
away while the module graph resolves rather than failing inside the ruleset.

`rules_nodejs` supplies the Node.js runtime toolchain. Pick the Node.js version
your project needs; the one above is what this ruleset is tested with.

### Before the module reaches the registry

`rules_yarn` is not in the [Bazel Central Registry](https://registry.bazel.build)
yet, so `bazel_dep` alone will not resolve it. Until it is, add an override
next to the `bazel_dep` above. A release archive, which every release carries:

```starlark
archive_override(
    module_name = "rules_yarn",
    integrity = "sha256-...",
    strip_prefix = "rules_yarn-0.1.0",
    urls = ["https://github.com/parkrevil/rules_yarn/releases/download/v0.1.0/rules_yarn-v0.1.0.tar.gz"],
)
```

The integrity value for each archive is in that release's notes.
[`git_override`](https://bazel.build/rules/lib/globals/module#git_override) and
[`local_path_override`](https://bazel.build/rules/lib/globals/module#local_path_override)
work too; `local_path_override` is what [`e2e/smoke`](e2e/smoke) uses, with
`path = "../.."`, because it sits two directories below this repository's root.

An override only takes effect in the root module, so a module that depends on
`rules_yarn` cannot pass it on — every root module that ends up depending on
`rules_yarn` has to repeat it. That is the reason to publish, and the reason
this section exists.

## Usage

In a `BUILD.bazel` file:

```starlark
load("@rules_yarn//yarn:defs.bzl", "yarn_binary")

yarn_binary(
    name = "yarn",
    yarn = "@yarn",
)
```

Then run Yarn. Arguments after `--` go to Yarn unchanged, and Yarn runs in the
directory you invoked Bazel from:

```shell
bazel run //:yarn -- --version
bazel run //:yarn -- install
```

## Installing a project's dependencies

`yarn.install` turns a project's `yarn.lock` into Bazel artifacts that other
targets can take as inputs.

```starlark
yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
yarn.install(
    name = "npm",
    package_json = "//:package.json",
    lockfile = "//:yarn.lock",
    pins = "//:yarn_pins.json",
    yarnrc = "//:.yarnrc.yml",
)
use_repo(yarn, "npm", "yarn")
```

The pin file need not exist yet; the pin target writes it:

```shell
bazel run @npm//:pin
```

Commit it beside `yarn.lock`, and run the same command whenever the lockfile
changes. `@npm//:node_modules` is then the installed tree.

What it guarantees:

- **Every registry package is fetched by Bazel** with the SHA-512 integrity the
  pin file records — the registry's published digest, taken when you pinned,
  or, for a registry that publishes none, the digest of the bytes it served
  then; the pin target names those packages.
  That puts the packages in Bazel's repository cache, and makes `--distdir`,
  `--downloader_config` and `--credential_helper` apply. A
  private registry's credentials reach Bazel through a credential helper.
- **The installed versions are exactly the lockfile's.** A lockfile that would
  have to change, a checksum it records that does not match, or a pin file
  that does not match it, fails the fetch with what to do.
- **Yarn lays the packages out, offline.** The selected Yarn runs on the
  Bazel-managed Node.js against a loopback server that serves only the
  verified tarballs, so peer dependencies, `packageExtensions` and patches —
  your own and Yarn's built-in ones — work as Yarn does them. Yarn sees none of
  the host's configuration, and nothing from your `.yarnrc.yml` but
  `packageExtensions`, `enableTransparentWorkspaces`, `defaultProtocol` and
  `compressionLevel`: no plugin, proxy or network setting reaches it.
- **No dependency build script runs**, whatever `dependenciesMeta` says.
- **Each package is its own artifact**, and each link between packages a
  symlink artifact, in Yarn's isolated `pnpm` layout, so the tree is cached
  package by package and needs no network to use.

Workspaces need their `package.json` files listed in `workspaces`, and patch
files their paths in `patches`. Platform-specific packages are installed for
the host unless `supported_architectures` names others, with Yarn's meaning:
`os`, `cpu` and `libc` each a set, so naming two systems and two CPUs admits
all four combinations.

Not supported yet, each refused with its reason: dependency resolution through
`git:`, `exec:`, `file:`, `link:`, `portal:` or tarball URLs; registries whose
tarballs are not at the conventional path; packages containing symbolic links;
and Yarn 1 lockfiles. The project's `nodeLinker` is not carried: the packages
are always laid out with Yarn's isolated `pnpm` linker, whatever the project
uses locally, so a project that relies on Plug'n'Play's resolution gets a
`node_modules` tree instead. Running project scripts and builds as Bazel
actions, linking workspaces to each other, and running dependency build scripts
are not part of this release.

## Public API

### `yarn.distribution` (module extension tag)

| Attribute | Default | Description |
| --- | --- | --- |
| `version` | required | Exact Yarn version. It must be a version that `rules_yarn` records a digest for: currently `4.18.0`. |
| `name` | `yarn` | Name of the generated repository. Its `yarn` target is the Yarn entry point, so `@yarn` refers to it under the default name. |

The extension downloads the standalone Yarn bundle from `repo.yarnpkg.com`, the
same source [Corepack](https://github.com/nodejs/corepack) uses for Yarn 2 and
later, and checks it against the digest recorded in
[`yarn/private/versions.bzl`](yarn/private/versions.bzl).

Repository naming and version selection follow Bazel's
[module extension guidance](https://bazel.build/external/extension#best-practices):

- Only the root module may choose a repository name other than `yarn`.
- For each repository name, the module closest to the root module decides the
  version, so the root module's choice wins over its dependencies'.
- Declaring one repository name with two versions in that module is an error, as
  is requesting a version without a recorded digest.

### `yarn.install` (module extension tag)

| Attribute | Default | Description |
| --- | --- | --- |
| `name` | required | Name of the repository holding the installed packages. Only the root module may declare installs. |
| `package_json` | required | The project's root `package.json`. |
| `lockfile` | required | The project's `yarn.lock`. |
| `pins` | required | The pin file `bazel run @<name>//:pin` writes. It need not exist, or may be empty, before the first pin. |
| `yarnrc` | none | The project's `.yarnrc.yml`. Only the settings listed above are read from it. |
| `workspaces` | `[]` | The `package.json` of every workspace other than the root. |
| `patches` | `[]` | Every patch file a `patch:` entry applies, other than Yarn's built-in ones. |
| `supported_architectures` | host | Yarn's `supportedArchitectures`: lists under `os`, `cpu` and `libc`. |
| `distribution` | `yarn` | The `yarn.distribution` repository whose Yarn lays the packages out. |

The repository provides `:node_modules`, carrying `YarnNodeModulesInfo` from
`@rules_yarn//yarn:providers.bzl`, and `:pin`.

### `yarn_binary` (rule)

| Attribute | Default | Description |
| --- | --- | --- |
| `yarn` | required | The Yarn JavaScript entry point, such as `@yarn`. |

The rule builds a launcher that runs the Yarn entry point with the `node` file
from the `@rules_nodejs//nodejs:runtime_toolchain_type` toolchain. The launcher:

- never falls back to host Node.js, Yarn, or Corepack;
- ignores a project's `yarnPath` setting, so the selected distribution runs;
- turns Yarn's telemetry off;
- runs Yarn in `BUILD_WORKING_DIRECTORY` under `bazel run`, and in the current
  directory when the built executable is run directly;
- passes arguments through without shell re-interpretation and preserves Yarn's
  output streams and exit status.

If the entry point target carries its own runtime files, such as a `filegroup`
with `data`, they stay in the launcher's runfiles. The entry point receives its
own runfiles path as `process.argv[1]`; resolve sibling files from there rather
than from `__dirname`, which Node.js resolves through the runfiles symlink.

Analysis fails if the resolved Node.js runtime toolchain provides only a host
path instead of a file.

`yarn_binary` takes the distribution as a label rather than resolving it through
a toolchain type, unlike the `register_toolchains` pattern `rules_nodejs` uses
for the Node.js runtime. A Yarn bundle is platform-independent
JavaScript — one artifact per version, with nothing for toolchain resolution to
select between — so a toolchain would add a registration step and a resolution
failure mode without deciding anything. The Node.js runtime, which is
platform-specific, does come from a toolchain.

## Tested configuration

Checked on 2026-09-20 on Linux x86_64:

| Component | Version |
| --- | --- |
| Bazel | 9.2.0, and 8.3.0 as the oldest supported |
| Yarn | 4.18.0 |
| Node.js | 24.21.0 |
| `rules_nodejs` | 6.7.5 |
| `rules_shell` | 0.8.0 |
| `bazel_skylib` | 1.9.2 |

`rules_yarn` declares `bazel_compatibility = [">=8.3.0"]`, the release where
the repository API it uses arrives. Bazel refuses an older version while it
resolves the module graph, so you get a message naming this ruleset rather
than an error from inside it.

The launcher is a Bash script: it uses `[[ ]]`, `pipefail` and `source`, and
the shell toolchain points at Bash on every operating system it supports. So
Windows needs work this ruleset does not do yet.

[`e2e/smoke`](e2e/smoke) is a consumer module that uses only the public API,
[`e2e/install`](e2e/install) installs a real project with `yarn.install`, and
[`tests/bcr`](tests/bcr) is the one the registry presubmit runs.

## Scope

`yarn_binary` runs the Yarn CLI and nothing more: a command you run through it
gets no caching, sandboxing, or dependency-installation guarantees from Bazel,
and Yarn reads and writes your project, its caches, and the network exactly as
it does outside Bazel.

`yarn.install` is the part with guarantees: it installs the lockfile's
dependencies as Bazel artifacts, as described above. It does not yet run your
project's scripts or builds as Bazel actions; those take the installed tree as
an input and come next.

## License

[Apache License 2.0](LICENSE), the license of the rulesets this one builds on.
