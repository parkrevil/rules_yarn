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
| **Command forwarding** | **three — arguments, streams and exit status are each relied on or lost alone; see below** |
| Working directory | one rule, stated for two cases |
| Self-contained version execution | one |
| Declared support boundary | one |
| Public API surface | one |
| Declared Bazel compatibility | one |
| Repository declaration reporting | one |

### Command forwarding is split too, after the criterion was applied to it properly

This change first argued that `Command forwarding` was one promise — "the
launcher is a transparent conduit" — and kept it whole. A reviewer showed the
argument was unsound, and it was: the other nine verdicts ask whether the
remaining sentence still means something, and this one asked whether the
resulting launcher would be any good. A launcher that swallows the exit status
is a bad launcher, not an incoherent requirement. That is a quality judgement
wearing the criterion's clothes.

Two things follow, and both are recorded rather than quietly dropped:

- Naming a unifying abstraction proves nothing. "The extension's
  declaration-resolution policy" covers `Repository naming` exactly as neatly
  as "a transparent conduit" covers this one. An abstraction is always
  available; it is not evidence.
- The README corroboration was overstated for this requirement. Under
  `yarn_binary`, README lists one bullet per behavior as a features list, so
  the bullet count there tracks prose style rather than obligations. Only the
  heading "Repository naming and version selection" is real outside evidence,
  and it supports the naming split alone.

So `Command forwarding` becomes `Argument forwarding`, `Output stream
passthrough` and `Exit status propagation`.

One scenario had to be reworded, which the other splits did not need.
`Failed command` asserted both the exit status and that the caller receives
Yarn's diagnostic output — it straddled two of the three obligations. Its
output clause is dropped, because `Output stream passthrough` promises exactly
that and its own scenario asserts it. The assertion moves; it does not
disappear. This is the only text in either split that is not carried across
verbatim, and the before-and-after comparison is expected to show it.

### Where the line is drawn, and why it stops here

The criterion decides the two requirements this change acts on. It does not
cleanly decide two others, and saying so is more useful than pretending it
does:

- `Explicit distribution selection` — an exact version and a recorded digest
  are two things a consumer could in principle want separately, yet they are
  one lookup feeding one download, and all three scenarios are angles on "the
  distribution is the one named".
- `Managed runtime` — three mechanisms deliver it, but dropping any one lets
  something other than the selected runtime execute, which is the absence of
  the promise rather than a narrower one.

Both reviewers left these alone and so does this change. The judgement is
residual, not mechanical, and it is written here so a later reader argues with
a stated position rather than guessing at an unstated one.

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
