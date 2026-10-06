## Why

AGENTS.md keeps `yarn/private/yarn_binary.sh.tpl` the only generated script
and forbids a shell command assembled at run time. Three tests break that:
`tests/launcher/yarn_cli_test.sh` and `e2e/smoke/yarn_version_test.sh` each
write a stand-in for a host's `node` with a heredoc and `chmod +x` it, and
`yarn_cli_test.sh` also writes `redirect.cjs`, a program its `yarnPath`
points at; `tools/hooks/openwiki_staleness_test.sh` assembles a wrapper script
with `printf` from a shell condition passed as a string. These were reported
during `extract-packages-from-tarballs` as defects outside that change.

## What Changes

- The host-tool stand-in is a checked-in `host_tool.sh` in `tests/launcher/`
  and in `e2e/smoke/`, copied under the names `node`, `yarn` and `corepack`.
- The `yarnPath` project is checked in under
  `tests/launcher/testdata/yarn_path_project/` and copied into the test's
  directory.
- The staleness test's wrapper is a checked-in
  `tools/hooks/fixtures/failing_tool.sh`, told the real tool and when to fail
  through `REAL_TOOL` and one of four named `FAIL_WHEN` modes, so no shell
  code is passed around as a string.

No behaviour of the ruleset changes, so no spec changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

Tests and their fixtures only; the wiki pages that describe these tests.
