#!/usr/bin/env bash
# pre-commit: bumps the patch of every series whose code is staged but whose version is not yet bumped,
# and stages the bumped pubspecs. Files outside every series (tool/, .githooks/, …) bump the first
# series in tool/version/series.conf. Doc-only changes (*.md, docs/) bump nothing.
# Stands aside for merge / rebase / cherry-pick / revert, the first commit, KEEP_VERSION=1, and while the
# base has no series.conf. An amend compares with HEAD^, so an already bumped commit is not bumped twice.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
. tool/version/version_lib.sh

vl_in_sequencer && exit 0
vl_keep_requested && exit 0
base=$(vl_commit_base)
[ -n "$base" ] || exit 0
git cat-file -e "$base:$VL_CONF" 2>/dev/null || exit 0

code_files=$(git diff --cached --name-only "$base" | grep -Ev "$VL_DOC_RE" || true)
[ -n "$code_files" ] || exit 0

need=""
while IFS= read -r f; do
  owner=$(vl_owner "$f")
  [ -n "$owner" ] || owner=$(vl_series | awk 'NR == 1 {print $1}')
  case " $need " in *" $owner "*) ;; *) need="$need $owner" ;; esac
done <<< "$code_files"

for name in $need; do
  pubspecs=$(vl_field "$name" 3-)
  first=$(echo "$pubspecs" | awk '{print $1}')
  old=$(vl_version_at "$base" "$first")
  [ -n "$old" ] || continue                                  # series new in this commit
  [ "$(vl_version_at : "$first")" = "$old" ] || continue     # already bumped (by hand or earlier)
  for p in $pubspecs; do
    if ! git diff --quiet -- "$p"; then
      echo "✗ auto-bump: $p has unstaged changes; stage or stash them first." >&2
      exit 1
    fi
  done
  tool/bump_version.sh "$name" >/dev/null
  # shellcheck disable=SC2086
  git add -- $pubspecs
  echo "auto-bump: $name $old -> $(vl_version_at : "$first") ($(vl_field "$name" 2)$(vl_version_at : "$first"))"
done
