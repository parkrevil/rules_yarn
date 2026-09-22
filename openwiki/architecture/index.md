# Files

- [Yarn distribution pipeline](distribution-pipeline.md) - How rules_yarn turns a version string in MODULE.bazel into a Bazel target, covering tag collection and version selection in the module extension, the integrity-checked download in the repository rule, and the filegroup it generates.
- [Launcher and execution model](launcher-execution.md) - How the yarn_binary rule resolves toolchains, expands a shell launcher, finds Node.js and the Yarn entry point through runfiles, and controls the working directory and environment Yarn runs under.
