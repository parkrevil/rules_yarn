## 1. CI

- [x] 1.1 Add a `tests/bcr` step to the build-and-test job; verify the commands it runs are the ones that pass locally, and that running them leaves the checkout clean.
  - 2026-10-02: the step runs `bazel build //... --lockfile_mode=off` and `bazel test //... --lockfile_mode=off --test_output=errors` in `tests/bcr`. Run locally, the test passes and `git status` is empty afterwards — no lockfile is written into the checkout.
- [x] 1.2 Verify the workflow still parses and the job holds the steps expected.
  - 2026-10-02: the build-and-test job's steps are the checkout, the Bazel version report, the sandbox report, and one build-and-test step per root — three roots, three steps.

## 2. Gate

- [x] 2.1 Run the repository's pre-commit gate and the build gate across all three roots.
  - 2026-10-02: the root passed 23 tests, `e2e/smoke` 2, `tests/bcr` 1; `tools/hooks/protect_generated_test.sh` passed 40 of 40; `pre-commit run --all-files` passed its ten hooks; `openspec validate --all --strict` passed 3 items.
- [x] 2.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - 2026-10-02: no blockers. One should-fix, upheld; one nit, applied.
    - **Should-fix.** design.md justified `--lockfile_mode=off` by saying `tests/bcr` keeps no lockfile. It does: `tests/bcr/MODULE.bazel.lock` is 700 lines and committed, added by `fef0398` — the change that wrote "keeps no lockfile on purpose" into AGENTS.md. Running Bazel there produced it and `git add -A` carried it in, and the opposite was written down without checking. The reviewer was right to say the removal belongs to its own change rather than being folded in here, which is what AGENTS.md asks for; design.md now states the real situation and names the follow-up.
    - **Nit, applied.** design.md argued no mechanical check was worth having, when the argument it made only rules out parsing AGENTS.md's prose. A narrower check — asserting one build-and-test step per root — would catch this regression. The wording now says that and says why it is not added.
    - The reviewer verified the flag independently: it ran the build in `tests/bcr` with `--lockfile_mode=off` and confirmed `git status` is unchanged before and after and the committed lock is untouched.
    - It compared AGENTS.md's gate line by line against every job in `ci.yml` and found no remaining mismatch, then swept the other `## Always` rules for the same shape. The two it found unenforced — the generated-script rules and fetch-by-digest — are disclaimed in the guard's own header as review-time rules, so they are declared gaps rather than drifted ones.
