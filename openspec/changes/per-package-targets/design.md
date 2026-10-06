## Context

`yarn.install` lays a project out with the pinned Yarn's `pnpm` linker, derives
from Yarn's `node_modules/.package-map.json` every store package directory,
every link and every `.bin` entry (`yarn/private/install/layout.js`), and
generates one `yarn_node_modules` target, `:node_modules`, that declares one
directory artifact per store package, filled by its own action, and one
symlink artifact per link and `.bin` entry (`node_modules.bzl`). A consumer
can only depend on all of it.

## Evidence

**What `rules_js` offers.** At v3.5.1, `npm_link_all_packages` generates
`node_modules/<package>` for each direct dependency of the Bazel package it is
called in, and `node_modules/@<scope>` for each scope, holding that scope's
packages (`npm/private/npm_translate_lock_generate.bzl`, lines 35 and 480).
Each package is a target of its own there (`npm_package_store.bzl`), so
dependency cycles between packages would be cycles between targets, which
Bazel forbids; `rules_js` breaks them with a "ref" target holding no files and
a "terminal" target whose `deps` are the whole transitive closure
(`npm_package_store.bzl`, the `elif not ctx.attr.src` branch).

**What Bazel builds.** "Bazel only builds these requested files and the files
that they directly or indirectly depend on. (In terms of the action graph,
Bazel only executes the actions that are reachable as transitive dependencies
of the requested files.)" (`site/en/extending/rules.md`, "Requesting output
files", identical at 8.3.0 and 9.2.0). A target whose files are one
dependency's closure therefore runs only the actions of that closure, even
when one rule declares the actions of every package. The documentation speaks
of requested files; that a test's runfiles follow the same rule is shown by
runs, not quoted: the plan review built, on Bazel 8.3.0, one rule declaring
two files and a target selecting one of them, named `node_modules/foo` beside
the rule `node_modules`, and only that file was built; the scenario "Only the
dependency's packages are built" and the e2e tests on a dependency's target
check the same for this ruleset, the latter through a test's runfiles.

**Target names.** Target names may hold `a`–`z`, `A`–`Z`, `0`–`9` and
``!%-@^_"#$&'()*-+,;<=>?[]{|}~/.``, with no empty, `.` or `..` segment
(`site/en/concepts/labels.md` at 8.3.0). Every character an npm package name
may hold is among them, and `layout.js` already refuses a dependency name
with an empty, `.` or `..` segment. A workspace's directory is part of its
dependencies' target names; a workspace has to be listed by the label of its
`package.json`, so its directory is a label already, but `layout.js` checks
every target name against that set anyway and reports a link outside it,
because a name outside it would make the generated `BUILD` file fail to load
and take the install's other targets, `:pin` among them, with it.

