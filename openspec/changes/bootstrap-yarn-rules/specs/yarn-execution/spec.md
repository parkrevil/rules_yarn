## Purpose

Allow a Bazel consumer to select and execute a reproducible Yarn distribution without installing Node.js or Yarn on the host.

## ADDED Requirements

### Requirement: Bzlmod consumer integration

The ruleset SHALL expose a documented Bzlmod configuration and public executable rule usable from an independent consumer module without loading private implementation files.

#### Scenario: Independent consumer
- **WHEN** a separate module follows the documented setup with a local override pointing to this ruleset
- **THEN** it can build and run a Yarn target using the public API

### Requirement: Explicit distribution selection

Each Yarn distribution SHALL be identified by an exact supported version and verified content digest. Configuration SHALL reject unknown versions or conflicting definitions for the same repository name instead of selecting an implicit latest version.

#### Scenario: Selected version
- **WHEN** a consumer configures a supported version and runs the resulting target with `--version`
- **THEN** the reported version matches the configured version

#### Scenario: Unsupported version
- **WHEN** a consumer requests a version absent from the supported distribution metadata
- **THEN** configuration fails with an actionable unsupported-version error

#### Scenario: Conflicting selection
- **WHEN** different declarations assign different versions to the same generated repository name
- **THEN** configuration fails and identifies the conflict

#### Scenario: Integrity mismatch
- **WHEN** fetched distribution bytes do not match the recorded digest
- **THEN** repository fetching fails before the distribution can execute

### Requirement: Managed runtime

The executable SHALL use Bazel-managed Node.js and Yarn files on each documented supported platform. It SHALL NOT fall back to host Node.js, Yarn, or Corepack executables.

#### Scenario: No host installation
- **WHEN** a consumer runs `--version` without Node.js, Yarn, or Corepack available on PATH
- **THEN** the target reports the selected Yarn version successfully

### Requirement: Command forwarding

The executable SHALL forward the arguments supplied after `bazel run <target> --` to Yarn without shell re-interpretation and preserve Yarn's output streams and exit status.

#### Scenario: Argument preservation
- **WHEN** a caller supplies arguments containing spaces or shell metacharacters
- **THEN** Yarn receives the original argument boundaries and characters

#### Scenario: Failed command
- **WHEN** Yarn rejects an invalid command with a nonzero exit status
- **THEN** the launcher exposes that failure and Yarn's diagnostic output

### Requirement: Self-contained version execution

After required repositories have been fetched, running the target with `--version` SHALL require no network access and SHALL NOT create or modify consumer manifests, lockfiles, or dependency installations.

#### Scenario: Offline version check
- **WHEN** `--version` runs with fetched tool repositories and network access disabled
- **THEN** it succeeds without changing the consumer's project files

### Requirement: Declared support boundary

The documentation SHALL identify tested Bazel, Node.js, Yarn, and platform versions and distinguish direct Yarn CLI execution from Bazel dependency-installation or build integration.

#### Scenario: Consumer reads the usage guide
- **WHEN** a consumer follows the usage guide
- **THEN** it can identify the tested configuration and understands that arbitrary Yarn commands do not acquire Bazel caching, sandboxing, or dependency-installation guarantees from this launcher
