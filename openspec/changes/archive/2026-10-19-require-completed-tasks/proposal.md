## Why

Nothing stops a change from being archived with tasks still unchecked, and
three were: `apply-one-obligation-per-requirement` (task 2.2, the check that
the regrouping lost nothing), `automate-verification-gate` (3.2, recording the
first macOS run) and `publish-to-the-registry` (7.1 and 7.2, the publish token
and the first tag). `openspec validate --archived` fails on exactly that
(`Totals: 14 passed, 3 failed`, exit 1). OpenSpec documents it for this use:
"it verifies that every change under `changes/archive/` has all of its
`tasks.md` checkboxes ticked, exiting non-zero if any are unchecked. This
catches changes that were archived with unfinished work — handy in a
pre-commit hook" (`docs/cli.md` at v1.13.0).

## What Changes

- A pre-commit hook runs `openspec validate --archived --no-interactive` when
  `openspec/` changes; CI runs every hook over all files, so it gates there too.
- The four unchecked tasks are settled with what shows each was done, recorded
  in their own archived task lists: the regrouping compared again now, the
  first macOS run and its fix found in history, and the publish token and the
  first release recorded by `automate-releases`.

No behaviour of the ruleset changes, so no spec changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

`.pre-commit-config.yaml`, three archived task lists, and the wiki page that
lists the hooks.

## Correction, 2026-10-20

From an adversarial review, recorded in `correct-the-completion-gate-records`:

- "Nothing stops a change from being archived with tasks still unchecked" is
  wrong: `openspec archive` asks before archiving incomplete tasks, and only a
  confirmation or `--yes` gets past it. What was missing was a check after the
  fact, which is what the hook adds.
- The hook checks archived changes only. An active change with unchecked
  tasks, a finished change left unarchived, a change deleted instead of
  archived, a task written without checkbox syntax and a box ticked without
  the work all pass it; and since `main` is not protected, a failing CI run
  does not block a push. The commit title "할 일이 남은 변경은 마무리할 수
  없게 막는다" claims more than this.
- Of the four tasks it settled, one (2.2) was done at the time and only left
  unticked; two (7.1 and 7.2) were handed off by design in section 7 of
  `publish-to-the-registry` and done after that change was archived; and one
  (3.2) had been left unticked on purpose by `close-the-verification-gate`
  4.1. The corrections are under each task.
- An archived change with no `tasks.md` also passes the hook.
