# Security

## Reporting

Report a vulnerability through GitHub's private advisory form, under the
repository's Security tab. Please do not open a public issue for one.

Expect an acknowledgement within a week. This is a small project with one
maintainer; there is no paid support and no guaranteed patch window.

## What this ruleset does with untrusted input

It downloads one file: the Yarn bundle named by `yarn.distribution`, from a URL
built out of the version, and checks it against a digest recorded in
`yarn/private/versions.bzl`. A download whose bytes do not match that digest
fails before anything executes.

The launcher it generates runs that bundle with the Node.js runtime Bazel
resolved. Every value substituted into the launcher is quoted with
`shell.quote` except the `#!` interpreter path, which the kernel reads
literally. The launcher assembles no shell command at run time and contains no
`eval`.

## What it does not protect

Running Yarn through `yarn_binary` is not sandboxed: Yarn reads and writes the
project, its caches and the network exactly as it does outside Bazel. Anything
`yarn install` fetches is outside this ruleset's integrity checking.
