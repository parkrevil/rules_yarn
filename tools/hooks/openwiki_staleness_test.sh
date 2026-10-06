#!/usr/bin/env bash
# Checks what openwiki_staleness.sh decides for each shape of record it can be
# handed, and for each command it depends on failing. The gate's contract is
# which records it clears and which it refuses, so the table is the contract.
#
# The worst outcome for a gate is clearing something it did not check, so most
# rows are refusals, and a refusal only counts when it is the right one: the
# gate has to exit with exactly 1 and say the thing the row is about. A row
# whose fixture could not be built stops the run instead of passing.
#
# Usage: tools/hooks/openwiki_staleness_test.sh [path-to-hook]
set -uo pipefail

# A helper that fails usually runs inside a command substitution, where exit
# would leave only that subshell and the row would go on with an empty value.
# So die signals the script itself, whose PID every subshell still knows as $$.
trap 'exit 2' TERM
die() {
  echo >&2 "openwiki_staleness_test.sh: $*"
  kill -s TERM $$
  exit 2
}

hook_argument=${1:-"$(dirname "$0")/openwiki_staleness.sh"}
hook=$(cd "$(dirname "$hook_argument")" && pwd -P)/$(basename "$hook_argument") ||
  die "cannot resolve $hook_argument"
[ -f "$hook" ] || die "no hook at $hook"
# The checked-in stand-in for a tool that does its work and then fails.
failing_tool=$(cd "$(dirname "$0")" && pwd -P)/fixtures/failing_tool.sh
[ -x "$failing_tool" ] || die "no executable fixture at $failing_tool"
failures=0
rows=0

# The same choice the gate makes, so the injected hashing failure wraps the
# command the gate actually runs.
if command -v sha256sum >/dev/null 2>&1; then
  hasher=sha256sum
  digest() { sha256sum | cut -d' ' -f1; }
else
  hasher=shasum
  digest() { shasum -a 256 | cut -d' ' -f1; }
fi
empty_digest=$(printf '' | digest)

record() {
  local expected=$1 got=$2 what=$3 mark
  rows=$((rows + 1))
  if [ "$expected" = "$got" ]; then
    mark="ok  "
  else
    mark="FAIL"
    failures=$((failures + 1))
  fi
  printf '%s  expected=%-6s got=%-10s  %s\n' "$mark" "$expected" "$got" "$what"
}

# A gate under test has to sit at its normal depth, because that is how it
# finds the repository it is judging.
new_repository() {
  fake=$(mktemp -d) || die "mktemp failed"
  mkdir -p "$fake/tools/hooks" "$fake/openwiki/.claims/nested" || die "mkdir failed"
  cp "$hook" "$fake/tools/hooks/openwiki_staleness.sh" || die "copying the hook failed"
  chmod +x "$fake/tools/hooks/openwiki_staleness.sh" || die "chmod failed"
  printf 'one\ntwo\nthree\nfour\nfive\n' >"$fake/subject.txt" || die "writing subject.txt failed"
}

# Writes raw content as a sidecar.
raw_sidecar() {
  printf '%s' "$2" >"$fake/openwiki/.claims/$1.json" || die "writing sidecar $1 failed"
}

# Writes a sidecar holding one claim with the given evidence objects.
sidecar() {
  local name=$1 joined
  shift
  joined=$(
    IFS=,
    echo "$*"
  )
  raw_sidecar "$name" "{\"schemaVersion\":1,\"claims\":[{\"id\":\"c1\",\"statement\":\"s\",\"evidence\":[$joined]}]}"
}

evidence() { jq -nc --arg r "$1" --arg v "$2" '{resource: $r, version: $v}' || die "jq failed"; }

lines_version() {
  local file=$1 first=$2 last=$3 d
  [ -f "$fake/$file" ] || die "lines_version: no $file in the fixture"
  d=$(sed -n "${first},${last}p" "$fake/$file" | digest) || die "lines_version: hashing $file failed"
  printf 'repo-lines-v1:sha256:%s:bWV0YQ' "$d"
}

file_version() {
  local d
  [ -f "$fake/$1" ] || die "file_version: no $1 in the fixture"
  d=$(digest <"$fake/$1") || die "file_version: hashing $1 failed"
  printf 'repo-file-v1:sha256:%s' "$d"
}

valid() { evidence "repo://subject.txt" "$(file_version subject.txt)"; }

