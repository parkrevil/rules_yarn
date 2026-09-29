## Why

Five things in the repository are wrong, stale or noisy. None breaks a build,
which is why they have survived; each costs a reader or a contributor
something.

- README calls the launcher "a POSIX shell script". It is not: it uses
  `[[ ]]`, `pipefail` and `source`. The claim matters because it is offered as
  the reason Windows is unsupported, so a reader could reasonably conclude the
  launcher would run under any `sh`.
- README's installation snippet carries `local_path_override(path = "../..")`
  with nothing saying what the path is relative to. It is the `e2e/smoke`
  value, correct only from two directories below the repository root, and a
  reader copying it gets a broken path.
- `.gitignore` does not list `.claude/settings.local.json`. It goes unnoticed
  here only because this machine's global ignore covers it; another
  contributor would commit it.
- `e2e/smoke/.bazelrc` has no `try-import` for per-user settings, which the
  root `.bazelrc` has. The two roots differ for no reason.
- The OKF tooling validates a bundle that does not exist. `tools/okf/` is 571
  lines plus a wrapper, a pre-commit hook filtered to `^\.okf/`, and a
  `PostToolUse` hook that exits immediately on `[ -d .okf ] || exit 0`. No
  `.okf/` directory exists, nothing in AGENTS.md or README mentions OKF, and
  `tools/okf/validate.sh` says in its own header that the generated
  `openwiki/` bundle is OpenWiki's to validate. It checks nothing, and the CI
  change recorded it as a job that would break the day a bundle appeared,
  because the hook shells out to `uv`, which the runner images do not carry.

Separately, every `bazel test //...` in the root prints eleven warnings that a
test finishing instantly is sized MODERATE. Warnings nobody can act on teach
people to skim output.

## What Changes

- README: the launcher is described as Bash, with what makes it Bash; the
  installation snippet says what `path` is relative to; the tested Bazel row
  names the declared floor, 8.3.0, rather than 8.3.1.
- `.gitignore` gains `.claude/settings.local.json`.
- `e2e/smoke/.bazelrc` gains the same `try-import` the root has.
- The OKF tooling is removed: `tools/okf/`, `tools/hooks/okf_conformance.sh`,
  the `okf-validate` pre-commit hook, and the `PostToolUse` block in
  `.claude/settings.json`.
- The eleven Starlark unit tests are given a size, which `rules_testing`'s
  `unit_test` cannot pass through.

## Capabilities

### Modified Capabilities

None. README changes correct how existing behavior is described rather than
what it is, and the rest is repository tooling. `.openspec.yaml` sets
`skip_specs: true`.

## Impact

- `README.md`, `.gitignore`, `e2e/smoke/.bazelrc`, `.pre-commit-config.yaml`,
  `.claude/settings.json`.
- Deleted: `tools/okf/validate.py`, `tools/okf/validate.sh`,
  `tools/hooks/okf_conformance.sh`.
- `tests/extensions/extensions_tests.bzl`,
  `tests/repositories/repositories_tests.bzl` — how the tests are declared,
  not what they assert.
- No Bazel rule, no public API, and no pin is affected.
