#!/usr/bin/env bash
# post-commit: tags HEAD with <tag-prefix><version> (annotated, so push.followTags pushes it) for every
# series whose version differs from HEAD^. After an amend, a tag left on the replaced commit moves to
# HEAD; a tag that was already pushed is not moved on the remote (a push of the moved tag is rejected).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
. tool/version/version_lib.sh

vl_in_sequencer && exit 0
[ -f "$VL_CONF" ] || exit 0
parent=""
git rev-parse -q --verify HEAD^ >/dev/null && parent="HEAD^"

# `git commit <paths>` commits from a temporary index, so the bumped pubspecs reach HEAD but the real
# index keeps the old ones. Re-sync a pubspec whose working copy already matches HEAD.
for p in $(for n in $(vl_series | awk '{print $1}'); do vl_field "$n" 3-; done); do
  git diff --quiet HEAD -- "$p" 2>/dev/null && ! git diff --cached --quiet HEAD -- "$p" 2>/dev/null \
    && git reset -q -- "$p"
done

for name in $(vl_series | awk '{print $1}'); do
  first=$(vl_field "$name" 3- | awk '{print $1}')
  new=$(vl_version_at HEAD "$first")
  [ -n "$new" ] || continue
  if [ -n "$parent" ]; then
    [ "$(vl_version_at "$parent" "$first")" != "$new" ] || continue
  fi
  tag="$(vl_field "$name" 2)$new"
  if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    git tag -a "$tag" -m "$tag"
    echo "tagged $tag"
    continue
  fi
  at=$(git rev-parse "$tag^{commit}")
  [ "$at" = "$(git rev-parse HEAD)" ] && continue
  if git merge-base --is-ancestor "$at" HEAD; then
    echo "⚠ tag $tag already exists on an earlier commit ($at); not moved." >&2
  else
    git tag -f -a "$tag" -m "$tag" >/dev/null
    echo "⚠ moved tag $tag to HEAD (it was on a replaced commit). If it was already pushed, fix it by hand." >&2
  fi
done
