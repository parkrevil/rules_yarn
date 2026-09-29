## 1. README

- [x] 1.1 Describe the launcher as Bash and say what makes it Bash, instead of calling it a POSIX shell script; verify the claim against the template and the shell toolchain rather than against the old sentence.
  - 2026-09-29: `yarn/private/yarn_binary.sh.tpl` uses `[[ ]]`, `pipefail` and `source`, none of which is POSIX `sh`. `rules_shell`'s `local_config_shell` points the shell toolchain at Bash for every operating system it configures — `/usr/bin/bash` on Linux, `/bin/bash` on macOS, `/usr/local/bin/bash` on the BSDs, `bash.exe` on Windows — so the launcher runs under Bash wherever the toolchain resolves.
- [x] 1.2 Say what the installation snippet's `path` is relative to; verify the snippet still matches `e2e/smoke` verbatim, since that is what makes it a checked snippet.
  - 2026-09-29: the snippet is unchanged and still matches `e2e/smoke/MODULE.bazel`; a sentence beneath it explains that `../..` is that module's value because it sits two directories below the repository root.
- [x] 1.3 Name the declared Bazel floor in the tested-configuration table.
  - 2026-09-29: the row read `8.3.1`, the version that happened to be run first. The declaration is `>=8.3.0` and 8.3.0 itself has since been run, so the row now reads 8.3.0.

## 2. Repository settings

- [x] 2.1 Add `.claude/settings.local.json` to `.gitignore`; verify it is currently ignored only by a machine-global file, so the repository does not depend on one.
  - 2026-09-29: `git check-ignore -v` pointed at `/home/revil/.config/git/ignore`, not at the repository's own `.gitignore`.
- [x] 2.2 Give `e2e/smoke/.bazelrc` the same per-user `try-import` the root has; verify both roots still build and test.
  - 2026-09-29: added with the root's wording. Both roots build and test clean.

## 3. OKF tooling

- [x] 3.1 Remove `tools/okf/`, `tools/hooks/okf_conformance.sh`, the `okf-validate` pre-commit hook and the `PostToolUse` block; verify first that the tooling has no input, and afterwards that the guard still runs and the hook set is otherwise unchanged.
  - 2026-09-29: before removal, `pre-commit run --all-files` reported `okf validate (.okf) (no files to check) Skipped` — the hook has nothing to act on. No `.okf/` directory exists, and `tools/okf/validate.sh` states in its header that `openwiki/` is OpenWiki's to validate.
  - After removal: `tools/hooks/protect_generated_test.sh` passes 40 of 40, so the `PreToolUse` guard is untouched, and `pre-commit run --all-files` passes its remaining ten hooks. This also closes the latent CI break the previous change recorded, since the removed hook called `uv`, which the runner images do not carry.
- [x] 3.2 Find what else in the repository still refers to the removed tooling, and deal with each according to who owns it.
  - 2026-09-29: outside `openwiki/`, the only remaining mentions are in this change's own documents and in the previous change's, where they describe the removal. Nothing executable refers to the deleted files.
  - `openwiki/workflows/development-workflow.md` and its Claims sidecar still describe the OKF conformance hook and cite `repo://tools/hooks/okf_conformance.sh` and `repo://tools/okf/validate.sh` as sources. Those citations are now dangling. AGENTS.md forbids hand-editing `openwiki/` — `openwiki --update` regenerates it — so this change leaves them and records that the scheduled OpenWiki run is what clears them. `openwiki/index.md`'s `okf_version: "0.2"` is the OKF document format the wiki is written in, not the deleted validator, and is unaffected.

## 4. Test sizes

- [x] 4.1 Give the Starlark unit tests a size; verify the eleven warnings are gone, every target keeps its name, and the tests still pass.
  - 2026-09-29: `bazel test //... --test_verbose_timeout_warnings` reported eleven `outside of range for MODERATE tests` warnings before and zero after, and `bazel test //...` no longer ends with `There were tests whose specified size is too big`. The root still runs 22 tests, all passing, and every target name is unchanged — the suites now call `analysis_test` over `rules_testing`'s own stub target with `attr_values = {"size": "small"}`, because `unit_test` has no size parameter to forward.


## 5. Gate

- [x] 5.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes, `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`, and the CI floor script still passes.
  - 2026-09-29: `buildifier -lint=warn -r .` reported nothing; root `bazel build //...` and `bazel test //...` passed 22 tests with no size warning; `e2e/smoke` passed 1; `tools/ci/minimum_bazel.sh` exited 0; `tools/hooks/protect_generated_test.sh` passed 40 of 40; `pre-commit run --all-files` passed its ten remaining hooks; `openspec validate --all --strict` passed 3 items.
- [x] 5.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - 2026-09-29: no blockers.
    - **Should-fix, upheld and recorded rather than fixed**: the dangling OpenWiki citations above. The reviewer agreed this change should not touch generated pages.
    - The reviewer reproduced the test-size rewrite independently: the function lists before and after hold the same 15 and 2 names, `bazel query 'tests(//tests/...)'` returns all 17 targets under unchanged names, and a fresh run with `--cache_test_results=no` gives 17/17 with zero size warnings. It also read the pinned `rules_testing` 0.9.0 source and confirmed the suites reproduce `unit_test`'s own shape through the public `analysis_test` entry point, over a stub target that `lib/BUILD` marks publicly visible.
    - **Nit, accepted**: that stub's name begins with an underscore, so a future `rules_testing` bump could rename it even though its visibility is public. design.md already records the trade-off.
    - The reviewer checked every changed README sentence against the code — the template's Bash-only syntax, the shell toolchain's Bash paths on every configured operating system, the snippet still matching `e2e/smoke/MODULE.bazel` verbatim, and 8.3.0 being the declared floor — and scanned the rest of README, finding no remaining stale claim.
    - It also judged `skip_specs: true` correct: `Declared support boundary` requires the documentation to state the tested versions and the oldest supported Bazel, not which values those are, so correcting a value and clarifying wording changes nothing the requirement demands.
    - **Note, acted on**: these two boxes were still unchecked when the review ran. They now carry the runs above.
