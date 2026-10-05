#!/bin/sh
# A Bazel credential helper for tools/ci/install_scenarios.sh: answers every
# request with the token the fixture registry is told to require.
cat >/dev/null
printf '{"headers": {"Authorization": ["Bearer secret-token"]}}\n'
