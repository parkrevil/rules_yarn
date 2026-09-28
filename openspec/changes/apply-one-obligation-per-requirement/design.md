## Context

See proposal.md — Why. This change exists because the previous one applied its
principle only where a linter had pointed.

## Goals / Non-Goals

Goals:

- Every requirement in `yarn-execution` is judged once, against a written
  criterion, and the judgement is recorded — including the ones left alone.
- Nothing is reworded or lost in the regrouping.

Non-Goals:

- Splitting a requirement into one requirement per scenario. That trades one
  bad shape for another.

## Decisions

### The criterion

A requirement holds one obligation when withdrawing any part of it would leave
the rest incoherent. Two promises that can each stand without the other are
two requirements, whatever their combined length.

Length is not the criterion. `openspec validate` reports a requirement over
500 characters, which is a useful smell and nothing more. Measured against
this spec: no requirement reaches 300 characters, the longest being `Managed
runtime` at 284, so the report is silent across the whole file — and it is
silent over the bundle this change fixes, at 230. It spoke once, about the
requirement the previous change split, and only after that requirement had
already been made long by piling a third obligation onto it. A report that
fires after the mistake is made is not a way of finding the mistake.

### Every requirement, judged

| requirement | verdict |
| --- | --- |
| Explicit distribution selection | one — drop the digest and "identified exactly" is gone |
| **Repository naming** | **two — naming authority and version arbitration each stand alone** |
| Managed runtime | one — drop the `yarnPath` rule and "the selected distribution runs" breaks |
| Command forwarding | one — see below |
| Working directory | one rule, stated for two cases |
| Self-contained version execution | one |
| Declared support boundary | one |
| Public API surface | one |
| Declared Bazel compatibility | one |
| Repository declaration reporting | one |

### Command forwarding stays as it is, against the review

The reviewer read `Command forwarding` as three obligations — argument
boundaries, output streams, exit status — one per scenario, and called
leaving it a should-fix. Applying the criterion says otherwise: the promise is
that the launcher is a transparent conduit, and a launcher that preserved
argument boundaries while swallowing the exit status would not be a weaker
version of that promise, it would be a broken one. None of the three stands
without the others.

README corroborates the reading from outside the spec. It describes command
forwarding in a single bullet — "passes arguments through without shell
re-interpretation and preserves Yarn's output streams and exit status" — while
giving repository naming a heading that names two things, "Repository naming
and version selection", and a bullet each.

Counted scenarios are not the test. `Command forwarding` has three scenarios
because one promise needs three angles to pin it down.

### Same delta shape as before, for the same reason

`MODIFIED` cannot express a scenario moving to another requirement: it
replaces the whole block and archive refuses to drop a scenario. A same-name
`REMOVED` plus `ADDED` is rejected outright, and `RENAMED` followed by a
`MODIFIED` is refused with the same omits-scenarios error — all three were
measured while splitting the previous requirement. So the requirement is
removed and two are added, with the reason and the replacements recorded in
the delta.

## Risks / Trade-offs

- [Archiving rewrites the main spec, so a mistake silently changes the
  contract] → The scenario set and the requirement sentences are compared
  before and after, as they were for the previous split.
- [The criterion is a judgement, and a later reader may draw the line
  elsewhere] → It is written down here with every verdict, including the one
  taken against a reviewer, so a later reader argues with a stated rule
  rather than guessing at an unstated one.

## Migration Plan

None.
