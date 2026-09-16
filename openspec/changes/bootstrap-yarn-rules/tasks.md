## 1. Ruleset foundation

- [ ] 1.1 Recheck stable Bazel, Yarn, rules_nodejs and Node releases and the exact APIs referenced in design.md; record the selected versions, distribution digest, upstream references, and compatibility requirements in the implementation documentation.
- [ ] 1.2 Create the minimal Bzlmod module, version/configuration files, and public/private package layout using the applicable rules-template structure; verify `bazel mod graph` resolves and Buildifier accepts the added files.

## 2. Yarn distribution

- [ ] 2.1 Add checked-in Yarn version metadata and integrity-checked repository fetching; verify the supported release fetches and a deliberately incorrect digest fails.
- [ ] 2.2 Implement the distribution module extension and its exported entry point; verify identical declarations deduplicate, unknown versions fail, and conflicting name/version declarations fail with actionable messages.

## 3. Yarn executable

- [ ] 3.1 Implement the public yarn_binary rule using the Node runtime toolchain and complete runfiles; verify analysis selects a file-backed runtime and rejects host-path-only configuration.
- [ ] 3.2 Implement the launcher with repository-aware runfiles lookup, explicit working-directory handling, selected-version enforcement and argument forwarding; verify arguments with spaces/metacharacters, output streams, nonzero exit status and project yarnPath redirection using focused launcher tests.

## 4. Consumer verification and documentation

- [ ] 4.1 Add an independent e2e/smoke consumer with exact Node/Yarn selections and a local module override; verify it builds and runs the public Yarn target without private loads or host Node/Yarn/Corepack installations.
- [ ] 4.2 Verify the selected version executes offline after repository fetch, leaves project files unchanged, and works with runfiles directory and manifest lookup; record actual Linux x86_64 results and any unsupported configurations.
- [ ] 4.3 Document installation, public API, tested versions/platforms, and CLI-versus-build-integration boundaries; verify every documented command against the independent consumer.
- [ ] 4.4 Run Buildifier, root and consumer `bazel build //...` and `bazel test //...`, and `openspec validate --all --strict`; review the resulting diff against the spec and cited official patterns, and record the results before marking implementation complete.
