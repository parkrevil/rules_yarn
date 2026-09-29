#!/usr/bin/env bash
# Builds and runs a Yarn target from a throwaway consumer module, under the
# oldest Bazel version MODULE.bazel says this ruleset supports.
#
# The repository's own roots cannot check this: their lockfiles are written by
# the Bazel in .bazelversion and both roots set --lockfile_mode=error, so an
# older Bazel fails on the lockfile before it reaches the ruleset. A consumer
# resolving from scratch is what a consumer actually does.
#
# Usage: tools/ci/minimum_bazel.sh [bazel-version]
#        Default: the floor declared in MODULE.bazel.
set -euo pipefail

repository=$(cd "$(dirname "$0")/../.." && pwd -P)

declared_floor() {
  # bazel_compatibility = [">=8.3.0"] -> 8.3.0
  sed -n 's/.*bazel_compatibility.*">=\([0-9][0-9.]*\)".*/\1/p' "$repository/MODULE.bazel"
}

version=${1:-$(declared_floor)}
if [ -z "$version" ]; then
  echo >&2 "FAIL: no Bazel version given and none found in MODULE.bazel's bazel_compatibility"
  exit 1
fi

yarn_version=$(sed -n 's/^    "\([0-9][0-9.]*\)": "sha.*/\1/p' "$repository/yarn/private/versions.bzl" | head -1)
if [ -z "$yarn_version" ]; then
  echo >&2 "FAIL: no Yarn version found in yarn/private/versions.bzl"
  exit 1
fi

consumer=$(mktemp -d)
trap 'rm -rf "$consumer"' EXIT

cat >"$consumer/MODULE.bazel" <<EOF
bazel_dep(name = "rules_yarn")
bazel_dep(name = "rules_nodejs", version = "6.7.5")

local_path_override(
    module_name = "rules_yarn",
    path = "$repository",
)

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "24.21.0")

yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "$yarn_version")
use_repo(yarn, "yarn")
EOF

cat >"$consumer/BUILD.bazel" <<'EOF'
load("@rules_yarn//yarn:defs.bzl", "yarn_binary")

yarn_binary(
    name = "yarn",
    yarn = "@yarn",
)
EOF

echo "Checking rules_yarn against Bazel $version, expecting Yarn $yarn_version"
cd "$consumer"

# The consumer resolves from scratch, so it keeps no lockfile of its own.
USE_BAZEL_VERSION=$version bazel build --lockfile_mode=off //:yarn
# Bazel's own output stays on stderr, so a failure here is diagnosable.
reported=$(USE_BAZEL_VERSION=$version bazel run --lockfile_mode=off //:yarn -- --version | tail -1)

if [ "$reported" != "$yarn_version" ]; then
  echo >&2 "FAIL: expected Yarn $yarn_version, got '$reported'"
  exit 1
fi
echo "PASS: Bazel $version builds and runs the Yarn target, reporting $reported"
