#!/bin/sh
# A Bazel credential helper for install_downloader_test.sh: answers every
# request with the token the fixture registry is told to require.
cat >/dev/null
printf '{"headers": {"Authorization": ["Bearer secret-token"]}}\n'
