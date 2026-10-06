#!/usr/bin/env bash
# Builds the archive of the public API's extracted documentation that the
# registry renders, by the recipe in the Bazel Central Registry's
# docs/stardoc.md: every starlark_doc_extract target, built in an output base
# of its own, and that output base's bazel-bin archived.
#
#   release_docs.sh <archive.tar.gz>
#
# release_prep.sh's standard output is the release notes, so everything here
# goes to standard error. A relative archive path is taken from the directory
# the script is run in. The output base is left for the runner to discard, as
# the recipe leaves it; its server is stopped.
set -o errexit -o nounset -o pipefail

case $1 in
  /*) out=$1 ;;
  *) out="$PWD/$1" ;;
esac
docs="$(mktemp -d)"
targets="$(mktemp)"
{
  bazel --output_base="$docs" query --output=label --output_file="$targets" 'kind("starlark_doc_extract rule", //...)'
  bazel --output_base="$docs" build --target_pattern_file="$targets"
  tar --create --auto-compress \
    --directory "$(bazel --output_base="$docs" info bazel-bin)" \
    --file "$out" .
  bazel --output_base="$docs" shutdown
} >&2
