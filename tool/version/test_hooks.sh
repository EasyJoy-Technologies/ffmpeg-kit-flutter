#!/usr/bin/env bash
# End-to-end self-test of the version hooks with real commits in a throwaway repo.
# Usage: tool/version/test_hooks.sh
set -euo pipefail

src="$(cd "$(dirname "$0")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp/remote.git"
cd "$tmp" && git init -q -b main work && cd work
git config user.email t@t; git config user.name t
mkdir -p tool pkgs/a pkgs/a2 pkgs/b
cp -r "$src/tool/version" tool/ && rm -f tool/version/series.conf
cp "$src/tool/bump_version.sh" tool/ && cp -r "$src/.githooks" .
printf 'name: a\nversion: 1.0.0\n' > pkgs/a/pubspec.yaml
printf 'name: a2\nversion: 1.0.0\n' > pkgs/a2/pubspec.yaml
printf 'name: b\nversion: 1.0.3\n' > pkgs/b/pubspec.yaml
echo x > pkgs/a/lib.dart; echo x > pkgs/b/lib.dart
git add -A && git commit -q -m init
printf 'a v pkgs/a/pubspec.yaml pkgs/a2/pubspec.yaml\nb b-v pkgs/b/pubspec.yaml\n' > tool/version/series.conf
git add -A && git commit -q -m conf          # hooks not enabled yet
tool/version/install_hooks.sh >/dev/null
git remote add origin "$tmp/remote.git" && git push -q origin main

pass=0 failn=0
ok() { pass=$((pass + 1)); }
bad() { failn=$((failn + 1)); echo "✗ $1"; }
expect() { # expect <description> <command...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}
ver() { sed -n 's/^version: //p' "$1"; }
subject() { git log -1 --format=%s; }
tag_at_head() { [ "$(git rev-parse "$1^{commit}" 2>/dev/null)" = "$(git rev-parse HEAD)" ]; }
annotated() { [ "$(git cat-file -t "refs/tags/$1")" = tag ]; }

# 1. Code change: patch +1 in every pubspec of the series, tag in the message, annotated tag on HEAD.
echo y >> pkgs/a/lib.dart; git add -A; git commit -q -m "fix a"
expect "auto-bump a" test "$(ver pkgs/a/pubspec.yaml)/$(ver pkgs/a2/pubspec.yaml)" = 1.0.1/1.0.1
expect "b untouched" test "$(ver pkgs/b/pubspec.yaml)" = 1.0.3
expect "message names tag" test "$(subject)" = "fix a v1.0.1"
expect "tag on HEAD" tag_at_head v1.0.1
expect "tag annotated" annotated v1.0.1
expect "clean tree" test -z "$(git status --porcelain)"

# 2. Bumped by hand: not bumped again.
echo y >> pkgs/a/lib.dart; tool/bump_version.sh a >/dev/null; git add -A; git commit -q -m "fix a again"
expect "manual bump once" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.2
expect "manual bump tagged" tag_at_head v1.0.2

# 3. Amend: compared with HEAD^, so no second bump; the tag follows the amended commit.
echo z >> pkgs/a/lib.dart; git add -A; git commit -q --amend -m "fix a again v1.0.2"
expect "amend keeps version" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.2
expect "amend moves tag" tag_at_head v1.0.2

# 4. Doc-only: no bump, no tag.
echo doc >> README.md; git add -A; git commit -q -m "docs"
expect "doc-only no bump" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.2
expect "doc-only subject unchanged" test "$(subject)" = docs

# 5. Other series only.
echo y >> pkgs/b/lib.dart; git add -A; git commit -q -m "fix b"
expect "series b bumped" test "$(ver pkgs/b/pubspec.yaml)/$(ver pkgs/a/pubspec.yaml)" = 1.0.4/1.0.2
expect "series b tag" tag_at_head b-v1.0.4

# 6. Both series in one commit.
echo w >> pkgs/a/lib.dart; echo w >> pkgs/b/lib.dart; git add -A; git commit -q -m "fix both"
expect "both bumped" test "$(ver pkgs/a/pubspec.yaml)/$(ver pkgs/b/pubspec.yaml)" = 1.0.3/1.0.5
expect "both tags in message" test "$(subject)" = "fix both v1.0.3 b-v1.0.5"
expect "both tagged" tag_at_head b-v1.0.5

# 7. Files outside every series bump the first series.
echo y >> tool/extra.sh; git add -A; git commit -q -m "tooling"
expect "orphan bumps first series" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.4

# 8. KEEP_VERSION=1: nothing bumped, gate passes.
echo k >> pkgs/a/lib.dart; git add -A; KEEP_VERSION=1 git commit -q -m "keep"
expect "keep-version" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.4

# 9. Partly staged pubspec: refused, nothing committed.
head=$(git rev-parse HEAD)
echo y >> pkgs/a/lib.dart; git add pkgs/a/lib.dart; echo '# note' >> pkgs/a/pubspec.yaml
if git commit -q -m "partial" >/dev/null 2>&1; then bad "partial pubspec refused"; else ok; fi
expect "nothing committed" test "$(git rev-parse HEAD)" = "$head"
git checkout -q -- pkgs/a/pubspec.yaml; git reset -q --hard HEAD

# 10. --no-verify skips the bump; the next gate run still sees a consistent history.
echo n >> pkgs/a/lib.dart; git add -A; git commit -q --no-verify -m "unchecked"
expect "no-verify does not bump" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.4

# 11. git commit -a.
echo a >> pkgs/a/lib.dart; git commit -q -a -m "commit -a"
expect "commit -a bumps" test "$(ver pkgs/a/pubspec.yaml)" = 1.0.5
expect "commit -a clean tree" test -z "$(git status --porcelain)"

# 12. git commit <paths> (temporary index): the bumped pubspec is committed and the index stays in sync.
echo o >> pkgs/a/lib.dart; git commit -q -m "only" pkgs/a/lib.dart
expect "commit <paths> bumps" test "$(git show HEAD:pkgs/a/pubspec.yaml | sed -n 's/^version: //p')" = 1.0.6
expect "commit <paths> clean tree" test -z "$(git status --porcelain)"

# 13. push carries the tags (push.followTags).
git push -q origin main
expect "tags pushed" test -n "$(git ls-remote --tags origin v1.0.6)"
expect "series b tag pushed" test -n "$(git ls-remote --tags origin b-v1.0.5)"

echo "passed $pass, failed $failn"
[ "$failn" -eq 0 ]
