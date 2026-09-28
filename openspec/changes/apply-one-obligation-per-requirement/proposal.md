## Why

The change before this one split a requirement that held three obligations,
and said in its own design that the length report which triggered it was a
symptom rather than the criterion. It then stopped at the requirement the
report had flagged. A reviewer asked the obvious question — whether the same
shape survives elsewhere in the spec — and it does.

Every requirement in `yarn-execution` has now been read against a stated
criterion rather than against a linter: **a requirement holds one obligation
when withdrawing any part of it would leave the rest incoherent.** One
requirement fails it.

`Repository naming` states who may choose a repository name, and separately
which module's declaration decides the version. Allowing any module to choose
a name would leave the version rule standing untouched, so these are two
promises under one name. README already describes them as two, under a heading
that names both: "Repository naming and version selection".

## What Changes

- Replace `Repository naming` with `Repository naming authority` and
  `Version arbitration across modules`.

No behavior changes. The same sentences and the same four scenarios, regrouped.

## Capabilities

### Modified Capabilities

- `yarn-execution`: `Repository naming` is removed and its two obligations are
  stated as `Repository naming authority` and `Version arbitration across
  modules`.

## Impact

- `openspec/specs/yarn-execution/spec.md`, through this change's delta.
- No source file, no test, no pin.
