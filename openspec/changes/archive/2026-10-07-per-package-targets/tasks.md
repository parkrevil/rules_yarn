## 1. Plan

- [x] 1.1 A reviewer without this conversation reviews the plan before code;
  each finding is checked against documentation or a failing test and
  recorded here.
  - 2026-10-06: no blocker. Should-fixes, all taken:
    - The reason given for rejecting output groups was false: the reviewer
      built `OutputGroupInfo(**{"@babel/core": …})` on Bazel 8.3.0 and it was
      accepted. The design now rejects them because a group is not a
      target's files or runfiles.
    - Laziness is recorded as a run (the reviewer's, and this change's
      scenario and e2e tests), not only the documentation's sentence about
      requested files.
    - A target name outside Bazel's set would break the generated `BUILD`
      file: `layout.js` now refuses such a link, with a test that fails
      without the check.
    - How the parts reach the rule (`dependencies`, `dependency_bins`,
      `scopes`) and what a scope's target is (the union of its dependencies'
      parts) are stated.
    - `YarnNodeModulesInfo.root` of a workspace's dependency was the root's
      `node_modules`, where the link is not: it is now the `node_modules`
      directory holding the link, with an e2e test that fails with the root's;
      the verdict on keeping version 1 is stated.
    - The install-error case and the tarballs still fetched are stated as
      limits; the spec's requirement says a dependency's target, not a
      scope's, builds nothing it does not reach; scenarios added for a
      dependency on another workspace and a link outside the name set; the
      `.bin` collision and `esbuild`'s platform packages are stated.
  - Nits taken: the self-link of every store package asserted in
    `layout_test`; tasks added for the rule's doc, README, `tests/bcr` and
    the oldest-supported runs. `:node_modules` unchanged is covered by the
    existing requirement's scenarios, which all run against it.

## 2. Tests first

- [x] 2.1 `layout_test`: each direct dependency's store packages and `.bin`
  entries, for the root and a workspace, a scoped dependency, a shared
  package reached twice, a two-package cycle, a peer-dependency instance, a
  `.bin` collision, a link outside the target-name set and the self-link of
  every store package. Red: the four first tests failed with `dependencies`
  and `scopes` undefined, and the target-name test failed with the check
  disabled.
- [x] 2.2 `e2e/install`: `part_test_*` take only one dependency's target —
  `is-number` (patched, so archived), `packages/app`'s `react-dom` (a
  peer-dependency instance in a workspace), `typescript` (its `.bin/tsc`) —
  and check that the runfiles hold exactly the store packages it reaches;
  `provider_root_workspace_part_test` resolves `packages/lib`'s `is-number`
  through its target's `YarnNodeModulesInfo.root`. Red: with the part's
  files replaced by the whole tree, the three `part_test_*` failed; with the
  part's root replaced by the install's, the provider test failed.
- [x] 2.3 `install_scenarios.sh`: after removing the outputs, building one
  direct dependency's target builds only its packages' directories; the
  cycle between `cyc-a` and `cyc-b`; a scope's target. Red: without the
  implementation, the three cases failed with Bazel's "no such target
  '@@rules_yarn++yarn+npm//:node_modules/left'".

## 3. Implementation

- [x] 3.1 `layout.js` computes each direct dependency's store packages and
  `.bin` entries; `driver.js` records them in `layout.json`, version 3.
- [x] 3.2 `node_modules.bzl`: `yarn_node_modules` returns the parts in a
  private provider; `yarn_node_modules_part` returns one, with
  `YarnNodeModulesInfo`. Cite the Bazel documentation used.
- [x] 3.3 `repository.bzl` generates a target per direct dependency and per
  scope.
- [x] 3.4 `yarn/providers.bzl` documents what `files` and `root` hold for
  these targets; the `yarn_node_modules` doc string; README describes the
  targets and their limits.
- [x] 3.5 Measure the 717-entry project: size of the generated `BUILD`,
  analysis time of `:node_modules` before and after, and the files and build
  time of one dependency's target against the whole tree. Memory is not
  measured.
  - 2026-10-06, Linux x64, warm caches: the generated `BUILD` file grew from
    403 KB to 476 KB. `bazel build --nobuild @npm//:node_modules` from a
    stopped server took 8.05, 8.00 and 7.98 s before and 8.18, 7.92 and
    8.00 s after. After removing the outputs and analysing, building
    `:node_modules/react` took 0.36 s and wrote 3 store packages (339 KB),
    `:node_modules/typescript` 0.30 s and 1, `:node_modules/next` 0.81 s and
    29, and `:node_modules` 2.54 s and 732 (425 MB).

## 4. Gate

- [x] 4.1 Every root builds and tests, `tests/bcr` included;
  `install_scenarios.sh` passes; Bazel 8.3.0 for `e2e/smoke` and
  `e2e/install`; pre-commit; `openspec validate --all --strict`.
  - 2026-10-06: root 40/40, `e2e/smoke` 2/2, `e2e/install` 7/7, `tests/bcr`
    1/1; scenarios 39/39 (after the review's case below); under Bazel 8.3.0 with the lock off, `e2e/install`
    7/7 and `e2e/smoke` 2/2. CI's floor job now runs every `e2e/install`
    test but the network-blocking one, where it ran `installed_test` alone,
    so the new targets are checked at the floor. `tests/bcr` is left as it
    is: it builds a Yarn target through the public API and does not install.
- [x] 4.2 The wiki is regenerated and the staleness gate passes.
- [x] 4.3 A reviewer without this conversation reviews the change; each
  finding checked and recorded.
  - 2026-10-06: no blocker, no should-fix. Nits:
    - The name check let through `@foo` and `a/b`, which Yarn does not
      write but which would collide with a scope's target or get the wrong
      root: a dependency name is now `name` or `@scope/name`, as Yarn's
      `parseIdent` reads one, with a test that fails without the check.
    - The limit that a failed install declares no dependency's target had no
      run: a scenario now builds `:node_modules/left` after the install
      refuses a `.yarnrc.yml` and finds Bazel's "no such target".
    - "Dependency on another workspace" rests on `layout_test`
      (`packages/a`'s link to `packages/b` is no dependency's) and on a
      recorded query of `e2e/install`: its part targets are the six for
      store packages, none for `packages/app`'s `lib`.
    - "A link a target name cannot hold" rests on `layout_test`; the driver's
      entry point reports what the layout throws, as `driver_test` shows.
    - A scope's target and a workspace's `.bin` entries are covered by the
      scenarios and `layout_test`, not by `e2e/install`, whose project has
      neither a scoped direct dependency nor a workspace dependency with a
      `bin`; left as it is.
