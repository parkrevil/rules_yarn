# yarn-dependencies Specification

## Purpose
Install a Yarn project's locked dependencies as Bazel artifacts, every registry package fetched by Bazel with a pinned integrity and laid out by the pinned Yarn offline, isolated from the host, so that builds and tests can take the installed tree as an input.

## Requirements

### Requirement: Pinned acquisition

Every package that comes from a registry SHALL be fetched by Bazel's downloader with the integrity the pin file records for it.

#### Scenario: Integrity mismatch
- **WHEN** the pin file records an integrity that does not match the tarball the registry serves
- **THEN** fetching fails and names the package

#### Scenario: Cold fetch from the repository cache
- **WHEN** a fresh output base fetches the install with a repository cache already holding every tarball, and Bazel's downloader configuration blocks the registry host
- **THEN** fetching succeeds

#### Scenario: Credentials from a credential helper
- **WHEN** the registry requires credentials and Bazel is given a credential helper that supplies them
- **THEN** fetching succeeds, and without the helper it fails

### Requirement: Pin file coverage

The pin file SHALL record every `npm:` entry of the lockfile, including conditional packages for every platform, and installation SHALL fail when it does not match the lockfile.

#### Scenario: Regenerating the pin file
- **WHEN** a consumer runs the install's pin target against a lockfile with platform-specific optional packages
- **THEN** the pin file records a tarball URL and integrity for every `npm:` entry, including the packages for platforms other than the host

#### Scenario: Stale pin file
- **WHEN** the lockfile holds an `npm:` entry the pin file does not record, or the pin file records one the lockfile does not hold
- **THEN** fetching fails, names the entry, and names the command that regenerates the pin file

#### Scenario: First pin
- **WHEN** a consumer declares an install whose pin file is missing or empty and runs the install's pin target
- **THEN** the pin target runs, writes a pin file covering the lockfile, and the install then succeeds

### Requirement: Lockfile-exact installation

Installing a project SHALL produce exactly the dependency versions its `yarn.lock` records, and SHALL fail rather than change the lockfile.

#### Scenario: Installed version
- **WHEN** a test requires an installed dependency and prints its `package.json` version
- **THEN** the printed version is the one the lockfile records

#### Scenario: Lockfile out of date
- **WHEN** the project's `package.json` declares a dependency the lockfile does not resolve
- **THEN** fetching fails, and the error says the lockfile would have to be modified

### Requirement: Lockfile checksums

A package whose lockfile entry records a checksum SHALL match it, including a patched package.

#### Scenario: Checksum mismatch
- **WHEN** the lockfile records a checksum that does not match the package Yarn produces from the verified tarball
- **THEN** fetching fails and names the package

#### Scenario: Built-in patch
- **WHEN** a project depends on a package the pinned Yarn patches by default, such as `typescript`
- **THEN** installation succeeds and the installed package is the patched one the lockfile records

### Requirement: Supported lockfiles and protocols

Installation SHALL accept a lockfile written by Yarn 2 or later whose cache key matches the selected distribution's, with entries resolved through `npm:`, `patch:` or `workspace:`, and SHALL refuse anything else before installing, naming what it refuses.

#### Scenario: Unsupported protocol
- **WHEN** the lockfile holds an entry resolved through `git:`, `exec:`, `file:`, `link:`, `portal:`, a tarball URL, or an `npm:` entry carrying its own archive URL
- **THEN** fetching fails and names the entry and its protocol

#### Scenario: Yarn 1 lockfile
- **WHEN** the lockfile was written by Yarn 1
- **THEN** fetching fails and says the lockfile is a Yarn 1 lockfile

#### Scenario: Different Yarn
- **WHEN** the project's `packageManager` names a Yarn version other than the selected distribution's, or the lockfile's cache key differs from the selected distribution's
- **THEN** fetching fails and names both

#### Scenario: Patch file
- **WHEN** a `patch:` entry refers to a patch file in the project and the consumer lists that file in the install declaration
- **THEN** installation succeeds, and without the file listed it fails naming the file

### Requirement: Managed toolchain for installation

Installation SHALL run the selected Yarn distribution on the Bazel-managed Node.js runtime, and SHALL NOT run a host Node.js, Yarn or Corepack.

#### Scenario: No host installation
- **WHEN** a consumer installs a project with `node`, `yarn` and `corepack` on `PATH` replaced by programs that fail
- **THEN** installation succeeds

### Requirement: Host isolation

Installation SHALL give Yarn no configuration but the ruleset's own — built from the few settings it carries over from the project's `.yarnrc.yml` — SHALL NOT read from or write to the host's Yarn global folder, and SHALL NOT let Yarn reach any host but the loopback server.

#### Scenario: Configuration above the project
- **WHEN** the host user's home directory and every directory above the repository hold a `.yarnrc.yml` that points the registry at an unreachable address
- **THEN** installation succeeds

#### Scenario: Host global folder
- **WHEN** a consumer installs a project
- **THEN** nothing is created or modified under the host user's Yarn global folder

#### Scenario: Plugins and network settings in the project's configuration
- **WHEN** the project's `.yarnrc.yml` names a plugin that records when it is loaded, and sets a proxy and `networkSettings` for another host
- **THEN** installation succeeds, the plugin is not loaded, and no request reaches the proxy or that host

