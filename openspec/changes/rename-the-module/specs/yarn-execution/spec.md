## ADDED Requirements

### Requirement: Module name

The ruleset SHALL be the Bazel module `parkrevil_rules_yarn`. A consumer that depends on it under that name SHALL be able to build Yarn targets and install dependencies without declaring any other name for the ruleset. Each release SHALL tell consumers to depend on it under that name, and SHALL be offered to the registry under it.

#### Scenario: Yarn target under the module name
- **WHEN** a consumer module depends on `parkrevil_rules_yarn` and declares a distribution and a Yarn target through `@parkrevil_rules_yarn//yarn:extensions.bzl` and `@parkrevil_rules_yarn//yarn:defs.bzl`
- **THEN** the target builds and reports the selected Yarn version

#### Scenario: Installation under the module name
- **WHEN** a consumer module that depends on `parkrevil_rules_yarn` and on no module named `rules_yarn` declares `yarn.install` and builds the installed dependencies and the pin target
- **THEN** both build

#### Scenario: Release notes
- **WHEN** a release's notes are generated
- **THEN** the `bazel_dep` and the override they show name the module `parkrevil_rules_yarn`

#### Scenario: Registry entry
- **WHEN** a release is offered to the registry
- **THEN** the registry pull request adds the release under `modules/parkrevil_rules_yarn/`
