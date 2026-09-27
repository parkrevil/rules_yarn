## Context

See proposal.md — Why. The guard answers one question: may this tool call
write this file? Where the caller hands over a path, that is a comparison.
Where the caller hands over a shell command, it is a prediction, and a
prediction about a shell needs a shell parser.

The two layers of the committed guard treat those as the same problem and
approach both with regular expressions over text. That is why both are wrong.

## Goals / Non-Goals

Goals:

- Every decision the guard makes is a fact about a path, not a guess about a
  program.
- The set of generated files is stated once, completely, and is what the test
  checks.
- The guard's contract is narrow enough to be true, and written down where
  someone would otherwise widen it back.

Non-Goals:

- Stopping a shell command from writing a generated file. See the decision
  below.
- Access control. The guard steers an agent that is trying to do the right
  thing; it is not a defence against one that is not, and it never was — the
  committed version is bypassed by `eval`.

## Decisions

### Enforce at the boundary where the decision is exact, and only there

`Write` and `Edit` carry the path they will write. Whether that path is
generated is a comparison with a fixed set, and the answer is always right.
This is the whole guard.

`Bash` carries a command. Deciding which files it writes is undecidable from
the text, and the legitimate writers of these paths — `openspec archive`,
`openwiki --update` — arrive through exactly that tool, so even a perfect
parser would still need to tell a generator run from a hand-edit. The layer is
removed rather than narrowed.

What this gives up is stated plainly: `sed -i` over `openspec/specs/` is no
longer refused. What it gives up is smaller than it looks, because the
committed layer does not refuse the same write behind a variable either, and
an agent that means to edit a file uses `Write` or `Edit`.

Alternatives considered:

- *Keep the layer and fix the patterns.* Rejected. One replacement expression
  drew four defects across three review passes — a delimiter collision that
  disabled the layer, a per-command sink rule that opened a bypass, two sink
  shapes with no coverage, and a separator class missing `<`. Each fix
  exposed the next edge. The cost is unbounded because the problem is
  undecidable.
- *Detect after the fact: hash the generated files before and after each Bash
  call and report a change.* Exact, and tempting. Rejected because it cannot
  tell a legitimate `openspec archive` from a hand-edit either, so it would
  either refuse the archive or need the same guessing over command text to
  excuse it. It trades an unsound rule for a noisy one.
- *Enforce at commit instead, in pre-commit.* Rejected as a replacement: a
  legitimate local commit does touch `openspec/specs/` — the commit before
  this change is one — so a commit-time rule needs the same discriminator and
  has the same problem. `openspec validate --all --strict` already runs there
  and checks what is checkable.

### Compare resolved, repository-relative paths

The committed guard greps the raw path for a substring, so it answers about a
spelling rather than a file. The replacement makes the path absolute, resolves
it with `realpath -m` — which needs no existing file — and expresses it
relative to the repository root, computed from the script's own location.
A result starting with `..` is outside the repository and is left alone.

`case` patterns over that relative path replace the regular expressions. In a
`case` pattern `*` spans `/`, so `openwiki/*/index.md` is every index page at
every depth, which is what the committed `openwiki/index.md` alternative was
meant to say and did not.

### Refuse when the guard cannot decide

The committed guard permits the write whenever anything goes wrong: `jq`
missing, a payload that does not parse, a tool whose target is not in
`file_path`. It disappears exactly when it is least able to notice that it
has. A guard whose only action is refusal has to fail closed, so each of
those now produces a refusal naming the cause.

The line is between *no answer* and *the answer is no*: a payload that parsed
and names no file is permitted, because the call is then not a write to a
file at all.

### Match tools by shape, not by name

A hook matcher is not a substring search. Measured by running the same
`NotebookEdit` onto a generated path under each matcher in turn:

| matcher | result |
| --- | --- |
| `Write\|Edit` | the write **succeeded** — no guard ran |
| `Write\|Edit\|NotebookEdit` | refused |
| `.*Write\|.*Edit` | refused |

So the committed `Write|Edit|Bash` never selected `NotebookEdit`, and a
notebook write to `openwiki/.claims/` reached nothing. A tool the matcher
misses is a hole the guard cannot report, because it is not running — the
same silent failure as failing open, one layer further out.

Naming the tools explicitly would close today's hole and leave the class
open. `.*Write|.*Edit` closes the class: any tool whose name ends in `Write`
or `Edit` is covered. Over-matching costs nothing, because a call carrying no
path is permitted anyway.

`notebook_path` is read alongside `file_path` for the same reason: the guard
should read whichever field names the target rather than assume one.

### The protected set is what OpenWiki and OpenSpec actually own

- `openspec/specs/` — written by `openspec archive`.
- `openwiki/.claims/`, `.run.json`, `.page-manifest.json`, `.last-update.json`
  — OpenWiki's bookkeeping.
- every `openwiki/**/index.md` — generated listings; none appears in
  `openwiki/.page-manifest.json`, which is OpenWiki's own record of the pages
  an agent writes during a run.
- Everything else under `openwiki/`, including the seven page bodies in that
  manifest, stays editable, because a run writes them through these tools.

### The test is the contract

The guard's behaviour is a finite table of calls, so the test is that table
rather than a sample of it: every protected path, the neighbouring paths that
must stay editable — a change's own delta spec most of all — the spellings a
path can arrive in, including absolute, unnormalised, and outside the
repository, and the calls the guard cannot read, which it has to refuse.

The missing-`jq` row runs the guard against a `PATH` holding only the other
tools it needs, so the fail-closed behaviour is exercised rather than
asserted.

It is a plain script because the hook is harness tooling, not part of the
build: it has no Bazel target and it needs `jq`, which the build does not.
Adding it to a gate belongs to the change that adds CI.

## Risks / Trade-offs

- [A shell command can now write a generated file without being refused] →
  Accepted and documented in the script's header, so the next reader does not
  rebuild the heuristic. AGENTS.md states the rule and review enforces it.
  The committed layer did not close this either.
- [`realpath` is GNU coreutils] → Already required in practice: the repository
  is Linux x86_64 only, and the guard already depends on `jq`.
- [A new generated file could be added without being added to the set] → The
  set and the test sit next to each other in the same directory, and a missing
  entry is a missing row.

## Migration Plan

None. The harness reads `.claude/settings.json` and the script per tool call,
so the next call uses the new guard. Rollback is reverting the commit.