**Where Yarn puts a package's dependencies.** The `pnpm` linker links a
store package's dependencies in `node_modules/.store/<slug>/node_modules/`,
beside its `package` directory, and the root's and each workspace's in their
own `node_modules` (`layout.js` `ownerOf`, from the package map's keys).

**Measured.** On the 717-entry project, walking Yarn's links from each direct
dependency of the root: `react` reaches 3 store packages (0.3 MB), `react-dom`
5 (4.9 MB), `typescript` 1 (22.5 MB), `eslint` 88 (11.3 MB), `jest` 301
(29.4 MB), `next` 29 (226.0 MB), against 732 store packages and 425.3 MB for
the whole tree.

## Goals / Non-Goals

**Goals:** a target per direct dependency and per scope, for the root and each
workspace, holding only what that dependency reaches; nothing for a consumer
to write; `:node_modules` unchanged.

**Non-Goals:** links between workspaces, which the install still records
without creating; targets for packages that are not a direct dependency of
the root or a workspace — `rules_js` offers none either.

## Decisions

**Each target's part is computed from Yarn's layout at install time.**
`layout.js` walks Yarn's links from each direct dependency — its link, the
store package it points at, that package's own links, and so on, each store
package once — and `layout.json` records the store packages each direct
dependency reaches, beside the `.bin` entries the install gives it. A cycle
is a store package already visited, so it needs no ref or terminal target:
`rules_js` needs those because its packages are targets, and here they are
artifacts of one target. Computing it in Starlark at analysis instead would
repeat the walk at every analysis, and in a language the driver's tests do not
reach.

**One rule still declares every artifact.** `yarn_node_modules` keeps
declaring every package's directory and every link. The generated `BUILD`
file also gives it `dependencies`, each direct dependency's link to the store
package directories it reaches; `dependency_bins`, each one's `.bin` entries;
and `scopes`, each scope's directory to its dependencies' links. From them it
returns, in a provider private to `node_modules.bzl`, one part per direct
dependency — a depset of its link, its `.bin` entries and, for each store
package it reaches, the package's directory and the links in that package's
own `node_modules`, one depset per store package shared by every part that
reaches it — and one per scope, the union of its dependencies' parts. A small
rule, `yarn_node_modules_part`, takes `:node_modules` and returns the part
named by its own target name as its files and runfiles, with
`YarnNodeModulesInfo`. Bazel builds only those files' actions. Rejected: an
output group per part — `OutputGroupInfo` takes any name, as the plan review
showed on Bazel 8.3.0 with `@babel/core` — because an output group is not a
target's files or runfiles, so a test could not take one as `data` without a
rule like this one anyway, and `--output_groups` applies to a whole command;
and a rule per package declaring its own artifacts, which would bring back the
target cycles `rules_js` has to break, for no gain, since Yarn computes the
layout all at once.

**Names follow `rules_js` and Yarn's paths.** A direct dependency's target is
named after the link Yarn writes for it — `node_modules/<name>` for the root,
`<workspace>/node_modules/<name>` for a workspace — and a scope's after its
directory there. A scope's target holds the parts of its packages.

**The provider keeps its version.** `YarnNodeModulesInfo` keeps its fields and
`layout_version = 1`; what each field means stays "the tree this target
holds": `files` is every artifact the target holds, and `root` is the
`node_modules` directory a package it holds is found in by name — for a
workspace's dependency, that workspace's `node_modules`, where its link is,
not the root's. A consumer that takes `files` as its inputs and resolves a
package from `root`, the pattern `e2e/install/provider_root.bzl` shows, works
unchanged on every target. `:node_modules` and what it carries do not change,
so nothing written against version 1 breaks. `layout.json`, internal to the
install, moves to version 3.

**A command two dependencies provide.** The install gives a `.bin` entry to
the first of the dependencies providing it, by name (`layout.js`), so the
other dependency's target does not hold that entry.

## Risks / Trade-offs

- Every target is analysed with `:node_modules`: analysis builds one depset
  per direct dependency and scope, bounded by the sum of their closures. The
  scale measurement records the analysis time and the size of the generated
  `BUILD` file before and after.
- A consumer that depends on a dependency's target and loads a package the
  dependency does not declare finds it missing, where `:node_modules` had it.
  That is the point of the target, as it is in `rules_js`, and `:node_modules`
  stays for anything that needs the whole tree.
- A package reached only through a link between workspaces is not in any
  target but `:node_modules`, since those links are not created yet.
- Limit: when the install fails, its repository declares only the target
  `:node_modules`, which reports why, and `:pin`; the dependencies' targets
  come from Yarn's layout, which a failed install does not have, so a
  consumer depending on one sees Bazel's "no such target", and building
  `:node_modules` shows the install's errors.
- Limit: a dependency's target cuts what is extracted, staged and hashed, not
  what is fetched. Analysing it analyses `:node_modules`, whose attributes
  name every pinned tarball repository, so every tarball is still fetched.
- A dependency that lists its platform packages as optional dependencies,
  as `esbuild` does, reaches each one the install has — the host's package and
  the stubs Yarn writes for the others — so its target holds them all.
