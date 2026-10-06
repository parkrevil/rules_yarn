## Context

The public API lives in `yarn/defs.bzl`, `yarn/extensions.bzl` and
`yarn/providers.bzl`, each with a `bzl_library` in `yarn/BUILD.bazel`. A
release runs `bazel-contrib/.github`'s `release_ruleset.yaml` (v7.7.0), which
calls `.github/workflows/release_prep.sh`, uploads `rules_yarn-*.tar.gz` and
attests every uploaded file; `publish-to-bcr` v1.5.0 then fills
`.bcr/source.template.json` into the registry entry.

## Evidence

**The extraction rule.** `starlark_doc_extract` is a native rule at Bazel
8.3.0 and 9.2.0 (`StarlarkDocExtractRule.java`): it takes a `.bzl` `src` and
`deps` whose `DefaultInfo` provides the files it loads, "under normal usage"
`bzl_library` targets; its default output is `<name>.binaryproto`, a
`stardoc_output.ModuleInfo`, and `<name>.textproto` is built on request.
`render_main_repo_name` "should be set ... to `True` when generating
documentation for Starlark files which are intended to be used from other
repositories". The rule warns that its exact output "is not a stable public
API", so golden tests should run with a single Bazel version. Neither version
marks it experimental or deprecated.

**What the registry takes.** `docs/README.md` of the registry: "The
`source.json` permits a `docs_url` attribute pointing to the documentation.
This may optionally point to an archive file of stardoc_output.proto files".
`docs/stardoc.md` (commit `c60e1f93`, 2026-08-19) gives the archive's recipe —
query every `starlark_doc_extract` target, build them in a fresh output base,
tar `bazel-bin` — and the template line `"docs_url":
"https://github.com/{OWNER}/{REPO}/releases/download/{TAG}/{REPO}-{TAG}.docs.tar.gz"`,
requiring publish-to-bcr v0.2.3 or later; registry.bazel.build renders it.
`tools/bcr_validation.py` does not check `docs_url`.

**What `rules_js` does.** At v3.5.1 it declares one `<file>.doc_extract`
target per public file on its `bzl_library`, without `render_main_repo_name`
(`js/BUILD.bazel`, `npm/BUILD.bazel`), builds the archive with
`.github/workflows/release_docs.sh` — the registry's recipe — called from
`release_prep.sh`, and links it in `.bcr/source.template.json`.

**The spike.** On Bazel 9.2.0, the three targets built from the existing
`bzl_library` targets; their text protos hold `yarn_binary` and its `yarn`
attribute, the `yarn` extension with its `distribution` and `install` tag
classes and their attributes, and `YarnNodeModulesInfo` with its seven
fields — 13 attributes, 7 fields, 2 tag classes, one rule, one provider and
one extension, each with a doc string. The plan review built the same
targets on Bazel 8.3.0, the declared floor, and its text protos were
byte-identical to 9.2.0's.

## Goals / Non-Goals

**Goals:** the public API's reference on the registry for every release;
a test that no public attribute, field or entity is undocumented.

**Non-Goals:** rendering Markdown into the repository — the registry renders
the protos, and the README stays the guide; documenting private files.

## Decisions

**One target per public file, named as `rules_js` names them**:
`defs.doc_extract`, `extensions.doc_extract`, `providers.doc_extract`, each on
the file's `bzl_library`. Extraction loads every file `src` loads, so a
`bzl_library` missing a dependency fails the build — the gap `docs/stardoc.md`
notes in skylib's `bzl_library`.

**`render_main_repo_name = True`**, as the rule's documentation says for files
used from other repositories, so labels read `@rules_yarn//yarn:defs.bzl`, the
way a consumer loads them. `rules_js` leaves the default.

**The completeness test reads the text protos, not a golden copy.** A Node
test under `tests/docs/` walks each text proto's blocks and requires a
non-empty `doc_string` in every `rule_info`, `provider_info`,
`module_extension_info`, `tag_class`, `attribute` and `field_info` — every
message of `stardoc_output.proto` at 9.2.0 that has a doc string, functions,
macros, aspects and repository rules included — and the public names above to
be present. An entry of any kind other than those and the three that only
refer to others (`origin_key`, `advertised_providers`,
`provider_name_group`) fails the test, so a kind a later Bazel adds is not
skipped unchecked. It compares nothing else, so a Bazel that
adds or rewords native attributes changes nothing it checks, in keeping with
the rule's warning.

**The archive follows the registry's recipe.** `.github/workflows/release_docs.sh`
takes the archive's path — a relative one taken from the directory it runs
in, since the archive is written by `tar --directory` — builds every
`starlark_doc_extract` target in a fresh output base, tars that `bazel-bin`
and stops that output base's server, writing nothing to standard output,
since `release_prep.sh`'s output is the release notes. `release_prep.sh` calls
it with `rules_yarn-<tag>.docs.tar.gz`, which the existing `release_files:
rules_yarn-*.tar.gz` uploads; `release_ruleset.yaml` attests every uploaded
file and writes an `.intoto.jsonl` for each archive, the docs archive
included, with nothing more to configure. The CI `checks` job runs
`release_prep.sh` itself on every push, under a tag of its own, and checks
the release notes, the source archive, the docs archive's three binary protos,
and that `docs_url` in `.bcr/source.template.json` names that archive.

## Risks / Trade-offs

- The protos come from the Bazel the release runs (`.bazelversion`, 9.2.0), so
  native parts, such as the `name` attribute's doc string, are that Bazel's.
- Limit: the CI run shows the archive is built and that `docs_url` names it;
  that the release uploads and attests it, and that registry.bazel.build
  renders it, can be shown only by a published release.
- The script leaves its output base for the runner to discard, as the
  registry's recipe does, so run locally it leaves the workspace's `bazel-*`
  symlinks pointing into that output base until the next build in the default
  one. Turning them off takes `--symlink_prefix=/`, whose help text at 8.3.0
  and 9.2.0 says it "will be deprecated soon", or the experimental
  `--experimental_convenience_symlinks=ignore`; neither is used.
