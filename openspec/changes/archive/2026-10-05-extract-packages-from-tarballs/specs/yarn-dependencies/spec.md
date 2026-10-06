## MODIFIED Requirements

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
