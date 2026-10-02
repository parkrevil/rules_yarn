## Why

The change before this one added a third build root, `tests/bcr`, and rewrote
AGENTS.md's commit gate to name all three:

> `bazel build //... && bazel test //...` passes in the root, in `e2e/smoke/`
> and in `tests/bcr/`

`.github/workflows/ci.yml` still runs two. So the rule says three and the
machine that enforces it checks two, which means the new root is verified only
when someone remembers to run it by hand — the state CI was added to end.

It is also the exact failure the same change wrote into AGENTS.md as a rule:
"When the change states a rule, apply it to everything that change touches."
That change stated the rule and did not apply it to the file that enforces it.
The review did not catch it either.

## What Changes

- `ci.yml`'s build-and-test job gains a step for `tests/bcr`, on both
  platforms, with `--lockfile_mode=off` because that module keeps no lockfile
  on purpose.

## Capabilities

### Modified Capabilities

None. This makes an existing rule enforced; it changes nothing about the
ruleset. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- `.github/workflows/ci.yml`.
- Nothing else.
