rules_yarn is a set of Bazel rules for integrating Yarn.

- Plan before code: create an OpenSpec change first; any behavior that can be implemented and verified on its own is its own task.
- One change = one branch, named after the change.
- Versions are pinned in `MODULE.bazel`, `.bazelversion`, and `yarn/private/versions.bzl`. Before adding or changing a pin, verify that the version exists in every source the build resolves it from, the registry included, and record the URLs you checked in the OpenSpec change.
- Fetch external artifacts by exact version with an integrity digest. Never resolve a build dependency from a host-installed tool.
- Before writing or changing Starlark, verify every API, provider, and toolchain field you use against the official documentation or source of the ruleset that defines it, at the version this repo pins, and read an applicable official ruleset example; cite both in the OpenSpec change. Use no deprecated or experimental APIs.
- No `eval` and no dynamically assembled shell command strings. Do not compensate for an unavailable pinned release or a missing API with an override or implementation that consumers must copy; stop and report instead.
- Claim behavior only when a test or a recorded run shows it. Supported platform: Linux x86_64.
- Before implementing new or changed behavior, write the test for its spec scenario and confirm it fails for the stated reason; for unchanged scenarios, point at the tests that already cover them.
- Public Starlark API lives in `yarn/` outside `yarn/private/`; private implementation in `yarn/private/`; tests in `tests/`; the consumer example in `e2e/smoke/`.
- Never hand-edit `openspec/specs/` (archive writes it) or `openwiki/` (run `openwiki --update`).
- Complete one task at a time. For each: `bazel build //... && bazel test //...` must pass in the root and in `e2e/smoke/`, then a Codex reviewer without the implementation conversation adversarially reviews every change in that task, staged, unstaged, and untracked. Check each finding against the official documentation or a test that demonstrates it, fix what holds, record why you rejected the rest, and repeat the checks and the review after each fix until no supported finding remains. Commit exactly what passed, then start the next task. Before archiving, run `/opsx:verify` and have a reviewer without the implementation conversation review the whole change, resolved the same way.
