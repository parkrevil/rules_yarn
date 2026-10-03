---
type: workflow
title: Development workflow
description: The rules a change must satisfy, the OpenSpec planning cycle, and the automation that enforces each — pre-commit, the editor guard, the wiki staleness gate, and CI.
tags: [workflow, agents, openspec, pre-commit, hooks, ci]
sources:
  - id: openwiki-source-1fe463fcf07912e5cdbb5a91
    resource: repo://.claude/settings.json
  - id: openwiki-source-164e2da859b5277df81c7d94
    resource: repo://.github/workflows/ci.yml
  - id: openwiki-source-4d1645cb6317345817452838
    resource: repo://.pre-commit-config.yaml
  - id: openwiki-source-8037e2358a2c4f9b2c722a11
    resource: repo://AGENTS.md
  - id: openwiki-source-a2371d6362e5db4bc834ad03
    resource: repo://CLAUDE.md
  - id: openwiki-source-38af7bdd34d817fbd3c29077
    resource: repo://openspec/config.yaml
  - id: openwiki-source-f62aa9ed7021af1727946d31
    resource: repo://tools/hooks/openwiki_staleness_test.sh
  - id: openwiki-source-c1d011fc51fb7948e3fbbd2e
    resource: repo://tools/hooks/openwiki_staleness.sh
  - id: openwiki-source-c344118095552b0e155044aa
    resource: repo://tools/hooks/protect_generated_test.sh
  - id: openwiki-source-1182253f19cc7fc5a1a4410d
    resource: repo://tools/hooks/protect_generated.sh
