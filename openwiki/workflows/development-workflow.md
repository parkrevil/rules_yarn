---
type: workflow
title: Development workflow
description: The working rules for changing this repository and the automation that enforces them — the agent instruction contract, OpenSpec planning, pre-commit checks, and the editor hooks that protect generated files and validate the OKF bundle.
tags: [workflow, agents, openspec, pre-commit, hooks]
sources:
  - id: openwiki-source-1fe463fcf07912e5cdbb5a91
    resource: repo://.claude/settings.json
  - id: openwiki-source-6d4b4e707b8d60b6ccfa3425
    resource: repo://.github/workflows/openwiki-update.yml
  - id: openwiki-source-4d1645cb6317345817452838
    resource: repo://.pre-commit-config.yaml
  - id: openwiki-source-8037e2358a2c4f9b2c722a11
    resource: repo://AGENTS.md
  - id: openwiki-source-a2371d6362e5db4bc834ad03
    resource: repo://CLAUDE.md
  - id: openwiki-source-38af7bdd34d817fbd3c29077
    resource: repo://openspec/config.yaml
  - id: openwiki-source-0cb44237da6bccd0ec35f61a
    resource: repo://tools/hooks/okf_conformance.sh
  - id: openwiki-source-1182253f19cc7fc5a1a4410d
    resource: repo://tools/hooks/protect_generated.sh
  - id: openwiki-source-6db3ba043defd51913cc9c45
    resource: repo://tools/okf/validate.sh
generated: { by: "claude-code", at: "2026-09-21T15:40:20.833Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-09-21T15:40:20.833Z
---

# Development workflow

The repository states its working rules in one file and enforces a subset of
them with tooling. Knowing which rules are enforced and which are not is part of
working here.

## The instruction contract

`AGENTS.md` is the single instruction file; `CLAUDE.md` only includes it. It is
organized by when a rule applies rather than by topic: rules that always hold,
rules before writing code, rules when changing a pinned version, and rules
before committing.

Its substantive content is the hermeticity invariant, the requirement to check
an API against the defining ruleset at the pinned version and cite it, the
instruction to stop and report rather than ship a consumer-visible workaround,
the constraint on generated shell, the list of pinned files, and the two-root
build-and-test gate.

## Planning

Changes are planned in OpenSpec before code. The project is configured with the
`spec-driven` schema, whose artifacts are a proposal, delta specs, an optional
design document, and a task list; archiving a completed change is what writes
`openspec/specs/`, which is therefore never hand-edited.

## Pre-commit

`pre-commit` runs three groups of checks at commit time:

- general hygiene from `pre-commit-hooks` — shebang and executable-bit
  consistency, TOML and YAML parsing, private-key detection, end-of-file and
  trailing-whitespace fixes;
- `buildifier` and its linter over Bazel files;
- two local checks, each scoped by path: the OKF bundle validator when `.okf/`
  changes, and `openspec validate --all --strict` when `openspec/` changes.

`commitizen` runs at the `commit-msg` stage and enforces the Conventional
Commits structure. The configuration declares both hook types it needs to be
installed under, so a plain `pre-commit install` wires the commit-message check
as well as the pre-commit one.

## Editor hooks

Two hooks run inside the agent's tool loop rather than at commit time, and both
match write-capable tools including shell commands:

- **Generated-file protection** refuses writes to files OpenWiki owns — its
  claims sidecar, run state, page manifest, last-update record and generated
  index — and to anything under `openspec/specs/`, pointing the writer at
  `openwiki --update` or at the change's delta spec instead. Page bodies under
  `openwiki/` are deliberately not protected: the agent authors those during a
  run.

  A write made through the file-editing tools carries an exact path, so that
  decision is precise. A shell command carries only a command string, and the
  hook does not parse shell, so that layer is advisory. It splits a compound
  command and judges each part on its own: a redirection must name the
  protected path; `sed -i`, `tee`, `rm`, `truncate`, `touch`, `ln`, `dd` and
  interpreters such as `python` or `node` count wherever the path appears; and
  `cp`, `mv` and `install` count only when the path is their last argument, so
  copying a protected file elsewhere is allowed. Because indirection through a
  variable or through `xargs` separates the path from the redirection that
  writes it, a redirection anywhere in a command that also names a protected
  path is treated as a write — which means a read whose output is redirected
  somewhere else is refused as well. That trade is deliberate: the precise
  guarantee lives on the file-editing path.
- **OKF conformance** runs the bundle validator after any write that touches
  `.okf/` and returns the validator's output as an error, so a non-conformant
  document is corrected before work continues. It exits quietly when the bundle
  does not exist.

## What is not enforced

Several rules in the instruction file have no mechanical backing: that an API
was checked against pinned-version documentation and cited, that the
spec-scenario test was written before the implementation, that an independent
reviewer saw the change, and that the build and test gate was actually run: no
workflow runs it. The repository's one workflow regenerates the wiki on a
schedule and is installed and owned by OpenWiki. These rules depend on the
author following them.
