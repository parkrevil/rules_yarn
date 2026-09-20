## Context

See [proposal.md](proposal.md) for motivation and [specs/yarn-execution/spec.md](specs/yarn-execution/spec.md) for required behavior. The repository has agent tooling only: no Bazel module, targets, or main specifications.

This design was checked on 2026-09-18 against primary sources: Bazel 9.2.0 documentation and Starlark API sources from the `9.2.0` tag, the latest releases of official rulesets (`rules-template` main, `rules_nodejs` 6.7.5/6.7.6/main, `rules_shell` 0.8.0, `rules_python` 2.3.3, `rules_go` 0.63.0, `rules_cc` 0.2.25, `rules_java` 9.9.0, `rules_testing` 0.9.0, `bazel_skylib` 1.9.2), Yarn 4.18.0 documentation and CLI sources, and Corepack's distribution configuration. A scratch module confirmed that `rules_nodejs` 6.7.5, `rules_shell` 0.8.0, `bazel_skylib` 1.9.2, `rules_testing` 0.9.0, and a Node.js 24.21.0 runtime toolchain resolve and run under Bazel 9.2.0 on Linux x86_64.

## Goals / Non-Goals

**Goals:** Separate Yarn acquisition from execution, keep the public API to one extension and one rule, use only stable Bazel APIs, and prove the API from an independent consumer.

**Non-Goals:** Running Yarn inside Bazel build actions, a Yarn toolchain type, version selection from `package.json`, Windows or macOS launchers, generated API documentation, BCR release automation, and Bazel versions other than 9.2.0. Experimental Starlark APIs (`subrule`, rule `initializer`, rule extension) are not used.

## Decisions

### 1. Ruleset layout and module metadata

- `module(name = "rules_yarn")` without `version`: the Bazel FAQ recommends leaving the version to the registry. `compatibility_level` is omitted because it is a deprecated no-op in Bazel 9.2.0.
- `yarn/BUILD.bazel` and `yarn/defs.bzl` hold the public rule, as in "Deploying Rules". `yarn/extensions.bzl` holds only the module extension, because extension identity is tied to its `.bzl` file and the extension guide recommends one extension per file.
- Implementation lives in `yarn/private/`. Each private `.bzl` declares load visibility with `visibility()`, as the visibility guide recommends and `rules_cc`, `rules_java`, and `rules_shell` do. Public `.bzl` files get `bzl_library` targets from `bazel_skylib`, as in `rules_shell` and `rules_python`.
- Tests live in a top-level `tests/` package, one of the two locations "Deploying Rules" allows and the layout `rules_cc` uses. The consumer example lives in `e2e/smoke`, the rules-template layout that a future BCR presubmit can reuse.
- The root and `e2e/smoke` commit `.bazelversion` and `MODULE.bazel.lock`, following the lockfile guide. The root `.bazelrc` sets `--lockfile_mode=error` like rules-template. `e2e/smoke` does not, because a BCR presubmit replaces its local override and would invalidate the lockfile.
- Alternative: copy rules-template wholesale. Rejected because it brings release automation, a placeholder toolchain, and `bazel_lib` documentation targets that this change does not use.

### 2. Dependencies and versions

