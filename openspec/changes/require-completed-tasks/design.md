## Context

The repository validates OpenSpec changes and specs with `openspec validate
--all --strict` in pre-commit, which checks structure, not whether a change's
tasks were done. `openspec archive` asks before archiving incomplete tasks and
goes ahead on confirmation, so an archived change can carry unchecked work.

## Decisions

**The documented check, as its own hook.** `openspec validate --archived` is
"its own scope: it does not validate spec deltas ... it verifies that every
change under `changes/archive/` has all of its `tasks.md` checkboxes ticked"
(`docs/cli.md`, OpenSpec v1.13.0), so it runs as a second hook beside the
existing one rather than as a flag on it. It runs on changes under
`openspec/`, as the existing hook does; CI's `pre-commit run --all-files`
runs it on every push.

**Settle the four tasks with evidence, not by ticking them.** Each is checked
only with what shows it was done, dated, in its own task list:
- `apply-one-obligation-per-requirement` 2.2: the main spec before and after
  its archive commit (`3b59a99`) compared now — 22 scenarios before and after
  with the same titles; one requirement sentence split into three with the
  same obligations; one scenario's output clause gone, the one `design.md`
  records as moved to `Output stream passthrough`, whose scenario asserts it.
- `automate-verification-gate` 3.2: the first CI run (36726763532) failed on
  macOS with `find: -printf: unknown primary or operator` in `launcher_test`;
  commit `c0bba48` replaced it with a portable form.
- `publish-to-the-registry` 7.1 and 7.2: `BCR_PUBLISH_TOKEN` set on
  2026-10-08 and `v0.1.0` released by run 37760533408, both recorded in
  `automate-releases`.

## Risks / Trade-offs

- A ticked box is still a claim: the hook proves only that no task was left
  open, not that each was done well; the evidence lines under each task, and
  the review of every change, are what show that.
