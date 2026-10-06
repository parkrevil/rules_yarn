## 1. Change

- [x] 1.1 `host_tool.sh` in `tests/launcher/` and `e2e/smoke/`, used by
  `yarn_cli_test` and `yarn_version_test`; run with `HOST_TOOL_MARKER` set,
  each records its path and exits 97, as the generated one did.
- [x] 1.2 `tests/launcher/testdata/yarn_path_project/`, copied by
  `yarn_cli_test`; `.yarnrc.yml` reaches the runfiles.
- [x] 1.3 `tools/hooks/fixtures/failing_tool.sh` with named modes; the
  staleness contract table passes 56/56, and with the fixture made never to
  fail in `always` and `second-run` modes five of its rows failed.
- [x] 1.4 Every place the repository writes an executable or uses `eval`
  (`grep` for `chmod +x`, `#!` in `printf`, `eval`) is one of the three above
  or the hook copy kept as it is.
- [x] 1.5 The `cycle` genrule's inline program is
  `tools/ci/fixtures/cycle_probe.js`; every heredoc in `tools/` and `tests/`
  is a declaration or data, with a verdict in the design.

## 2. Gate

- [x] 2.1 Every root builds and tests; scenarios; the staleness contract
  table; pre-commit; `openspec validate --all --strict`.
  - 2026-10-07: root 41/41, `e2e/smoke` 2/2, `e2e/install` 7/7, `tests/bcr`
    1/1, scenarios 39/39, staleness contract table 56/56.
- [x] 2.2 The wiki is regenerated and the staleness gate passes.
- [x] 2.3 A reviewer without this conversation reviews the change; each
  finding checked and recorded.
  - 2026-10-07: no blocker. Should-fixes taken: the verdicts now cover every
    heredoc, and the `cycle` genrule's program, a command held as a string,
    moved into a fixture; why `host_tool.sh` and `poison.sh` stay apart is
    recorded. Nits taken: each `host_tool.sh` names its twin, and
    `yarn_cli_test` requires `.yarnrc.yml` in its project.
