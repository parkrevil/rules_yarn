## 1. Report the root module's repositories

- [x] 1.1 Add unit tests in `tests/extensions/` for splitting the root module's declarations into regular and development-only, covering a regular declaration, a development-only one, the same repository declared both ways, a repository a dependency asked for, and a declaration the extension did not act on; verify they fail against the extension as it stands, because it reports nothing.
  - 2026-09-27: the load failed first — `file '//yarn/private:extensions.bzl' does not contain symbol 'root_repositories'` — which proves the symbol is missing, not that the assertions bite. A stub returning two empty lists was added so they would run: 5 of the 6 then failed on their assertions, and the sixth, which expects nothing to be reported, passed against the stub as it should.
- [x] 1.2 Report the split from the extension through `module_ctx.extension_metadata`; verify the new unit tests pass and `bazel test //...` stays green in the root.
  - 2026-09-27: `bazel test //tests/extensions:all` passes 15, and the root `bazel test //...` passes 22, up from 16.
  - 2026-09-27: the tests were then checked against a wrong implementation rather than only a right one. Five mutations of `root_repositories` were each caught, by the test written for them: dropping the `selected` filter, swapping the regular and development lists, dropping the regular list's de-duplication, dropping the rule that a repository declared both ways is regular, and dropping the root-module filter. None survived.
- [x] 1.3 Verify the reporting against real module graphs rather than only the unit tests: this repository's own root module, which declares the extension as a development dependency, and `e2e/smoke`, which declares it regularly, both build and test; and `bazel mod tidy` restores a `use_repo` line removed from `e2e/smoke`.
  - 2026-09-27: both roots build and test clean under `--lockfile_mode=error`. With `use_repo(yarn, "yarn")` deleted from `e2e/smoke/MODULE.bazel`, `bazel mod tidy` reported `Updated use_repo calls for @rules_yarn//yarn:extensions.bzl%yarn` and put the line back at line 16. The file was restored afterwards.
  - The development-only case is the one that matters: reporting every root declaration as regular fails this repository's own build with `root_module_direct_deps must be empty if the root module contains no usages with dev_dependency = False`, measured while designing the change.

## 2. Declare the minimum Bazel version

- [x] 2.1 Add `bazel_compatibility` to `MODULE.bazel` at the oldest version measured to work; verify by running a consumer module with a local override under the version below the floor and under the floor itself, recording both outcomes here.
  - 2026-09-27, a consumer module with `local_path_override` onto this repository, with the declaration in place:
    - Bazel 8.2.1 — `ERROR: Bazel version 8.2.1 is not compatible with module "rules_yarn@_" (bazel_compatibility: [>=8.3.0])`, and nothing from inside the ruleset. Without the declaration the same consumer failed at `yarn/private/repositories.bzl:30` with `'repository_ctx' value has no field or method 'repo_metadata'`.
    - Bazel 8.3.0, the version the declaration names — `bazel build //:yarn` succeeded, `bazel run //:yarn -- --version` printed `4.18.0`, and the built launcher printed `4.18.0`. The boundary itself is run, not inferred from a release note and a point inside the range.
    - Bazel 8.3.1 — the same.
    - Bazel 9.2.0 — the same, still working.
- [x] 2.2 Re-resolve both lockfiles per AGENTS.md's "Changing a pin" and record whether either changed; verify both roots still build and test with `--lockfile_mode=error`.
  - 2026-09-27: `bazel mod deps --lockfile_mode=update` in both roots. `MODULE.bazel.lock` is unchanged. `e2e/smoke/MODULE.bazel.lock` gains 22 lines recording a `pybind11_bazel` extension. That delta is not this change's: reverting `MODULE.bazel` and `yarn/private/extensions.bzl` to `9d801ab` and re-running produces the same 22 lines, so the committed lock was already stale. It is refreshed here because the pin procedure says to commit both locks.
- [x] 2.3 Add the minimum Bazel version to README's tested-configuration table; verify the table states the floor and the tested version.
  - 2026-09-27: the Bazel row reads `9.2.0, and 8.3.1 as the oldest supported line`, followed by a paragraph naming the declaration and what a consumer below it sees.

## 3. Gate

- [x] 3.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`.
  - 2026-09-27: `buildifier -lint=warn -r .` reported nothing. Root `bazel build //...` succeeded and `bazel test //...` passed 22 tests; `e2e/smoke` `bazel build //...` succeeded and `bazel test //...` passed 1 test; `tools/hooks/protect_generated_test.sh` passes 40 of 40; `openspec validate --all --strict --no-interactive` passed. The pre-commit hooks run at commit time and are recorded with the commit.
- [x] 3.2 Have a reviewer without this implementation conversation review the change, check each finding against a measurement or a failing test, and record the outcome here.
  - 2026-09-27: no blockers.
  - Should-fix, **upheld and closed**: the floor was recorded at 8.2.1 and 8.3.1, but not at 8.3.0, the version the declaration actually names. The probe was run at 8.3.0 and 2.1 now carries it.
  - The reviewer went through every Bazel API the ruleset uses — `visibility()`, `is_dev_dependency`, `extension_metadata`, `ctx.toolchains[Label]`, `runfiles.merge_all`, `expand_template(is_executable=)`, `attr.label(allow_single_file=[...])` — and found none needing a floor above 8.3.0, so `repo_metadata` is the binding constraint. `test_suite` comes from `rules_testing`, a development-only dependency, and does not reach a consumer.
  - The reviewer built the "declared both ways" graph in real Bazel, with two extension proxies of the same extension, one development-only and one not, and confirmed it builds clean and `bazel mod tidy` leaves it alone — so reporting it as regular is what Bazel expects. No module graph was found where Bazel rejects the report.
  - The reviewer repeated the mutation check independently and found no surviving mutation, and re-derived the lockfile claim from a worktree at `9d801ab` rather than trusting this document.

## Left alone on purpose

README still calls the launcher a POSIX shell script, which is wrong — it is
Bash. That sentence sits next to text this change edits, but it belongs to the
documentation cleanup change, and widening scope to reach it would make this
change harder to review, not the repository better.
