#!/usr/bin/env bash
# The only way to change a version: bumps the patch of one series by 1 in all of its pubspecs.
#
#   tool/bump_version.sh [<series>] [--line X.Y]
#
# <series> is required when tool/version/series.conf lists more than one. --line X.Y changes the
# first two digits (explicit human instruction only); the patch still goes +1.
# Afterwards: git add the printed files, put the printed tag in the commit message, then tag
# the commit with it and push the tag.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
. tool/version/version_lib.sh

series="" line=""
while [ $# -gt 0 ]; do
  case "$1" in
    --line) line="${2:?--line needs X.Y}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) series="$1"; shift ;;
  esac
done

names=$(vl_series | awk '{print $1}')
if [ -z "$series" ]; then
  [ "$(echo "$names" | wc -l)" -eq 1 ] || { echo "Series required: $(echo $names)" >&2; exit 2; }
  series="$names"
fi
echo "$names" | grep -qx "$series" || { echo "Unknown series '$series' (have: $(echo $names))" >&2; exit 2; }
if [ -n "$line" ] && ! echo "$line" | grep -Eq '^[0-9]+\.[0-9]+$'; then
  echo "--line must be X.Y" >&2; exit 2
fi

pubspecs=$(vl_field "$series" 3-)
first=$(echo "$pubspecs" | awk '{print $1}')
cur=$(vl_version_at worktree "$first")
[ -n "$cur" ] || { echo "No version in $first" >&2; exit 1; }
for p in $pubspecs; do
  [ "$(vl_version_at worktree "$p")" = "$cur" ] || { echo "Out of sync: $p differs from $first ($cur)" >&2; exit 1; }
done

patch=${cur##*.}
new="${line:-${cur%.*}}.$((patch + 1))"
for p in $pubspecs; do
  sed -i -E "s/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[^[:space:]]*/version: $new/" "$p"
done

tag="$(vl_field "$series" 2)$new"
echo "$series: $cur -> $new"
echo "git add $pubspecs"
echo "Commit message must contain: $tag"
echo "After committing: git tag $tag && git push origin $tag"
