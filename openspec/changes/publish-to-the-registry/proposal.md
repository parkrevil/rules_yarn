## Why

An enterprise cannot adopt this ruleset, and the reason is not its code. It is
not in the Bazel Central Registry, so `bazel_dep` does not resolve it; a
consumer needs a non-registry override, and an override only takes effect in
the root module. Measured: a module that depends on `rules_yarn` and is itself
depended on fails with

```
in module dependency chain <root> -> mylib@_ -> rules_yarn@_:
bad bazel_dep on module 'rules_yarn' with no version.
```

so every root module downstream has to repeat the override. AGENTS.md calls
that out as something never to ship — "Never ship a workaround consumers must
copy into their own module" — and right now the ruleset is that workaround.

There is also nothing to pin: no tag, no release, and `module()` carries no
version. An organisation that adopts a ruleset pins it and upgrades on its own
schedule; neither is possible.

## What Changes

Everything needed to publish, following the registry's own documented path and
the arrangement `rules_shell` uses, which this ruleset already depends on:

- `module()` gains the `version = "0.0.0"` placeholder. The real version lives
  in the registry entry, which `publish-to-bcr` supplies as a generated patch
  over the released archive.
- `.bcr/` — `metadata.template.json`, `source.template.json`, `presubmit.yml`
  and `config.yml`, the four files the publishing automation reads.
- `tests/bcr/` — the module the registry presubmit runs. Separate from
  `e2e/smoke`, which pins a lockfile; a presubmit runs several Bazel versions
  and a pinned lock would defeat that.
- `.github/workflows/release.yml` and `release_prep.sh` — a tag cuts a release
  carrying an archive the ruleset builds itself, because the registry checks
  that a GitHub source-archive URL is stable and the generated ones are not.
- `.github/workflows/publish.yaml` — calls the registry's own reusable
  publishing workflow.
- `.gitattributes` — keeps the development tooling and the planning record out
  of the published archive.
- `README.md` leads with the registry form and says plainly where that stands.
- `CONTRIBUTING.md`, `SECURITY.md`.
- `AGENTS.md` — a third build root and a third set of pins now exist.

## Capabilities

### Modified Capabilities

None. How the module is distributed is not behaviour the specification
describes; the rules do the same thing. `.openspec.yaml` sets
`skip_specs: true`.

## Impact

- New `.bcr/`, `tests/bcr/`, `.gitattributes`, `CONTRIBUTING.md`,
  `SECURITY.md`, two workflow files and a release script.
- `MODULE.bazel`, `.bazelignore`, `.gitignore`, `README.md`, `AGENTS.md`.
- No rule, no public API, no Yarn or Node.js pin changes.

## Out of scope, and stated so it is not mistaken for done

- **Publishing.** Two steps cannot be done from here: installing the
  publishing app or creating the `BCR_PUBLISH_TOKEN` secret and the registry
  fork it pushes to, and the pull request against
  `bazelbuild/bazel-central-registry`. This change prepares and verifies
  everything up to them.
- **Scope of the ruleset.** It delivers the Yarn CLI. Turning `yarn install`
  into a Bazel action, translating `yarn.lock` into targets, and
  `node_modules` or Plug'n'Play integration remain outside it, as README's
  Scope section says. Publishing does not change that, and nothing here
  pretends it does.
- **Windows**, and more than one Yarn version in the table.
