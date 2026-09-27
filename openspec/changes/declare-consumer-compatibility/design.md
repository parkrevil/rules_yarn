## Context

See proposal.md — Why. Both additions are the ruleset telling Bazel something
it already knows about itself, so Bazel can act on it instead of the consumer
discovering it the hard way.

## Goals / Non-Goals

Goals:

- The declared floor is the oldest version that was actually run, not the
  oldest that looks plausible from reading the APIs.
- The extension's report matches how the root module used it, in every shape
  a root module can use it.

Non-Goals:

- Widening support. The floor records where the ruleset already works; it
  does not make older Bazel work.
- Publishing. A registry release brings its own metadata and is out of scope.

## Decisions

### The floor is `>=8.3.0`, established by running it

`yarn/private/repositories.bzl` calls `repository_ctx.repo_metadata(reproducible = True)`.
`bazel_features` gates that parameter at `>=8.3.0` or `>=9.0.0-pre.20250831.1`
(`features.bzl:85`, Bazel issue #25938), which says where the API arrives but
not whether the rest of the ruleset works there. So both sides of the boundary
were run, with a consumer module using a local override onto this repository:

| Bazel | result |
| --- | --- |
| 8.2.1 | `Error: 'repository_ctx' value has no field or method 'repo_metadata'`, raised at `yarn/private/repositories.bzl:30` |
| 8.3.0 | `bazel build //:yarn` succeeds; `bazel run //:yarn -- --version` and the built launcher both print `4.18.0` |
| 8.3.1 | the same |

and the declaration itself was run rather than assumed: with
`bazel_compatibility = [">=8.3.0"]` in place, 8.2.1 reports
`Bazel version 8.2.1 is not compatible with module "rules_yarn@_" (bazel_compatibility: [>=8.3.0])`
and stops before reaching any of the ruleset's files.

Alternative considered: declare `>=9.0.0`, the line this repository develops
on. Rejected — it would refuse a version measured to work, and the only
argument for it was that 8.3 had not been tried, which is an argument for
trying it.

### Report the root module's repositories, split by how they were declared

`module_ctx.extension_metadata` takes the repositories the root module treats
as direct dependencies, and Bazel checks them against the root module's
`use_repo` lines. It takes regular and development-only ones separately, and
they have to match how the root module declared the extension.

That split is not optional here. This repository's own root module declares
the extension with `dev_dependency = True`, so reporting every root tag as a
regular dependency fails the build outright:

```
ERROR: root_module_direct_deps must be empty if the root module contains no
usages with dev_dependency = False
```

`module_ctx.is_dev_dependency(tag)` is what separates them. Measured at Bazel
9.2.0: a regular usage yields the repository in the regular list and an empty
development list, a development-only usage the reverse, and both resolve
clean.

A repository the root module declares both ways counts as regular, because
Bazel requires a repository in the regular list to be declared with a regular
`use_repo`.

What this buys, stated exactly so it is not oversold: `bazel mod tidy` gains
the ability to write and keep the `use_repo` line. The error a consumer sees
when the line is missing is unchanged — still `No repository visible as
'@yarn'` — because Bazel raises that before the extension's report is
consulted. Both were measured.

### Only the root module's declarations are reported

A repository a dependency asked for is not a direct dependency of the root
module, so it does not belong in either list. The report is therefore built
from the root module's tags, filtered to the repositories the extension
actually creates.

## Risks / Trade-offs

- [Only Bazel releases were run, so a version between 8.3.0 and 9.2.0 could
  in principle break] → 8.3.0, 8.3.1 and 9.2.0 all build and run the probe,
  and no API the ruleset uses arrives between them. The change that adds CI
  pins a job at the declared floor so this stays true.
- [`bazel_compatibility` is a pin, so the lockfiles have to agree] → Both
  roots are re-resolved and the outcome recorded, per AGENTS.md's "Changing a
  pin".
- [Nothing in the repository's own builds exercises the floor, so it could
  rot] → The change that adds CI adds a job at the declared floor; until
  then the floor rests on a recorded run.

## Migration Plan

None for existing consumers: there are none, and 9.2.0 remains supported.
