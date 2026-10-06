## 1. Plan

- [x] 1.1 A reviewer without this conversation reviews the plan before code;
  each finding checked and recorded here.
  - 2026-10-07: no blocker; every evidence claim checked against its source,
    including publish-to-bcr v1.5.0 substituting `docs_url` and requiring
    nothing else for it, and `release_ruleset.yaml` attesting the docs
    archive. The reviewer built the targets on Bazel 8.3.0 with text protos
    byte-identical to 9.2.0's. Should-fixes, all taken: the registry link
    gets a check — CI now runs `release_prep.sh` and checks that `docs_url`
    names the archive it wrote, which failed with the template's name
    changed; the script takes a relative path from where it runs; the limit
    that upload, attestation and rendering are shown only by a release is
    stated. Nits: the script stops its server; leaving the output base and
    its `bazel-*` symlinks is stated, with why no flag turns them off.

## 2. Tests first

- [x] 2.1 `tests/docs`: a Node test that every public entity, attribute and
  field in the three text protos has a non-empty doc string and that the
  public names are present, and that text-format escapes read back as
  written. Red: with `YarnNodeModulesInfo.yarn_version`'s doc emptied it
  failed naming that field; its own fixture shows a missing name is not
  taken for present.
- [x] 2.2 A CI step runs `release_prep.sh` under a tag of its own and checks
  the release notes, the source archive, the docs archive's three binary
  protos and that `docs_url` names that archive. Red: with
  `release_docs.sh` absent the step failed (exit 127), and with the
  template's name changed the name check failed.

## 3. Implementation

- [x] 3.1 `yarn/BUILD.bazel`: the three `starlark_doc_extract` targets.
- [x] 3.2 `.github/workflows/release_docs.sh`, called from `release_prep.sh`;
  `.bcr/source.template.json` gains `docs_url`.
- [x] 3.3 README says where the API reference is published.

## 4. Gate

- [x] 4.1 Every root builds and tests; scenarios; pre-commit; `openspec
  validate --all --strict`; the docs script run locally.
  - 2026-10-07: root 41/41, `e2e/smoke` 2/2, `e2e/install` 7/7, `tests/bcr`
    1/1, scenarios 39/39; `docs_test` passes under Bazel 8.3.0 too; the CI
    step's commands, run locally under a tag of their own, passed.
- [x] 4.2 The wiki is regenerated and the staleness gate passes.
- [x] 4.3 A reviewer without this conversation reviews the change; each
  finding checked and recorded.
  - 2026-10-07: no blocker. Should-fix taken: the test skipped entries of a
    kind it did not list, so an undocumented function, macro or later kind
    would pass; it now knows every message of `stardoc_output.proto` at 9.2.0,
    as documented or as a reference, and fails on any other, with a test
    that failed without the check. Nits left as they are: the leftover
    `bazel-*` symlinks are stated in the design; an empty target list cannot
    pass the CI step, which requires all three protos; the public-name check
    samples names, and the completeness check covers every attribute.
