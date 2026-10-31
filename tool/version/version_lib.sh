#!/usr/bin/env bash
# Shared helpers for the version scheme (sourced by bump_version.sh and check_version_commit.sh).
#
# tool/version/series.conf lists one version series per line:
#   <name> <tag-prefix> <pubspec> [<pubspec> ...]
# All pubspecs of a series carry the same version; each bump is tagged <tag-prefix><version>.
# A file belongs to a series when it sits under the directory of one of its pubspecs.

VL_CONF="tool/version/series.conf"

# Prints the series lines without comments or blank lines.
vl_series() {
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "${1:-$VL_CONF}"
}

# vl_field <series-name> <n>: field n (1-based) of the series line; n=3- gives all pubspecs.
vl_field() {
  vl_series | awk -v n="$1" '$1 == n' | tr -s ' \t' ' ' | sed 's/^ //' | cut -d' ' -f"$2"
}

# Extracts X.Y.Z from pubspec text on stdin (drops any +build suffix).
vl_parse_version() {
  sed -n 's/^version:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1
}

# vl_version_at <rev|:index|worktree> <pubspec>: prints the version or nothing if missing.
vl_version_at() {
  case "$1" in
    worktree) [ -f "$2" ] && vl_parse_version < "$2" ;;
    :) git show ":$2" 2>/dev/null | vl_parse_version ;;
    *) git show "$1:$2" 2>/dev/null | vl_parse_version ;;
  esac
}

# Prints the directories of a series' pubspecs, one per line ("." for the repo root).
vl_series_dirs() {
  local p
  for p in $(vl_field "$1" 3-); do dirname "$p"; done
}

# vl_owner <file>: prints the name of the series that owns the file, or nothing.
vl_owner() {
  local name dir
  for name in $(vl_series | awk '{print $1}'); do
    for dir in $(vl_series_dirs "$name"); do
      if [ "$dir" = "." ] || [ "${1#"$dir"/}" != "$1" ]; then
        echo "$name"
        return
      fi
    done
  done
}

VL_DOC_RE='(\.md$|(^|/)docs/)'

# Succeeds while a merge / cherry-pick / revert / rebase is in progress (version hooks stand aside).
vl_in_sequencer() {
  local d
  d=$(git rev-parse --git-dir)
  for s in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do [ -e "$d/$s" ] && return 0; done
  [ -d "$d/rebase-merge" ] || [ -d "$d/rebase-apply" ]
}

# Prints the commit a new commit is compared with: HEAD, or HEAD^ for `git commit --amend`
# (hooks run as children of the git commit process). Prints nothing for the first commit.
vl_commit_base() {
  git rev-parse -q --verify HEAD >/dev/null || return 0
  case " $(ps -o args= -p "$PPID" 2>/dev/null || true) " in
    *" --amend "*) git rev-parse -q --verify HEAD^ >/dev/null && echo "HEAD^" ;;
    *) echo "HEAD" ;;
  esac
}

# Succeeds when the caller asked to keep every version (explicit human instruction only).
vl_keep_requested() {
  [ "${KEEP_VERSION:-}" = "1" ]
}
