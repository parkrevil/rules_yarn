## 1. Correct

- [x] 1.1 A dated correction under each wrong line in the three archived task
  lists, a correction section in `require-completed-tasks`, and a pointer
  under `close-the-verification-gate` 4.1 and 4.2; verified by reading each
  against the sources design.md lists, and `openspec validate --archived
  --no-interactive` still exiting 0.
  - 2026-10-20: written, then corrected twice after review — the email line
    first cited `8ab6d8d` (2026-10-03), when the wiki still listed the email as
    open; it was added by `aa36173` (2026-10-05); then the 2.2, 3.2, proposal
    and task corrections were reworded as recorded under 2.2. `openspec
    validate --archived --no-interactive` exits 0 (18 passed).
- [x] 1.2 The CI comment over the pre-commit step names the hooks that run at
  the pre-commit stage; verified by comparing it with `.pre-commit-config.yaml`.
  - 2026-10-20: the comment names buildifier, its linter, actionlint, the file
    hygiene hooks, `openspec validate --all --strict` and `openspec validate
    --archived`, the pre-commit-stage hooks of `.pre-commit-config.yaml`;
    commitizen runs at commit-msg and the wiki staleness gate at pre-push.
- [x] 1.3 The workflow wiki page states the gaps around the checks; verified
  by the staleness gate exiting 0. At archive time the claim citing this
  change's `design.md` is re-anchored to the archive path.
  - 2026-10-20: the page's "What is still not enforced" section names the
    unprotected `main` and the hook's gaps; `tools/hooks/openwiki_staleness.sh`
    exits 0.

## 2. Gate

- [x] 2.1 Before the commit: every root builds and tests,
  `install_scenarios.sh` passes, pre-commit passes, the wiki staleness gate
  passes; verified by those commands' output.
  - 2026-10-20, before the commit: root 41/41, `e2e/smoke` 2/2,
    `e2e/install` 7/7, `tests/bcr` 1/1, `install_scenarios.sh` 39/39,
    `pre-commit run --all-files` passing, `tools/hooks/openwiki_staleness.sh`
    exit 0.
- [x] 2.2 An adversarial review without this conversation, from Codex and from
  an independent agent; each finding checked against its source and recorded.
  - 2026-10-20, first round. Codex: the email correction cited `8ab6d8d`,
    where the wiki still listed the email as open; `git log -G 'maintainer
    chose'` gives `aa36173` — taken. Independent agent, one blocker and six
    should-fixes, each checked and taken: the wiki gate failed after that fix
    (regenerated); the 3.2 correction attributed a motive (now states the
    hook's behaviour only); the 2.2 correction quoted a note that contradicts
    the 2026-10-19 result (now cites `3b59a99`'s commit message); the
    proposal bullet miscounted the tasks and said section 7 was done at the
    time (corrected); `close-the-verification-gate` 4.1 and 4.2 were left
    unmarked (pointers appended); the new convention that a ticked box can
    record a skip was stated nowhere (stated in the correction, as holding for
    these four tasks until the repository's principles are agreed); this
    change's tasks lacked evidence and a meaningful check, and its plan
    omitted the wiki (all added). Nits taken: the token's date source, the
    rulesets endpoint, task-less archives among the hook's gaps, the 2.1
    correction now naming the order rather than "locally".
  - 2026-10-20, second round, Codex on the corrected tree: approve, no
    finding; history and OpenSpec 1.13.0 source support each correction and
    all wiki citation digests match. It could not reach GitHub; the secret's
    date, the unprotected `main` and the CI log were checked by the
    independent agent in the first round (`gh secret list`,
    `gh api .../branches/main/protection` and `.../rulesets`,
    `gh run view 39139044245`).
