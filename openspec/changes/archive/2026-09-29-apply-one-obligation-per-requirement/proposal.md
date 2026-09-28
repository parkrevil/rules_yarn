## Why

The change before this one split a requirement that held three obligations,
and said in its own design that the length report which triggered it was a
symptom rather than the criterion. It then stopped at the requirement the
report had flagged. A reviewer asked the obvious question — whether the same
shape survives elsewhere in the spec — and it does.

Every requirement in `yarn-execution` has now been read against a stated
criterion rather than against a linter: **a requirement holds one obligation
when withdrawing any part of it would leave the rest incoherent.**

Two requirements fail it.

`Repository naming` states who may choose a repository name, and separately
which module's declaration decides the version. Allowing any module to choose
a name would leave the version rule standing untouched, so these are two
promises under one name. README already describes them as two, under a heading
that names both: "Repository naming and version selection".

`Command forwarding` states that arguments reach Yarn unaltered, that Yarn's
output streams reach the caller, and that Yarn's exit status is the
executable's. A caller can rely on or lose each without the others becoming
meaningless. This change first kept it whole on the argument that a launcher
losing any of the three would be broken rather than weaker — which judges the
launcher's quality, not the requirement's coherence, and is not the criterion
applied to the other nine. A reviewer caught it; the argument does not stand
and the requirement is split.

## What Changes

- Replace `Repository naming` with `Repository naming authority` and
  `Version arbitration across modules`.
- Replace `Command forwarding` with `Argument forwarding`, `Output stream
  passthrough` and `Exit status propagation`.

No behavior changes. The same sentences and the same seven scenarios,
regrouped — with one clause moved: the `Failed command` scenario no longer
repeats that the caller receives Yarn's output, because that is now its own
requirement with its own scenario.

## Capabilities

### Modified Capabilities

- `yarn-execution`: `Repository naming` and `Command forwarding` are removed,
  and their obligations are stated as `Repository naming authority`,
  `Version arbitration across modules`, `Argument forwarding`, `Output stream
  passthrough` and `Exit status propagation`.

## Impact

- `openspec/specs/yarn-execution/spec.md`, through this change's delta.
- No source file, no test, no pin.
