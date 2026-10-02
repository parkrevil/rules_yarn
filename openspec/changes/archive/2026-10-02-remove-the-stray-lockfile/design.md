## Context

See proposal.md — Why.

## Goals / Non-Goals

Goals:

- The repository matches what AGENTS.md says about it.
- The file cannot come back by accident.

Non-Goals:

- Changing what the registry test module does.

## Decisions

### Configure the module, do not ignore the file

`.gitignore` would stop the lockfile being committed again and leave Bazel
writing it on every build — an untracked file that reappears, which is the
kind of thing people learn to ignore and then stop seeing. A `.bazelrc` in
that module stops it being written at all, and puts the decision where the
other two roots keep theirs.

Checked rather than assumed: with the `.bazelrc` in place, deleting the
lockfile and running `bazel build //...` in `tests/bcr` leaves no lockfile
behind, and the test still passes.

### CI stops passing the flag

The step added in the previous change passed `--lockfile_mode=off` explicitly
because nothing else said it. The module now does, so the step runs the same
command as the other two roots. One place states the mode, which is the point
of moving it there.

## Risks / Trade-offs

- [A future contributor wanting a lockfile here will find it silently
  refused] → The `.bazelrc` says why in the file itself, including what went
  wrong without it.

## Migration Plan

None.
