## Why

The repository is public at `github.com/parkrevil/rules_yarn` and carries no
`LICENSE`. Without one, the default applies: nobody may copy, modify or
distribute the ruleset, so the `bazel_dep` plus override that README documents
is something no one can lawfully act on. README also tells a reader to depend
on the ruleset, which is an invitation the repository does not currently grant.

## What Changes

- Add `LICENSE`, the unmodified Apache License 2.0.
- State the license in README.

Apache-2.0 is the license of every ruleset this one depends on or was modelled
on — `rules_nodejs`, `rules_shell`, `bazel_skylib`, `rules_testing`, and the
`bazel-contrib/rules-template` that the bootstrap change's design.md cites as
the layout this repository follows. Choosing anything else would make this
ruleset the odd one out in its own dependency graph.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. A license changes what a consumer is permitted to do, not what the rules
do, so no requirement in `yarn-execution` changes. `.openspec.yaml` sets
`skip_specs: true`.

## Impact

- New `LICENSE`.
- `README.md` gains a License section.
- No Bazel target, no public API, and no pin is affected.
