## Context

See proposal.md — Why. Two defects, one measurement, and two corrections to
how this work has been recorded.

## Goals / Non-Goals

Goals:

- CI fails only where something is actually wrong, and where it fails it says
  what.
- No check is weakened to make a job green.

Non-Goals:

- Guessing why the Linux runner does not give Bazel `linux-sandbox`. This
  change measures it; the next one acts on the measurement.

## Decisions

### The offline assertion becomes its own target

`yarn_cli_test` asserted four things, only one of which needs the network
taken away: that `--version` works without it. The other three — the host
tools being unusable, `yarnPath` being ignored, an invalid command's status
and diagnostic — hold whether or not the sandbox blocks anything. Bundling
them meant one unavailable capability took down three unrelated checks.

So the network assertion and the offline `--version` check move into
`yarn_offline_test`, tagged `block-network`, in both roots. This is the split
the specification already draws: `Self-contained version execution` is its own
requirement, and now its own target.

The alternative — making the assertion conditional, so the test passes when
the sandbox does not block — was rejected. A test that reports success after
failing to test anything is worse than a red one. Where the sandbox does not
block, `yarn_offline_test` fails and says the environment cannot show what it
exists to show.

### The sandbox question is measured, not guessed

The first run used `processwrapper-sandbox` for every action on Linux and
`darwin-sandbox` on macOS. The Linux log carries no warning explaining the
fallback, and searching the Bazel and runner-images issue trackers returned
nothing. Any fix written now would be a guess.

The added CI step reports the two user-namespace sysctls and whether the
runner can create a user namespace at all, then addresses one plausible cause
and reports the same facts again, then asks Bazel directly for
`linux-sandbox` and prints what it says. Whatever the outcome, the log
explains it: if the cause was the one addressed, the before-and-after pair
shows it; if not, Bazel's own refusal message is there.

### Why `find -printf` survived a local gate

`launcher_test.sh` built its manifest with `find -printf '%P\n'`, a GNU
extension. It passed locally because this machine's `find` is `bfs`, which
implements it, and on the first CI run macOS refused it. The replacement,
`find -print | sed 's|^\./||'`, produces the same lines; that was checked
against both forms on a fixture tree before the change.

The general lesson is recorded rather than the specific one: a local gate
tests one machine's tools, and portability is not among the things it can
show.

### The AGENTS.md rules are scoped and moved

As written they said "Fix what you find" and "apply a rule you state to
everything it covers". Neither had a boundary. Read literally the first pulls
unrelated defects into the current branch, against `## Before code`'s "One
change, one branch named after it", and the second demands an unbounded audit
that no commit in this repository has ever performed — an instruction that
cannot be followed is one that will be ignored, or satisfied on paper.

They now speak of the change at hand: fix what the change is for, report a
defect outside it, and apply a stated rule to everything that change touches.
They also move to `## Before commit`, which already owns how findings are
handled; `## Always` holds invariants about the delivered artifact.

## Risks / Trade-offs

- [CI stays red on Linux after this change] → The red is a real unverified
  requirement, not noise, and it is confined to the one target that proves it.
  The measurement that clears it ships in the same push.
- [Two roots now carry a near-identical offline test] → They test different
  things: one the launcher this repository builds, the other the launcher a
  consumer builds from the public API. The duplication already existed for
  the version check.

## Migration Plan

None.
