#!/usr/bin/env bash
# Self-test for the version gate and bump script; runs in a throwaway repo. Usage: tool/version/test_check_version_commit.sh
set -euo pipefail

src="$(cd "$(dirname "$0")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main
git config user.email t@t; git config user.name t
mkdir -p tool/version pkgs/a pkgs/a2 pkgs/b
cp "$src/tool/version/version_lib.sh" "$src/tool/version/check_version_commit.sh" tool/version/
cp "$src/tool/bump_version.sh" tool/
printf 'name: a\nversion: 1.0.0\n' > pkgs/a/pubspec.yaml
printf 'name: a2\nversion: 1.0.0\n' > pkgs/a2/pubspec.yaml
printf 'name: b\nversion: 1.0.3\n' > pkgs/b/pubspec.yaml
echo x > pkgs/a/lib.dart; echo x > pkgs/b/lib.dart; echo x > root.sh
git add -A && git commit -q -m init   # base without series.conf
pass=0 failn=0
check() { # check <expect pass|fail> <description> <message>
  printf '%s\n' "$3" > "$tmp/.msg"
  if tool/version/check_version_commit.sh "$tmp/.msg" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$1" ]; then pass=$((pass + 1)); else failn=$((failn + 1)); echo "✗ $2: expected $1, got $got"; fi
}
reset() { git reset -q --hard HEAD; }

printf 'a v pkgs/a/pubspec.yaml pkgs/a2/pubspec.yaml\nb b-v pkgs/b/pubspec.yaml\n' > tool/version/series.conf
echo y >> pkgs/a/lib.dart; git add -A; check pass "introducing commit (base lacks series.conf)" "scheme"
git commit -q -m scheme
echo doc >> README.md; git add README.md; check pass "doc-only" "docs"; reset
echo y >> pkgs/a/lib.dart; git add -A; check fail "code change without bump" "fix"; reset
echo y >> pkgs/a/lib.dart; tool/bump_version.sh a >/dev/null; git add -A; check pass "bump with tag" "fix v1.0.1"; reset
echo y >> pkgs/a/lib.dart; tool/bump_version.sh a >/dev/null; git add -A; check fail "bump without tag in message" "fix"; reset
echo y >> pkgs/a/lib.dart; sed -i 's/1.0.0/1.0.2/' pkgs/a/pubspec.yaml pkgs/a2/pubspec.yaml; git add -A; check fail "+2" "fix v1.0.2"; reset
echo y >> pkgs/a/lib.dart; sed -i 's/1.0.0/1.0.1/' pkgs/a/pubspec.yaml; git add -A; check fail "out of sync" "fix v1.0.1"; reset
echo y >> pkgs/b/lib.dart; tool/bump_version.sh a >/dev/null; git add -A; check fail "wrong series bumped" "fix v1.0.1"; reset
echo y >> root.sh; git add -A; check fail "repo file without any bump" "chore"; reset
echo y >> root.sh; tool/bump_version.sh b >/dev/null; git add -A; check pass "repo file with one bump" "chore b-v1.0.4"; reset
echo y >> pkgs/a/lib.dart; git add -A; check pass "keep-version" "fix [keep-version]"; reset
echo y >> pkgs/a/lib.dart; tool/bump_version.sh a >/dev/null; git add -A; check fail "keep-version with bump" "fix v1.0.1 [keep-version]"; reset
echo y >> pkgs/a/lib.dart; tool/bump_version.sh a --line 1.1 >/dev/null; git add -A; check pass "--line keeps patch +1" "fix v1.1.1"; reset
if tool/bump_version.sh >/dev/null 2>&1; then failn=$((failn + 1)); echo "✗ bump without series should fail with two series"; else pass=$((pass + 1)); fi

echo "passed $pass, failed $failn"
[ "$failn" -eq 0 ]
