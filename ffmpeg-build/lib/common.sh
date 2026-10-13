#!/usr/bin/env bash
# Small helpers shared by the build scripts.

die() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

# checkout_commit <repo-url> <commit-sha> <dir>: shallow checkout of exactly that commit, verified.
checkout_commit() {
  local url=$1 sha=$2 dir=$3
  if [[ -d $dir/.git ]] && [[ $(git -C "$dir" rev-parse HEAD 2>/dev/null) == "$sha" ]]; then
    git -C "$dir" reset -q --hard && git -C "$dir" clean -qfdx
  else
    rm -rf "$dir"; mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" fetch -q --depth 1 "$url" "$sha"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
  fi
  [[ $(git -C "$dir" rev-parse HEAD) == "$sha" ]] || die "$url: expected $sha"
}
