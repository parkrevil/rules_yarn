## Why

`Bzlmod consumer integration` now carries three unrelated obligations: what
the public API surface is, what the oldest supported Bazel version is, and
what the distribution extension reports about the root module. They were added
to an existing requirement rather than stated as their own, which is why
`openspec validate` reports the requirement text as very long.

A requirement that bundles three obligations cannot be satisfied, dropped or
changed one at a time. Each of the three already has its own scenarios; they
are requirements wearing one name.

## What Changes

- Replace `Bzlmod consumer integration` with three requirements, one per
  obligation: `Public API surface`, `Declared Bazel compatibility`, and
  `Repository declaration reporting`.

No behavior changes. The same obligations and the same scenarios, regrouped so
each requirement states one thing, and the first renamed to what its two
scenarios actually test.

## Capabilities

### Modified Capabilities

- `yarn-execution`: `Bzlmod consumer integration` is removed and its three
  obligations are stated as `Public API surface`, `Declared Bazel
  compatibility` and `Repository declaration reporting`.

## Impact

- `openspec/specs/yarn-execution/spec.md`, through this change's delta.
- No source file, no test, no pin.
