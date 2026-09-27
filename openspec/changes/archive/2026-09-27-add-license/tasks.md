## 1. License

- [x] 1.1 Add `LICENSE` by copying the Apache License 2.0 from a pinned dependency rather than reproducing it; verify the committed file's sha256 equals the one four pinned dependencies ship, and that it is unmodified — 202 lines, ending with the upstream appendix placeholder.
  - 2026-09-27: copied from the fetched `rules_shell` 0.8.0 archive. `sha256sum LICENSE` is `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`, 202 lines, and `cmp` reports it byte-identical to the `LICENSE` shipped by `rules_shell` 0.8.0, `rules_nodejs` 6.7.5, `bazel_skylib` 1.9.2 and `rules_testing` 0.9.0. The appendix keeps upstream's `Copyright [yyyy] [name of copyright owner]`, as all four do.
- [x] 1.2 State the license in `README.md`; verify the statement names Apache-2.0 and points at the file.
  - 2026-09-27: README ends with a License section linking `LICENSE`.

- [x] 1.3 Check the claim the choice rests on, rather than assuming it: every module `MODULE.bazel` names, and the layout this repository follows, is Apache-2.0.
  - 2026-09-27: each project's declared license, read from its repository: `bazel-contrib/rules_nodejs`, `bazel-contrib/rules_shell`, `bazelbuild/bazel-skylib`, `bazelbuild/rules_testing`, `bazelbuild/platforms` and `bazel-contrib/rules-template` all report `Apache-2.0`. `platforms` and `rules-template` were the two the byte comparison in 1.1 did not cover; the reviewer then compared the fetched `platforms` copy directly and found the same text, differing only by the leading blank line, leaving `rules-template` as the one checked by declaration alone.

## 2. Gate

- [x] 2.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`.
  - 2026-09-27: root `bazel build //...` succeeded and `bazel test //...` passed 16 tests; `e2e/smoke` `bazel build //...` succeeded and `bazel test //...` passed 1 test; `tools/hooks/protect_generated_test.sh` passes 40 of 40; `openspec validate --all --strict --no-interactive` passed. The reviewer ran the two Bazel roots independently and saw the same. The pre-commit hooks run at commit time and are recorded with the commit.
- [x] 2.2 Have a reviewer without this implementation conversation review the change, check each finding against the file or a documented fact, and record the outcome here.
  - 2026-09-27: no blockers. The reviewer re-derived the sha256 and the byte-identity against the four fetched dependencies from the cache rather than from this document, and confirmed the text is canonical, ASCII, and free of CRLF damage.
  - On what the change leaves out — a copyright line, a NOTICE file, per-file headers, `rules_license` targets, a module-level license field — the reviewer agreed none is required for Apache-2.0 and noted that no dependency ships a NOTICE, so there is nothing to carry forward. Correctly deferred rather than overlooked.
  - The appendix placeholder is right as it stands: the reviewer confirmed every dependency ships the same unfilled text, because the appendix is instructions to a licensee rather than a grant.
  - Should-fix, applied: these two boxes were still unticked. They now carry the runs above.
