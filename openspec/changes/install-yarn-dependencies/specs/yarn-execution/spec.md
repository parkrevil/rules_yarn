## MODIFIED Requirements

### Requirement: Declared support boundary

The documentation SHALL identify tested Bazel, Node.js, Yarn, and platform versions, SHALL state the oldest supported Bazel version, SHALL distinguish direct Yarn CLI execution, which carries no Bazel guarantees, from dependency installation through `yarn.install`, which fetches every registry package with a pinned integrity and lays them out as Bazel artifacts, and SHALL state what installation does not yet cover: running project scripts and build steps as Bazel actions, dependency build scripts, and the refused protocols.

#### Scenario: Consumer reads the usage guide
- **WHEN** a consumer follows the usage guide
- **THEN** it can identify the tested configuration and the oldest Bazel version the ruleset accepts, understands that arbitrary Yarn commands run through `yarn_binary` do not acquire Bazel caching, sandboxing, or dependency-installation guarantees, understands what `yarn.install` guarantees, and can find which project features installation does not yet support
