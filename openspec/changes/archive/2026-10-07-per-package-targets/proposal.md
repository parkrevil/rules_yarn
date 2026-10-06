## Why

An install offers one target, `:node_modules`, holding the whole tree, so every
build or test that uses any installed package takes every package as input:
all of them are extracted or unpacked before it runs, staged in its sandbox,
and part of its cache key. Measured on the 717-entry project, a test that
needs only `react` takes 732 packages and 425 MB where `react`'s dependency
closure is 3 packages and 0.3 MB; `typescript` alone is 1 package of 22.5 MB.

`rules_js`, the reference for installing npm packages under Bazel, gives each
direct dependency a target of its own, `:node_modules/<package>`, and each
scope one, `:node_modules/@<scope>` (`npm/private/npm_translate_lock_generate.bzl`
at v3.5.1), holding the package and what it needs at run time. Bazel builds
only the files a target requests and the actions they depend on (Bazel 8.3.0
and 9.2.0 `site/en/extending/rules.md`, "Requesting output files"), so a
target holding one package's closure builds only that closure.

## What Changes

- Each install repository provides a target for every direct dependency of
  the project root, `:node_modules/<name>`, and of each workspace,
  `:<workspace>/node_modules/<name>`, holding the link Yarn writes for it, the
  store packages it reaches through Yarn's links, their links, and the `.bin`
  entries the install gives that dependency there. Each carries
  `YarnNodeModulesInfo` for that part of the tree.
- Each scope among those direct dependencies gets a target,
  `:node_modules/@<scope>` and `:<workspace>/node_modules/@<scope>`, holding
  the targets of its packages.
- Dependency cycles between packages need nothing of the consumer: what each
  target holds is computed from Yarn's layout at install time.
- `:node_modules` stays the whole tree, unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `yarn-dependencies`: a requirement that each direct dependency and scope
  is a target holding only its part of the installed tree.

## Impact

- `yarn/private/install/layout.js` computes each target's part of the tree;
  `driver.js` records it in `layout.json`; `repository.bzl` generates the
  targets; `node_modules.bzl` gains the rule they use.
- `yarn/providers.bzl`: `YarnNodeModulesInfo.files` documents that a
  dependency's target carries its own part of the tree.
- README, tests, the scenarios and the wiki describe the new targets.
