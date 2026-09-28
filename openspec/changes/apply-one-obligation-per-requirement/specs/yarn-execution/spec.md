## REMOVED Requirements

### Requirement: Repository naming

**Reason**: The requirement states two obligations — who may choose a repository name, and which module's declaration decides the version. Either can be changed or withdrawn while the other still stands, so they are two promises under one name.

**Migration**: None for a consumer. Both obligations and all four scenarios continue below as `Repository naming authority` and `Version arbitration across modules`.

### Requirement: Command forwarding

**Reason**: The requirement states three obligations — that arguments reach Yarn unaltered, that Yarn's output streams reach the caller, and that Yarn's exit status is the executable's. Each is a promise a caller can rely on or lose without the others becoming meaningless.

**Migration**: None for a consumer. All three obligations continue below as `Argument forwarding`, `Output stream passthrough` and `Exit status propagation`. The `Failed command` scenario drops the clause about receiving Yarn's diagnostic output, because that is what `Output stream passthrough` promises and its own scenario asserts; the assertion moves rather than disappears.

## ADDED Requirements

### Requirement: Repository naming authority

Only the root module SHALL be able to choose a distribution repository name other than the default.

#### Scenario: Custom name in a dependency
- **WHEN** a non-root module declares a distribution with a repository name other than the default
- **THEN** configuration fails and identifies the module

### Requirement: Version arbitration across modules

For each repository name, the declaration from the module closest to the root in the dependency graph SHALL determine the version.

#### Scenario: Root module and dependency select different versions
- **WHEN** the root module and a dependency both declare the default repository with different versions
- **THEN** the repository provides the version declared by the root module

#### Scenario: Conflicting declarations in the deciding module
- **WHEN** the module that determines a repository declares that repository name with two different versions
- **THEN** configuration fails and identifies both versions

#### Scenario: Identical declarations
- **WHEN** a module declares the same repository name and version more than once
- **THEN** configuration succeeds and creates one repository

### Requirement: Argument forwarding

The executable SHALL forward the arguments supplied after `bazel run <target> --` to Yarn without shell re-interpretation.

#### Scenario: Argument preservation
- **WHEN** a caller supplies arguments containing spaces or shell metacharacters
- **THEN** Yarn receives the original argument boundaries and characters

### Requirement: Output stream passthrough

The executable SHALL preserve Yarn's standard output and standard error.

#### Scenario: Output streams
- **WHEN** the Yarn process writes to standard output and standard error
- **THEN** the caller receives each output on the same stream

### Requirement: Exit status propagation

The executable SHALL exit with the status Yarn exited with.

#### Scenario: Failed command
- **WHEN** Yarn rejects an invalid command with a nonzero exit status
- **THEN** the executable exits with that status
