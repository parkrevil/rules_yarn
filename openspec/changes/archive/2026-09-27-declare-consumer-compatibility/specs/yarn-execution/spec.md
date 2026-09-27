## MODIFIED Requirements

### Requirement: Bzlmod consumer integration

The ruleset SHALL expose a documented Bzlmod configuration and a public executable rule that an independent consumer module can use without loading private implementation files. Private implementation files SHALL NOT be loadable from consumer modules.

The ruleset SHALL declare the oldest Bazel version it supports, so that a consumer using an older one is refused while the module graph is resolved rather than by an error raised inside the ruleset's implementation.

The distribution extension SHALL report the repositories the root module asked it to create, distinguishing a development-only declaration from a regular one, so that Bazel's module tooling can maintain the root module's repository declarations.

#### Scenario: Independent consumer
- **WHEN** a separate module follows the documented setup with a local override pointing to this ruleset
- **THEN** it can build and run a Yarn target using only the public API

#### Scenario: Private implementation file
- **WHEN** a consumer module loads a `.bzl` file from the ruleset's private package
- **THEN** loading fails with a visibility error

#### Scenario: Bazel older than the declared minimum
- **WHEN** a consumer resolves the module graph with a Bazel version below the declared minimum
- **THEN** resolution fails with an error naming the ruleset and the version it requires, and no error is raised from inside the ruleset's files

#### Scenario: Bazel at the declared minimum
- **WHEN** a consumer resolves and builds with the declared minimum Bazel version
- **THEN** the Yarn target builds and reports the selected Yarn version

#### Scenario: Repository declaration left out
- **WHEN** the root module declares a distribution but not the repository the extension creates for it
- **THEN** `bazel mod tidy` adds the missing declaration, matching how the root module declared the extension

### Requirement: Declared support boundary

The documentation SHALL identify tested Bazel, Node.js, Yarn, and platform versions, SHALL state the oldest supported Bazel version, and SHALL distinguish direct Yarn CLI execution from Bazel dependency-installation or build integration.

#### Scenario: Consumer reads the usage guide
- **WHEN** a consumer follows the usage guide
- **THEN** it can identify the tested configuration and the oldest Bazel version the ruleset accepts, and understands that arbitrary Yarn commands do not acquire Bazel caching, sandboxing, or dependency-installation guarantees from this executable
