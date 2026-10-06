## Why

The ruleset's public API — `yarn_binary`, the `yarn` module extension and its
`distribution` and `install` tags, and `YarnNodeModulesInfo` — is documented
only in its `doc` strings and the README. The Bazel Central Registry renders a
module's API reference at registry.bazel.build from an archive of
`stardoc_output.ModuleInfo` protos that the module's `source.json` links
through `docs_url` (`docs/README.md` and `docs/stardoc.md` of
bazelbuild/bazel-central-registry), and `rules_js` publishes one with every
release (`.bcr/source.template.json` and `.github/workflows/release_docs.sh`
at v3.5.1). This ruleset publishes none, and nothing checks that every public
attribute and field carries documentation.

## What Changes

- A `starlark_doc_extract` target for each public `.bzl` file —
  `yarn/defs.bzl`, `yarn/extensions.bzl`, `yarn/providers.bzl` — on its
  `bzl_library`, so extraction also checks that the library declares every
  file it loads.
- A test that every rule, extension, tag class, provider, attribute and field
  of the public API carries a non-empty doc string.
- The release builds an archive of the extracted protos beside the source
  archive, as the registry's guide shows, and `.bcr/source.template.json`
  links it as `docs_url`; CI builds that archive on every push.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `yarn-execution`: a requirement that the public API is documented in full
  and that each release publishes that documentation for the registry.

## Impact

- `yarn/BUILD.bazel`, a test under `tests/`, `.github/workflows/release_prep.sh`
  and a new `release_docs.sh` beside it, `.github/workflows/ci.yml`,
  `.bcr/source.template.json`, README and the wiki.