- `rules_nodejs` 6.7.5. Version 6.7.6 is pinned in project instructions but is not in the Bazel Central Registry: `bazel mod graph` fails with "module rules_nodejs@6.7.6 not found", and the registry lists 6.7.5 as the latest. The GitHub comparison `v6.7.5...v6.7.6` changes only `README.md` and `nodejs/private/node_versions.bzl`. Alternative: `archive_override` for 6.7.6. Rejected because overrides apply only in the root module, so every consumer would have to copy it. Move to 6.7.6 once the registry publishes it.
- `rules_shell` 0.8.0 provides the Bash runfiles library, the shell toolchain type, and `sh_test`. In Bazel 9.2.0, `@bazel_tools//tools/bash/runfiles` is an alias to `@rules_shell//shell/runfiles`.
- `bazel_skylib` 1.9.2 provides `bzl_library` and `shell.quote`. `rules_testing` 0.9.0 is a development dependency.
- Node.js 24.21.0 (released 2026-09-07) is the latest Active LTS release. Node.js 26 is the Current line, and Node.js recommends LTS lines for production. The `rules_nodejs` 6.7.5 version table ends at 24.18.0. For newer versions, its `node` extension downloads `SHASUMS256.txt` and records the digests as lockfile facts. That is a supported `rules_nodejs` API, and the committed lockfile pins the digests.
- Yarn 4.18.0 is fetched from `https://repo.yarnpkg.com/4.18.0/packages/yarnpkg-cli/bin/yarn.js`, the source Corepack uses for Yarn 2 and later, with integrity `sha256-+4sdIL5yoLVEo1vOxMftD/Vamxc8AfGRsCuhZLIFHbU=`. Two independent upstream records confirm the digest: the bytes equal `bin/yarn.js` in the npm tarball `@yarnpkg/cli-dist@4.18.0` (registry integrity `sha512-WV9H+/O8BPElO7GKzrKipTtCNt8/gBCUJaNAEOw4U/x2k17aZjseYzll4QhpZE4xIsEvo8bK6KvjhsXuHrclPg==`), and their SHA-224 equals Corepack's `4.18.0+sha224.5707fce90df5d8720fae4e85a07ab55e90aa20fded8914893e2ba225`.

### 3. Distribution extension and repository

- `yarn.distribution(version, name = "yarn")` is the only tag. Following the extension guide's naming best practice and the `rules_nodejs` `node` extension, only the root module may use a name other than the default.
- `module_ctx.modules` is in breadth-first order from the root. For each repository name, the first module that declares it decides the version, so the root module decides whenever it declares one. Declarations in that module must agree, and later modules' declarations for that name are ignored. This matches how `rules_nodejs` selects its default toolchain.
  - Alternative: select the highest version, as rules-template does. Rejected because the template marks SemVer selection as unfinished, and it would silently override the root module's choice.
  - Alternative: fail on any cross-module difference. Rejected because it breaks module graphs in which a dependency also uses rules_yarn.
- Unsupported versions fail before any repository is created. The error lists the versions in the checked-in table.
- The extension returns `extension_metadata(reproducible = True)` and sets `os_dependent = False` and `arch_dependent = False`, per the extension guide and rules-template.
- Tag processing is a function with an injectable failure callback, like `rules_python`'s `parse_modules(..., _fail = fail)`, so unit tests can assert error messages.
- A `yarn_distribution` repository rule calls `repository_ctx.download(url, output = "yarn.js", integrity)`, returns `repo_metadata(reproducible = True)`, and writes a `BUILD.bazel` whose public `yarn` filegroup is the entry point, so `@yarn` labels it. Alternative: `http_file`. Rejected because it exposes the file only as `@<name>//file`.
- There is no Yarn toolchain type. `yarn.js` is platform-independent, and rules-template instructs removing toolchain code when a ruleset fetches no platform-dependent tools. The platform-dependent Node.js runtime already comes from `rules_nodejs` toolchains. Alternative: a toolchain type like `rules_python`'s uv toolchain. Rejected because uv ships native binaries per platform, and a Yarn toolchain would add resolution without choosing between platform variants.

### 4. `yarn_binary` rule

