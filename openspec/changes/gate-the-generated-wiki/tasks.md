## 1. Remove the refresh that cannot run

- [x] 1.1 Delete `.github/workflows/openwiki-update.yml`; verify from the run
  history that every scheduled run failed and why.
  - 2026-10-03: `gh run list` shows two runs titled "OpenWiki Update" on `main`,
    36833773352 at `c78fd6f` and 36981675114 at `c0bba48`, both `failure`. They
    are the only failing runs on `main` apart from the first CI run. The
    workflow calls a model and reads a key from secrets; the repository has no
    such secret, so no scheduled run could ever have succeeded.

## 2. The gate

- [x] 2.1 Establish what `openwiki/.claims` records about each source, by
  reproducing both digest kinds from the working tree rather than assuming the
  format.
  - 2026-10-03: 157 evidence entries across eight sidecars, in two kinds.
    `repo-file-v1:sha256:<d>` is the whole file —
    `sha256sum e2e/smoke/MODULE.bazel` gives
    `fba29c68…829c548e`, which is the recorded digest.
    `repo-lines-v1:sha256:<d>:<base64>` is the cited range —
    `sed -n '29,53p' README.md | sha256sum` gives `46d3ca45…c8c4816b`, the
    digest recorded for `repo://README.md#L29-L53`. The base64 metadata's
    `precedingContextHash` and `followingContextHash` reproduce the same way
    from lines 26–28 and 54–56. A single-line range hashes the line with its
    newline: `sed -n '3p' AGENTS.md | sha256sum` matched, the newline-stripped
    form did not.
- [x] 2.2 Write `tools/hooks/openwiki_staleness.sh` to recompute every
  recorded digest and report what no longer matches, what is gone, and what it
  cannot recompute; verify it reports nothing on a tree the wiki describes and
  reports the right entries on one it does not.
  - 2026-10-03: on the regenerated tree it exits 0 and prints nothing, in
    0.19s for 157 entries. Prepending one line to `README.md` makes it exit 1
    and list every `README.md` citation plus the entries drifted at the time;
    removing `.bazelignore` makes it list `.bazelignore` under "no longer
    exist". Both probes were reverted and `git status` confirmed clean.
  - Its first run on the then-current tree reported fifteen drifted citations
    across seven pages, none of which OpenWiki's own incremental check had
    flagged. Task 4.2 re-anchors them.
- [x] 2.3 Show that the commit-comparison alternative cannot work, rather than
  asserting it: run it against a depth-1 clone and against the commit-together
  workflow.
  - 2026-10-03: in `git clone --depth 1` of this repository,
    `git cat-file -e 008019a^{commit}` fails with `Not a valid object name` and
    `git diff --name-only 008019a HEAD -- README.md` with `bad revision`. Only
    `HEAD` exists. `actions/checkout` clones at depth 1 by default, so the CI
    step would have failed on every push.
  - The local failure is independent of CI: `openwiki/.last-update.json`
    records the `HEAD` at the start of the run, but a run reads the working
    tree. With this change's edits uncommitted, the recorded head was `091ae19`
    and the gate reported the change's own files — `ci.yml`,
    `.pre-commit-config.yaml`, `openwiki_staleness.sh` — as drift. Committing
    the wiki alongside what it describes would trip it every time.
- [x] 2.4 Wire it at `pre-push` in `.pre-commit-config.yaml`, declaring the
  install hook type, and in the CI `checks` job.
  - 2026-10-03: `default_install_hook_types: [pre-commit, commit-msg, pre-push]`,
    and the hook sets `stages: [pre-push]`, `always_run: true`,
    `pass_filenames: false`. `pre-commit run --all-files` runs the ten
    pre-commit-stage hooks and not this one, which is why CI's `checks` job
    invokes the script directly after it.

## 3. The obligation

