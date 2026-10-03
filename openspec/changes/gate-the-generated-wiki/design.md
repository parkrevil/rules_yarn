## Context

A generated document goes stale rather than wrong: nothing breaks, the prose
simply stops matching the code. The only thing that can fix it is the
generator, which here is an agent driving OpenWiki's MCP server. So the
question is not how to repair the wiki automatically but how to make its
staleness impossible to miss.

## What the gate compares

OpenWiki already records the answer. Each claim in `openwiki/.claims/**.json`
names its sources as `repo://<path>` or `repo://<path>#L<first>-L<last>` and
stores a `version` beside each one:

- `repo-file-v1:sha256:<digest>` — the digest of the whole file;
- `repo-lines-v1:sha256:<digest>:<base64 metadata>` — the digest of the cited
  line range.

Both were verified against the current tree before the gate was written to
rely on them. `sha256sum e2e/smoke/MODULE.bazel` reproduces the `repo-file-v1`
digest exactly; `sed -n '29,53p' README.md | sha256sum` reproduces the
`repo-lines-v1` digest for `repo://README.md#L29-L53`, as do the metadata's
`precedingContextHash` and `followingContextHash` for the three lines on each
side. A single-line range hashes the line including its newline.

So the gate reads every evidence entry, recomputes its digest from the working
tree, and reports the ones that no longer match, the ones whose file is gone,
and any record it cannot check as written.

## How it stays closed

Two independent reviews each found records the gate cleared without checking,
so its structure is built around one rule: nothing that fails, and nothing it
cannot read, may look like a clean result.

The work is split in two. jq reads each sidecar slurped, so a second JSON
document cannot hide behind the first, and turns every piece of repository
evidence into a row it has already validated — digest kind and algorithm, 64
hexadecimal characters, a line range on a line digest and none on a file
digest, line numbers of at most nine digits with no leading zero, a path that
neither starts with `/` nor climbs with `..` — or stops, naming the sidecar.
The shell only touches files: it checks that each cited file is a regular file
whose directory resolves inside the repository — the directory taken by
parameter expansion, because `dirname` reads a leading `-` as an option — counts its lines, and hashes
it. Every command whose failure could pass for success is status-checked, and
at the end the shell compares the rows it handled with the rows jq produced, so
a read that stopped early is a refusal rather than a shorter list.

`tools/hooks/openwiki_staleness_test.sh` holds the gate to this as a table of
fifty-six rows. A refusal row counts only if the gate exits with exactly 1 and
names what the row is about, and seven rows inject a failure into a command the
gate depends on, after that command has done its work.

## Why not a commit comparison

The obvious design — record the commit the wiki was generated from, ask git
which cited files changed since — was written first and discarded for two
reasons, both demonstrated rather than argued.

It cannot run in CI. `actions/checkout` clones at depth 1 by default, so no
commit other than `HEAD` exists in the working copy. In a `git clone --depth 1`
of this repository, `git cat-file -e 008019a^{commit}` fails with
`Not a valid object name` and `git diff 008019a HEAD` with `bad revision`. The
gate would have failed the `checks` job on every push.

It asks the wrong question locally. `openwiki/.last-update.json` records the
`HEAD` at the time of the run, but a run reads the *working tree*, which
normally holds the very changes being described. Committing the wiki alongside
the change it describes — the workflow `AGENTS.md` asks for — therefore trips
the gate on its own commit, every time. A gate that must be skipped routinely
is not a gate.

The digest comparison has neither problem, because it never asks when anything
happened. It needs no git at all.

## Why it refuses instead of fixing

Regenerating a page needs a model. A shell hook cannot have one, and the
scheduled workflow that did was removed because the repository has no key for
it. What the hook can do is say precisely which citations no longer hold and
name the lifecycle that fixes them, which is enough for the agent that is
already in the repository to act. `SKIP=openwiki-staleness git push` is printed
with the failure, so going ahead anyway is a stated decision.

## Why pre-push

A stale wiki is a property of what is being published, not of each commit on
the way there. Regenerating at every commit would be work thrown away by the
next one. `pre-push` is also where the gate sees the finished change, which is
what the wiki has to describe.

## What the gate is strict about

It compares bytes at the cited lines, so inserting a line above a citation
makes that citation report. That is not noise: the citation now points at the
wrong lines, and a reader following it lands somewhere else. OpenWiki fixes it
by re-anchoring the claim, which is a normal part of a run — and the first run
of this gate found fifteen such citations that OpenWiki's own check had let
through.

Re-anchoring was confirmed to close the loop before the gate was adopted:
`claim_0d817a7a3b964d06937894529d820b10` cited `repo://AGENTS.md`, was reported
stale by OpenWiki, was confirmed during the run, and its recorded digest now
matches the current file.

## What a page may cite

A citation has to survive the repository's own routine operations. `openspec
archive` renames a change directory, so a page citing
`openspec/changes/<name>/…` is guaranteed to report "no longer exists" the
moment that change is archived. Two claims written during this change did cite
its own design and proposal; both were re-anchored onto the gate script, the CI
workflow and `.pre-commit-config.yaml` before the change was committed, and the
gate confirmed silent afterwards. Citing an already-archived change is fine —
two claims do — because an archived path does not move again.

## Risks

A hand-edited page body would satisfy the gate while being unverified, because
the gate checks sources against claims and not prose against sources. That is
already forbidden by `## Always`, and the editor guard refuses writes to the
bookkeeping those claims live in.

An OpenWiki release that introduces a new `version` kind makes the gate stop
rather than pass quietly; it names the entries it cannot recompute.
