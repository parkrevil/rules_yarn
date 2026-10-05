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

# Maps each supported Yarn version to its cache version, `CACHE_VERSION` in
# packages/yarnpkg-core/sources/Cache.ts at that version's tag. A lockfile's
# cache key is this joined with the project's compression setting, so an
# install checks it before running Yarn.
YARN_CACHE_VERSIONS = {
    "4.18.0": "10",
}