generated: { by: "claude-code", at: "2026-10-03T09:26:35.806Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-03T09:50:46.826Z
---

# Development workflow

The repository states its working rules in one file and enforces most of them
with tooling. Knowing which rules a machine checks and which rest on the author
is part of working here.

## The instruction contract

`AGENTS.md` is the single instruction file; `CLAUDE.md` only includes it. It is
organized by when a rule applies rather than by topic: rules that always hold,
rules before writing code, rules when changing a pinned version, and rules
before committing.

What is always true: behaviour is claimed from a test or a recorded run; every
external artifact is fetched by exact version with a digest; an API is checked
against the defining ruleset at the pinned version and cited; a missing release
or API is reported rather than worked around; the launcher template is the only
generated script; generated directories are not hand-edited.

Before committing, five things: the build-and-test gate across all three roots;
a reviewer who was not in the implementation conversation, **including for a
commit that changes `AGENTS.md` itself**; fixing what the change is for instead
of recording it as a known limit; applying a rule the change states to
everything that change touches, with a verdict recorded for each — including
what is left alone; and regenerating the wiki when the change touches anything
the claims cite.

Four of the five were added after they were broken. The reviewer clause names
itself because a commit to this file went in without one, on the argument that
the file was not code.

## Planning

Changes are planned in OpenSpec before code. The project is configured with the
`spec-driven` schema, whose artifacts are a proposal, delta specs, an optional
design document, and a task list; archiving a completed change is what writes
`openspec/specs/`, which is therefore never hand-edited. One change, one branch
named after it.

The configuration deliberately keeps no copy of the engineering constraints: it
points at `AGENTS.md` and says not to restate them, so there is one place a
rule can be wrong.

## Pre-commit

`pre-commit` installs under three hook types, which it declares itself, so a
plain `pre-commit install` wires all of them:

| Stage | What runs |
| --- | --- |
| `pre-commit` | file hygiene, buildifier and its linter, `openspec validate --all --strict` when `openspec/` changed |
| `commit-msg` | `commitizen`, enforcing Conventional Commits |
| `pre-push` | the wiki staleness gate |

The `pre-push` stage is why `pre-commit run --all-files` does not run that
gate: `--all-files` runs the `pre-commit` stage, so CI invokes the script
itself after the hooks.

File hygiene is the `pre-commit-hooks` set: shebang and executable-bit
consistency, TOML and YAML parsing, private-key detection, end-of-file and
trailing-whitespace fixes.

## The editor guard

One hook runs inside the agent's tool loop rather than at commit time. It
matches the tools that write a file directly, and nothing else.

It refuses writes to files a generator owns — OpenWiki's bookkeeping and every
generated index page, and anything under `openspec/specs/` — pointing the
writer at `openwiki --update` or at the change's own delta spec instead. Page
bodies under `openwiki/` stay writable, because the agent authors those during
a run.

Two decisions give it its shape.

It does not look at shell commands. Deciding which files a command writes means
parsing a shell, and the programs that are *supposed* to write these paths are
shell commands themselves, so any rule over command text refuses legitimate
runs and still misses a write behind a variable. `AGENTS.md` states the rule;
review enforces it where a hook cannot decide it. An earlier version did try,
with a growing set of patterns per writer program, and a path reached through a
variable still got through.

It fails closed. A payload it cannot parse, a tool it needs that is absent, a
path it cannot resolve — each is a refusal, not a pass, because a guard that
answers nothing is a guard that permits. The one refusal it has to phrase
without `jq` is hand-written JSON.

Paths are judged by what they name rather than how they are spelled: every path
is resolved twice, following symlinks and not following them, and either
spelling landing on a generated file is enough. Bookkeeping is recognised by
shape — a dot-named entry at any depth — so a file OpenWiki adds later is
covered without the guard being edited.

`tools/hooks/protect_generated_test.sh` is the guard's contract written out as
a table: forty rows naming every generated path, the neighbouring paths that
must stay editable, the spellings a path can arrive in, two symlink
constructions built in a throwaway repository, and the payloads the guard has
to answer without a usable path. It is a plain script, not a Bazel target, and
CI runs it.

## The wiki staleness gate

The wiki is generated, so it goes stale rather than wrong, and rebuilding it
needs an agent driving OpenWiki — a shell hook cannot have a model. So the gate
reports and refuses instead of fixing.

It does not guess which files matter, and it does not reason about commits.
Every claim records the exact bytes it was written from: `openwiki/.claims`
names each source as `repo://<path>` or `repo://<path>#L<first>-L<last>` and
stores a digest beside it — of the whole file, or of the cited line range. The
gate recomputes each one from the working tree. A source whose bytes no longer
hash to what the page recorded is a source the page may now describe wrongly.
A run over the whole wiki takes about half a second.

Three lists come back: sources that changed, sources that no longer exist, and
records the gate could not check as written. The third is the one that took the
most care, because a gate's worst outcome is clearing something it never
checked. The work is split so that each half can be held to that. jq reads each
sidecar whole — so a second JSON document cannot hide behind the first — and
turns every piece of repository evidence into a row it has already validated,
or stops and names the sidecar: the digest has to name an algorithm the script
computes and be 64 hexadecimal characters; a line digest has to carry a line
range and a file digest must not; line numbers are at most nine digits with no
leading zero, so the shell is never handed a number it cannot compare; the path
may not start with `/` or climb with `..`. The shell only touches files. It
checks that each cited file is a regular file whose directory resolves inside
the repository, counts its lines, hashes it, and status-checks every command
whose failure could pass for success. At the end it compares the rows it
handled with the rows jq produced, so a read that stopped early is a refusal
rather than a shorter list.

`tools/hooks/openwiki_staleness_test.sh` is that contract as a table of
fifty-six rows, each built in a throwaway repository laid out like this one.
A row counts only when the gate exits with exactly 0 or exactly 1, and a
refusal only when its message names what the row is about; seven rows inject a
failure into a command the gate depends on, after the command has done its
work. Three independent reviews shaped it. Each found records the gate of the
time cleared without checking — a `sha512` label beside a SHA-256 digest, a
line range past the end of the file, an empty sidecar beside a readable one,
then line numbers too long to compare and a sidecar holding two JSON documents,
then a path beginning with `-` that `dirname` read as an option, letting a file
behind a symlink outside the repository through —
and each of those is a row that was watched failing against the version it was
found in before the gate was rewritten.

The commit-based alternative was written first and discarded, for two reasons
that were measured rather than argued. CI checks the repository out without
asking for history, so no commit but `HEAD` is present and a diff against a
recorded earlier one fails outright. And a run reads the *working tree*, which
normally holds the very changes being described, so committing the wiki
alongside the change it describes — the workflow this file asks for — would
trip the gate on its own commit every time. The digest comparison asks when
nothing happened, and needs no git at all.

It is strict about bytes at the cited lines, so inserting a line above a
citation makes that citation report. That is not noise: the citation now points
at the wrong lines, and a reader following it lands somewhere else. A run fixes
it by re-anchoring the claim. The gate's first run found fifteen such citations
across seven pages that OpenWiki's own incremental check had let through — one
of them a claim about development-only dependencies pointing at a range that,
since `version` and `bazel_compatibility` were added, had come to span a comment
and the `module()` block.

It runs at `pre-push` rather than `pre-commit` because a stale wiki is a
property of what is being published, not of each commit along the way.
`SKIP=openwiki-staleness git push` is the way past it, which the message says,
so bypassing is a stated decision rather than a quiet one.

`AGENTS.md` carries the matching obligation in `## Before commit`: regenerate
the wiki when the change touches anything the claims cite, and commit it with
the change. That rule also carries its own correction, because the `## OpenWiki`
section below it still names a scheduled workflow as what refreshes the wiki —
a paragraph inside the marker block OpenWiki owns and restores on every run, so
the repository cannot hold an edit to it.

## CI

`.github/workflows/ci.yml` runs on every push and pull request, with read-only
permissions, in three jobs.

**build and test** runs the gate `AGENTS.md` asks for — all three roots, each
in its own invocation because `.bazelignore` keeps two of them out of the root
run — on `ubuntu-latest` and `macos-latest`, with `fail-fast` off so one
platform's failure does not hide the other's result. Both runner images ship
Bazelisk as `bazel`, so each root's `.bazelversion` decides the version and no
setup action is needed.

**oldest supported Bazel** builds a throwaway consumer at the floor
`MODULE.bazel` declares. The repository's own roots cannot check this: their
lockfiles are written by a newer Bazel and both set `--lockfile_mode=error`.

**checks** runs the pre-commit hooks over all files, both hooks' contract
tables, and the staleness gate itself.

The Linux job also carries a measurement step, left in after it answered its
question: the first CI run used `processwrapper-sandbox` rather than
`linux-sandbox`, so the `block-network` tag was not honoured and the offline
test could not show what it exists to show, and nothing in the log said why. It
reports the relevant sysctls and whether `unshare -Ur` works, before and after
clearing `kernel.apparmor_restrict_unprivileged_userns`, and the clearing stays
in effect for the build steps below it on the same runner.

This is also the layer that found the two defects local runs could not: a
GNU-only `find` flag that this machine's `find` happens to implement, and the
sandbox fallback. Neither was reachable from one developer's machine.

## What is still not enforced

Three rules have no mechanical backing, and all three are about the order and
provenance of work rather than its result: that an API was checked against
pinned-version documentation and cited, that the spec-scenario test was written
before the implementation and watched to fail, and that an independent reviewer
saw the change. A machine can see the citation but not that it was read, the
test but not when it was written, the commit but not who reviewed it. These
depend on the author.
