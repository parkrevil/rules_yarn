#!/usr/bin/env bash
# Reports whether the generated wiki still describes the repository.
#
# It does not guess which files matter, and it does not reason about commits.
# Every claim a page makes records the exact bytes it was written from:
# openwiki/.claims/**.json names each source as `repo://<path>` or
# `repo://<path>#L<first>-L<last>` and stores a digest of it. Recomputing those
# digests from the working tree answers the question directly — a source whose
# bytes no longer hash to what the page recorded is a source the page may now
# describe wrongly.
#
# Regenerating needs an agent driving OpenWiki's MCP server, which a shell hook
# cannot do, so this reports and refuses rather than fixing.
#
# Everything here fails closed: a gate that cannot read a record must not clear
# it. The work is split so that each half can be held to that. jq reads every
# sidecar and turns each record into a row it has already validated, or stops
# naming what it could not read. The shell only touches files: it confirms
# each cited file is inside the repository, counts its lines and hashes it,
# and at the end proves it handled every row jq produced.
set -uo pipefail

repository=$(cd "$(dirname "$0")/../.." && pwd -P) || exit 1
cd "$repository" || exit 1

refuse() {
  echo >&2 "$*"
  echo >&2 "tools/hooks/openwiki_staleness.sh cannot tell whether the wiki is current, so it refuses."
  exit 1
}

for tool in jq awk sed find mktemp; do
  command -v "$tool" >/dev/null 2>&1 ||
    refuse "openwiki_staleness.sh needs ${tool}, which is not on PATH."
done

# sha256sum on Linux, shasum on macOS; both print the digest as the first word.
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256; }
else
  refuse "openwiki_staleness.sh needs sha256sum or shasum, and found neither."
fi

[ -d openwiki/.claims ] ||
  refuse "openwiki/.claims is missing, so there is no record of what the wiki rests on."

work=$(mktemp -d) || refuse "openwiki_staleness.sh could not create a working directory."
trap 'rm -rf "$work"' EXIT

find openwiki/.claims -name '*.json' -print0 >"$work/sidecars" ||
  refuse "openwiki_staleness.sh could not list openwiki/.claims."

