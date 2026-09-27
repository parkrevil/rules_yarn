## Why

The ruleset does not tell a consumer what it needs, and leaves the consumer to
maintain a declaration the ruleset could maintain for them.

A consumer on Bazel 8.2.1 gets this, measured with a local override onto this
repository:

```
ERROR: .../yarn/private/repositories.bzl:30:26: An error occurred during the
fetch of repository 'rules_yarn++yarn+yarn':
  Error: 'repository_ctx' value has no field or method 'repo_metadata'
```

An error inside a private file of a ruleset they did not write, naming an API
they never called. Bazel 8.3.1 works — build, `bazel run`, and the built
launcher all report Yarn 4.18.0 — so a supported floor exists; the ruleset
simply never states it.

Separately, a consumer who forgets `use_repo(yarn, "yarn")` gets only
`No repository visible as '@yarn'`, and `bazel mod tidy` cannot help, because
the extension does not report which repositories the root module asked for.

## What Changes

- Declare the minimum Bazel version the ruleset supports, so a consumer below
  it is refused while the module graph is being resolved rather than inside a
  private implementation file.
- Report the repositories the root module declares, so Bazel's module tooling
  maintains the root module's `use_repo` line instead of the consumer.
- Add the minimum Bazel version to the tested-configuration table in README.

## Capabilities

### Modified Capabilities

- `yarn-execution`: `Bzlmod consumer integration` gains what the ruleset owes
  a consumer about its own requirements; `Declared support boundary` gains the
  minimum Bazel version.

## Impact

- `MODULE.bazel` — a `bazel_compatibility` declaration. This is a pin under
  AGENTS.md's "Changing a pin", so both lockfiles are re-resolved and the
  result recorded.
- `yarn/private/extensions.bzl` — the extension reports its root
  repositories. The reporting has to distinguish a development-only usage
  from a regular one, because this repository's own root module uses the
  extension as a development dependency.
- `tests/extensions/` — coverage for that distinction.
- `README.md` — the tested-configuration table.
- No change to what the launcher does or to the public API's shape.
