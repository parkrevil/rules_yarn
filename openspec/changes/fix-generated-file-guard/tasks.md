Measurements below name the guard they were taken against: `fa33984` is the
guard this change replaces, `01b1086` is this change's first pass.

## 1. Contract test

- [x] 1.1 Add `tools/hooks/protect_generated_test.sh`: every generator-owned path, the neighbouring paths that must stay editable including a change's own delta spec, the spellings a path can arrive in — absolute, unnormalised, symlinked, and outside the repository — and the calls the guard cannot read; verify it runs against `fa33984` and reports the calls that guard gets wrong.
  - 2026-09-27: 40 rows, of which `fa33984` gets 13 wrong. Seven from matching an unanchored substring of the path as spelled, two from the protected files being a hard-coded list, one from the matcher never selecting `NotebookEdit`, and three from failing open on a symlinked path, an unparseable payload, and a missing `jq`.
  - The guard under test has to sit at its normal depth in the repository, because that is how it finds the repository root. An earlier baseline run from `/tmp` reported three extra failures that were this mistake, not the guard's.

## 2. Guard

- [x] 2.1 Decide on the path rather than on the command: rewrite `tools/hooks/protect_generated.sh` around repository-relative `case` patterns, and drop the shell-command layer along with `Bash` in the `PreToolUse` matcher, stating in the header why a shell command is out of scope.
  - 2026-09-27: the script no longer reads `.tool_input.command`; `guarded_write` and its five regular expressions over command text are gone.
- [x] 2.2 Name the protected files by shape, not by filename — `openspec/specs/`, any dot-named entry under `openwiki/` at any depth, and every `openwiki/**/index.md`; verify the shape is the real ownership boundary and that files which do not exist yet are judged correctly.
  - 2026-09-27: checked against the repository — every OpenWiki-owned entry under `openwiki/` is dot-named (`.claims/`, `.page-manifest.json`, `.last-update.json`, transient `.run.json`) or an `index.md`, and the only non-dot files absent from `openwiki/.page-manifest.json` are the six index pages. `openwiki/.a-file-openwiki-adds-later.json` and `openwiki/architecture/.a-nested-one.json` are refused; `openwiki/a-page-a-run-has-not-written-yet.md` stays editable.
- [x] 2.3 Judge the path in both senses, as written and as its symlinks resolve, so a path reaching a generated file and a generated path replaced by a symlink are both refused; verify with real symlinks rather than by argument.
  - 2026-09-27: the test builds a throwaway repository per case. A symlink reaching a generated file is refused, a symlink standing in for one is refused, a symlink between two ordinary files is permitted. `01b1086` refuses only the first.
- [x] 2.4 Fail closed and read whichever field names the target: refuse when `jq` or `realpath` is missing, when the payload does not parse, or when the path will not resolve, and read `notebook_path` as well as `file_path`.
  - 2026-09-27: the missing-`jq` row runs the guard under a `PATH` holding only `cat`, `dirname` and `realpath`, invoking it through `"$BASH"` by absolute path, so the behaviour is exercised rather than asserted.
- [x] 2.5 Set the `PreToolUse` matcher so a file-writing tool is covered whether or not it was listed by name; verify by running the same edit under each candidate matcher, since a matcher cannot be exercised from the contract table.
  - 2026-09-27: a `NotebookEdit` inserting a cell into `openwiki/.claims/__matcher_probe__.ipynb`, a throwaway notebook created for the run and deleted after it. Under `Write|Edit` the edit **succeeded** — `Inserted cell b7812d94` — so no guard ran. Under `Write|Edit|NotebookEdit` and under `.*Write|.*Edit` it was refused. `.*Write|.*Edit` was chosen, and a `Write` to `openwiki/.last-update.json` under it is still refused, so the permissive form kept what the old matcher held.
- [x] 2.6 Verify against the live harness, not only the table.
  - 2026-09-27: `cat openwiki/index.md 2>/dev/null | head -3`, refused by the harness earlier in this session, returns the file's first three lines. A `Write` to `openwiki/.last-update.json` is refused. A `Write` to `openwiki/testing/index.md` — allowed by `fa33984` — is refused. `git status -- openwiki` is empty afterwards, so no refused write reached a file.

## 3. Claims

- [x] 3.1 Bring design.md back to what was measured.
  - 2026-09-27: "a hook matcher is not a substring search" was a general rule drawn from three measurements, and now states what those three show. "`.*Write|.*Edit` closes the class" was false — it covers names ending in `Write` or `Edit`, and a lower-case `write_file` from an MCP server would not match; the limit is written down rather than implied. The risk entry that answered drift with "the set and the test sit next to each other" is gone, because drift is fixed rather than documented.

## 4. Gate

- [x] 4.1 Run the repository's pre-commit gate and the build gate.
  - 2026-09-27: `tools/hooks/protect_generated_test.sh` passes 40 of 40. Root `bazel build //...` succeeded and `bazel test //...` passed 16 tests; `e2e/smoke` `bazel build //...` succeeded and `bazel test //...` passed 1 test; `openspec validate --all --strict --no-interactive` passed. The pre-commit hooks run at commit time and are recorded with the commit.
- [x] 4.2 Have a reviewer without this implementation conversation review the change, check each finding against the guard's behavior or a failing table row, and record the outcome here.
  - 2026-09-27, against the first pass:
    - Blocker, **upheld**: the matcher does not select `NotebookEdit`, so the `notebook_path` branch was unreachable and a notebook write to a generated path reached no guard. The reviewer asked for a live check rather than an argument; 2.5 is that check.
    - Should-fix, **already fixed** when the review arrived: the missing-`jq` row ran `bash` from a stripped `PATH` and so failed for the wrong reason.
    - Should-fix, **already fixed** when the review arrived: the recorded counts were stale.
    - The reviewer found the path-matching core sound over its own probes, confirmed the fail-closed behaviour by direct invocation, and offered no sound alternative to dropping the shell-command layer.
    - The reviewer read a symlink planted at a generated path as out of scope, since only an unguarded shell command can plant one. **Not accepted.** A symlinked `openwiki/` is an ordinary layout, not an attack, and the guard was answering only half the question. 2.3 closes it.
