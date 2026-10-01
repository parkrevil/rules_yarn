## Why

The CI added in the previous change ran for the first time and failed on both
platforms (run 36726763532, `main` at `c78fd6f`). That is the gate working.
Six things surfaced, four of them defects the local gate could never have
caught, and two of them process failures of my own.

- **macOS**: `//tests/launcher:launcher_test` fails with
  `find: -printf: unknown primary or operator`. `tests/launcher/launcher_test.sh:102`
  uses GNU find's `-printf`, which BSD find does not have. The line has been
  there since the original feature commit; nothing before macOS CI could have
  found it. It passed locally because this machine's `find` is `bfs`, which
  implements `-printf` — so the local run never tested portability.
- **Linux on CI**: `//tests/launcher:yarn_cli_test` fails with
  "the test can reach the network". Bazel used `processwrapper-sandbox`, not
  `linux-sandbox`, so the `block-network` tag was not honoured. The CI log
  gives no reason for the fallback, and neither the Bazel nor the
  runner-images issue trackers answered it.
- The macOS prediction recorded in the previous change was backwards. It
  expected the network tests to fail there; on macOS `darwin-sandbox` honours
  the tag and `yarn_cli_test` passed. The variable was the runner's sandbox,
  not the operating system.
- `automate-verification-gate`'s task 3.2 — "Record what the macOS job reports
  on the first run" — was left unchecked and the change was archived anyway.
  That is the task that existed to catch exactly this.
- `apply-one-obligation-per-requirement`'s task 2.2 is unchecked although the
  verification was run and reported. The work happened; the record did not.
- `c78fd6f` changed AGENTS.md with no reviewer, which `## Before commit`
  forbids. The defence offered at the time — that the repository treats
  AGENTS.md edits as plain `chore:` commits — does not hold: `52aaf4f`, the
  commit that wrote the review rule, records five reviews in its own message.
  The two rules it added were also unbounded in scope and sat in `## Always`,
  which otherwise holds invariants about the delivered artifact rather than
  rules about handling findings.

## What Changes

- `tests/launcher/launcher_test.sh` builds its manifest with portable `find`.
- The assertion that the sandbox blocks the network moves out of
  `yarn_cli_test` and `e2e/smoke`'s `yarn_version_test` into a target of its
  own in each root, `yarn_offline_test`. Only that target needs the tag
  honoured; the checks that do not need it stop depending on it.
- CI gains a step that reports what sandbox the Linux runner allows, before
  and after addressing one plausible cause, so the next change acts on a
  measurement.
- AGENTS.md: the two rules added by `c78fd6f` are scoped to the change at hand
  and moved to `## Before commit`, where the rules about handling findings
  already live. The reviewer rule now says in the file that it covers a commit
  to the file itself.

## Capabilities

### Modified Capabilities

None. Splitting a test target changes which test proves which requirement, not
what the ruleset does; `Self-contained version execution` is now proved by the
target named for it. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- `tests/launcher/launcher_test.sh`, `tests/launcher/yarn_cli_test.sh`,
  `tests/launcher/BUILD.bazel`, and the same split in `e2e/smoke/`.
- New `tests/launcher/yarn_offline_test.sh` and
  `e2e/smoke/yarn_offline_test.sh`.
- `.github/workflows/ci.yml`, `AGENTS.md`.
- No Bazel rule, no public API, no pin.
- CI is expected to stay red on Linux until the measurement comes back. The
  offline target is the only thing failing there, and silencing it would throw
  away the one check that proves the offline requirement.
