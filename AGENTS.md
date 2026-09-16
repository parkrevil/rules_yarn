# Project
rules_yarn is a set of Bazel rules for integrating Yarn.

# Rules
- Plan before code: create an OpenSpec change first, implement from its tasks.
- One change = one branch, named after the change.
- Pinned: Bazel 9.2.0, Yarn 4.18.0, rules_nodejs 6.7.6. To change a version, check its release page and record what you checked.
- Fetch external artifacts by exact version with an integrity digest. Never detect installed tools.
- Follow the official Bazel documentation and the patterns of official rulesets; cite what you followed. No deprecated APIs.
- No workarounds. No `eval`, no reassembled shell strings. If no supported API exists, stop and report.
- Claim only what is tested. Supported platform: Linux x86_64.
- Public API lives in `yarn/`; everything else in `yarn/private/`.
- Never hand-edit `openspec/specs/` (archive writes it) or `openwiki/` (run `openwiki --update`).
- Before finishing: `buildifier -lint=warn -r .`, `bazel build //... && bazel test //...` in the root and in `e2e/`, `openspec validate --all --strict`.
- Review order after implementation: `/opsx:verify` for spec compliance, then Codex adversarial review for the approach.
