## Context

See proposal.md — Why. The obligations and their scenarios already exist and
are already satisfied by committed code; only their grouping changes.

## Goals / Non-Goals

Goals:

- One requirement states one obligation.
- Not a scenario is lost, added or reworded in the move.

Non-Goals:

- Changing behavior, code, or tests. If this change alters what the ruleset
  does, it is wrong.

## Decisions

### Three requirements, along the lines the scenarios already draw

The scenarios partition cleanly, which is the sign the obligations were
separate all along:

| requirement | scenarios |
| --- | --- |
| Public API surface | Independent consumer, Private implementation file |
| Declared Bazel compatibility | Bazel older than the declared minimum, Bazel at the declared minimum |
| Repository declaration reporting | Repository declaration left out |

Alternative considered: leave it and treat the length report as noise.
Rejected — the report is a symptom, and the cost of the grouping is not the
character count. Three obligations under one name cannot be changed or
dropped one at a time, and a reader cannot tell which scenario tests which
promise.

### Expressed as a removal and three additions, because OpenSpec refuses a move

Two shapes were tried first and rejected by `openspec validate`, each for a
good reason:

- `MODIFIED` on the old requirement, keeping only its own two scenarios:
  *"MODIFIED ... omits scenario(s) the current spec still has ... a MODIFIED
  requirement replaces the whole block, so archive refuses to drop them."*
  The guard is right — silently dropping a scenario deletes a promise — and
  it means `MODIFIED` cannot express a scenario moving elsewhere.
- Removing the requirement and adding it back under the same name:
  *"Requirement present in both ADDED and REMOVED."*

So the requirement is removed, with the reason and what replaces it recorded
in the delta, and three requirements are added. The first is named
`Public API surface`, not the old name, which the same rule requires — and
which is the better name anyway, since that is what its two scenarios test.

### Moved verbatim

Each sentence and each scenario is carried across unchanged, so the diff on
the main spec is a regrouping and nothing else. That is checked rather than
intended: the requirement and scenario text before and after are compared.

## Risks / Trade-offs

- [Archiving a delta rewrites the main spec, so a mistake here silently
  changes the contract] → The scenario set and the requirement sentences are
  compared before and after the archive, not just eyeballed.

## Migration Plan

None.
