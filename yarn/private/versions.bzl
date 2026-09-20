"""Yarn distributions that rules_yarn can fetch."""

visibility(["//tests/...", "//yarn/..."])

# URL of the standalone Yarn bundle for a version. Corepack downloads Yarn 2
# and later from the same location.
YARN_URL_TEMPLATE = "https://repo.yarnpkg.com/{version}/packages/yarnpkg-cli/bin/yarn.js"

# Maps each supported Yarn version to the Subresource Integrity digest of its
# bundle. Add a version only after checking the digest against an upstream
# record: the `bin/yarn.js` file of `@yarnpkg/cli-dist` on the npm registry, or
# the hash for the version in Corepack's `config.json`.
YARN_VERSIONS = {
    "4.18.0": "sha256-+4sdIL5yoLVEo1vOxMftD/Vamxc8AfGRsCuhZLIFHbU=",
}
