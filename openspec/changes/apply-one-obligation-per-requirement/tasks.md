## 1. Judge every requirement

- [x] 1.1 Read every requirement in `yarn-execution` against the criterion in design.md and record a verdict for each, including the ones left alone; verify the judgement is not a restatement of what `openspec validate` reports, by measuring the report against this spec.
  - 2026-09-29: ten requirements judged, table in design.md. Two fail the criterion, `Repository naming` and `Command forwarding`. The second was first recorded as passing; a reviewer showed that verdict applied a different test from the other nine, and design.md now records the correction rather than the original claim. The length report never flagged it: its text is 230 characters, and no requirement in the spec now exceeds 284, so the report is silent across the whole file and still missed a real bundle. It did flag the requirement the previous change split, and it flagged it only after that change had already made it long.
- [x] 1.2 Check the verdicts against a document outside the spec, so the criterion is not applied only from the inside.
  - 2026-09-29: README describes repository naming under a heading that names two things, "Repository naming and version selection", with a bullet for naming authority and two for version arbitration. It describes command forwarding in a single bullet covering arguments, streams and exit status together. Both readings match the verdicts.

## 2. Regroup

- [x] 2.1 Write the delta that replaces `Repository naming` with `Repository naming authority` and `Version arbitration across modules`, and `Command forwarding` with `Argument forwarding`, `Output stream passthrough` and `Exit status propagation`; verify `openspec validate --strict` accepts the change.
  - 2026-09-29: `Change 'apply-one-obligation-per-requirement' is valid`. The shape is a removal plus two additions, for the reasons measured while splitting the previous requirement.
- [ ] 2.2 Verify the regrouping loses nothing: compare the requirement sentences and the scenario set in the main spec before and after archiving, and confirm the only difference is which requirement each one sits under, apart from the one clause design.md records as deliberately moved.

## 3. Gate

- [x] 3.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`. Nothing outside `openspec/` changes, so an unchanged build is the expected result.
  - 2026-09-29: root `bazel test //...` passed 22, `e2e/smoke` passed 1, `tools/hooks/protect_generated_test.sh` passed 40 of 40, `openspec validate --all --strict` passed — all unchanged, as a specification-only change should leave them. The pre-commit hooks run at commit time and are recorded with the commit.
- [ ] 3.2 Have a reviewer without this implementation conversation review the change, and record the outcome here — including the verdict this change takes against the previous review, so the disagreement is settled by someone else rather than asserted.
