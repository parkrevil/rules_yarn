#!/usr/bin/env bash
# PreToolUse guard: refuse writes to files another tool owns.
# Reads the hook payload on stdin, prints a permission decision on stdout.
set -uo pipefail

payload=$(cat)
path=$(jq -r '.tool_input.file_path // empty' <<<"$payload")
command=$(jq -r '.tool_input.command // empty' <<<"$payload")

openwiki_reason='OpenWiki owns this file. Regenerate it with `openwiki --update` instead of editing it.'
openspec_reason='`openspec archive` writes openspec/specs/. Edit the delta spec in the change instead.'

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

# OpenWiki owns its bookkeeping, but the page bodies are written by the agent
# during a run, so only the bookkeeping is protected.
openwiki_owned='openwiki/(\.claims/|\.run\.json|\.page-manifest\.json|\.last-update\.json|index\.md)'

# Write and Edit carry an exact path.
if [ -n "$path" ]; then
  grep -qE "$openwiki_owned" <<<"$path" && deny "$openwiki_reason ($path)"
  case "$path" in
    */openspec/specs/*|openspec/specs/*) deny "$openspec_reason ($path)" ;;
  esac
fi

# Bash carries a command string instead of a path, so this layer is advisory:
# a shell command cannot be parsed soundly here, and the exact guarantee lives
# on the Write and Edit paths above. Each command in a compound command is
# judged on its own, so an unrelated writer in one segment does not condemn a
# read in another, and copy-like commands are judged on their destination only.
guarded_write() {
  local target=$1 segment last
  while IFS= read -r segment; do
    [ -n "$segment" ] || continue

    # A redirection has to name the protected path directly; a bare `>` turns
    # up in unrelated commands.
    grep -qE ">>?[[:space:]]*['\"]?[^[:space:]'\"]*${target}" <<<"$segment" && return 0

    # These take their targets as ordinary arguments. Interpreters are included
    # because `-c` scripts write too; the cost is denying an interpreted read.
    if grep -qE "(^|[[:space:]])(sed[[:space:]]+-i|tee|rm|truncate|touch|ln|dd|python3?|node|perl|ruby)([[:space:]]|$)" <<<"$segment" &&
      grep -qE "$target" <<<"$segment"; then
      return 0
    fi

    # Copy-like commands write only to their last argument.
    if grep -qE "(^|[[:space:]])(cp|mv|install)([[:space:]]|$)" <<<"$segment"; then
      last=${segment##* }
      grep -qE "$target" <<<"$last" && return 0
    fi
  done < <(tr ';|&\n' '\n' <<<"$command")

  # Indirection — a variable, xargs, a nested shell — separates the path from
  # the redirection that writes it, so a file redirection anywhere in a command
  # that also names a protected path counts. This denies a read whose output is
  # redirected elsewhere; that trade is deliberate.
  grep -qE ">>?[[:space:]]*['\"]?[^&[:space:]]" <<<"$command" &&
    grep -qE "$target" <<<"$command" && return 0

  return 1
}

if [ -n "$command" ]; then
  guarded_write "$openwiki_owned" && deny "$openwiki_reason"
  guarded_write "openspec/specs/" && deny "$openspec_reason"
fi

exit 0
