## 1. Cause

- [x] 1.1 Find why the lockfile exists before deleting it, so the fix is not just a deletion.
  - 2026-10-02: `.bazelrc` in the root and in `e2e/smoke` each set a lockfile mode; `tests/bcr` has none, so Bazel's default `--lockfile_mode=update` applies. Deleting the file and running `bazel build //...` there brought it straight back, which is how it reached `fef0398` in the first place.

## 2. Fix

- [x] 2.1 Add `tests/bcr/.bazelrc` setting the mode the module needs, and delete the committed lockfile; verify the file does not come back and the module still passes.
  - 2026-10-02: with the `.bazelrc` in place, `bazel build //...` in `tests/bcr` leaves no `MODULE.bazel.lock`, and `bazel test //...` passes 1 of 1. `git ls-files tests/bcr` no longer lists the lockfile.
- [x] 2.2 Drop the explicit flag from CI now that the module states its mode; verify the command CI will run passes locally.
  - 2026-10-02: the step is now `bazel build //... && bazel test //... --test_output=errors`, the same shape as the other two roots. Run in `tests/bcr`, it passes.
- [x] 2.3 Make AGENTS.md say what makes its claim true.
  - 2026-10-02: it said `tests/bcr/` keeps no lockfile on purpose, which was false when written. It now also names the `.bazelrc` setting that keeps it true.

## 3. Gate

- [x] 3.1 Run the repository's pre-commit gate and the build gate across all three roots.
  - 2026-10-02: `buildifier -lint=warn -r .` reported nothing; the root passed 23 tests, `e2e/smoke` 2, `tests/bcr` 1; `tools/ci/minimum_bazel.sh` exited 0; `tools/hooks/protect_generated_test.sh` passed 40 of 40; `pre-commit run --all-files` passed its ten hooks; `openspec validate --all --strict` passed 4 items.
- [x] 3.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - 2026-10-02: no blockers; one nit, which was these two boxes being unchecked. They now carry the runs above.
    - The question this change could not answer about itself — whether `off` is the right mode or whether it hides something — was answered. `off` disables only the Bzlmod resolution lockfile, the record of the resolved module graph and registry hashes. Per-artifact integrity checking is unaffected, so a tampered download is still refused; what is given up is a cache of module resolution, which is exactly what a module meant to re-resolve under several Bazel versions should give up. `bazel help build` at 9.2.0 lists `off` as a documented, non-deprecated value.
    - `.bcr/presubmit.yml` passes no `--lockfile_mode` of its own and runs Bazel inside `tests/bcr`, so the presubmit reads this `.bazelrc` exactly as CI and a local run do. No conflict.
    - The reviewer deleted the lockfile itself, rebuilt, and confirmed nothing writes it back and the test still passes; and that `grep -rn "tests/bcr/MODULE.bazel.lock"` now finds only the prose line in AGENTS.md.
    - It checked the other two roots' lockfile claims are still true and that no archived change document is newly false, and agreed the split out of the previous change follows the rule that change itself invoked.
