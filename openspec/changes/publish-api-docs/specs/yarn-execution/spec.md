## ADDED Requirements

### Requirement: Published API reference

Every rule, module extension, tag class, provider, attribute and field the ruleset's public `.bzl` files export SHALL carry documentation, extracted by Bazel's `starlark_doc_extract`, and each release SHALL publish that documentation as an archive the registry entry links through `docs_url`.

#### Scenario: Public API documented in full
- **WHEN** the documentation of the public `.bzl` files is extracted
- **THEN** `yarn_binary`, the `yarn` extension with its `distribution` and `install` tags, and `YarnNodeModulesInfo` are present, and each of them and each of their attributes and fields has a non-empty doc string

#### Scenario: Release documentation archive
- **WHEN** the release's documentation script runs
- **THEN** it writes an archive holding the extracted documentation of each public `.bzl` file, and writes nothing to the release notes

#### Scenario: Registry link
- **WHEN** a release is offered to the registry
- **THEN** its `source.json` links the release's documentation archive as `docs_url`
