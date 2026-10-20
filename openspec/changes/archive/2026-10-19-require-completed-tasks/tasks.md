## 1. Change

- [x] 1.1 Red: `openspec validate --archived --no-interactive` exits 1 on the
  repository as it is, naming the three archived changes.
  - 2026-10-19: exit 1, `Totals: 14 passed, 3 failed`:
    `apply-one-obligation-per-requirement` (5/6), `automate-verification-gate`
    (8/9), `publish-to-the-registry` (14/16).
- [x] 1.2 The pre-commit hook `openspec-validate-archived`.
- [x] 1.3 The four tasks settled with their evidence; the hook exits 0.
  - 2026-10-19: each task carries a dated line naming its evidence;
    `openspec validate --archived --no-interactive` exits 0.

## 2. Gate

- [x] 2.1 Every root builds and tests; pre-commit; `openspec validate --all
  --strict`; CI on the branch.
  - 2026-10-19: CI run 39139044245 passed all five jobs, its `checks` job
    running the new hook over all files.
- [x] 2.2 The wiki is regenerated and the staleness gate passes.
- [x] 2.3 A reviewer without this conversation reviews the change; each
  finding checked and recorded.
  - 2026-10-19: no blocker; every evidence line checked against its source —
    the spec diff at `3b59a99`, runs 36726763532 and 36852664790, the secret,
    run 37760533408 and #10979 — and the hook's before and after. Should-fix:
    the wiki cites this change's `design.md`, which archiving moves; the
    citation is re-anchored at archive time, as every earlier archive did.
    Nits left: the 3.2 line names the macOS failure only, the Linux one being
    recorded in `close-the-verification-gate`'s own history.

## Correction, 2026-10-20

- 1.2 named no way to verify it, against `openspec/config.yaml`'s rule that
  every task does: CI run 39139044245's log shows
  `openspec validate --archived ... Passed`.
- 2.1 was ticked after the commit it gates (`6ff562a`). CI run 39139044245,
  on that commit, did run every root and `install_scenarios.sh`; the fault is
  the order — AGENTS.md's "Before commit" asks for those to pass before the
  commit, and the task's own wording, "CI on the branch", could only be met
  after it.
- The review recorded in 2.3 missed the contradiction with
  `close-the-verification-gate` 4.1 and the wrong "done late" and email
  lines; an adversarial review on 2026-10-20 found them, and
  `correct-the-completion-gate-records` corrects them.
