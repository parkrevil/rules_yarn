## 1. The macOS failure

- [x] 1.1 Replace `find -printf` in `tests/launcher/launcher_test.sh` with a portable form; verify the replacement produces the same lines, and that the test still passes.
  - 2026-09-30: on a fixture tree holding a nested file, a top-level file and a symlink, `find . \( -type f -o -type l \) -printf '%P\n' | sort` and `find . \( -type f -o -type l \) -print | sed 's|^\./||' | sort` print the same three lines. `bazel test //tests/launcher:launcher_test --cache_test_results=no` passes.
  - Why the local gate missed it: this machine's `find` is `bfs 4.1.1`, not GNU findutils, and `bfs` implements `-printf`. The local run never tested portability, so passing locally said nothing about BSD.

## 2. The Linux failure

- [x] 2.1 Move the network assertion out of the tests that do not need it, into a target of its own in each root; verify both roots pass locally with the split.
  - 2026-09-30: `yarn_cli_test` keeps the host-tools, `yarnPath` and invalid-command checks, which hold whether or not the sandbox blocks anything; `e2e/smoke`'s `yarn_version_test` keeps its version check. The assertion and the offline `--version` check move to `yarn_offline_test` in both roots, tagged `block-network`. Root `bazel test //... --cache_test_results=no` passes 23 of 23, `e2e/smoke` 2 of 2.
- [x] 2.2 Add a CI step that reports what sandbox the Linux runner allows, so the cause is measured rather than guessed; verify the step is written to explain the outcome either way.
  - 2026-09-30: it prints the two user-namespace sysctls and whether `unshare -Ur` succeeds, addresses one plausible cause, prints both again, then demands `linux-sandbox` from Bazel and prints what Bazel says. If the addressed cause was the right one the before-and-after pair shows it; if not, Bazel's refusal is in the log.
- [ ] 2.3 Read what the run reports and fix the measured cause, or record that `linux-sandbox` cannot be had on this runner and say what that costs.

## 3. The rules added without review

- [x] 3.1 Scope the two rules `c78fd6f` added and move them to the section that owns handling findings; verify the wording no longer conflicts with `## Before code`.
  - 2026-09-30: they now speak of the change at hand — fix what the change is for, report a defect outside it, apply a stated rule to everything that change touches — so neither pulls unrelated work into the current branch. Both moved from `## Always`, which holds invariants about the delivered artifact, to `## Before commit`.
- [x] 3.2 Record why the defence for committing `c78fd6f` without a review was wrong, and make the rule say plainly that it covers this file.
  - 2026-09-30: the defence was that the repository treats AGENTS.md edits as plain `chore:` commits. `git log -1 --format=%B 52aaf4f` records "리뷰 5회" — the commit that wrote the review rule went through five reviews. `d5ee42b` records none, but a commit that broke a rule is not an exemption from it. The reviewer rule now ends "This holds for every commit, including one that changes this file."

## 4. Records left incomplete

- [x] 4.1 Supersede the unchecked task in `automate-verification-gate`, which is the one that would have caught this CI failure.
  - 2026-09-30: its task 3.2, "Record what the macOS job reports on the first run, and act on it there rather than guessing now", was never done and the change was archived with it unchecked. The run it asked about is 36726763532; what it reports is recorded in this change's proposal, and acting on it is tasks 1.1 and 2.1 here. The archived change is left as it stands, because an archive is a record of what happened, including that this was skipped.
- [x] 4.2 Supersede the unchecked task in `apply-one-obligation-per-requirement`.
  - 2026-09-30: its task 2.2 asked for a before-and-after comparison of the spec across archiving. That comparison was run and reported — sorted, the scenario sets were identical apart from the one clause design.md records as deliberately moved — but the box was never ticked. The work happened; the record did not.
- [x] 4.3 Record what `fa33984` did without saying so.
  - 2026-09-30: besides committing the archive and the main spec, it restored `openspec/config.yaml`, 14 insertions and 28 deletions, undoing a revert made by the earlier snapshot commit `a34df4d`. The restored content is correct, and the commit message does not mention it. The commit is pushed, so it is recorded here rather than amended.

## 5. Gate

- [x] 5.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`.
  - 2026-10-01: `buildifier -lint=warn -r .` reported nothing; root `bazel build //...` succeeded and `bazel test //... --cache_test_results=no` passed 23 of 23; `e2e/smoke` passed 2 of 2; `tools/ci/minimum_bazel.sh` exited 0; `tools/hooks/protect_generated_test.sh` passed 40 of 40; `pre-commit run --all-files` passed its ten hooks; `openspec validate --all --strict` passed.
  - The target that must be able to fail was checked in both directions rather than assumed: `bazel test //tests/launcher:yarn_offline_test` passes under the default `linux-sandbox`, and fails with its own message under `--spawn_strategy=local`. The reviewer repeated it with `--spawn_strategy=processwrapper-sandbox`, which is what CI actually fell back to, and saw the same failure.
- [x] 5.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
  - The first reviewer was killed by a session limit before producing anything. A second pass reviewed the change from scratch.
  - 2026-10-01: no blockers, no should-fixes.
    - **Nit, applied.** The measurement step relies on a sysctl it sets persisting into the build and test steps of the same job, which is desirable but was not stated. The comment now says so.
    - The reviewer confirmed the `find` replacement is equivalent for this use — `-type l` matches directory symlinks the same way in both forms, embedded spaces survive both, and only embedded newlines break either, which is a limitation the old form had too.
    - It diffed all four test scripts against `HEAD` and found nothing asserted nowhere, and agreed that dropping `block-network` from the two targets that no longer assert anything about the network is correct rather than a weakening — keeping the tag would have been a false claim.
    - It walked the CI step against GitHub's documented default shell, `bash --noprofile --norc -eo pipefail`, and confirmed no command in it can fail the job, and that `sudo` is passwordless on the hosted Ubuntu images.
    - It checked the factual claims this change makes about other commits — that `52aaf4f` records five reviews, that `c78fd6f` records none, that `fa33984` never mentions `openspec/config.yaml` — against the commits themselves.
    - It arrived independently at the same CI prediction: macOS green, Linux red on `yarn_offline_test` alone unless the sysctl turns out to be the cause.
