## Decisions

**Append, never rewrite.** Each correction is a new dated line under the line
it corrects, naming this change, so a reader sees the claim, that it was
wrong, and why. Removing the wrong lines would hide that they were written;
reverting `require-completed-tasks` instead would drop a hook that does catch
an archived change with unchecked tasks, which the review found not redundant.

**The 3.2 tick stays, and says what it is.** `openspec validate --archived`
has no exemption, so keeping the hook means the box is ticked; the correction
under it records that the task was skipped in that change and done in
`close-the-verification-gate`, and that the tick reverses 4.1's decision.

**Sources for each correction**: `close-the-verification-gate` tasks 4.1 and
4.2 (2026-09-30); the 3.2 reviewer note in
`apply-one-obligation-per-requirement`; `openwiki/operations/publishing.md`
lines 194-197, present since commit `aa36173` (2026-10-05; `8ab6d8d`
still listed the email as open); the archive commit message of `3b59a99`; `git show 6ff562a`, whose task
list has 2.1 unticked; OpenSpec 1.13.0's `openspec archive`, which asks before
archiving incomplete tasks; `gh api .../branches/main/protection` answering
"Branch not protected" and `gh api .../rulesets` answering `[]`.

## Risks / Trade-offs

- Limit: the hook does not see active changes, unarchived finished changes,
  deleted changes, tasks without checkbox syntax, or a box ticked without the
  work; the corrections state this where the original records claimed more.
