# Files

- [Verification strategy](verification-strategy.md) - The test layers that hold the ruleset's guarantees — Starlark unit tests over selection, analysis tests over the rule, shell tests that execute the launcher and the real Yarn CLI, Node.js tests of the install driver's programs, consumer modules that use only the public API, nested-Bazel tests that install from a local registry in a hostile host, and a test of the Yarn behavior the install's design rests on.
