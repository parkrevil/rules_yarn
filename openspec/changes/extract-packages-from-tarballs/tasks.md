## 1. Evidence and APIs

- [x] 1.1 Check `tar.bzl` 0.10.9's toolchain API (`tar_lib.toolchain_type`, the
  toolchain's `tarinfo.binary` and `default_env`) in its source at that
  version, and Bazel's validation actions (`OutputGroupInfo(_validation = …)`)
  in the documentation at Bazel 8.3.0 and 9.2.0; cite both. Verified by the
  citations.
  - 2026-10-05: cited in design.md, Evidence. The validation-action check
    changed the design: those actions do not run for a target used as a tool,
    an implicit dependency or in the exec configuration, so the check moves
    into the extracting action.
- [x] 1.2 Record the bsdtar comparison as a reproducible check: the repository
  rule's decision is that comparison, made at every install; the scale
  measurement (3.4) records how many of the 717-entry project's packages it
  builds from tarballs, against the evidence's 576 plain `npm:` packages and
  75 peer-dependency instances, with the 4 patched packages and 77 stubs
  archived. Verified by the recorded counts.
  - 2026-10-05: 576 plain `npm:` packages and 75 peer-dependency instances
    built from their tarballs, 77 stubs and 4 patched packages archived —
    the evidence's counts exactly (3.4).

## 2. Tests first

- [x] 2.1 Unit tests for naming each store package's candidate: an `npm:`
  package, a scoped one, one with `::` parameters, a peer-dependency
  instance, a stub, a resolution not fetched, a version `semver.valid` would
  change; and the store path against the 717-entry project's layout. Verified
  red against a stub module.
  - `tests/install/sources_test.js`, 6 tests; 5 failed against the stub. The
    first version assumed every `npm:` entry gets a store path of its own,
    which a patch's source (`typescript@npm:5.6.3`) or a package installed
    only as a peer instance (`react-dom@npm:18.3.1`) does not; the test now
    requires every `-npm-` store path Yarn wrote to be computed for an entry,
    on the two captured projects in `tests/install/testdata/`. On the
    717-entry project all 653 are, by a run recorded here and not kept as a
    test.
- [x] 2.2 Unit tests for `extract.js`: the manifest and its comparison — equal
  trees, a changed file, a missing and an extra entry, a directory in place of
  a file — normalisation of an unreadable directory and a mode-0000 file, the
  case-only collision check, and cleanup after a failed extraction. Verified
  red against a stub.
  - `tests/install/extract_test.js`, 11 tests, run with tar.bzl's host bsdtar;
    10 failed against the stub, and the normalisation test, which a stub's
    empty manifests passed, failed with normalisation made a no-op.
- [x] 2.3 Scenario: after an install, the repository holds no archive for a
  package built from its tarball. Verified red against the current driver.
  - The scenario "Package built from its tarball"; with the decision always
    choosing an archive, as the previous driver did, it failed.
- [x] 2.4 The build action's check: a unit test running `extract.js`'s check
  with a manifest altered after the decision fails and names the package.
  Verified red with the check removed.
  - The last test of `extract_test.js`; against the stub it failed.
- [x] 2.5 Scenarios with tarballs the fixture registry crafts, each installing
  and giving Yarn's tree: directories without an execute bit (as
  `pngjs@5.0.0`) and a file of mode 0000, built from their tarballs; a hard
  link, a contiguous file, an absolute path, a `./package/` prefix, a `..`
  entry, a FIFO and two entries differing only by case, archived. Verified red
  against the implementation without the comparison.
  - The scenario "Tarballs bsdtar and Yarn extract differently"; with the
    decision always choosing the tarball it failed, the build's check
    refusing the packages whose extraction is not Yarn's tree.

## 3. Implementation

- [x] 3.1 `tar.bzl` in `MODULE.bazel`; locks refreshed in every root that
  keeps one. Verified by the builds.
- [x] 3.2 The driver's source decision and manifests; `layout.json` version 2.
  Verified by 2.1, 2.2 and the e2e tests.
- [x] 3.3 `node_modules.bzl`: the extracting and checking action in a custom
  `exec_group` with both toolchains; archive unpacking for the rest. Verified by 2.3, 2.4 and the e2e tests.
