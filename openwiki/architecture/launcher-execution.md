---
type: architecture
title: Launcher and execution model
description: How the yarn_binary rule resolves toolchains, expands a shell launcher, finds Node.js and the Yarn entry point through runfiles, and controls the working directory and environment Yarn runs under.
tags: [rule, toolchain, runfiles, launcher, bazel-run]
sources:
  - id: openwiki-source-8a52f3cc97aa21919ea82129
    resource: repo://tests/launcher/launcher_test.sh
  - id: openwiki-source-d066155d67929b81ea0f151f
    resource: repo://tests/launcher/yarn_cli_test.sh
  - id: openwiki-source-eb3dcfac0b874f311a6353ac
    resource: repo://tests/yarn_binary/yarn_binary_tests.bzl
  - id: openwiki-source-6da6376cacb3a4c5f3725a78
    resource: repo://yarn/private/install/repository.bzl
  - id: openwiki-source-d9081795909674dafc7044aa
    resource: repo://yarn/private/yarn_binary.bzl
  - id: openwiki-source-c20b05d8b903795173b9a3b2
    resource: repo://yarn/private/yarn_binary.sh.tpl
generated: { by: "claude-code", at: "2026-10-04T12:22:38.266Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-10-05T14:22:28.209Z
---

# Launcher and execution model

`yarn_binary` produces an executable whose only job is to start one JavaScript
file with one Node.js binary, both taken from the build rather than from the
machine. Everything below exists to make that true at run time, not just at
analysis time.

## Analysis: what the rule resolves

The rule declares two toolchain types and uses each for one thing:

- `@rules_nodejs//nodejs:runtime_toolchain_type` supplies `nodeinfo`. The rule
  reads `nodeinfo.node`, the Node.js **file**. `rules_nodejs` models a runtime
  either as a file or as a bare host path, never both, so an empty `node` means
  the resolved toolchain points at some path on the machine. That case fails
  analysis with a message naming the host path and telling the reader to
  register a toolchain that sets `node`. This is where the ruleset's
  no-host-tools guarantee is actually enforced.
- `@rules_shell//shell:toolchain_type` supplies `path`, the interpreter for the
  target platform. It becomes the launcher's `#!` line.

The entry point comes from the mandatory `yarn` attribute, restricted to a
single `.js` or `.cjs` file.

## Analysis: what the rule builds

One action: `expand_template` over a checked-in template, producing an
executable named after the target. Three placeholders are substituted — the
Node.js runfiles path, the Yarn runfiles path, and the shell interpreter.

The two runfiles paths are quoted with `shell.quote` because they are
interpolated into shell word positions inside the script. The interpreter path
is not quoted: it lands on the `#!` line, which the kernel parses literally, so
quoting it would produce an unusable launcher.

A small helper converts a `File` into the path `rlocation` expects: files from
the main repository are prefixed with the workspace name, and files from an
external repository have their `../` prefix stripped.

## Runfiles composition

The launcher needs three things at run time and gets them from three sources:

- the Node.js file and the Yarn entry point, added directly;
- the entry point target's own default runfiles, merged in, so an entry point
  that is a `filegroup` with `data` keeps its runtime resources;
- `@rules_shell//shell/runfiles`, merged in, because the template sources the
  Bash runfiles library.

## Run time: the launcher script

The script begins with the standard Bash runfiles initialization snippet, which
locates the runfiles library through a directory, a manifest, or a sibling
`.runfiles` tree — whichever is available.

It then resolves both paths with `rlocation` and fails with a specific message
if either lookup comes back empty, rather than letting Node.js report a missing
file. Because `rlocation` can return a path relative to the current directory,
both results are made absolute before anything changes directories.

Two environment variables are exported unconditionally, overriding whatever the
caller set: `YARN_IGNORE_PATH=1`, so a project's `yarnPath` setting cannot
redirect execution to a different Yarn, and `YARN_ENABLE_TELEMETRY=0`.

Finally the working directory is set. Under `bazel run` Bazel starts the binary
inside its runfiles tree and records the user's directory in
`BUILD_WORKING_DIRECTORY`; the launcher changes into it so Yarn operates on the
project the user was standing in. When that variable is absent — the executable
run directly — the current directory is left alone. The last statement is an
`exec`, so Yarn replaces the launcher process and its exit status and output
streams are the target's.

## Consequences

Running Yarn this way is hermetic in exactly one dimension: which Node.js and
which Yarn execute. It is not hermetic in any other sense. Yarn still reads and
writes the project directory, its caches, and the network exactly as it would
outside Bazel, and the rule's own documentation says so.

That is also why the one `yarn_binary` the ruleset itself generates is a tool
run by hand rather than part of a build: each install repository declares
`pin`, a `yarn_binary` whose entry point is the pin program, so that
`bazel run @<name>//:pin` runs it with the selected Yarn beside it, in the
developer's checkout, with the developer's configuration — what refreshing a
pin file needs. See [Installing a project's
dependencies](dependency-installation.md).

## Tests that hold this

Analysis tests assert the executable's name and default outputs, that Node.js,
the entry point, the executable itself, and the Bash runfiles library are all in
the runfiles, that the substitution keys are exactly the three expected ones
with correctly quoted values and an absolute interpreter path, that an entry
point's own `data` survives into the launcher's runfiles, and — under a platform
that selects a host-path-only Node.js toolchain — that analysis fails with the
expected message.

Execution tests run the launcher against a probe entry point that echoes what it
received: argument fidelity for spaces, quotes, globs, semicolons, newlines and
empty strings; that the forced environment overrides the caller's; exit-status
propagation; the working-directory rules in both directions; survival of
relative runfiles paths across the directory change; and a manifest-only
runfiles lookup. A separate test drives the real Yarn distribution with fake
`node`, `yarn` and `corepack` on `PATH` that record any use — the recorded
marker never appears, the selected version is printed, a project `yarnPath`
redirect is ignored, and the project files are unchanged.
