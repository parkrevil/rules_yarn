#!/usr/bin/env bash
# Builds the release archive and prints the release notes, for the reusable
# workflow at bazel-contrib/.github, which calls this path by name.
set -o errexit -o nounset -o pipefail

# The tag being released, as the reusable release workflow passes it
# (release_ruleset.yaml at v7.7.0: `release_prep.sh ${{ inputs.tag_name ||
# github.ref_name }}`). GITHUB_REF_NAME is the tag only when a pushed tag
# started the run; called from tag.yaml it is the branch.
TAG=$1
# The prefix matches what GitHub generates for a source archive, so a consumer
# can move between the two without changing strip_prefix.
PREFIX="rules_yarn-${TAG:1}"
ARCHIVE="rules_yarn-$TAG.tar.gz"

git archive --format=tar --prefix="${PREFIX}/" "${TAG}" | gzip > "$ARCHIVE"
SHA=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')

# The public API's documentation, which .bcr/source.template.json links as
# docs_url and the registry renders.
.github/workflows/release_docs.sh "${ARCHIVE%.tar.gz}.docs.tar.gz"

cat <<EOF
## Using this release

Add to your \`MODULE.bazel\`:

\`\`\`starlark
bazel_dep(name = "rules_yarn", version = "${TAG:1}")
\`\`\`

Bazel 8.3.0 or newer is required; \`rules_yarn\` declares that and older
versions are refused while the module graph resolves.

Until the module is in the Bazel Central Registry, depend on the archive
directly:

\`\`\`starlark
bazel_dep(name = "rules_yarn", version = "${TAG:1}")

archive_override(
    module_name = "rules_yarn",
    integrity = "sha256-$(openssl dgst -binary -sha256 "$ARCHIVE" | openssl base64 -A)",
    strip_prefix = "${PREFIX}",
    urls = ["https://github.com/parkrevil/rules_yarn/releases/download/${TAG}/${ARCHIVE}"],
)
\`\`\`

SHA-256 of \`${ARCHIVE}\`: \`${SHA}\`
EOF
