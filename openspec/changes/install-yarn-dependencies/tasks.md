## 1. Evidence

- [x] 1.1 Record the measurements in design.md's Evidence section as
  reproducible fixtures: project files, commands, full digests. Verified by
  re-running them from the fixtures.
  - The lockfiles, package maps and on-disk link lists the unit tests use are
    under `tests/install/testdata/`, taken from real Yarn 4.18.0 installs.
    Each measured fact design.md relies on is reproduced by a checked-in
    test (2026-10-05, all passing; "the scenario" means a case of
    `tools/ci/install_scenarios.sh`, which runs on the root's Bazel, 9.2.0):
    - what a lockfile checksum covers: the scenario "The lockfile's checksum
      is the SHA-512 of Yarn's cache archive; the pin is the registry
      tarball's, which differs", on a fixture package;
    - conditional packages without a checksum: `e2e/install/yarn.lock`, 25
      conditional entries and none with a checksum; the patch-source
      exception in `conditions_test.js`;
    - what Yarn reads: the scenario "Yarn run on its own, given an rc name,
      loads the plugin a file of that name above the project names" (the
      walk above the project, under the name it is given), and "Yarn run on
      its own installs with the registry refusing everything, from the
      host's global cache";
    - what stops builds: `e2e/install/installed_test.sh` (esbuild's
      postinstall did not run, with `built: true`);
    - what a locked install asks the registry for: `e2e/install`, installing
      from a loopback server that refuses anything but the fetched tarballs
      (which shows nothing outside the fetched set was asked for, not the
      count of 4 the measurement gave); a changed checksum refused, on a
      plain entry and on a patched one: the scenarios "Checksum mismatch" and
      "Checksum mismatch on a patched entry" (a user patch, where the
      measurement used Yarn's built-in TypeScript patch);
    - the `pnpm` linker's layout, peers, workspaces and missing `.bin`:
      `layout_test.js` against the captured package maps and link lists; the
      stub of another platform's package: `installed_test.sh`;
    - what `yarn npm info` answers: the scenario of that name, an existing
      version, a missing one, and a package whose `latest` tag is not its
      highest version (the measurement asked about is-number on the public
      registry; the scenario asks the same of fixture packages);
    - platforms not reachable through the environment: the scenario
      "YARN_SUPPORTED_ARCHITECTURES cannot carry Yarn's architecture sets";
    - the cache key: the scenario "The cache key Yarn writes";
    - what the project's configuration does to Yarn: the scenarios "Yarn run
      on its own loads the plugin the project's file names" and "Yarn run on
      its own with enableNetwork false still sends requests through a
      project's per-host networkSettings proxy";
    - what a locked install needs from it: the scenario "packageExtensions:
      the added dependency is an entry, not a dependency of left; …";
    - YAML reading and conditions: `yarnrc_test.js`, `yarnrc_yarn_test.js`,
      `lockfile_test.js`, `conditions_test.js`;
    - a link in a tarball: the scenario "Link inside a package";
    - the chosen representation: `e2e/install` in a sandbox and in runfiles
      at 9.2.0 and 8.3.0; a cycle of links and a file named `col:on.js`, in
      a sandboxed action that reads both links, the scenario "A dependency
      cycle" at 9.2.0 only — at 8.3.0 those two remain the recorded run in
      1.2;
  - Read from Yarn's source at the 4.18.0 tag, not reproduced: that Yarn also
    reads the home directory's `.yarnrc.yml`; that `validateFile` accepts any
    digest for an unstable package and switches to `update` on a different
    cache key without `--check-cache`; that `enableScripts: false` alone
    would not stop a build forced by `dependenciesMeta.built`; that the cache
    version can be changed only through `YARN_CACHE_VERSION_OVERRIDE`. The
    design relies on none of these alone: the install's home is empty, it
    passes `--check-cache` and checks the cache key, it sets both
    `enableScripts: false` and `skip-build`, and it gives Yarn no environment
    but its own.
  - The measurements of alternatives not taken — what Bazel refuses as an
    artifact, at 9.2.0 — remain recorded runs; nothing relies on them.
  - The first version of this mapping overstated it; an independent review
    (Codex being unavailable until 2026-10-10) named each gap, and the
    scenarios above were added or tightened for them: the cycle case now
    checks both links and runs in a sandboxed action, the `yarn npm info`
    case tells the latest tag from the highest version, the checksum case
    compares the tarball with its pin, and the fixture proxy records CONNECT
    requests — without which the earlier case "the proxy sees nothing"
    could not have seen a tunnel. Its second pass found the patch case's
    `sed -i` GNU-only, which would have failed the macOS CI job; it now uses
    the script's Node `edit` helper and undoes the edit afterwards. Its third
    pass found no blocker and no should-fix; its two nits are applied. All
    33 scenarios pass.
- [x] 1.2 Measure the chosen representation — directory artifacts per store
  package, `declare_symlink` per link, including a cycle — in a sandboxed
  action and in runfiles at Bazel 8.3.0 and 9.2.0. Verified by the recorded
  output at both versions.
  - 2026-10-03: `require("a") === 42` in a `linux-sandbox` action and in a
    test's runfiles at both versions, and `col:on.js` kept. The glob and
    single-directory failures that rejected the alternatives were measured at
    9.2.0 only; nothing relies on them.
- [x] 1.3 Measure how `node_modules/.package-map.json` represents a peer
  instance and a workspace. Verified by a recorded fixture.
  - 2026-10-03: `tests/install/testdata/workspaces_peers.package-map.json`.
    Peer instances are their own store packages; workspaces are keyed by
    project-relative path; the lockfile has no `virtual:` entries.

## 2. Tests first

Each test is run red against an implementation missing what it tests, and the
red result is recorded here.

- [x] 2.1 Extension unit tests: install authority, duplicate name, a name
  shared with a distribution, unknown distribution, the report to Bazel.
  - 2026-10-03, red: against a `select_installs` that accepted everything, the
    5 refusal and report tests failed and the positive one passed.
- [x] 2.2 Driver unit tests: the pre-checks, the lockfile reader, the
  `.yarnrc.yml` reader, condition evaluation and tarball selection, the layout
  derivation.
  - Pre-checks (`check_test.js`, 35 tests). Red: 18 of 21 against a stub that
    refused nothing; after the second review, the 15 cases it raised failed
    against the first implementation for the reasons it gave — `~/` treated as
    outside the project, `builtin<` matched as a prefix, selectors not decoded,
    `__archiveUrl` found only as a substring, pins accepted without a URL or
    with a short digest.
  - Lockfile reader (`lockfile_test.js`, 21 tests). Red: 15 of 15 against a
    stub; the 4 grammar cases the second review raised failed against the first
    implementation; the U+2028 case failed against the regular expression it
    replaced. Compared with js-yaml as recorded in design.md.
  - `.yarnrc.yml` reader (`yarnrc_test.js`, 21 tests). Written before its
    tests, so not red first; instead compared with js-yaml as recorded in
    design.md, which found the three defects fixed before the unit tests were
    written, and the enterprise fixture then failed against the version that
    refused mappings inside sequence items.
  - Conditions (`conditions_test.js`, 20 tests). The evaluator was written
    before its tests and compared with tinylogic 2.0.0 on 50,000 random
    expressions, with no difference. The selection tests were written with
    their implementation; removing the exclusion rule, ignoring `optional`,
    treating optional edges as required, and counting open dimensions as
    incompatible each made them fail.
  - Layout (`layout_test.js`, 10 tests). Red: 10 of 10 against a stub. The
    golden link lists are what Yarn wrote on disk.
- [x] 2.3 Archive unit tests (`archive_test.js`, 19 tests). Red: 11 of 12
  against a stub (the determinism test passed on empty output and was
  strengthened); after the second review, 7 new cases failed against the first
  implementation. Removing each of 12 properties made at least one test fail;
  the NUL case needed a valid entry before it to catch the missing check, and
  was changed to have one.
- [x] 2.4 `e2e/install/` consumer module covering its scenarios, each
  assertion red against a deliberately wrong tree — the wrong version, the
  unpatched package, a missing `.bin` — not only by failing to resolve.
  - 2026-10-04: a real project — `is-number` patched by a project patch file
    through `resolutions` with a `~/` path, `typescript` with Yarn's built-in
    patch, `esbuild` with platform packages, a `bin` and `dependenciesMeta`
    `built: true`, two workspaces one of which uses `react-dom`'s peer, and
    `packageExtensions` in `.yarnrc.yml`. Its lockfile was written by the
    pinned Yarn; its pin file was written by `bazel run @npm//:pin` starting
    from an empty file, the "First pin" scenario.
  - `installed_test` and `offline_test` pass. The test was written after the
    tree was first built, so its red runs were done on a writable copy of the
    built tree with one fault introduced per assertion: a wrong version, the
    project patch removed, the TypeScript patch removed, `.bin/tsc` removed,
    `bin/esbuild` replaced as esbuild's postinstall would, the
    `packageExtensions` link removed, `js-tokens` unshared, the workspace's
    link removed, `react-dom`'s peer pointed at a copy of `react`, the host's
    binary removed, a file added to another platform's package. All eleven
    failed with their own message and the unmodified copy passed. Two of the
    eleven at first did not: the workspace check passed because Node found the
    root's `is-number` further up, and two checks that fail inside `$(…)` ended
    without a message under the runfiles snippet's `set -e`. Both were fixed in
    the test before the counts above.
  - The first runs also exposed two faults in the test itself, fixed before
    those runs: it took the last `*/node_modules/is-number` it saw, which was
    a workspace's; and it expected another platform's package to be empty,
    where Yarn's `pnpm` linker writes a stub `package.json` marked `mocked`.
- [x] 2.5 `tools/ci/install_scenarios.sh` covering its scenarios, including a
  lockfile-only and a pin-only change, each red for its stated reason.
  - 2026-10-04: 17 cases, all passing, in about 70 s, against a local registry
    (`tools/ci/fixture_registry.js`) that builds its fixture packages — a
    scoped one, platform packages, one whose tarball holds a link — so no case
    depends on a public registry. Every case runs with a `.yarnrc.yml`
    pointing the registry at a closed port in the Bazel client's `HOME`, the
    directory above the output root and the output root itself.
  - Writing them found two defects in the implementation, both fixed with
    regression tests: the `.yarnrc.yml` reader refused a flow sequence
    (`unsafeHttpWhitelist: ["127.0.0.1"]`) in a setting it does not even carry
    — it now reads only the carried settings and skips the rest, and was
    compared with js-yaml again, 200,000 documents with no disagreement, after
    that comparison found three more ways YAML lets a skipped value run on
    (an open quote, a block scalar, an indented document); and a dependency the
    lockfile does not record was reported as a missing platform package,
    because Yarn asks the registry for metadata to resolve it — such a request
    now reports that the lockfile would have to be modified.
  - It also found five mistakes in the cases, fixed in the script: a lockfile
    edit cannot leave an install valid, because Yarn's immutable check compares
    the text, so the refetch trigger is a re-indented pin file and the lockfile
    case checks that a changed file is judged and a restored one installs
    again; a borrowed digest was answered from the repository cache, which is
    content-addressed, without a download — Yarn then refused the bytes by
    their lockfile checksum, which is the second check working — so the case
    uses a digest no content has; the host-folder case passed on a failed
    build; and the pin re-indent wrote identical text.
  - Red runs against the implementation with one isolation measure disabled:
    handing Yarn the project's `.yarnrc.yml` failed exactly the plugins and
    network settings case; leaving out `YARN_RC_FILENAME` failed the
    configuration-above-the-project case, and every install with it, because
    the closed-port registry was then read; running `node` from `PATH` made
    every install fail, which shows a dependence on host tools is caught but
    does not isolate it to the no-host-installation case.

## 3. Implementation

- [x] 3.1 The `install` tag class and its selection and reporting in
  `yarn/private/extensions.bzl`. Verified by 2.1.
- [x] 3.2 The per-tarball repositories the extension creates from the pin file.
  Verified by 2.4: 33 pinned, 9 fetched for a Linux x64 host — the
  platform package `@esbuild/linux-x64` and the eight packages every platform
  needs. (4 was the count for the first version of the project, before its
  workspaces and their React dependencies were added.)
- [x] 3.3 The driver's main program and loopback server, composing the
  verified modules — `check.js`, `lockfile.js`, `yarnrc.js`, `conditions.js`,
  `layout.js`, `archive.js`. Verified by 2.4, and before that by running it
  outside Bazel on the `esbuild`/`typescript` project: it chose exactly the
  four tarballs Yarn had requested in the spike, and produced 28 packages, the
  56 links Yarn writes and three `.bin` entries in 1.5 s.
- [x] 3.4 The layout repository rule and the rules that turn archives and links
  into artifacts, with the `layout.json` contract and its provider. Verified by
  2.4. The artifact rule is loaded from a symlink at each install
  repository's root, so `visibility("private")` keeps it unloadable from
  anywhere else; measured at Bazel 8.3.0 and 9.2.0 that a repository generated
  this way builds while a consumer loading the file directly is refused. The
  provider is public, in `//yarn:providers.bzl`, so that it has one identity
  for every install.
- [x] 3.5 The pin target, runnable whatever state the pin file is in. Verified
  by 2.4's first pin from an empty file; a failing check makes the install's
  `node_modules` target report its errors when built, not the repository fetch
  fail, so `pin` stays runnable.
- [x] 3.6 `MODULE.bazel`: the regular use of the `node` extension.
  Lock-bearing roots — the repository, `e2e/smoke`, `e2e/install` — refreshed
  with `bazel mod deps --lockfile_mode=update`; `tests/bcr` keeps no lockfile.
  - 2026-10-04: `bazel mod deps --lockfile_mode=error` passes in all three; the
    repository's and `e2e/smoke`'s locks did not change, `e2e/install`'s is
    new and holds no host path. The `yarn` extension reports itself
    reproducible, so its results — which depend on the pin file — are not
    recorded in a lock.
- [x] 3.7 Measure installing a large project — on the order of a thousand
  packages — and record fetch time, layout time, artifact count and the build
  of `node_modules`; record what it shows, including any limit.
  - 2026-10-04, Linux x64, a project depending on `@babel/core`,
    `@nestjs/cli`, `eslint`, `jest`, `next`, `react`, `react-dom`, `storybook`,
    `typescript`, `vite` and `webpack`: 717 lockfile entries, 84 conditional,
    8 patched. `bazel run @npm//:pin` wrote 712 pins in 41.3 s. Fetching and
    laying out took 11.7 s with the tarballs already in the repository cache.
    Building `@npm//:node_modules` took 2.0 s for 2,978 actions — 732 packages
    unpacked, 2,234 links and 11 `.bin` entries created — and a second build
    0.2 s. Every top-level package reported its locked version, `typescript`
    transpiled and `@babel/core` transformed, and `.bin/tsc`, `.bin/jest` and
    `.bin/next` ran.
  - Limit: the archives (409 MB) and the unpacked tree (501 MB) each take about
    a `node_modules`, so an install costs roughly twice its size on disk.
  - The measurement found two defects, fixed with a regression test each: the
    darwin-only `fsevents`, the source of Yarn's built-in patch, was left out on
    Linux although Yarn fetches it everywhere (design.md, Architectures); and a
    changed driver did not reinstall, because the repository rule did not watch
    it (design.md, Inputs and refetching). The second was found because the
    first fix did not take effect.
- [x] 3.8 Public docstrings and `README.md` meeting the modified support
  boundary; `AGENTS.md`'s roots and pins; CI running `e2e/install` and the
  scenario script on Linux and macOS.
  - `README.md` gains "Installing a project's dependencies" — the guarantees,
    what is refused, what this release does not do — and the `yarn.install`
    attribute table; its Scope separates `yarn_binary`, which has no
    guarantees, from `yarn.install`. The extension's docstring shows an
    install. `AGENTS.md` names `e2e/install` among the consumer modules, the
    build roots and the pins, with how to regenerate its lockfile and pins.
  - CI runs `e2e/install` and `tools/ci/install_scenarios.sh` in the
    build-and-test job on Linux and macOS, and `installed_test` at the
    declared floor (Bazel 8.3.0, which passed locally) with the lock off, as a
    consumer resolving from scratch would.

## 4. Gate

- [x] 4.1 Every root builds and tests; pre-commit, both contract tables, the
  floor probe and `openspec validate --all --strict` pass.
  - 2026-10-05: root 38/38, `e2e/smoke` 2/2, `e2e/install` 3/3 (also at
    Bazel 8.3.0), `tests/bcr` 1/1, `tools/ci/install_scenarios.sh` 33/33,
    pre-commit, the guard's table (40 cases) and the staleness gate's (56
    rows), `tools/ci/minimum_bazel.sh` at 8.3.0, `openspec validate --all
    --strict`.
- [x] 4.2 The wiki is regenerated through OpenWiki and the staleness gate
  passes.
  - Three runs on 2026-10-05: one wrote the new page,
    `architecture/dependency-installation.md`, and updated eight others
    (the maintainer email item is closed in `operations/publishing.md`); one
    re-anchored the citations OpenWiki flagged after the review rounds; the
    third re-anchored 26 claims whose cited lines had moved, which the
    staleness gate found and OpenWiki's own check did not. The gate then
    passed.
  - Writing the installation page found a defect: the install repository
    returned `repo_metadata(reproducible = True)`, which Bazel 8.3.0 defines
    as producing the same output "even if other untracked conditions change"
    and uses to reuse contents across workspaces. Its contents depend on the
    host — the platform packages selected for `current`, the Node.js binary
    — and hold absolute paths into the output base (`pin_config.json`, the
    staged symlinks), so the claim was false. It is no longer made; the
    tarball repositories, pinned by integrity, keep it.
- [x] 4.3 A reviewer without this implementation conversation reviews the
  change; each finding is checked against documentation or a failing test and
  recorded here with its verdict.
  - First round (Codex, 2026-10-04): not ready. Every finding was checked and
    all were accepted:
    - Ancestor configuration (blocker, confirmed): Yarn looks for the name
      `YARN_RC_FILENAME` gives in every directory above the project, so the
      fixed name could be planted there with a plugin. The name is now drawn
      from 128 random bits each run. Regression: the scenario script plants
      the former name, with a marker plugin, above the project; with the
      former fixed name restored, that case failed.
    - Scenario statuses (blocker, confirmed by reading: `[ $x = 0 ] && [ $? =
      0 ]` tests the first test's status; a loop's status is its last
      iteration's): each status is now saved at once and the loop
      accumulates. Mutation run: a failing restore, a wrong second version, a
      missing platform package first in the loop and a missing credential
      helper each failed their case.
    - Malformed pin JSON (confirmed): the driver threw, the repository failed
      and `:pin` went with it. It now reports the error through the
      deferred-error target. Regression: "Malformed pin file" in the scenario
      script, which failed with the throw restored.
    - Anchors and tags before a quote (confirmed with js-yaml 4.3.0
      `FAILSAFE_SCHEMA`): `readCarried` now sets aside `&anchor` and `!tag`
      properties in front of a scalar. Three regression tests failed before
      the fix; the generator now writes such properties, and eight runs of
      about 18,000 documents found no disagreement after two more cases the
      runs found (a quote fused to a property's name) were fixed.
    - `YarnNodeModulesInfo.root` (confirmed): it named the source root, where
      no artifact is. It is now taken from a declared artifact's path, which
      also avoids `Label.workspace_root`, deprecated at Bazel master. Test:
      `e2e/install`'s `provider_root` action requires `is-number` through it;
      with the former path it failed with "Cannot find module".
    - `Label.workspace_name` (confirmed: "Deprecated" in Bazel 8.3.0's
      `Label.java`): replaced by `Label.repo_name`.
    - Host global folder (accepted): the home now holds a seeded Yarn global
      folder (`~/.yarn/berry`), and the comparison covers every entry's type,
      mode, size, modification time and content, leaving out only
      `.cache/bazelisk`, which Bazelisk writes. A same-size, same-mtime
      content change failed the case.
    - Generated scripts in the harness (accepted): the poison executables, the
      marker plugin and the credential helper are checked in under
      `tools/ci/fixtures/` and copied.
    - Records (accepted): pinning downloads only packages without a published
      SHA-512, now said in design.md and `README.md`; the link count is
      2,234 links and 11 `.bin` entries; design.md names the red-first
      exceptions; `--fields name,version,dist`.
  - The rule "no generated script" applied to everything this change touches:
    the scenario script still writes `MODULE.bazel`, `BUILD.bazel`,
    `.yarnrc.yml`, `package.json` and pin files, which are data, and passes
    fixed JavaScript expressions to `node -e` in `edit`, text of the script
    itself and not assembled from data — left as they are. The fixture
    registry packs a `cli.js` into a fixture tarball, package content — left.
    The tests under `tests/install/` write only data files. (Both wrong; see
    the second round.)
  - Scenario count: 20 cases, all passing, after the round's additions.
  - Second round (Codex, 2026-10-04): not ready. Every finding was checked
    and all were accepted:
    - `.yarnrc.yml` read differently from Yarn (blocker, confirmed with
      js-yaml 4.3.0): a comma and a quote in a plain scalar outside a flow
      collection made the former reader skip a setting Yarn reads; a
      no-break space after a value was removed by `trim`, which YAML does not
      do. A hand-written reader had now failed in a new way at every review,
      so it was replaced, not patched: both `yarn.lock` and `.yarnrc.yml` are
      read with js-yaml 4.3.0 itself, the version Yarn 4.18.0's own lockfile
      resolves, fetched with `http_archive` by the registry's integrity,
      through `syml.js`, a port of Yarn's `parseSyml` (design.md, "What
      Yarn's YAML reading is"). The spec's "Configuration that cannot be
      read" scenario now refuses only what Yarn cannot read, and a new
      scenario says the carried settings are exactly Yarn's. The new
      `yarnrc_test.js` (12 tests) states what Yarn reads in each case the
      reviews found; against the former reader 5 failed, the two this round
      found among them. `lockfile_test.js` lost its writer-grammar refusals,
      which no longer apply, and gained tests that YAML is read as Yarn reads
      it (13 tests). The repository rule watches js-yaml's tree, and the pin
      target reads the lockfile with the same parser; `e2e/install`
      refetched, and its pin target rewrote the same 33 pins.
    - Wiki not regenerated (blocker): accepted; it is task 4.2, done after
      the review settles, before the commit.
    - Status masking (confirmed): the first pin's status and the repeat
      build's status were dropped; both are kept now. Every other `build`
      and `pin` call in the script was checked: each status is saved or
      judged in its chain. The repeat-build fragment with a failing build
      now fails.
    - Errors thrown, not reported (confirmed): a missing pin file, a
      `package.json` that is not an object, and a resolution with a malformed
      `%` escape threw. Each is now reported; `driver_test.js` (5 tests) and
      a `check_test.js` case fail with the former code.
    - No-break space (confirmed): closed by the js-yaml change above.
    - Generated scripts (confirmed): `archive_test.js` wrote a shebang script
      where only an executable mode was needed — it now writes data; the
      fixture registry built `cli.js` in code — it now reads
      `tools/ci/fixtures/tool_cli.js`. Every file the change adds was
      searched for a written `#!`: the only other is `installed_test.sh`,
      which reads one.
    - `tree_digest.js` (accepted): it lists the directory itself, and any
      file that is neither regular, a directory nor a link by its metadata
      without opening it.
    - Fetch count in 3.2 (confirmed): 9, corrected above.
  - Third round (Codex, 2026-10-04): not ready. Every finding was checked:
    - Configuration wrappers (blocker, confirmed): a `.yarnrc.yml` whose whole
      document is an `onConflict` wrapper with a `value` lost every carried
      setting. Yarn resolves a file by unwrapping such markers at every
      mapping (`normalizeValue` and `resolveValueAt`, configUtils.ts at
      4.18.0); `yarnrc.js` now does the same for the one file the install
      reads (`resolveSingle`). New `yarnrc_yarn_test.js` runs the pinned Yarn
      itself — `yarn config --json`, with the install's empty home and
      environment — on the project's file and on the file the driver writes,
      and requires the same effective value for every carried setting, over
      eight configurations including both wrapper forms, wrappers inside a
      setting, `"00"` and a block scalar. Against the former reader, the
      wrapper-with-value case and the compression case failed.
    - Compression level (blocker, confirmed): the cache key was built from the
      raw string. It is now built from the level Yarn uses —
      `parseSingleValue`'s rule for a NUMBER setting with values `mixed` and
      0–9: an allowed value as is, otherwise `parseInt`, otherwise an error,
      0 when absent — and anything Yarn would not accept is reported, not
      thrown. The Yarn comparison test checks the level for five files.
    - Settings from the environment (accepted): Yarn replaces `${NAME}` in a
      setting from its own environment, which the install does not share with
      the developer. A carried setting holding `${` is refused, naming it; a
      setting that is not carried may use it.
    - Wiki (blocker): task 4.2, in progress.
    - Setup status (confirmed): `lock && pin` before the link case now stops
      the script when it fails.
    - Missing pin file (confirmed end to end): the extension read the file
      unconditionally, so a missing file failed the whole extension with a
      traceback, taking `@yarn` and `:pin` with it. It now watches the path —
      Bazel 8.3.0 documents `watch` as covering a file starting to exist —
      and reads it only if it exists; the driver says the file does not exist
      and names the pin command. Run on the 717-entry project: the build said
      so, `:pin` wrote the file, the build then succeeded, and the file
      matched the one removed. A scenario now covers it, and the spec's first
      pin scenario says "missing or empty".
    - `reproducible = True` (confirmed): already removed (4.2 above).
    - Nits: `node_test.sh`'s comment now names js-yaml. The counts in 2.x are
      those recorded when each test was first run; today's are archive 19,
      check 36, conditions 21, driver 5, layout 10, lockfile 13, watched 1,
      yarnrc 14, yarnrc against Yarn 9. Two files outside this change write
      scripts at run time (`tests/launcher/yarn_cli_test.sh`,
      `tools/hooks/openwiki_staleness_test.sh`); they are reported for a
      change of their own, not changed here.
  - Scenario count: 21 cases, all passing.
  - Fourth round (Codex, 2026-10-04): not ready. Every finding was confirmed:
    `hardReset` around the whole document, a dependency literally named
    `onConflict`, nulls written as JSON, and a document resolving to a list all
    made Yarn read the carried settings differently. Porting more of Yarn's
    resolution was abandoned: `carriedFile` now keeps the document as parsed,
    drops non-carried top-level settings (keeping a root marker), writes it with
    js-yaml and refuses it unless it reads back identically; the driver puts it
    one directory above the project and its own settings in the project, and
    Yarn resolves everything. The cache key check asks Yarn for the compression
    level (`yarn config get`). `yarnrc_yarn_test.js` compares `yarn config get`
    per carried key (`yarn config --json` prints maps as `{}`, which had hidden
    a difference) over 13 configurations: all pass; the former approach fails
    the five the review named. `clean --expunge` failures in the scenario
    script are fatal; design.md's bootstrap and README's Plug'n'Play wording corrected.
    Gate: root 38/38, e2e/smoke 2/2, e2e/install 3/3, tests/bcr 1/1, scenarios
    21/21.
  - Fifth round (Codex, 2026-10-05): not ready. Confirmed:
    - A document whose `onConflict` marker holds a list (blocker): kept in
      the carried file, it is not a mapping where the install's own file is
      one, and Yarn's resolver then drops the install's settings too — Yarn
      tried to open an environment file named `null`. The test had hidden it
      by standing a one-setting file in for the driver's. Now a marker holding
      a list keeps nothing, which is what the document gives Yarn on its own;
      a marker holding null or a scalar is refused, because Yarn itself fails
      on that file — the test runs Yarn on each and requires it to fail.
    - The comparison test (should-fix): it now builds the install's own file
      and the whole environment with the driver's `installSettings` and
      `yarnEnvironment`, requires every `yarn config get` to succeed, and
      states what Yarn makes of each case (14 cases, 2 refusals). Run against
      the previous `yarnrc.js`, the list case and both refusals fail.
    - The driver now reports output from `yarn config get` that is not JSON
      instead of throwing.
    - Nit: the record above said cleanup failures; it is `clean --expunge`
      failures that are fatal, and the EXIT trap's cleanup is left as it is,
      since a failed cleanup of a temporary directory does not change any
      result.
  - Sixth round (Codex, 2026-10-05): no blockers; three should-fixes and two
    nits, each confirmed:
    - `value: ""` under `reset` or `extend` is a file Yarn reads with every
      setting at its default, and the fifth-round fix refused it. Rather than
      copy which non-mapping values Yarn accepts and which it fails on, a
      marker holding anything but a mapping now carries nothing; for a file
      Yarn fails on, installing without settings the lockfile needed fails
      loudly. The Yarn comparison test covers both empty-string forms, and
      three files Yarn fails on — Yarn must fail on each, and the install's
      settings must stand.
    - Conditions that cannot be parsed threw out of `plan()`, failing the
      fetch before the deferred-error target existed. They are now reported
      with the entry's resolution; a `driver_test.js` case failed against the
      former code.
    - The comparison test now also asks Yarn for every one of the install's
      own settings in every case, against a baseline stated in the test, with
      non-empty architectures, and states what Yarn makes of the null-settings
      case: 15 configurations and 3 files Yarn fails on. Against the
      fifth-round `yarnrc.js`, the five new cases failed.
    - Nits: the counts are corrected; `--experimental_downloader_config` is
      the old name of Bazel 8.3.0's `--downloader_config`
      (RepositoryOptions.java), so the canonical name is used.
  - Seventh round (Codex, 2026-10-05): stopped at a usage limit before
    reporting. Of what it printed first, one escape was confirmed and fixed:
    a `packageManager` that is not a string threw out of the checks, before
    the deferred-error target existed. It is now reported, and anything else
    the checks cannot handle is reported as an error rather than thrown; a
    `driver_test.js` case failed against the former code. Its other note —
    that a document Yarn fails on now installs without its carried settings —
    is the sixth round's stated decision.
  - Seventh round, rerun over the whole change with the wiki (Codex,
    2026-10-05): not ready. Every finding was checked:
    - Installing with defaults where Yarn fails on the project's document
      (blocker, confirmed): the sixth-round argument that a missing setting
      makes the immutable install fail is false for `packageExtensions` —
      Yarn records an extension's dependencies only in the layout, and
      Codex showed dropping the e2e project's extension leaves its lockfile
      byte for byte the same. Withdrawn. The driver now has Yarn itself
      judge the project's carried settings at every install: `carriedFiles`
      writes the carried part in its own shape (`alone`) besides the layered
      file, and before installing the driver runs `yarn config get` for each
      carried setting on `alone` in a directory of its own and on the
      install's configuration; Yarn must accept the first, and both must
      agree, or the install is refused with Yarn's output. A new scenario
      shows a document Yarn cannot read refused; `yarnrc_yarn_test.js` shows
      Yarn failing on the carried part of each such document, and giving the
      same settings from it as from the whole file for four it accepts.
      design.md, yarnrc.js and the wiki no longer say immutability catches
      every missing setting; configuration outside the project — home,
      environment, plugins — is stated as a limit: what it changes only in the
      layout is not reproduced and not detected.
    - Malformed cache metadata and `bin: null` (blockers, confirmed): a
      non-string `__metadata.cacheKey` is reported by the checks, and the
      driver's entry point now turns anything either step throws into a
      reported error, so the pin target always survives; a driver test runs
      the driver as a process with a throwing install and requires
      `errors.json` and a normal exit. `layout.js` reads `bin` as Yarn's
      `Manifest.load` does — null, empty and non-string entries give
      nothing, a scoped key gives its name, backslashes become slashes; a new
      layout test failed against the former code.
    - Scenario output (should-fix): a failing case prints its whole build log.
    - Nits: the wiki's "absent for conditional packages entirely" is
      corrected in the regeneration; the count is 15 configurations and 3
      files Yarn fails on.
  - Eighth round (Codex, 2026-10-05, after two runs stopped at usage limits):
    no blockers. It confirmed the runtime Yarn check over the 15 accepted
    configurations and the 3 refused documents through Yarn's own
    `Configuration.find`, the driver's error boundary, the cache-key report,
    the bin port's null, array, scoped, empty, numeric and backslash cases,
    the full-log output and the counts, and all 243 wiki citations against
    the staged bytes. One should-fix, confirmed: a string `bin` of a package
    named `__proto__` gave no command, where Yarn gives one; it is now set
    as an own property, and a layout test failed against the former code.
    One nit: a wiki sentence still said a lockfile written with
    `packageExtensions` fails an immutable install without them; corrected in
    the final regeneration.
  - Narrow check of those two fixes (Codex, 2026-10-05): Yarn 4.18.0's
    `Manifest.load` and `binsOf` agree on 12 combinations of `__proto__`,
    `constructor`, `prototype`, scopes and bin forms, and no other sentence
    claims a missing setting always fails the install. It found the new test
    itself flawed — a `"__proto__"` key in an object literal sets the
    prototype instead of making a key, so the unscoped case was never
    exercised — and the test now builds its objects with `defineProperty`
    and covers string and mapping bins, scoped and not; restoring the former
    string branch fails it. The one stale wiki citation it named is the
    task list's, reconfirmed in the final regeneration once this record was
    written.

## 5. Reviews of the plan

- [x] 5.1 First review (v1, Codex): revise before implementation. Every
  blocker was confirmed — checksum coverage (`Cache.ts`), ancestor
  configuration (`findRcFiles`), `dependenciesMeta.built` overriding
  `enableScripts`, protocols needing staged inputs, host-selected installation,
  the output representation — and v1 was replaced rather than patched.
- [x] 5.2 Second review (v2, Codex): not ready. Confirmed and resolved: the
  project's `networkSettings` and proxies survive the gate and existing plugin
  files run (the project's file no longer reaches Yarn); OS/CPU pairs cross
  (the attribute is now Yarn's sets); archive link chains escape (links
  refused); patch and archive-URL parsing diverged from Yarn's (ported); the
  lockfile reader accepted plain scalars Yarn reads differently (writer grammar
  enforced, compared with js-yaml); pins and archives under-validated; scoped
  tarball spellings. Plan items — the layout contract, narrowed claims, the
  scale task, pin bootstrap, watch semantics, the testing table — are in
  design.md and above.
