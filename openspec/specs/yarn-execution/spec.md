# yarn-execution Specification

## Purpose
Allow a Bazel consumer to select and execute a reproducible Yarn distribution without installing Node.js or Yarn on the host.

## Requirements

### Requirement: Explicit distribution selection

Each Yarn distribution SHALL be identified by an exact supported version and a recorded content digest. Configuration SHALL NOT select an implicit latest version.

#### Scenario: Selected version
- **WHEN** a consumer configures a supported version and runs the resulting target with `--version`
- **THEN** the reported version matches the configured version

#### Scenario: Unsupported version
- **WHEN** a consumer requests a version absent from the supported distribution metadata
- **THEN** configuration fails with an error that names the requested version and lists the supported versions

#### Scenario: Integrity mismatch
- **WHEN** fetched distribution bytes do not match the recorded digest
- **THEN** repository fetching fails before the distribution can execute

### Requirement: Repository naming

Only the root module SHALL be able to choose a distribution repository name other than the default. For each repository name, the declaration from the module closest to the root in the dependency graph SHALL determine the version.

#### Scenario: Custom name in a dependency
- **WHEN** a non-root module declares a distribution with a repository name other than the default
- **THEN** configuration fails and identifies the module

#### Scenario: Root module and dependency select different versions
- **WHEN** the root module and a dependency both declare the default repository with different versions
- **THEN** the repository provides the version declared by the root module

#### Scenario: Conflicting declarations in the deciding module
- **WHEN** the module that determines a repository declares that repository name with two different versions
- **THEN** configuration fails and identifies both versions

#### Scenario: Identical declarations
- **WHEN** a module declares the same repository name and version more than once
- **THEN** configuration succeeds and creates one repository

### Requirement: Managed runtime

The executable SHALL use the Bazel-managed Node.js runtime and the selected Yarn distribution on each documented supported platform. It SHALL NOT fall back to host Node.js, Yarn, or Corepack executables, and project Yarn configuration SHALL NOT redirect it to a different Yarn binary.

#### Scenario: No host installation
- **WHEN** a consumer runs `--version` with a `PATH` whose `node`, `yarn`, and `corepack` entries are unusable
- **THEN** the target reports the selected Yarn version successfully

#### Scenario: Project yarnPath
- **WHEN** the target runs in a project whose Yarn configuration sets `yarnPath` to another script
- **THEN** the selected distribution runs instead of that script

#### Scenario: Host path runtime
- **WHEN** the resolved Node.js runtime toolchain provides only a host path instead of a Bazel-managed file
- **THEN** analysis fails with an error stating that a file-backed Node.js runtime is required

### Requirement: Command forwarding

The executable SHALL forward the arguments supplied after `bazel run <target> --` to Yarn without shell re-interpretation and preserve Yarn's standard output, standard error, and exit status.

#### Scenario: Argument preservation
- **WHEN** a caller supplies arguments containing spaces or shell metacharacters
- **THEN** Yarn receives the original argument boundaries and characters

#### Scenario: Output streams
- **WHEN** the Yarn process writes to standard output and standard error
- **THEN** the caller receives each output on the same stream

#### Scenario: Failed command
- **WHEN** Yarn rejects an invalid command with a nonzero exit status
- **THEN** the executable exits with that status and the caller receives Yarn's diagnostic output

### Requirement: Working directory

When run with `bazel run`, Yarn SHALL run in the directory from which Bazel was invoked. When the executable is invoked directly, Yarn SHALL run in the caller's current directory.

#### Scenario: bazel run from a subdirectory
- **WHEN** a consumer runs the target with `bazel run` from a subdirectory of the workspace
- **THEN** Yarn's working directory is that subdirectory

#### Scenario: Direct invocation
- **WHEN** a caller executes the built target directly without `bazel run`
- **THEN** Yarn's working directory is the caller's current directory

### Requirement: Self-contained version execution

After required repositories have been fetched, running the target with `--version` SHALL require no network access and SHALL NOT create or modify consumer manifests, lockfiles, or dependency installations.

#### Scenario: Offline version check
- **WHEN** `--version` runs with fetched tool repositories and network access disabled
- **THEN** it succeeds without changing the consumer's project files

### Requirement: Declared support boundary

The documentation SHALL identify tested Bazel, Node.js, Yarn, and platform versions, SHALL state the oldest supported Bazel version, and SHALL distinguish direct Yarn CLI execution from Bazel dependency-installation or build integration.

#### Scenario: Consumer reads the usage guide
- **WHEN** a consumer follows the usage guide
- **THEN** it can identify the tested configuration and the oldest Bazel version the ruleset accepts, and understands that arbitrary Yarn commands do not acquire Bazel caching, sandboxing, or dependency-installation guarantees from this executable

### Requirement: Public API surface

The ruleset SHALL expose a documented Bzlmod configuration and a public executable rule that an independent consumer module can use without loading private implementation files. Private implementation files SHALL NOT be loadable from consumer modules.

#### Scenario: Independent consumer
- **WHEN** a separate module follows the documented setup with a local override pointing to this ruleset
- **THEN** it can build and run a Yarn target using only the public API

#### Scenario: Private implementation file
- **WHEN** a consumer module loads a `.bzl` file from the ruleset's private package
- **THEN** loading fails with a visibility error

### Requirement: Declared Bazel compatibility

The ruleset SHALL declare the oldest Bazel version it supports, so that a consumer using an older one is refused while the module graph is resolved rather than by an error raised inside the ruleset's implementation.

#### Scenario: Bazel older than the declared minimum
- **WHEN** a consumer resolves the module graph with a Bazel version below the declared minimum
- **THEN** resolution fails with an error naming the ruleset and the version it requires, and no error is raised from inside the ruleset's files

#### Scenario: Bazel at the declared minimum
- **WHEN** a consumer resolves and builds with the declared minimum Bazel version
- **THEN** the Yarn target builds and reports the selected Yarn version

### Requirement: Repository declaration reporting

The distribution extension SHALL report the repositories the root module asked it to create, distinguishing a development-only declaration from a regular one, so that Bazel's module tooling can maintain the root module's repository declarations.

#### Scenario: Repository declaration left out
- **WHEN** the root module declares a distribution but not the repository the extension creates for it
- **THEN** `bazel mod tidy` adds the missing declaration, matching how the root module declared the extension
