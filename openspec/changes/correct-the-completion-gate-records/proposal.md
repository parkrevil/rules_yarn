## Why

An adversarial review of `require-completed-tasks` (2026-10-20) found records
it wrote that are wrong or that silently overrule earlier ones: the tick on
`automate-verification-gate` 3.2 reverses `close-the-verification-gate` 4.1's
recorded decision without saying so; "done late" on
`apply-one-obligation-per-requirement` 2.2 is false, the work having been done
at archive time; the email decision is dated 2026-10-08 though the publishing
wiki page has recorded it since 2026-10-05; its proposal and commit title
overstate what the hook stops; its task 1.2 names no verification; its gate
2.1 was ticked after the commit it gates.

## What Changes

- A dated correction is appended under each wrong line, and a correction
  section to `require-completed-tasks`' proposal, design and tasks. Nothing
  already recorded is rewritten or removed: an archive records what happened,
  including the mistakes.
- `close-the-verification-gate` 4.1 and 4.2, whose decisions the ticks
  overrode, get a dated line pointing to the corrections.
- The comment over CI's pre-commit step names the hooks it now covers.
- The workflow wiki page states the gaps around the checks: `main` is not
  protected, and the archived-tasks hook does not see active, unarchived,
  deleted or task-less changes, non-checkbox tasks, or unticked work.

No behaviour of the ruleset changes, so no spec changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

Four archived changes' records, `close-the-verification-gate`'s task list, one
comment in `.github/workflows/ci.yml`, and `openwiki/workflows/development-workflow.md`.
