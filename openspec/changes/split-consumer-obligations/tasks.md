## 1. Regroup

- [ ] 1.1 Write the delta that returns `Bzlmod consumer integration` to its own obligation and states the other two as their own requirements; verify `openspec validate --strict` accepts the change and no longer reports a requirement as very long.
- [ ] 1.2 Verify the regrouping loses nothing: compare the requirement sentences and the scenario set in the main spec before and after archiving, and confirm the only difference is which requirement each one sits under.

## 2. Gate

- [ ] 2.1 Run the repository's pre-commit gate and the build gate; verify every pre-commit hook passes and `bazel build //... && bazel test //...` passes in the root and in `e2e/smoke`. Nothing outside `openspec/` changes, so an unchanged build is the expected result rather than a formality.
- [ ] 2.2 Have a reviewer without this implementation conversation review the change, and record the outcome here.