# Runs the gate and reports clear (exit 0), refuse (exit 1, and the expected
# words in what it said), or what else happened.
verdict() {
  local expected_words=$1 status output
  shift
  output=$("$@" 2>&1)
  status=$?
  case "$status" in
    0) echo clear ;;
    1)
      if [ -z "$expected_words" ] || grep -qF -- "$expected_words" <<<"$output"; then
        echo refuse
      else
        echo "wrong-why"
        printf '      said: %s\n' "$(head -c 300 <<<"$output" | tr '\n' ' ')" >&2
      fi
      ;;
    *) echo "exit-$status" ;;
  esac
}

case_is() {
  local expected=$1 what=$2 words=${3:-}
  record "$expected" "$(verdict "$words" "$fake/tools/hooks/openwiki_staleness.sh")" "$what"
  rm -rf "$fake"
}

# Runs the gate with every tool it needs on PATH, and one of them replaced by a
# wrapper that does the real work, prints the real output, and then fails —
# the case where a failure would most easily pass for success.
case_with_failing() {
  local tool=$1 what=$2 words=$3 when=${4:-always} stub real t
  stub=$(mktemp -d) || die "mktemp failed"
  for t in bash sh dirname jq awk sed find mktemp sha256sum shasum sort rm cat cut head grep tr; do
    real=$(command -v "$t" 2>/dev/null) || continue
    ln -s "$real" "$stub/$t" || die "linking $t failed"
  done
  real=$(command -v "$tool") || die "no $tool to wrap"
  rm -f "$stub/$tool"
  cp "$failing_tool" "$stub/$tool" || die "copying the $tool wrapper failed"
  record refuse "$(verdict "$words" env PATH="$stub" REAL_TOOL="$real" FAIL_WHEN="$when" "$stub/bash" "$fake/tools/hooks/openwiki_staleness.sh")" "$what"
  rm -rf "$stub" "$fake"
}

echo "# a record the gate can verify"

new_repository
sidecar page "$(evidence "repo://subject.txt#L2-L4" "$(lines_version subject.txt 2 4)")"
case_is clear "a line range whose bytes still hash to the recorded digest"

new_repository
sidecar page "$(evidence "repo://subject.txt#L3" "$(lines_version subject.txt 3 3)")"
case_is clear "a single-line citation written as #L3"

new_repository
sidecar page "$(valid)"
case_is clear "a whole-file digest"

new_repository
: >"$fake/empty.txt" || die "writing empty.txt failed"
sidecar page "$(evidence "repo://empty.txt" "$(file_version empty.txt)")"
case_is clear "an empty file cited whole"

new_repository
printf 'one\ntwo' >"$fake/unterminated.txt" || die "writing unterminated.txt failed"
sidecar page "$(evidence "repo://unterminated.txt#L2" "$(lines_version unterminated.txt 2 2)")"
case_is clear "the last line of a file with no trailing newline"

new_repository
cp "$fake/subject.txt" "$fake/sub#ject.txt" || die "copy failed"
sidecar page "$(evidence "repo://sub#ject.txt#L1-L2" "$(lines_version 'sub#ject.txt' 1 2)")"
case_is clear "a path containing # with a line range after it"

new_repository
sidecar page "$(valid)" '{"resource":"https://bazel.build/external/extension"}'
case_is clear "a source outside the repository, which is not this gate's question"

new_repository
sidecar a "$(evidence "repo://subject.txt#L1-L2" "$(lines_version subject.txt 1 2)")"
sidecar b "$(valid)"
cp "$fake/openwiki/.claims/b.json" "$fake/openwiki/.claims/nested/c.json" || die "copy failed"
case_is clear "several sidecars, including a nested one"

echo
echo "# the wiki has gone stale"

new_repository
sidecar page "$(valid)"
printf 'one\ntwo\nthree\nfour\nsix\n' >"$fake/subject.txt" || die "rewrite failed"
case_is refuse "the cited file changed" "have changed"

new_repository
sidecar page "$(evidence "repo://subject.txt#L2-L4" "$(lines_version subject.txt 2 4)")"
printf 'one\ntwo\nTHREE\nfour\nfive\n' >"$fake/subject.txt" || die "rewrite failed"
case_is refuse "a line inside the cited range changed" "have changed"

new_repository
sidecar page "$(evidence "repo://subject.txt#L2-L4" "$(lines_version subject.txt 2 4)")"
printf 'zero\none\ntwo\nthree\nfour\nfive\n' >"$fake/subject.txt" || die "rewrite failed"
case_is refuse "a line was inserted above the cited range, so the citation moved" "have changed"

new_repository
sidecar page "$(valid)"
rm "$fake/subject.txt" || die "rm failed"
case_is refuse "the cited file is gone" "no longer exist"

new_repository
sidecar page "$(valid)" '{"resource":"https://bazel.build/external/extension"}'
printf 'changed\n' >"$fake/subject.txt" || die "rewrite failed"
case_is refuse "an outside source is skipped, and the repository source is still checked" "have changed"

