#!/usr/bin/env bash
# prepare-commit-msg <msg-file> [<source> [<sha>]]: appends every bumped series' new tag to the subject
# line when the message does not name it yet. The commit-msg gate still checks the final message.
set -euo pipefail

msg_file="$1"
cd "$(git rev-parse --show-toplevel)"
. tool/version/version_lib.sh

vl_in_sequencer && exit 0
base=$(vl_commit_base)
[ -n "$base" ] || exit 0
git cat-file -e "$base:$VL_CONF" 2>/dev/null || exit 0

tags=""
for name in $(vl_series | awk '{print $1}'); do
  first=$(vl_field "$name" 3- | awk '{print $1}')
  old=$(vl_version_at "$base" "$first")
  new=$(vl_version_at : "$first")
  [ -n "$old" ] && [ -n "$new" ] && [ "$old" != "$new" ] || continue
  tag="$(vl_field "$name" 2)$new"
  grep -v '^#' "$msg_file" | grep -qF -- "$tag" || tags="$tags $tag"
done
[ -n "$tags" ] || exit 0

# Append to the first non-comment line; an empty message gets the tags as its subject.
awk -v t="$tags" '
  !done && !/^#/ && NF { print $0 t; done = 1; next }
  { print }
  END { if (!done) print substr(t, 2) }
' "$msg_file" > "$msg_file.tmp"
mv "$msg_file.tmp" "$msg_file"