- The rule is `rule(executable = True)` with a mandatory `yarn` label attribute that accepts a single `.js` or `.cjs` file. Private attributes hold the launcher template and `@rules_shell//shell/runfiles`.
- It requires `@rules_nodejs//nodejs:runtime_toolchain_type`, which `rules_nodejs` designates for executable Node.js outputs. It also requires `@rules_shell//shell:toolchain_type` for the interpreter path in the shebang, as `rules_shell`'s Bash launcher does.
- It fails analysis when `NodeInfo.node` is unset, which means a host-path-only runtime. It never reads the deprecated `target_tool_path` or `tool_files` fields.
- The executable is declared with `ctx.actions.declare_file(ctx.label.name)` and written with `expand_template(is_executable = True)`, following the rules guide and avoiding the deprecated `ctx.outputs.executable`. Runfiles-root paths come from `File.short_path` the same way `rules_shell`'s `_to_rlocation_path` computes them. Each is inserted as a single shell word quoted with `bazel_skylib`'s `shell.quote`.
- Runfiles contain the Node.js file, the Yarn file, and the merged `default_runfiles` of the runfiles library, as the rules guide recommends.
- Alternative: a symbolic macro around `sh_binary(use_bash_launcher = True)`. Rejected because `sh_binary` cannot resolve the Node.js toolchain. Alternative: `rules_js`'s `js_binary`, which `rules_nodejs` suggests for general Node.js programs. Rejected because it adds a non-official dependency and a much larger launcher to run one entry point.

### 5. Launcher behavior

- The launcher initializes the Bash runfiles library with its documented v3 snippet and resolves Node.js and Yarn with `rlocation`, which handles runfiles directories, manifests, and repository mapping.
- It exports `YARN_IGNORE_PATH=1`, Yarn's documented `ignorePath` setting, so project `yarnPath` cannot replace the selected distribution. It exports `YARN_ENABLE_TELEMETRY=0` because Yarn 4.18.0 starts telemetry for interactive terminals, which would break the offline `--version` requirement under `bazel run`.
- When `BUILD_WORKING_DIRECTORY` is set, which the Bazel user manual documents for `bazel run`, the launcher changes to that directory before starting Yarn, as `rules_go`'s `go` runner does. Otherwise it keeps the current directory. Under `bazel run`, Bazel starts the launcher by absolute path without `RUNFILES_DIR`, so the resolved runfiles paths stay valid after the directory change.
- It ends with `exec "$node" "$yarn" "$@"`: arguments pass as an array, and standard streams and exit status belong to Yarn. There is no `eval` and no reassembled command string.
- It does not call `runfiles_export_envvars`. Yarn does not read runfiles, and exporting them would mislead Bazel-built programs that Yarn scripts start.

### 6. Verification

- Starlark tests use `rules_testing` `unit_test` and `analysis_test`, the framework `rules_cc`, `rules_java`, and `rules_python` use. Bazel's testing page describes the older `bazel_skylib` framework, which offers no additional capability here.
- Extension tests call the tag-processing function with mock modules and a recording failure callback. Repository rule tests call the implementation with a mock `repository_ctx`.
- Analysis tests check runfiles and launcher substitutions under the host platform. A failure test uses a test-only platform and a registered development toolchain that provides only `node_path`.
- Launcher tests are `sh_test` targets, the approach Bazel's testing page gives for validating executables. They use a probe entry point for argument, stream, exit-status, working-directory, and manifest-lookup checks, and the real Yarn distribution for `--version`, invalid commands, `yarnPath`, unusable host tools, and unchanged project files. Offline checks use the documented `block-network` tag and assert that network access is blocked.
- `e2e/smoke` depends on the ruleset through `local_path_override` and uses only public loads.
- Failures that stop Bazel before tests run are verified manually in scratch modules, with commands and output recorded under the corresponding task in tasks.md: integrity mismatch, extension configuration errors, and private-load denial. So are `bazel run` from a subdirectory and offline direct execution.

### 7. Documentation

`README.md` describes installation, the public API, the tested configuration, and the difference between running the Yarn CLI and Bazel dependency or build integration, as "Deploying Rules" asks. Public Starlark symbols carry docstrings that Stardoc and `starlark_doc_extract` can read. Generated documentation is deferred to the BCR publication change.

## Risks / Trade-offs

