#!/usr/bin/env bash
# PreToolUse guard: refuse writes to files OpenWiki owns.
# Reads the hook payload on stdin, prints a permission decision on stdout.
set -uo pipefail

path=$(jq -r '.tool_input.file_path // empty')

case "$path" in
  */openwiki/.claims/*|*/openwiki/.run.json|*/openwiki/.page-manifest.json|*/openwiki/.last-update.json|*/openwiki/index.md)
    jq -nc --arg p "$path" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("OpenWiki owns \($p). Regenerate it with `openwiki --update` instead of editing it.")
      }
    }'
    ;;
esac
exit 0
