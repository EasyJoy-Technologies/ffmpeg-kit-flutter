#!/usr/bin/env bash
# The only way to change a version: bumps the patch of one series by 1 in all of its pubspecs.
#
#   tool/bump_version.sh [<series>] [--line X.Y]
#
# <series> is required when tool/version/series.conf lists more than one. --line X.Y changes the
# first two digits (explicit human instruction only); the patch still goes +1.
# Normally the pre-commit hook runs this for you (tool/version/install_hooks.sh). By hand: git add the
# printed files; the hooks then add the tag to the message and tag the commit.
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
echo "Tag: $tag (the version hooks add it to the commit message and tag the commit)"
echo "Without the hooks: name $tag in the message, then git tag -a $tag -m $tag and push it."
