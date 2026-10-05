## Why

An installed tree takes about twice its size on disk: the install repository
keeps an uncompressed archive of every package Yarn laid out (409 MB for a
717-entry project), and build actions unpack each one into `bazel-out` (501
MB). The first copy holds nothing the build needs that Bazel does not already
have: the registry tarball every package came from is already fetched, by its
pinned integrity, into a repository of its own.

`rules_js`, the reference for installing npm packages under Bazel, keeps the
downloaded tarball as the repository's file and extracts it in a build action
into a directory artifact; it extracts in the repository only a package it has
to patch or build (`npm/private/npm_import.bzl` and
`npm/private/npm_package_store.bzl`, extracting with the `tar.bzl` bsdtar
toolchain).

Measured on the 717-entry project with `tar.bzl`'s bsdtar and `rules_js`'s
flags: for all 576 store packages Yarn installed from a plain `npm:` resolution,
and all 75 peer-dependency instances, the extracted files are the files Yarn
laid out, byte for byte. Some real and crafted tarballs part — `pngjs@5.0.0`'s
directories lack an execute bit; hard links, absolute paths, `..` entries are
treated differently — so extraction cannot be assumed equal; it has to be
checked.

## What Changes

- The repository rule extracts each candidate package's pinned tarball with
  `tar.bzl`'s bsdtar, as `rules_js` does in its repository rule where it has
  to, and compares the result with what Yarn laid out. A package that matches
  is built by a build action extracting the same tarball; the install keeps
  no copy of it.
- Every other package — patched, a stub for another platform, a tarball
  bsdtar and Yarn treat differently — keeps its archive, as now.
- The repository records, for every package built from a tarball, the files
  Yarn laid out and their digests; the extracting action compares what it
  extracted with that record and fails, naming the package, if they differ.
  What Yarn laid out stays the definition of the installed tree.
- `rules_yarn` names `tar.bzl`'s per-platform bsdtar repositories, for the
  repository rule.
- A package containing a symbolic link is still refused, from the tree Yarn
  laid out, before any archive or record is written.

## Capabilities

### Modified Capabilities

- `yarn-dependencies`: the installed tree is built from the pinned tarballs
  where Yarn copied them unchanged, and is checked against what Yarn laid out.

## Impact

- `yarn/private/install/driver.js`, `layout.js` and a new module deciding each
  package's source; `node_modules.bzl` gains the extracting and checking action; `MODULE.bazel` gains `tar.bzl` 0.10.9 from the Bazel Central
  Registry.
- The layout contract (`layout.json`) moves to version 2.
- Disk: the install repository keeps per-package records and only the archives
  above, instead of an archive of every package.
