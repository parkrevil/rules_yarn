## REMOVED Requirements

### Requirement: Repository naming

**Reason**: The requirement states two obligations — who may choose a repository name, and which module's declaration decides the version. Either can be changed or withdrawn while the other still stands, so they are two promises under one name.

**Migration**: None for a consumer. Both obligations and all four scenarios continue below as `Repository naming authority` and `Version arbitration across modules`.

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
