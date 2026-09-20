# Yarn rules for [Bazel](https://bazel.build)

`rules_yarn` delivers an exact [Yarn](https://yarnpkg.com) version to a Bazel
workspace and runs it with a Bazel-managed Node.js runtime, so nobody needs
Node.js, Yarn, or Corepack installed to run Yarn.

## Installation

`rules_yarn` is not published to the [Bazel Central Registry](https://registry.bazel.build)
yet, so depend on it with a non-registry override. In `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_yarn")
bazel_dep(name = "rules_nodejs", version = "6.7.5")

local_path_override(
    module_name = "rules_yarn",
    path = "../..",
)

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "24.21.0")

yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
use_repo(yarn, "yarn")
```

`rules_nodejs` supplies the Node.js runtime toolchain. Pick the Node.js version
your project needs; the version above is the one this ruleset is tested with.
[`archive_override`](https://bazel.build/rules/lib/globals/module#archive_override)
and [`git_override`](https://bazel.build/rules/lib/globals/module#git_override)
work in place of `local_path_override`.

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

## Tested configuration

Checked on 2026-09-20 on Linux x86_64:

| Component | Version |
| --- | --- |
| Bazel | 9.2.0 |
| Yarn | 4.18.0 |
| Node.js | 24.21.0 |
| `rules_nodejs` | 6.7.5 |
| `rules_shell` | 0.8.0 |
| `bazel_skylib` | 1.9.2 |

Other platforms are untested: the launcher is a POSIX shell script, so Windows
needs work that this ruleset does not do yet. [`e2e/smoke`](e2e/smoke) is a
consumer module that uses only the public API; its snippets are the ones above.

## Scope

This ruleset delivers the Yarn CLI. It does not turn Yarn commands into Bazel
build actions, so a command you run through `yarn_binary` gets no caching,
sandboxing, or dependency-installation guarantees from Bazel: Yarn reads and
writes your project, its caches, and the network exactly as it does outside
Bazel. Installing dependencies, translating `yarn.lock` into Bazel targets, and
Plug'n'Play or `node_modules` integration are not part of this ruleset.