- [x] 3.4 Measure the 717-entry project again: disk of the install repository,
  the tarball repositories and the tree, before and after; fetch and build
  times; how many packages are built from tarballs. Verified by the recorded
  numbers.
  - 2026-10-05, Linux x64, warm repository cache: the install repository's
    archives went from 409 MB to 53 MB (the four patched packages, the
    TypeScript patch among them, and 77 stubs), plus 4.8 MB of manifests; the
    built tree stays 501 MB; the tarballs were already kept by the tarball
    repositories before and after. Fetching and laying out took 19.0 s, up
    from 11.7 s, for the decision's extraction of 651 tarballs; a cold build
    of `@npm//:node_modules` took 8.1 s, up from 2.0 s, gunzipping and
    hashing in place of reading uncompressed archives; a second build 0.6 s.

## 4. Gate

- [x] 4.1 Every root builds and tests; the scenarios, pre-commit, both
  contract tables, the floor probe and `openspec validate --all --strict`
  pass.
- [x] 4.2 The wiki is regenerated and the staleness gate passes.
  - 2026-10-05: `architecture/dependency-installation.md` describes building
    from tarballs and the new figures; the public API, version pinning and
    verification pages were updated; moved citations re-anchored by locating
    each cited block of the previous commit in the current file, and checked
    by the reviewer against the lines they cite.
- [x] 4.3 A reviewer without this conversation reviews the plan before code
  and the change before commit; each finding is checked and recorded here.
  - Plan review, first round (independent reviewer, Codex being unavailable
    until 2026-10-10): not ready. Confirmed and taken into the plan: bsdtar
    leaves `pngjs@5.0.0`'s execute-less directories unreadable where Yarn
    makes them 0755 (`rules_js` runs `chmod -R a+X` for it); tarball shapes
    bsdtar and Yarn treat differently would each have failed a build Yarn
    succeeds at, so the source is now decided by extracting and comparing in
    the repository rule, with an archive as the fallback; one action with two
    toolchains needs a custom `exec_group`; the evidence's counts were wrong
    (576 `npm:` packages, 77 stubs) and the comparison was not made with
    bsdtar, now restated from the review's bsdtar run; crafted-tarball
    scenarios added (2.5); the store folder default and `::` parameters in
    the reference stated.
  - Plan review, second round: no blocker. Confirmed and taken in: the spec
    now says which packages are built from their tarballs and adds a scenario
    for the others; a mode-0000 file is built from its tarball once
    normalised, so the evidence and task 2.5 say so; a case-only collision is
    refused in the decision, since a case-folding host and a case-sensitive
    executor would extract different trees, and the decision runs bsdtar with
    the toolchain's locale; one module, `extract.js`, does extraction,
    normalisation, manifest and comparison for both the decision and the
    action, normalising before anything reads; task 2.4 now names how the
    mismatch arises; `tar/extensions.bzl` cited for the repository names; the
    new bsdtar download at fetch stated; task 1.2's counts named; a
    contiguous-file case added.
  - Change review, first round: one blocker, confirmed by reasoning about
    macOS's case-insensitive APFS — the scenario required both `README` and
    `readme` in one package, which Yarn cannot write there; it now checks both
    files only where the filesystem keeps case apart, and that the package is
    archived and installs everywhere. Should-fixes, confirmed: the spec now
    names the case and normalisation exception and says the build-time
    scenario concerns an execution platform other than the deciding host;
    `caseCollisions` folds Unicode normalisation (NFD) as well as case, as APFS
    does, with a test that failed with case folding alone. Nits taken: task
    2.1's record says which projects the test covers; the link-refusal path
    removes the scratch directory; the driver reports a host bsdtar that
    cannot run instead of archiving every package unseen; the archive
    unpacking action names its toolchain (`toolchain =`), as automatic exec
    groups expect. Left as it is: path mapping, which the action's `.path`
    arguments could not use. All 35 scenarios pass.
  - Change review, second round: no blocker, no should-fix; every earlier
    finding closed, and each of the 32 changed wiki claims checked against
    the lines it cites. Its two nits are taken: the extract exec group's
    Node.js toolchain gets the same clear error for a host-path-only
    toolchain as the default one, and the wiki claim about `tar.bzl`'s
    toolchain says only what rules_yarn's files show.
