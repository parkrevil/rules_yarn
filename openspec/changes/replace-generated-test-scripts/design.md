## Context

The three tests need executables that behave in a fixed way: a host tool that
records it ran and fails, a program Yarn would run if it honoured `yarnPath`,
and a tool that does its real work and then fails at one chosen moment.

## Decisions

**Checked-in files, copied.** Each stand-in is a file in the repository,
reached through the runfiles (`$(rlocationpath ...)`) by the Bazel tests and
beside the script by the staleness test, which CI runs directly. A copy keeps
the source's mode, so nothing is made executable at run time. `e2e/smoke` is
a module of its own, so it holds its own copy of `host_tool.sh`.

**Named modes instead of code.** The staleness test's four conditions —
always, the second run, awk counting the collected rows, awk given anything
else — become `FAIL_WHEN` values the fixture's `case` knows; an unknown value
fails loudly. The wrapper reads `REAL_TOOL` and `FAIL_WHEN` from the
environment the test sets for the gate it runs.

**What stays.** `openwiki_staleness_test.sh` copies the gate under test into a
throwaway repository and restores its execute bit: a copy of a checked-in
script, not a generated one. The data files tests write — `package.json`,
`.yarnrc.yml`, pin and lock files in `install_scenarios.sh` and the staleness
test's subjects and sidecars — are not programs; nor are the `MODULE.bazel`
and `BUILD.bazel` files `install_scenarios.sh` and `minimum_bazel.sh` write
for their throwaway consumers, which only declare targets. The one exception
there was the `cycle` genrule `install_scenarios.sh` appends, whose `cmd` held
a whole Node.js program as a string: that program is now
`tools/ci/fixtures/cycle_probe.js`, copied in beside the BUILD file, and the
`cmd` only names it. The fixtures already checked in under
`tools/ci/fixtures/` stay as they are.

## Risks / Trade-offs

`host_tool.sh` exists twice, once per module, each naming its twin. It stays
apart from `tools/ci/fixtures/poison.sh`, which also exits 97: the launcher
tests assert that a host tool never ran, so their stand-in records each run,
while the install scenarios only need a host tool that would make the
install fail, and `poison.sh` lives outside both test modules.