- [x] 3.1 State it in `AGENTS.md` `## Before commit`, and correct the OpenWiki
  block, which claims a scheduled workflow this change removes.
  - 2026-10-03: the rule is the fifth bullet of `## Before commit`, naming the
    script and the stage.
  - The block could not be corrected, and this was established rather than
    assumed. The sentence was rewritten; `openwiki_finish` then restored
    OpenWiki's own wording, and `git diff AGENTS.md` came back as one insertion
    — the new rule — with the block unchanged. It is generator-owned output,
    rewritten on every run, so the repository cannot hold a correction to it.
    The generated wiki's development-workflow page records that the sentence is
    no longer true and why.

## 4. Regenerate the wiki

- [x] 4.1 Run the OpenWiki page-job lifecycle over every page; verify each
  page's body and claims agree with the current tree.
  - 2026-10-03: run `6993ae61` wrote all eight pages, adding
    `operations/publishing.md` for the release and registry apparatus that
    `publish-to-the-registry` added without a page, and new sections on the
    extension's report to Bazel, the consumer's obligations, the three-root
    lockfile split, the offline test layer and the two consumer modules.
- [x] 4.2 Re-anchor every citation the gate reports; verify the gate is silent
  afterwards.
  - 2026-10-03: run `71303b62` re-anchored fifteen citations across seven
    pages: four selection tests and the failure-handler helper in
    `extensions_tests.bzl` (the file grew six report tests at the top, shifting
    everything below), the host-tools blocks in `yarn_cli_test.sh` and
    `e2e/smoke/yarn_version_test.sh`, the `expand_template` assertions in
    `yarn_binary_tests.bzl`, the tag-class documentation in
    `yarn/private/extensions.bzl`, the scope and `bazel run` sections of
    `README.md`, and `MODULE.bazel`'s development dependencies — which since
    `version` and `bazel_compatibility` were added had come to span a comment
    and the `module()` block instead.
  - `tools/hooks/openwiki_staleness.sh` then exits 0.
  - That re-anchoring closes the loop was confirmed before the gate was
    adopted: `claim_0d817a7a3b964d06937894529d820b10` cited `repo://AGENTS.md`,
    OpenWiki reported it stale, it was confirmed during the run, and the
    recorded digest now equals `sha256sum AGENTS.md`.
- [x] 4.3 Make sure no citation written by this change breaks on a routine
  operation; verify the gate afterwards.
  - 2026-10-03: two claims cited this change's own `design.md` and
    `proposal.md`. `openspec archive` renames the change directory, so both
    would have reported "no longer exists" the moment the change is archived —
    the gate's own first failure would have been caused by the change that
    introduced it. Both were re-anchored onto `tools/hooks/openwiki_staleness.sh`,
    `.github/workflows/ci.yml` and `.pre-commit-config.yaml`, and the page prose
    was reworded so the claims and the body still agree. `openspec archive`
    runs after merge, so this was fixed rather than left to surface there.
  - The two remaining OpenSpec citations point into
    `openspec/changes/archive/2026-10-02-publish-to-the-registry/`, which does
    not move again, and `openspec/config.yaml`.

## 5. Records left open

- [x] 5.1 Close `close-the-verification-gate`'s task 2.3 with what the CI
  measurement reported.
  - 2026-10-03: recorded there from run 36852664790 — the cause was
    `kernel.apparmor_restrict_unprivileged_userns = 1`, `unshare -Ur` refused;
    after clearing it Bazel used `linux-sandbox` and every job was green, with
    `yarn_offline_test` passing on both platforms.

## 5b. What the review forced

