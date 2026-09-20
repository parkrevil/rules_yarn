rules_yarn is a set of Bazel rules for integrating Yarn. Supported platform: Linux x86_64.

# Invariants

- External artifacts are fetched by exact version with an integrity digest, never resolved from a host-installed tool. The Node.js runtime is a Bazel-managed file.
- Public Starlark API lives in `yarn/` outside `yarn/private/`; tests in `tests/`; the consumer example in `e2e/smoke/`.
- Behavior is claimed only from a test or a recorded run.
- When a pinned release or a supported API is missing, stop and report. Never ship an override that consumers must copy.
- No `eval`, no dynamically assembled shell command strings, no deprecated or experimental APIs.

# Working rules

- Plan in OpenSpec before code; any behavior that can be verified on its own is its own task.
- One change = one branch named after it.
- Before implementing new or changed behavior, write its spec-scenario test and watch it fail for the stated reason.
- Before using an API, provider, or toolchain field, check it against the documentation or source of the ruleset that defines it at the pinned version, and cite that in the change.
- Pins live in `MODULE.bazel`, `.bazelversion`, and `yarn/private/versions.bzl`. Before changing one, confirm the version exists in every source the build resolves it from, and record the URLs in the change.
- Per task: `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke/`, a reviewer without the implementation conversation reviews every change in the task, each finding is checked against documentation or a failing test, and only what passed is committed.
- Never hand-edit `openspec/specs/` (archive writes it) or `openwiki/` (run `openwiki --update`).
