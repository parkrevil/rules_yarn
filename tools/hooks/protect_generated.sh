#!/usr/bin/env bash
# PreToolUse guard: refuses to author a file that a generator owns.
# Reads the hook payload on stdin, prints a permission decision on stdout.
#
# Scope. The guard covers the tools that write a file directly. They carry the
# exact path, so the decision is a path comparison and nothing is inferred.
#
# A shell command is deliberately outside that scope. Deciding which files a
# command writes means parsing a shell, and the programs that are supposed to
# write these paths — `openspec archive` and `openwiki --update` — are shell
# commands themselves, so any rule over command text refuses legitimate runs
# and still misses a write behind a variable or `eval`. AGENTS.md states the
# rule; review enforces it where a hook cannot decide it.
set -uo pipefail

repository=$(cd "$(dirname "$0")/../.." && pwd -P)

# Refusing is this guard's only job, so it fails closed: when it cannot read
# the call it cannot clear the write either. `deny_without_jq` exists because
# that is the one refusal it has to phrase without jq.
deny_without_jq() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

for tool in jq realpath; do
  command -v "$tool" >/dev/null 2>&1 ||
    deny_without_jq "tools/hooks/protect_generated.sh needs ${tool} to decide whether this file is generated, and refuses rather than guess while it is missing."
done

deny() {
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

payload=$(cat)
# Every tool this guard is matched against names its target in one of these.
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$payload" 2>/dev/null) ||
  deny_without_jq "tools/hooks/protect_generated.sh could not read the hook payload, and refuses rather than guess."

# A payload that parsed and names no file is not a write to a generated file.
[ -n "$path" ] || exit 0

# Judge the path by what it names, not by how it is spelled: resolve `.`, `..`
# and symlinks, and express it relative to the repository so a matching name
# somewhere else on the filesystem is not this repository's file.
case "$path" in
  /*) ;;
  *) path=$repository/$path ;;
esac
relative=$(realpath -m --relative-to="$repository" -- "$path") ||
  deny "tools/hooks/protect_generated.sh could not resolve $path, and refuses rather than guess."
case "$relative" in
  .. | ../*) exit 0 ;;
esac

case "$relative" in
  openspec/specs | openspec/specs/*)
    deny "\`openspec archive\` writes openspec/specs/. Edit the delta spec under the change's own specs/ directory instead. ($relative)"
    ;;
esac

# OpenWiki owns its bookkeeping and every index page. The page bodies listed in
# openwiki/.page-manifest.json are written by the agent during a run, so they
# stay editable.
case "$relative" in
  openwiki/.claims | openwiki/.claims/* | \
    openwiki/.run.json | openwiki/.page-manifest.json | openwiki/.last-update.json | \
    openwiki/index.md | openwiki/*/index.md)
    deny "OpenWiki owns this file. Regenerate it with \`openwiki --update\` instead of editing it. ($relative)"
    ;;
esac

exit 0
