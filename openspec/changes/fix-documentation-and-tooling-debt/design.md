## Context

See proposal.md — Why. Four of the six items are one-line edits with no
decision in them. Two are worth explaining.

## Goals / Non-Goals

Goals:

- Nothing in the repository claims something that is not true.
- Nothing in the repository runs, or fails to run, for a reason nobody can
  name.

Non-Goals:

- Rewriting README. Only the sentences that are wrong or incomplete change.
- Changing what any test asserts. Only how the tests are declared changes.

## Decisions

### The OKF tooling is removed rather than given a bundle

`tools/okf/validate.py` implements a conformance checker for the Open
Knowledge Format. It has no input: there is no `.okf/` directory, the
pre-commit hook is filtered to `^\.okf/` so it reports "no files to check" on
every run, and the `PostToolUse` hook returns immediately on `[ -d .okf ]`.
The one bundle-shaped thing in the repository, `openwiki/`, is validated by
OpenWiki — which `tools/okf/validate.sh` states in its own header.

The alternative is to create an `.okf/` bundle so the validator has something
to check. Rejected: the repository has no hand-authored knowledge bundle and
no reason to grow one, and that would turn a dormant 571-line dependency into
a live one — including on `uv`, which the CI runners do not carry. Removing it
also closes the latent CI failure the previous change recorded rather than
fixed.

### The unit tests get a size by calling `analysis_test` directly

`rules_testing`'s `unit_test(name, impl, attrs)` has no parameter for a test's
size, and `test_suite`'s `test_kwargs` are forwarded into it, so
`test_kwargs = {"size": "small"}` is an error rather than a fix. `unit_test`
is itself a thin wrapper: it calls `analysis_test` against a stub target,
`@rules_testing//lib:_stub_target_for_unit_tests`, which is publicly visible.

So the suites call `analysis_test` with that same stub and
`attr_values = {"size": "small"}` — the shape `tests/yarn_binary` already
uses for its analysis tests. Each test is named explicitly in a dict rather
than derived from its function, because `test_suite` derives names through a
private helper and Starlark cannot read a function's name.

The result keeps every target name, so nothing referring to these tests
changes.

Alternative considered: a global `--test_timeout` in `.bazelrc`. Rejected —
it would silence the warning by overriding every test's timeout, including
the ones where a timeout means something.

## Risks / Trade-offs

- [Naming each test in a dict duplicates the function name] → The duplication
  is visible in one place and the test fails to build if the names disagree.
  The alternative is a private `rules_testing` helper.
- [Removing the OKF tooling loses work if a bundle is ever wanted] → It is in
  the history, and a validator with no input is not doing the work it would
  do then.

## Migration Plan

None.