echo
echo "# a record the gate cannot check as written"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt" "repo-tree-v1:sha256:$(digest <"$fake/subject.txt")")"
case_is refuse "a digest kind this script does not know" "the digest is recorded as"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt" "repo-file-v1:sha512:$(digest <"$fake/subject.txt")")"
case_is refuse "an algorithm label that is not the digest that follows it" "the digest is recorded as"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt" "repo-file-v1:sha256:abc123")"
case_is refuse "a digest that is not 64 hexadecimal characters" "the digest is recorded as"

new_repository
sidecar page "$(valid)" '{"resource":"repo://subject.txt"}'
case_is refuse "repository evidence with no recorded digest, beside a valid citation" "no digest is recorded"

new_repository
sidecar page "$(valid)" '{"resource":"repo://subject.txt","version":null}'
case_is refuse "repository evidence whose digest is null, beside a valid citation" "no digest is recorded"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#not-a-line" "repo-lines-v1:sha256:$empty_digest:bWV0YQ")"
case_is refuse "a line digest whose fragment is not a line range, matching the digest of nothing" "without a usable line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L1-L2" "$(file_version subject.txt)")"
case_is refuse "a whole-file digest recorded against a line range" "whole-file digest is recorded against a line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L99-L99" "repo-lines-v1:sha256:$empty_digest:bWV0YQ")"
case_is refuse "a line range past the end of the file, matching the digest of nothing" "the file has lines 1-5"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L4-L2" "repo-lines-v1:sha256:$empty_digest:bWV0YQ")"
case_is refuse "a line range that runs backwards" "the file has lines 1-5"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L0-L2" "repo-lines-v1:sha256:$empty_digest:bWV0YQ")"
case_is refuse "a line range starting at zero" "without a usable line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L01-L02" "$(lines_version subject.txt 1 2)")"
case_is refuse "a line number written with a leading zero" "without a usable line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L999999999999999999999999999999999" "repo-lines-v1:sha256:$empty_digest:bWV0YQ")"
case_is refuse "a first line number too long to compare" "without a usable line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://subject.txt#L1-L999999999999999999999999" "$(lines_version subject.txt 1 5)")"
case_is refuse "a last line number too long to compare, with the whole file's digest" "without a usable line range"

new_repository
sidecar page "$(valid)" "$(evidence "repo://" "repo-file-v1:sha256:$empty_digest")"
case_is refuse "a resource that names no path" "does not stay inside the repository"

new_repository
sidecar page "$(valid)" "$(evidence "repo://../outside.txt" "repo-file-v1:sha256:$empty_digest")"
case_is refuse "a path that climbs out with .." "does not stay inside the repository"

new_repository
sidecar page "$(valid)" "$(evidence "repo:///etc/hostname" "repo-file-v1:sha256:$empty_digest")"
case_is refuse "an absolute path" "does not stay inside the repository"

new_repository
sidecar page "$(valid)" "$(evidence "repo://openwiki//subject.txt" "$(file_version subject.txt)")"
case_is refuse "a path with an empty segment" "does not stay inside the repository"

new_repository
sidecar page "$(valid)" "$(evidence "repo://sub"$'\t'"ject.txt" "repo-file-v1:sha256:$empty_digest")"
case_is refuse "a resource holding a tab" "control character or a backslash"

new_repository
sidecar page "$(valid)" "$(evidence 'repo://sub\ject.txt' "repo-file-v1:sha256:$empty_digest")"
case_is refuse "a resource holding a backslash" "control character or a backslash"

new_repository
sidecar page "$(valid)" "$(evidence "repo://openwiki" "repo-file-v1:sha256:$empty_digest")"
case_is refuse "a directory cited as a file" "not a regular file inside the repository"

new_repository
ln -s subject.txt "$fake/link.txt" || die "ln failed"
sidecar page "$(valid)" "$(evidence "repo://link.txt" "$(file_version subject.txt)")"
case_is refuse "a symlink cited as a file, even one pointing inside" "not a regular file inside the repository"

new_repository
outside=$(mktemp -d) || die "mktemp failed"
cp "$fake/subject.txt" "$outside/subject.txt" || die "copy failed"
ln -s "$outside" "$fake/escape" || die "ln failed"
sidecar page "$(valid)" "$(evidence "repo://escape/subject.txt" "$(file_version subject.txt)")"
case_is refuse "a file reached through a symlinked directory outside the repository" "not a regular file inside the repository"
rm -rf "$outside"

