# rules_yarn

Bazel rules that deliver the Yarn CLI and install Yarn projects' locked dependencies. Linux and macOS. Public API lives in `yarn/` outside `yarn/private/`; tests in `tests/`; the consumer examples in `e2e/smoke/` and `e2e/install/`; the module the registry presubmit runs in `tests/bcr/`.

## Always

- Claim behavior only from a test or a recorded run.
- Fetch every external artifact by exact version with an integrity digest, never from a host-installed tool.
- Check any Bazel or ruleset API against the defining ruleset's documentation or source at the pinned version, and cite that in the change. Nothing deprecated or experimental.
- Stop and report when a pinned release or API is missing. Never ship a workaround consumers must copy into their own module.
- Keep `yarn/private/yarn_binary.sh.tpl` the only generated script. `shell.quote` each substituted value that lands in a shell word; leave the `#!` interpreter path unquoted, since quoting it makes the kernel reject the launcher. No `eval`, no shell command assembled at run time.
- Never hand-edit `openspec/specs/` (archive writes it) or `openwiki/` (`openwiki --update` regenerates it; page bodies are written only during a run).

## Before code

- Plan in OpenSpec. One change, one branch named after it.
- Write the spec-scenario test first and watch it fail for the stated reason.

## Changing a pin

Pins are `MODULE.bazel`, `MODULE.bazel.lock`, `.bazelversion`, `yarn/private/versions.bzl` (a Yarn version's digest and its cache version), the `MODULE.bazel`, `MODULE.bazel.lock` and `.bazelversion` of `e2e/smoke/` and of `e2e/install/`, `e2e/install/`'s `yarn.lock` and `yarn_pins.json`, and `tests/bcr/MODULE.bazel`. `tests/bcr/` keeps no lockfile on purpose — the registry presubmit runs it under several Bazel versions and a pinned lock would defeat that — and its own `.bazelrc` sets `--lockfile_mode=off` so Bazel does not write one.

- Confirm the version exists in every source the build resolves it from, and record the URLs in the change.
- Run `bazel mod deps --lockfile_mode=update` in the root, in `e2e/smoke/` and in `e2e/install/`, then commit the locks. Each of those roots sets `--lockfile_mode=error`, so a stale lock fails that root's build. After changing `e2e/install/`'s dependencies, regenerate its `yarn.lock` with the pinned Yarn and its pins with `bazel run @npm//:pin`.

## Before commit

- `bazel build //... && bazel test //...` passes in the root, in `e2e/smoke/`, in `e2e/install/` and in `tests/bcr/`, and `tools/ci/install_scenarios.sh` passes; `.bazelignore` keeps the other roots out of the root run.
- A reviewer without the implementation conversation reviews the change; check each finding against documentation or a failing test; commit only what passed. This holds for every commit, including one that changes this file.
- Fix what the change is for, rather than recording it. A risk or a known limit states what the approach cannot do; it is not a place to put what you chose not to do. Say which one it is. A defect outside the change gets reported, and its own change.
- When the change states a rule, apply it to everything that change touches, not only where a linter or a reviewer pointed, and record the verdict for each — including what you leave as it is.
- Regenerate the wiki when the change touches anything `openwiki/.claims` cites, and commit it with the change. `tools/hooks/openwiki_staleness.sh` recomputes each citation's digest and names what no longer matches; it runs at `pre-push`. Nothing regenerates the wiki on a schedule: the `## OpenWiki` section below says a workflow does, but that paragraph is written by the generator and the workflow it names was removed, because it needed a model API key this repository does not hold.

<!-- OPENWIKI:START -->

## OpenWiki

This repository has a generated `openwiki/` evidence index. It is optional just-in-time context, not required startup reading.

- Treat source code and tests as authoritative. A brief's unknowns and review items are verification gaps, not automatic requirements.
- Prefer the narrowest quiet validation that proves the changed behavior. Preserve complete failure output.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
