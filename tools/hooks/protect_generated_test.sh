#!/usr/bin/env bash
# Checks the decision protect_generated.sh returns for each path it can be
# asked about. The guard's whole contract is which paths it refuses, so the
# table is the contract: every generator-owned path, every neighbouring path
# that must stay editable, and the spellings a path can arrive in.
#
# Usage: tools/hooks/protect_generated_test.sh [path-to-hook]
set -uo pipefail

hook=${1:-"$(dirname "$0")/protect_generated.sh"}
repository=$(cd "$(dirname "$0")/../.." && pwd -P)
failures=0

# The hook prints a decision only when it refuses, so output means "deny".
case_is() {
  local expected=$1 path=$2 got
  if [ -n "$(jq -nc --arg p "$path" '{tool_input: {file_path: $p}}' | "$hook")" ]; then
    got=deny
  else
    got=allow
  fi
  record "$expected" "$got" "$path"
}

record() {
  local expected=$1 got=$2 what=$3 mark
  if [ "$expected" = "$got" ]; then
    mark="ok  "
  else
    mark="FAIL"
    failures=$((failures + 1))
  fi
  printf '%s  expected=%-5s got=%-5s  %s\n' "$mark" "$expected" "$got" "$what"
}

# Payloads the guard has to answer without a usable file_path.
payload_is() {
  local expected=$1 payload=$2 what=$3 got
  if [ -n "$("$hook" <<<"$payload" 2>/dev/null)" ]; then got=deny; else got=allow; fi
  record "$expected" "$got" "$what"
}

# The guard has to refuse while a tool it depends on is missing, so run it
# against a PATH that holds everything it needs except jq.
without_jq_is() {
  local expected=$1 what=$2 got stub tool
  stub=$(mktemp -d)
  for tool in cat dirname realpath; do
    ln -s "$(command -v "$tool")" "$stub/$tool"
  done
  if [ -n "$(PATH=$stub "$BASH" "$hook" <<<'{"tool_input": {"file_path": "openwiki/index.md"}}' 2>/dev/null)" ]; then
    got=deny
  else
    got=allow
  fi
  rm -rf "$stub"
  record "$expected" "$got" "$what"
}

echo "# openspec: archive writes the main specs"
case_is deny openspec/specs/yarn-execution/spec.md
case_is deny openspec/specs/.gitkeep
case_is deny openspec/specs

echo
echo "# openspec: a change's own delta spec is the file to edit"
case_is allow openspec/changes/fix-generated-file-guard/specs/yarn-execution/spec.md
case_is allow openspec/changes/fix-generated-file-guard/proposal.md
case_is allow openspec/config.yaml

echo
echo "# openwiki: bookkeeping"
case_is deny openwiki/.claims/quickstart.json
case_is deny openwiki/.claims/architecture/distribution-pipeline.json
case_is deny openwiki/.run.json
case_is deny openwiki/.page-manifest.json
case_is deny openwiki/.last-update.json

echo
echo "# openwiki: every index page is generated, at any depth"
case_is deny openwiki/index.md
case_is deny openwiki/architecture/index.md
case_is deny openwiki/workflows/index.md

echo
echo "# openwiki: page bodies are written during a run"
case_is allow openwiki/quickstart.md
case_is allow openwiki/architecture/launcher-execution.md
case_is allow openwiki/concepts/public-api-surface.md

echo
echo "# ordinary files"
case_is allow README.md
case_is allow AGENTS.md
case_is allow yarn/private/yarn_binary.bzl
case_is allow tools/hooks/protect_generated.sh

echo
echo "# the same file, spelled differently"
case_is deny "$repository/openwiki/index.md"
case_is deny "$repository/./openwiki/architecture/../index.md"
case_is deny "$repository/openspec/specs/yarn-execution/spec.md"

echo
echo "# a matching name outside this repository is not this repository's file"
case_is allow /tmp/openwiki/index.md
case_is allow /tmp/openspec/specs/spec.md
case_is allow "$repository/../openwiki/index.md"

echo
echo "# a notebook edit names its target in notebook_path"
payload_is deny '{"tool_input": {"notebook_path": "openwiki/index.md"}}' 'notebook_path=openwiki/index.md'
payload_is allow '{"tool_input": {"notebook_path": "notes.ipynb"}}' 'notebook_path=notes.ipynb'

echo
echo "# the guard refuses when it cannot read the call"
payload_is allow '{}' 'payload names no file'
payload_is deny 'not json at all' 'payload does not parse'
without_jq_is deny 'jq is missing'

echo
printf 'failures: %d\n' "$failures"
[ "$failures" -eq 0 ]