new_repository
outside=$(mktemp -d) || die "mktemp failed"
cp "$fake/subject.txt" "$outside/subject.txt" || die "copy failed"
ln -s "$outside" "$fake/-escape" || die "ln failed"
sidecar page "$(valid)" "$(evidence "repo://-escape/subject.txt" "$(file_version subject.txt)")"
case_is refuse "a file reached through a symlinked directory outside, named with a leading dash" "not a regular file inside the repository"
rm -rf "$outside"

echo
echo "# a sidecar the gate cannot read"

new_repository
sidecar page "$(valid)"
raw_sidecar empty '{}'
case_is refuse "an empty object beside a readable sidecar" "no claims array"

new_repository
sidecar page "$(valid)"
raw_sidecar empty ''
case_is refuse "an empty file beside a readable sidecar" "0 JSON documents"

new_repository
sidecar aaa "$(valid)"
raw_sidecar zzz 'not json {{{'
case_is refuse "a sidecar that does not parse, beside a readable one" "cannot be read as a claims sidecar"

new_repository
sidecar aaa "$(valid)"
printf 'not json {{{' >"$fake/openwiki/.claims/nested/zzz.json" || die "write failed"
case_is refuse "a sidecar that does not parse, nested below a readable one" "cannot be read as a claims sidecar"

new_repository
raw_sidecar page "{\"claims\":[{\"evidence\":[$(valid)]}]}
{\"claims\":[{\"id\":\"c1\",\"evidence\":[$(valid)]}]}"
case_is refuse "two JSON documents, the first invalid" "2 JSON documents"

new_repository
raw_sidecar page "{\"claims\":[{\"id\":\"c1\",\"evidence\":[$(valid)]}]}
{\"claims\":[{\"evidence\":[$(valid)]}]}"
case_is refuse "two JSON documents, the second invalid" "2 JSON documents"

new_repository
raw_sidecar page "{\"claims\":[{\"id\":\"c1\",\"evidence\":[]}]}"
case_is refuse "a claim resting on no evidence at all" "rests on no evidence"

new_repository
raw_sidecar page "{\"claims\":[{\"evidence\":[$(valid)]}]}"
case_is refuse "a claim with no id" "a claim has no id"

new_repository
raw_sidecar page "{\"claims\":[{\"id\":\"c1\",\"evidence\":[$(valid),{\"resource\":null,\"version\":\"x\"}]}]}"
case_is refuse "evidence whose resource is null" "has evidence with no resource"

new_repository
case_is refuse "no sidecars at all" "holds no sidecars"

new_repository
rm -rf "$fake/openwiki/.claims" || die "rm failed"
case_is refuse "openwiki/.claims does not exist" "openwiki/.claims is missing"

new_repository
sidecar page '{"resource":"https://bazel.build/external/extension"}'
case_is refuse "nothing in the repository to check" "nothing to check"

echo
echo "# a command the gate depends on fails after doing its work"

new_repository
sidecar page "$(valid)"
case_with_failing "$hasher" "hashing a whole file" "could not hash subject.txt"

new_repository
sidecar page "$(evidence "repo://subject.txt#L2-L4" "$(lines_version subject.txt 2 4)")"
case_with_failing sed "extracting a line range to hash" "could not hash lines 2-4"

new_repository
sidecar page "$(valid)"
case_with_failing find "listing the sidecars" "could not list openwiki/.claims"

new_repository
sidecar page "$(valid)"
case_with_failing jq "reading a sidecar" "cannot be read as a claims sidecar"

new_repository
sidecar aaa "$(valid)"
sidecar zzz "$(evidence "repo://subject.txt#L1-L2" "$(lines_version subject.txt 1 2)")"
case_with_failing jq "reading the second sidecar, after the first was read cleanly" "cannot be read as a claims sidecar" second-run

new_repository
sidecar page "$(valid)"
case_with_failing awk "counting the rows collected" "could not count the rows" counting-rows

new_repository
sidecar page "$(evidence "repo://subject.txt#L2-L4" "$(lines_version subject.txt 2 4)")"
case_with_failing awk "counting a cited file's lines" "could not count the lines of subject.txt" counting-lines

echo
echo "# a tool the gate depends on is missing"

new_repository
sidecar page "$(valid)"
stub=$(mktemp -d) || die "mktemp failed"
for t in bash dirname awk sed find mktemp sha256sum shasum sort rm cat; do
  real=$(command -v "$t" 2>/dev/null) || continue
  ln -s "$real" "$stub/$t" || die "linking $t failed"
done
record refuse "$(verdict "needs jq" env PATH="$stub" "$stub/bash" "$fake/tools/hooks/openwiki_staleness.sh")" "jq is missing"
rm -rf "$stub" "$fake"

echo
echo "rows: $rows  failures: $failures"
[ "$failures" -eq 0 ]
