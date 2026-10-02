## Why

`tests/bcr/MODULE.bazel.lock` is committed — 700 lines, added by `fef0398`,
the change that wrote into AGENTS.md that the module "keeps no lockfile on
purpose". The repository and the rule contradict each other, and the rule is
the one that is right: the registry presubmit resolves that module under
several Bazel versions, and a lockfile written by one of them fails under
another.

The cause is not carelessness about `git add`, or not only that. The other
two roots each state a lockfile mode in their own `.bazelrc`; `tests/bcr` has
no `.bazelrc`, so Bazel's default of `--lockfile_mode=update` applies and it
writes one. Measured: delete the file, run `bazel build //...` there, and it
comes back.

So removing the file alone would leave the next person who runs Bazel in that
directory to commit it again.

## What Changes

- Delete `tests/bcr/MODULE.bazel.lock`.
- Add `tests/bcr/.bazelrc` setting `--lockfile_mode=off`, so the module states
  its own mode as the other two roots do and Bazel stops writing the file.
- `ci.yml` drops the `--lockfile_mode=off` it was passing by hand, now that
  the module says it.
- AGENTS.md says what makes its claim true, rather than only asserting it.

## Capabilities

### Modified Capabilities

None. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- Deleted `tests/bcr/MODULE.bazel.lock`; new `tests/bcr/.bazelrc`.
- `.github/workflows/ci.yml`, `AGENTS.md`.
