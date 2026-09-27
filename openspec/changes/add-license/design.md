## Context

See proposal.md — Why. The only decisions here are which license and where the
text comes from.

## Goals / Non-Goals

Goals:

- The repository grants the rights its own README assumes.
- The license text is the canonical one, byte for byte.

Non-Goals:

- Per-file license headers. No file in this repository carries one today, and
  Apache-2.0 does not require them.
- Bazel license metadata targets. `rules_license` would be a new dependency
  for a ruleset that publishes nothing yet; it belongs to whatever change
  publishes to a registry.

## Decisions

### Apache-2.0

Every module `MODULE.bazel` names ships Apache-2.0, as does the
`bazel-contrib/rules-template` layout this repository follows. Checked, rather
than assumed, through each project's declared license: `rules_nodejs`,
`rules_shell`, `bazel_skylib`, `rules_testing`, `platforms` and
`rules-template` all report `Apache-2.0`. Matching them keeps the dependency
graph uniform and keeps the ruleset usable by anyone already depending on
those.

Alternatives considered: MIT, which is compatible but does not carry the
patent grant the rest of the graph does, and would be a difference with no
reason behind it.

### Take the text from a pinned dependency, not from memory

The license is a legal instrument, so an approximately correct copy is a
defect. The text is copied from the fetched `rules_shell` 0.8.0 archive, and
corroborated by three other pinned dependencies that ship the same file:
`rules_nodejs` 6.7.5, `bazel_skylib` 1.9.2 and `rules_testing` 0.9.0 all match
it at `sha256:cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.

The appendix keeps the upstream `Copyright [yyyy] [name of copyright owner]`
placeholder. That is how all four dependencies ship it: the appendix is
instructions for applying the license to a file, not a statement about this
repository.

## Risks / Trade-offs

- [The license choice is effectively permanent — relicensing later needs every
  contributor's agreement] → There is one contributor and no release, so the
  cost of choosing now is at its lowest, and the choice matches the ecosystem.

## Migration Plan

None.
