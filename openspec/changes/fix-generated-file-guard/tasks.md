## 1. Contract test

- [x] 1.1 Add `tools/hooks/protect_generated_test.sh`, a table of every generator-owned path, the neighbouring paths that must stay editable including a change's own delta spec, the spellings a path can arrive in — absolute, unnormalised, and outside the repository — and the calls the guard cannot read; verify it runs against the committed guard and reports the rows that guard gets wrong.
  - 2026-09-27: against the guard at `fa33984`, the table reported 10 failures of 32 rows. Four generated paths were allowed — `openwiki/architecture/index.md`, `openwiki/workflows/index.md`, `openspec/specs`, and `<repo>/./openwiki/architecture/../index.md`. Three unrelated paths were refused — `/tmp/openwiki/index.md`, `/tmp/openspec/specs/spec.md`, and `<repo>/../openwiki/index.md`. Three calls the guard cannot read were allowed — a `notebook_path` target, an unparseable payload, and a run with `jq` missing from `PATH`.

## 2. Guard

- [x] 2.1 Rewrite `tools/hooks/protect_generated.sh` to decide on a resolved, repository-relative path with `case` patterns, covering `openspec/specs/`, OpenWiki's bookkeeping, and every `openwiki/**/index.md`; verify `tools/hooks/protect_generated_test.sh` reports zero failures.
  - 2026-09-27: `tools/hooks/protect_generated_test.sh` reports `failures: 0` over 32 rows.
- [x] 2.2 Remove the shell-command layer and drop `Bash` from the `PreToolUse` matcher in `.claude/settings.json`, and state in the script's header why a shell command is out of scope; verify the script contains no pattern over command text.
  - 2026-09-27: the script no longer reads `.tool_input.command`; `guarded_write` and its five regular expressions over command text are gone. 79 lines to 80 — the length is unchanged because the room went to failing closed.
- [x] 2.3 Make the guard fail closed and cover every tool its matcher selects: refuse when `jq` or `realpath` is missing, when the payload does not parse, or when the path will not resolve, and read `notebook_path` as well as `file_path`; verify the three corresponding table rows refuse.
  - 2026-09-27: all three rows refuse. The missing-`jq` row runs the guard under a `PATH` containing only `cat`, `dirname` and `realpath`, so the behaviour is exercised, not asserted.
- [x] 2.5 Set the `PreToolUse` matcher so a file-writing tool is covered whether or not it was listed by name; verify by running the same edit onto a generated path under each candidate matcher, since a matcher cannot be exercised from the contract table.
  - 2026-09-27: a `NotebookEdit` inserting a cell into `openwiki/.claims/__matcher_probe__.ipynb`, a throwaway notebook created for the run and deleted after it. Under `Write|Edit` the edit **succeeded** — `Inserted cell b7812d94` — so no guard ran. Under `Write|Edit|NotebookEdit` and under `.*Write|.*Edit` it was refused with the OpenWiki message. `.*Write|.*Edit` was chosen, and a `Write` to `openwiki/.last-update.json` under it is still refused, so the permissive form did not lose the tools the old matcher held. `git status` is clean afterwards.
- [x] 2.4 Verify against the live harness, not only the table: the `Bash` read that the committed guard refused now runs, a `Write` to an OpenWiki bookkeeping path is still refused, and a `Write` to a generated index page — which the committed guard allowed — is now refused.
  - 2026-09-27: `cat openwiki/index.md 2>/dev/null | head -3` was refused by the harness earlier in this session and now returns the file's first three lines. A `Write` to `openwiki/.last-update.json` was refused. A `Write` to `openwiki/testing/index.md` — allowed by the guard at `fa33984` — was refused. `git status -- openwiki` is empty afterwards, so neither refused write reached a file.

## 3. Gate

- [x] 3.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`.
  - 2026-09-27: root `bazel build //...` succeeded and `bazel test //...` passed 16 tests; `e2e/smoke` `bazel build //...` succeeded and `bazel test //...` passed 1 test; `openspec validate --all --strict --no-interactive` passed 2 items. The pre-commit hooks run at commit time and are recorded with the commit.
- [x] 3.2 Have a reviewer without this implementation conversation review the change, check each finding against the guard's behavior or a failing table row, and record the outcome here.
  - 2026-09-27: the reviewer read the tree mid-iteration and raised one blocker and two should-fixes.
    - Blocker, **upheld**: the matcher does not select `NotebookEdit`, so the `notebook_path` branch was unreachable and a notebook write to a generated path reached no guard. The reviewer asked for a live check rather than an argument; the A/B run recorded in 2.5 confirms it and the matcher is now `.*Write|.*Edit`.
    - Should-fix, **already fixed** before the review arrived: the missing-`jq` row ran `bash` from a stripped `PATH`, so it failed for the wrong reason. It now invokes `"$BASH"` by absolute path.
    - Should-fix, **already fixed** before the review arrived: the recorded line and row counts were stale. They are 79 to 80 lines and 32 rows, re-measured.
    - The reviewer found the path-matching core sound over its own probes, agreed the protected set is complete against `openwiki/.page-manifest.json`, confirmed the fail-closed behaviour by direct invocation, and offered no sound alternative to dropping the shell-command layer.
    - The reviewer noted that a symlink planted at a generated path by an unguarded shell command would send a later write elsewhere. That is the stated non-goal, and the write then no longer reaches the generated file, so nothing new is exposed.