#### Scenario: Settings that shape the install
- **WHEN** the project's `.yarnrc.yml` declares `packageExtensions` that add a dependency, and the lockfile was written with them
- **THEN** installation succeeds and the added dependency is linked

#### Scenario: Configuration read as Yarn reads it
- **WHEN** the project's `.yarnrc.yml` uses YAML that Yarn reads in a way its look does not show, such as an open quote after an anchor or a plain value ending in a no-break space
- **THEN** the settings carried over are exactly the ones Yarn would read from it

#### Scenario: Configuration that cannot be read
- **WHEN** the project's `.yarnrc.yml` is not YAML that Yarn can read
- **THEN** fetching fails, saying the file cannot be read as YAML

### Requirement: No dependency builds

Dependency build scripts SHALL NOT run during installation, whatever the project's configuration says.

#### Scenario: Build forced by metadata
- **WHEN** a dependency declares a `postinstall` script and the project marks it `built: true` in `dependenciesMeta`
- **THEN** the script does not run

### Requirement: Architectures

Installation SHALL include the platform-specific packages compatible with the architectures the install declaration names, with Yarn's meaning of `supportedArchitectures` — `os`, `cpu` and `libc` each a set of its own — and by default the host's.

#### Scenario: Default architecture
- **WHEN** a consumer installs a project depending on a package with per-platform optional dependencies without naming architectures
- **THEN** the installed tree holds the host's package and not another platform's

#### Scenario: Named architectures
- **WHEN** the install declaration names two operating systems and two CPUs
- **THEN** the installed tree holds the packages for all four combinations, and none for an operating system or CPU it did not name

### Requirement: Faithful layout as artifacts

Each installed package SHALL be a Bazel artifact and each link between packages a symlink artifact, so that the layout Yarn computed is preserved exactly — links from one workspace to another excepted, which are recorded for the next change to create — and using it SHALL need no network access. A package whose pinned tarball, extracted and normalised as the build does, gives the tree Yarn laid out, and holds no two entries differing only by case or Unicode normalisation, SHALL be built from that tarball, without a second uncompressed copy kept by the install; every other package SHALL keep its archive; and the tree built SHALL be the one Yarn laid out, or the build SHALL fail.

#### Scenario: Offline use
- **WHEN** a test takes the installed tree as runfiles, requires a dependency, and runs with network access blocked
- **THEN** the test succeeds

#### Scenario: File names Bazel labels cannot hold
- **WHEN** an installed package contains a file whose name contains `:`
- **THEN** the file is present in the installed tree

#### Scenario: Executables
- **WHEN** an installed package declares a `bin`
- **THEN** the installed tree's `.bin` entry for it runs that package's executable

#### Scenario: Shared package
- **WHEN** two installed packages depend on the same package instance
- **THEN** both resolve it to the same real path

#### Scenario: Link inside a package
- **WHEN** an installed package's tarball contains a symbolic link
- **THEN** fetching fails and names the package and the link

#### Scenario: Package built from its tarball
- **WHEN** a package's pinned tarball, extracted and normalised as the build does, gives the tree Yarn laid out, and holds no two entries differing only by case or Unicode normalisation
- **THEN** the install repository holds no copy of its files, and the built package's files are the ones Yarn laid out

#### Scenario: Tarball that does not give Yarn's tree
- **WHEN** Yarn lays out a package whose pinned tarball, extracted and normalised as the build does, gives a tree other than Yarn's, or holds two entries differing only by case or Unicode normalisation
- **THEN** the package is built from its archive, and the built package's files are the ones Yarn laid out

#### Scenario: Extraction at build time that differs from Yarn's layout
- **WHEN** a package was chosen to be built from its tarball, and the files the build action extracts — on an execution platform other than the host that chose, say — differ from the files Yarn laid out for it
- **THEN** the build fails and names the package

### Requirement: Workspaces

Installation SHALL install the dependencies of every workspace the project declares, provided the consumer lists their `package.json` files, and SHALL fail on a workspace it was not given.

#### Scenario: Workspace dependencies
- **WHEN** a project with two workspaces, each with its own dependency, is installed with both `package.json` files listed
- **THEN** each workspace's dependency is installed

#### Scenario: Workspace not listed
- **WHEN** the lockfile holds a workspace whose `package.json` the consumer does not list
- **THEN** fetching fails and names the workspace

### Requirement: Refetch on change

The installation SHALL be repeated when an input of the install declaration changes — a listed file, an attribute, the selected Yarn or Node.js — and SHALL NOT be repeated otherwise while Bazel's caches are intact.

#### Scenario: Lockfile changed
- **WHEN** the lockfile and pin file change between two builds
- **THEN** the second build installs again and sees the new versions

#### Scenario: Nothing changed
- **WHEN** a second build runs with no input changed
- **THEN** nothing is fetched or installed again

### Requirement: Install declaration authority

Only the root module SHALL declare installs, each install SHALL have a distinct repository name, and an install SHALL name a distribution the extension created.

#### Scenario: Install in a dependency
- **WHEN** a non-root module declares an install
- **THEN** configuration fails and identifies the module

#### Scenario: Duplicate name
- **WHEN** the root module declares two installs with the same repository name
- **THEN** configuration fails and names the repository

#### Scenario: Unknown distribution
- **WHEN** an install names a distribution repository the extension did not create
- **THEN** configuration fails and names it

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
