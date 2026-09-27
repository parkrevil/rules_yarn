## Why

`tools/hooks/protect_generated.sh` enforces AGENTS.md's rule that generated
files are not hand-edited. It is wrong in both directions, and in both of its
layers.

The shell-command layer guesses, from the text of a command, which files that
command will write. That question needs a shell parser, so the layer refuses
reads it should allow:

| command | decision |
| --- | --- |
| `cat openwiki/index.md 2>/dev/null \| head -3` | denied |
| `grep -n Requirement openspec/specs/yarn-execution/spec.md 2>/dev/null` | denied |

and misses writes it should refuse — `d=openwiki; eval "echo x > $d/index.md"`
is allowed. It cannot be made right: the programs that are supposed to write
these paths, `openspec archive` and `openwiki --update`, are shell commands
too, so no rule over command text separates them from a hand-edit.

The path layer was believed exact. It is not. Of the 40 calls in the contract
table this change adds, the guard as committed gets 13 wrong:

| call | decision | should be |
| --- | --- | --- |
| `openwiki/architecture/index.md` | allowed | refused — a generated index page |
| `openwiki/workflows/index.md` | allowed | refused — a generated index page |
| `openspec/specs` | allowed | refused |
| `openwiki/.a-file-openwiki-adds-later.json` | allowed | refused — bookkeeping the hard-coded list does not know about |
| `openwiki/architecture/.a-nested-one.json` | allowed | refused — same |
| `<repo>/./openwiki/architecture/../index.md` | allowed | refused — the same file, spelled differently |
| a symlink reaching a generated file | allowed | refused |
| `/tmp/openwiki/index.md` | refused | allowed — not this repository |
| `/tmp/openspec/specs/spec.md` | refused | allowed — not this repository |
| `<repo>/../openwiki/index.md` | refused | allowed — not this repository |
| a `NotebookEdit` onto `openwiki/.claims/…` | allowed | refused — a generated file written by a tool the guard never sees |
| a payload that does not parse | allowed | refused — the guard cannot clear what it cannot read |
| `jq` missing from `PATH` | allowed | refused — same |

They fall into four causes. Seven come from matching an unanchored substring
of the path as spelled. Two come from the protected files being a hard-coded
list, which goes stale the moment OpenWiki adds a file. One comes from the
matcher: `Write|Edit|Bash` does not select `NotebookEdit`, so a notebook write
to a generated path reaches no guard at all. The last two are the guard
failing open — when it cannot do its job it permits the write, silently,
which is the one thing a guard must not do.

## What Changes

- **BREAKING (for the guard's contract)** Drop the shell-command layer and
  remove `Bash` from the hook's matcher in `.claude/settings.json`. The guard
  covers the tools that author a file directly and says so; a shell command
  that writes a generated file is a review matter, because it is not one a
  hook can decide.
- Match `.*Write|.*Edit` instead of naming tools one by one, so a tool that
  writes a file is covered whether or not someone remembered to list it.
- Replace the substring patterns with a comparison of repository-relative
  paths. The path is resolved first, so `.`, `..` and symlinks name the file
  they actually name, and a path outside the repository is not this
  repository's file.
- Compare the path in both senses — as written and as its symlinks resolve —
  so a path that reaches a generated file from elsewhere and a generated path
  that has been replaced by a symlink are both refused.
- Name the protected files by shape instead of listing them: `openspec/specs/`,
  any dot-named entry under `openwiki/` at any depth, and every `index.md`
  under `openwiki/`. A list goes stale without anyone noticing; these patterns
  are the ownership boundary itself, so a bookkeeping file OpenWiki adds later
  is covered the day it appears. Page bodies stay editable.
- Read the target from `notebook_path` as well as `file_path`, so the guard
  covers every tool its matcher selects.
- Fail closed. A missing `jq` or `realpath`, an unreadable payload, or a path
  that will not resolve is refused with a reason, instead of permitting the
  write.
- Add `tools/hooks/protect_generated_test.sh`: the guard's contract is which
  calls it refuses, so the test is a table of every one of them, of the
  neighbouring paths that must stay editable, of the spellings a path can
  arrive in — including real symlinks, built in a throwaway repository — and
  of the calls it cannot read.

The script holds no regular expression over command text, and answers all 40
rows of the table correctly where the committed one answers 27.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The guard is repository tooling for agents working in this repository.
It does not change what the Yarn rules do or what a consumer observes, so no
requirement in `yarn-execution` changes. `.openspec.yaml` sets
`skip_specs: true`.

## Impact

- `tools/hooks/protect_generated.sh` — rewritten.
- `.claude/settings.json` — the `PreToolUse` matcher becomes `.*Write|.*Edit`.
- New `tools/hooks/protect_generated_test.sh`.
- No Bazel target, no public API, and no pin is affected.
