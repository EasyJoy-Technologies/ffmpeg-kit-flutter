#!/usr/bin/env bash
# Run once per clone: enables the version hooks and makes `git push` carry the version tags.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
git config push.followTags true
echo "Version hooks enabled (.githooks); push.followTags=true."
