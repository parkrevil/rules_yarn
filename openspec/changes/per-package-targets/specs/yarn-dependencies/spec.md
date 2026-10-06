## ADDED Requirements

### Requirement: Targets per direct dependency

Each direct dependency of the project root and of each workspace that resolves to an installed package SHALL be a target of the install repository, named after the link Yarn writes for it, holding that link, the installed packages it reaches through Yarn's links, their links and the `.bin` entries the install gives it, and carrying `YarnNodeModulesInfo` whose root is the `node_modules` directory that link is in; each scope among them SHALL be a target holding its packages' parts; and building a direct dependency's target SHALL build no package it does not reach, whatever cycles the packages' dependencies form.

#### Scenario: Only the dependency's packages
- **WHEN** a test takes a direct dependency's target as runfiles and requires that dependency
- **THEN** the test succeeds, and its runfiles hold no installed package that dependency does not reach

#### Scenario: Only the dependency's packages are built
- **WHEN** a build with no outputs yet builds one direct dependency's target
- **THEN** the directories of the packages it reaches are built, and no other package's directory is

#### Scenario: Dependency cycle
- **WHEN** two installed packages depend on each other and one of them is a direct dependency of the root
- **THEN** its target holds both packages, and requiring it succeeds

#### Scenario: Scope
- **WHEN** the root depends directly on two packages of one scope
- **THEN** the scope's target holds both packages

#### Scenario: Workspace dependency
- **WHEN** a workspace depends directly on an installed package
- **THEN** the target named after that workspace's link holds that package, and an action given the target's `YarnNodeModulesInfo` finds the package under its root

#### Scenario: Dependency on another workspace
- **WHEN** a workspace depends directly on another workspace
- **THEN** that dependency has no target

#### Scenario: Executables of the dependency
- **WHEN** a direct dependency declares a `bin`
- **THEN** its target holds the `.bin` entry the install gives it, and that entry runs the dependency's executable

#### Scenario: A link a target name cannot hold
- **WHEN** a direct dependency's link holds a character a Bazel target name cannot
- **THEN** fetching fails and names the link
