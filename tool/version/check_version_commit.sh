#!/usr/bin/env bash
# Commit gate, called by .githooks/commit-msg with the message file. Base = HEAD (HEAD^ on --amend).
#
# Rules:
#   1. Doc-only commits (every staged file is *.md or under a docs/ directory) pass.
#   2. All pubspecs of a series carry the same version; the patch stays or goes +1 (never +2 or down).
#   3. A series whose files changed (docs excepted) must go +1. Changed files outside every
#      series require at least one series +1.
#   4. Every bumped series' tag (<tag-prefix><version>) appears in the commit message.
#   5. [keep-version] in the message or KEEP_VERSION=1: every version must stay unchanged (explicit human
#      instruction only).
#   6. The first two digits are not checked here (they change only on explicit human instruction).
#   7. Pass when the base has no tool/version/series.conf (the commit that introduces the scheme).
# Skipped during merge / cherry-pick / revert / rebase and for the first commit.
set -euo pipefail

MARKER='[keep-version]'
msg_file="$1"

cd "$(git rev-parse --show-toplevel)"
. tool/version/version_lib.sh

vl_in_sequencer && exit 0
base=$(vl_commit_base)
[ -n "$base" ] || exit 0
git cat-file -e "$base:$VL_CONF" 2>/dev/null || exit 0

fail() {
  {
    echo "✗ Version check failed: $1"
    echo "  The pre-commit hook bumps automatically (tool/version/install_hooks.sh); by hand: tool/bump_version.sh [<series>]."
    echo "  Keeping every version unchanged needs KEEP_VERSION=1 git commit (explicit human instruction only)."
  } >&2
  exit 1
}

files=$(git diff --cached --name-only "$base")
[ -n "$files" ] || exit 0
code_files=$(echo "$files" | grep -Ev "$VL_DOC_RE" || true)
[ -n "$code_files" ] || exit 0

msg=$(grep -v '^#' "$msg_file" || true)
keep=0
case "$msg" in *"$MARKER"*) keep=1 ;; esac
vl_keep_requested && keep=1

bumped_any=0 orphan=0
touched=""
while IFS= read -r f; do
  owner=$(vl_owner "$f")
  if [ -z "$owner" ]; then orphan=1; else touched="$touched $owner"; fi
done <<< "$code_files"

for name in $(vl_series | awk '{print $1}'); do
  pubspecs=$(vl_field "$name" 3-)
  first=$(echo "$pubspecs" | awk '{print $1}')
  new=$(vl_version_at : "$first")
  old=$(vl_version_at "$base" "$first")
  [ -n "$new" ] || fail "$first has no version"
  for p in $pubspecs; do
    [ "$(vl_version_at : "$p")" = "$new" ] || fail "series $name out of sync: $p differs from $first ($new)"
  done
  [ -n "$old" ] || continue  # series new in this commit
  if [ "$new" = "$old" ]; then
    case " $touched " in
      *" $name "*) [ "$keep" -eq 1 ] || fail "series $name changed but its version stayed $old" ;;
    esac
    continue
  fi
  [ "$keep" -eq 0 ] || fail "$MARKER declared but series $name changed $old -> $new"
  [ "${new##*.}" -eq $(( ${old##*.} + 1 )) ] || fail "series $name patch must go +1 ($old -> $new)"
  tag="$(vl_field "$name" 2)$new"
  case "$msg" in *"$tag"*) ;; *) fail "commit message must contain $tag" ;; esac
  bumped_any=1
done

if [ "$orphan" -eq 1 ] && [ "$bumped_any" -eq 0 ] && [ "$keep" -eq 0 ]; then
  fail "repository files changed; at least one series must go +1"
fi
exit 0