- [x] 5b.1 Give the gate a contract table, as the generated-file guard has, and
  watch it fail against each version the review found holes in.
  - 2026-10-03: `tools/hooks/openwiki_staleness_test.sh`, fifty-six rows. A
    row counts only when the gate exits with exactly 0 for a clear or exactly
    1 for a refusal, and a refusal only when the gate's message names what the
    row is about; any other exit is reported as such, and a fixture that cannot
    be built stops the run with exit 2 instead of passing — `die` signals the
    script itself, because a helper usually fails inside a command
    substitution, where a plain `exit` would leave only that subshell; the
    harness before this change carried on with an empty digest in that case,
    and now stops with 2, both shown by sourcing the helpers and calling
    `file_version` on a missing file. Seven rows inject a
    failure into a command the gate depends on — a wrapper that does the real
    work, prints the real output, and then exits 7 — including one where the
    second sidecar fails after the first was read cleanly.
  - Run against the first version (`git cat-file -p e42ca592`): 40 of 55 rows
    fail, 21 of them clears of something it never checked. Against the second
    version, the one the second review found holes in: 35 fail, 7 of them
    clears — a first line number too long to compare, a last one too long to
    compare, a symlinked file, a file reached through a symlinked directory
    outside the repository, two JSON documents in one sidecar with the first
    invalid, a line number with a leading zero (which checks the right lines,
    so it is a strictness rule rather than a hole), and the row-count failure,
    a step that version did not have. The other failures against both are
    refusals with a different message, which the table reports as `wrong-why`
    rather than accepting. Against the third version, the one the third review
    found a hole in, one row fails, as a clear: a file behind a symlinked
    directory outside the repository, reached through a name beginning with
    `-`. Against the current version all 56 pass. These counts are from this
    machine; the reviewer's sandbox could not create fixtures and did not
    confirm them, and it notes the first version also needs `xargs`, which the
    injected-failure rows' stub `PATH` omits, so some of that version's
    failures in those rows are for an unrelated reason.
- [x] 5b.2 Rewrite the gate so no command failure, unreadable sidecar or
  record in an unrecognised form can be mistaken for a clean result.
  - 2026-10-03, third version: the work is split so each half can be held to
    that. jq reads each sidecar slurped — so a second JSON document cannot hide
    behind the first — and turns every piece of repository evidence into a row
    it has already validated, or stops naming what it could not read. The
    shell only touches files: it confirms each cited file is a regular file
    whose directory resolves inside the repository, counts its lines and
    hashes it. At the end it compares the rows it handled with the rows jq
    produced, so a read that failed or stopped early cannot look like a short,
    clean list. Line numbers are at most nine digits with no leading zero, so
    the shell's integer comparisons are never handed one they cannot compare.
    Rows are joined with the ASCII unit separator rather than tabs, because
    the shell collapses consecutive tabs and an empty field would shift every
    field after it — a defect in an intermediate draft of this version, caught
    by testing the separator before relying on it. A resource holding a
    control character or a backslash is refused rather than escaped.

## 6. Gate

- [x] 6.1 `bazel build //... && bazel test //...` in the root, in `e2e/smoke/`
  and in `tests/bcr/`; `pre-commit run --all-files`;
  `tools/hooks/protect_generated_test.sh`; `tools/ci/minimum_bazel.sh`;
  `openspec validate --all --strict`.
  - 2026-10-03, after the second review's fixes and the last wiki run: root
    `bazel build //...` succeeded and `bazel test //... --cache_test_results=no`
    passed 23 of 23; `e2e/smoke` 2 of 2; `tests/bcr` 1 of 1, with
    `git status tests/bcr/` clean, so no lockfile was written.
    `pre-commit run --all-files` passed its ten hooks and changed nothing.
    `tools/hooks/protect_generated_test.sh` 40 of 40;
    `tools/hooks/openwiki_staleness_test.sh` 56 of 56.
    `tools/ci/minimum_bazel.sh` exited 0, reporting Yarn 4.18.0 under Bazel
    8.3.0. `openspec validate --all --strict` 3 of 3.
    `tools/hooks/openwiki_staleness.sh` exited 0 over 174 evidence entries
    naming 149 distinct sources, in about two thirds of a second.
