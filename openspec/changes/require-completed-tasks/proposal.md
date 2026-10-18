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
