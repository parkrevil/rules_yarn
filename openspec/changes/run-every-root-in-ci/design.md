## Context

See proposal.md — Why.

## Goals / Non-Goals

Goals:

- What AGENTS.md's gate says and what CI runs are the same list.

Non-Goals:

- Rearranging the workflow. One step is added beside the two already there.

## Decisions

### `--lockfile_mode=off` for the third root

The other two roots set `--lockfile_mode=error` in their own `.bazelrc` and
commit a lockfile that is kept current. `tests/bcr` is meant to have neither,
because the registry presubmit runs it under several Bazel versions and a
lockfile written by one of them fails under another. `--lockfile_mode=off`
says that, and keeps the CI run from writing a lockfile into the checkout.

It is also the right flag for the state the repository is actually in, which
is not the state AGENTS.md describes. `tests/bcr/MODULE.bazel.lock` is
committed — 700 lines, added by `fef0398`, the change that wrote "keeps no
lockfile on purpose" into AGENTS.md. Running Bazel in that directory produced
it and `git add -A` carried it in. `--lockfile_mode=off` ignores it either
way, so this change is correct before and after that is sorted out.

Sorting it out is not this change's job. AGENTS.md says a defect outside the
change gets reported and its own change, so this one reports it and
`remove-the-stray-lockfile` removes it.

### Why this was missed

The gate was rewritten in the same change that created the root it now names.
Nothing compares AGENTS.md's list of roots against the workflow's, so the two
drifted the moment one was edited without the other. That is worth saying out
loud rather than treating the omission as carelessness: the check that would
have caught it does not exist, and this change does not add one — a test that
parses prose out of AGENTS.md to compare against YAML would be more fragile
than the thing it guards.

## Risks / Trade-offs

- [The two lists can drift again] → Deriving one from the other would mean
  parsing a sentence written for people, which is not worth it. Something
  narrower might be — asserting that the build-and-test job has one step per
  root would catch this exact regression without reading prose. It is not
  added here because the cost of the drift it guards is one review comment,
  but the option is real and the argument against parsing AGENTS.md does not
  rule it out.

## Migration Plan

None.
