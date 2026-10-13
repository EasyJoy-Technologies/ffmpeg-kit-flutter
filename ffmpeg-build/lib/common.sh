#!/usr/bin/env bash
# Small helpers shared by the build scripts.

die() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

# checkout_commit <repo-url> <commit-sha> <dir> [tag]: shallow checkout of exactly that commit, verified.
# With a tag, the tag is fetched too and must point at the commit: FFmpeg's version string comes from
# `git describe --tags` (ffbuild/version.sh), which gives "n8.1.2" only when the tag is present and the
# bare short hash otherwise.
checkout_commit() {
  local url=$1 sha=$2 dir=$3 tag=${4:-}
  if [[ -d $dir/.git ]] && [[ $(git -C "$dir" rev-parse HEAD 2>/dev/null) == "$sha" ]] &&
     { [[ -z $tag ]] || [[ $(git -C "$dir" rev-parse -q --verify "refs/tags/$tag^{commit}") == "$sha" ]]; }; then
    git -C "$dir" reset -q --hard && git -C "$dir" clean -qfdx
  else
    rm -rf "$dir"; mkdir -p "$dir"
    git -C "$dir" init -q
    if [[ -n $tag ]]; then
      git -C "$dir" fetch -q --depth 1 "$url" "+refs/tags/$tag:refs/tags/$tag"
      git -C "$dir" -c advice.detachedHead=false checkout -q "refs/tags/$tag^{commit}"
    else
      git -C "$dir" fetch -q --depth 1 "$url" "$sha"
      git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
  fi
  [[ $(git -C "$dir" rev-parse HEAD) == "$sha" ]] || die "$url: expected $sha"
  if [[ -n $tag ]]; then
    [[ $(git -C "$dir" describe --tags --always) == "$tag" ]] || die "$url: $tag does not describe $sha"
  fi
}