# One sidecar in, one validated row per piece of repository evidence out, its
# fields joined by the ASCII unit separator:
#   check  kind  digest  path  first  last  resource
#   bad    reason  resource
# The separator is not whitespace to the shell, so an empty field — `first` and
# `last` on a whole-file row — survives `read` instead of collapsing, and no
# field can contain it: a check row's resource holds no control character, and
# a bad row quotes anything it reports.
# A sidecar this filter cannot read as a whole is an error, never a partial
# result: it is slurped so that a second JSON document cannot hide behind the
# first, and every claim and every piece of evidence has to carry the fields
# the rows are built from.
#
# A line number is at most nine digits with no leading zero, so the shell's
# integer comparisons below can never be handed a number they cannot compare.
# A resource holding a control character or a backslash is refused rather than
# escaped: no file name OpenWiki writes needs one, and a path that had to be
# unescaped on the way out is a path this script could get wrong.
rows_from_sidecar='
  def shown: if test("[[:cntrl:]\\\\]") then tojson else . end;
  def bad($why): ["bad", $why, (.resource | ltrimstr("repo://") | shown)] | join("\u001f");

  if length != 1 then error("it holds \(length) JSON documents, not one") else .[0] end
  | if type != "object" or (.claims | type) != "array"
    then error("it has no claims array") else . end
  | .claims[]
  | if (.id | type) != "string" then error("a claim has no id") else . end
  | .id as $id
  | if (.evidence | type) != "array" or (.evidence | length) == 0
    then error("claim \($id) rests on no evidence") else . end
  | .evidence[]
  | if (.resource | type) != "string"
    then error("claim \($id) has evidence with no resource") else . end
  # Out of scope rather than unchecked: this gate answers whether the wiki
  # still describes this repository, so a source outside it is not its
  # question. Nothing in the sidecars is such a source today.
  | select(.resource | startswith("repo://"))
  | if (.version | type) != "string" then bad("no digest is recorded")
    elif (.resource | test("[[:cntrl:]\\\\]")) then bad("the resource holds a control character or a backslash")
    else
      (.version | capture("^(?<kind>repo-file-v1|repo-lines-v1):sha256:(?<digest>[0-9a-f]{64})(:.*)?$")
        // null) as $v
      | (.resource | ltrimstr("repo://")) as $rest
      | ($rest | capture("^(?<path>.+)#L(?<first>[1-9][0-9]{0,8})(-L(?<last>[1-9][0-9]{0,8}))?$")
        // null) as $range
      | if $v == null then bad("the digest is recorded as \(.version | shown)")
        elif $v.kind == "repo-file-v1" and $range != null then bad("a whole-file digest is recorded against a line range")
        elif $v.kind == "repo-lines-v1" and $range == null then bad("a line digest is recorded without a usable line range")
        else
          (if $range == null then {path: $rest, first: "", last: ""}
           else {path: $range.path, first: $range.first, last: ($range.last // $range.first)} end) as $at
          | if ($at.path | test("^/|(^|/)\\.\\.(/|$)|(^|/)(/|$)"))
            then bad("the path does not stay inside the repository")
            else ["check", $v.kind, $v.digest, $at.path, $at.first, $at.last, .resource] | join("\u001f") end
        end
    end
'

sidecars=0
while IFS= read -r -d '' sidecar; do
  sidecars=$((sidecars + 1))
  if ! message=$(jq -r -s "$rows_from_sidecar" "$sidecar" 2>&1 >>"$work/rows"); then
    refuse "$sidecar cannot be read as a claims sidecar: ${message#jq: error (at <unknown>): }"
  fi
done <"$work/sidecars"
[ "$sidecars" -gt 0 ] ||
  refuse "openwiki/.claims holds no sidecars, so there is no record of what the wiki rests on."

expected=$(awk 'END {print NR}' "$work/rows") ||
  refuse "openwiki_staleness.sh could not count the rows it collected."
[ "$expected" -gt 0 ] ||
  refuse "No source in openwiki/.claims is in this repository, so there is nothing to check."

missing=
changed=
unreadable=
handled=0

# The parent directory is taken by parameter expansion, not dirname: a path
# beginning with `-` would be read by dirname as an option, and its empty
# output would send the check to the repository root and clear the file.
inside_repository() {
  local parent directory
  [ ! -L "./$1" ] || return 1
  case "$1" in
    */*) parent=${1%/*} ;;
    *) parent=. ;;
  esac
  directory=$(cd "./$parent" 2>/dev/null && pwd -P) || return 1
  case "$directory/" in
    "$repository"/*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS=$'\x1f' read -r verdict a b c d e f; do
  handled=$((handled + 1))
  if [ "$verdict" = bad ]; then
    unreadable+="$b — $a"$'\n'
    continue
  fi
  kind=$a expected_digest=$b path=$c first=$d last=$e resource=${f#repo://}

  if [ ! -e "./$path" ] && [ ! -L "./$path" ]; then
    missing+="$resource"$'\n'
    continue
  fi
  if [ ! -f "./$path" ] || ! inside_repository "$path"; then
    unreadable+="$resource — not a regular file inside the repository"$'\n'
    continue
  fi

  if [ "$kind" = repo-lines-v1 ]; then
    lines=$(awk 'END {print NR}' "./$path") ||
      refuse "openwiki_staleness.sh could not count the lines of $path."
    # An empty or out-of-order range hashes nothing, which would match the
    # digest of nothing. Saying the range is wrong is the honest answer.
    if [ "$last" -lt "$first" ] || [ "$last" -gt "$lines" ]; then
      unreadable+="$resource — the file has lines 1-$lines"$'\n'
      continue
    fi
    got=$(sed -n "${first},${last}p" "./$path" | sha256) ||
      refuse "openwiki_staleness.sh could not hash lines $first-$last of $path."
  else
    got=$(sha256 <"./$path") ||
      refuse "openwiki_staleness.sh could not hash $path."
  fi

  [ "${got%% *}" = "$expected_digest" ] || changed+="$resource"$'\n'
done <"$work/rows"

# Every row jq produced has to have been handled. A read that failed or stopped
# early would otherwise look exactly like a short, clean list.
[ "$handled" -eq "$expected" ] ||
  refuse "openwiki_staleness.sh collected $expected rows but handled $handled."

if [ -z "$changed" ] && [ -z "$missing" ] && [ -z "$unreadable" ]; then
  exit 0
fi

# More than one claim can cite the same source, so each is named once.
listed() { printf '%s' "$1" | sort -u | sed 's/^/    /'; }

{
  echo "The wiki no longer describes this repository."
  [ -z "$changed" ] || { echo; echo "  these sources it cites have changed:"; listed "$changed"; }
  [ -z "$missing" ] || { echo; echo "  these sources it cites no longer exist:"; listed "$missing"; }
  [ -z "$unreadable" ] || { echo; echo "  these records could not be checked as written:"; listed "$unreadable"; }
  echo
  echo "Regenerate it with OpenWiki — in a session with the openwiki MCP server,"
  echo "run the page-job lifecycle; AGENTS.md says not to hand-edit the pages."
  echo "To push without doing that, state why:  SKIP=openwiki-staleness git push"
} >&2
exit 1
