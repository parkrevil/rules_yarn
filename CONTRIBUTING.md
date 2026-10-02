# Contributing

The working rules are in [AGENTS.md](AGENTS.md). They are short, and they are
the actual conditions for a change to be accepted, not a style guide. Read
them before writing anything.

## What a change looks like

1. Plan it in OpenSpec: `openspec new change <name>`, then the proposal,
   design and task artifacts. One change, one branch named after it.
2. Write the test for the behaviour first and watch it fail for the reason you
   expect.
3. Implement, then record under each task how it was verified — a command and
   its output, not an assertion that it works.
4. Run the gate: `bazel build //... && bazel test //...` in the root, in
   `e2e/smoke/` and in `tests/bcr/`, plus `pre-commit run --all-files`.
5. Have someone who did not write it review it, check each finding against
   documentation or a failing test, and commit only what passed.

## What gets rejected

- A claim with no test or recorded run behind it.
- An external artifact fetched by anything other than an exact version with an
  integrity digest.
- A Bazel or ruleset API used without checking it against that ruleset's own
  documentation or source at the pinned version.
- A defect written into a risk list instead of being fixed. A risk records what
  the approach cannot do, not what you chose not to do.

## Adding a Yarn version

Add the version and its digest to `yarn/private/versions.bzl`. The digest must
be checked against an upstream record — `bin/yarn.js` in the
`@yarnpkg/cli-dist` npm tarball, or the hash for that version in Corepack's
`config.json` — and the check recorded in the change.

## Setup

```shell
pre-commit install          # also installs the commit-message hook
bazel test //...            # the root
(cd e2e/smoke && bazel test //...)
(cd tests/bcr && bazel test //...)
```

`jq` is needed by the generated-file guard in `tools/hooks/`, and `buildifier`
by pre-commit.