- [x] 6.2 A reviewer without this implementation conversation reviews the
  change; record each finding and its verdict here.
  - **First review, 2026-10-03: request changes.** Two blockers, two
    should-fixes, one nit.
    - **Blocker, confirmed.** Command failures could become success: the
      evidence collection's status was never checked. The reviewer's example —
      valid evidence followed by a malformed sidecar exits 0 — does reproduce
      against the first version, with their method of feeding `find` a valid
      sidecar and then a truncated one. An earlier draft of this record
      disputed it and blamed `jq` discarding buffered output; that explanation
      was never tested and was wrong. The real reason my own attempt exited 1
      is that `find` listed `zzz.json` before `aaa.json` — directory order, not
      name order — so `jq` stopped on the malformed file before reading the
      valid one. The reviewer's second example, a hash command that prints the
      right digest and then fails, also reproduces against the first version,
      by overriding `sha256sum` with a function; my earlier attempt used an
      incomplete stub `PATH` and exited 127, which proved nothing.
    - **Blocker, confirmed.** Invalid sidecars and evidence silently
      disappeared: a `{}` sidecar beside a readable one exited 0, and evidence
      whose `version` was absent or `null` was filtered out.
    - **Should-fix, confirmed.** Four false accepts: a `sha512` label with a
      SHA-256 digest, `#not-a-line` with the digest of nothing,
      `#L99999-L99999` with the digest of nothing, and a whole-file digest on
      a line fragment silently hashing the whole file. An earlier draft of
      this record credited the reviewer with a fifth example, reversed ranges;
      the reviewer never claimed that, and it was not a hole.
    - **Should-fix, confirmed.** The proposal said the OpenWiki block no longer
      claimed scheduled regeneration while `AGENTS.md` still did, and task 3.1
      was ticked over it. Fixed as recorded under 3.1.
    - **Nit, confirmed.** The entry count was stale.
  - **Second review, 2026-10-03: request changes.** Three blockers, two
    should-fixes, one nit, against the second version.
    - **Blocker, confirmed.** Oversized line numbers bypassed the bounds
      check: `#L999999999999999999999999999999999` with the digest of nothing,
      and `#L1-L999999999999999999999999` with the whole file's digest, both
      exited 0, because a failed `[` comparison is simply false. Reproduced
      here.
    - **Blocker, confirmed.** The shape check judged only the last JSON
      document in a sidecar, because `jq -e` takes its status from the last
      output while extraction read all of them. Two documents with the first
      lacking a claim id, or carrying a null resource, exited 0. Reproduced
      here.
    - **Blocker, confirmed by inspection, not reproduced here.** A failed
      here-string feeding the evidence loop was ignored, so a sidecar could be
      skipped after an earlier one had set `checked`. The reviewer reproduced
      it in a read-only sandbox; here the here-string succeeded. The third
      version removes the here-string and adds the handled-rows check, which
      catches any early stop whatever its cause.
    - **Should-fix, confirmed.** Refusal rows could pass because their fixture
      failed, exit 127 counted as a refusal, and the missing- and null-digest
      rows passed against the first version for the wrong reason. The table
      was rewritten as recorded under 5b.1.
    - **Should-fix, confirmed.** This record disputed two findings that do
      reproduce. Corrected above.
    - **Nit, confirmed in part.** Counts are corrected below and in the wiki.
      The table's repository row was removed: it ran the current hook whatever
      the argument, and CI already runs the gate on the real tree. Traversal,
      symlinks, control characters and backslashes in a resource are now
      refused and are rows.
  - **Third review, 2026-10-03: request changes.** One blocker, two
    should-fixes, one nit, against the third version.
    - **Blocker, confirmed.** `inside_repository` called `dirname` on the
      cited path unprotected and unchecked. For `-escape/file`, `dirname`
      failed as an invalid option, printed nothing, the check resolved the
      repository root and cleared the file. Reproduced here with a real
      symlink named `-escape` pointing outside: exit 0. The parent directory
      is now taken by parameter expansion, with no external command to fail;
      the reproduction is a row.
    - **Should-fix, confirmed.** A fixture helper failing inside a command
      substitution did not stop the run. Fixed and shown as recorded in 5b.1.
    - **Should-fix, accepted by reading.** The hashing-failure row wrapped
      `sha256sum` even on a host where the gate would use `shasum`. It now
      wraps whichever command the gate selects. Not run on macOS.
    - **Nit, confirmed.** The records said six injected-failure rows; there
      were seven. Corrected here, in `design.md`, the proposal and the wiki.
  - After the fixes the whole gate was run again; the results are under 6.1.