- [Project instructions pin `rules_nodejs` 6.7.6] → Record the registry check and move to 6.7.6 when the registry publishes it.
- [Node.js digests come from `SHASUMS256.txt` on first resolution] → Commit lockfiles and keep `--lockfile_mode=error` in the root.
- [The runfiles library exports its own lookup variables into Yarn's environment] → Document it, and do not export extra runfiles variables.
- [`BUILD_WORKING_DIRECTORY` is inherited by programs that Yarn starts] → Document that the variable follows `bazel run` semantics.
- [Yarn commands can change projects, caches, and global folders] → Document that the rule delivers the CLI and gives no hermeticity guarantees.
- [The shell interpreter path comes from `rules_shell`'s host-detected toolchain] → Support only the tested Linux x86_64 configuration.
- [Silently ignoring farther modules' default-name declarations can surprise dependency authors] → Document the selection rule and cover it with tests.

## Migration Plan

No consumers exist. Implement in task order and verify the independent consumer last. No commits or releases are part of this change unless requested.

## References

- Bazel 9.2.0 documentation sources: [Deploying Rules](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/rules/deploying.mdx), [Rules](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/extending/rules.mdx), [Toolchains](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/extending/toolchains.mdx), [Macros](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/extending/macros.mdx), [Module extensions](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/external/extension.mdx), [Repository rules](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/external/repo.mdx), [Lockfile](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/external/lockfile.mdx), [Module FAQ](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/external/faq.mdx), [Visibility](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/concepts/visibility.mdx), [Testing](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/rules/testing.mdx), [User manual: bazel run](https://github.com/bazelbuild/bazel/blob/9.2.0/docs/docs/user-manual.mdx), [common `tags`](https://github.com/bazelbuild/bazel/blob/9.2.0/src/main/java/com/google/devtools/build/docgen/templates/attributes/common/tags.html).
- Bazel 9.2.0 API sources: [`rule`/`subrule`](https://github.com/bazelbuild/bazel/blob/9.2.0/src/main/java/com/google/devtools/build/lib/starlarkbuildapi/StarlarkRuleFunctionsApi.java), [`repository_ctx.repo_metadata`](https://github.com/bazelbuild/bazel/blob/9.2.0/src/main/java/com/google/devtools/build/lib/bazel/repository/starlark/StarlarkRepositoryContext.java), [`module_ctx.extension_metadata`](https://github.com/bazelbuild/bazel/blob/9.2.0/src/main/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleExtensionContext.java), [`module()`](https://github.com/bazelbuild/bazel/blob/9.2.0/src/main/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileGlobals.java).
- Rulesets: [rules-template](https://github.com/bazel-contrib/rules-template), [rules_nodejs 6.7.5](https://github.com/bazel-contrib/rules_nodejs/tree/v6.7.5) and [v6.7.5...v6.7.6](https://github.com/bazel-contrib/rules_nodejs/compare/v6.7.5...v6.7.6), [BCR rules_nodejs](https://github.com/bazelbuild/bazel-central-registry/tree/main/modules/rules_nodejs), [rules_shell sh_executable](https://github.com/bazel-contrib/rules_shell/blob/v0.8.0/shell/private/sh_executable.bzl), [rules_python uv](https://github.com/bazel-contrib/rules_python/tree/2.3.3/python/uv) and [python.bzl](https://github.com/bazel-contrib/rules_python/blob/2.3.3/python/private/python.bzl), [rules_go go runner](https://github.com/bazel-contrib/rules_go/tree/v0.63.0/go/tools/go_bin_runner), [rules_testing](https://github.com/bazelbuild/rules_testing/tree/v0.9.0).
- Yarn and Node.js: [Yarn install](https://github.com/yarnpkg/berry/blob/%40yarnpkg/cli/4.18.0/packages/docusaurus/docs/getting-started/basics/install.mdx), [yarnrc settings](https://github.com/yarnpkg/berry/blob/%40yarnpkg/cli/4.18.0/packages/docusaurus/static/configuration/yarnrc.json), [telemetry](https://github.com/yarnpkg/berry/blob/%40yarnpkg/cli/4.18.0/packages/docusaurus/docs/advanced/04-technical/telemetry.mdx), [CLI startup](https://github.com/yarnpkg/berry/blob/%40yarnpkg/cli/4.18.0/packages/yarnpkg-cli/sources/lib.ts), [Corepack config](https://github.com/nodejs/corepack/blob/main/config.json), [Node.js releases](https://nodejs.org/dist/index.json).
