#!/usr/bin/env bash
# Builds the comparison corpus into "$1" (outside the repo; ~70 MB) and writes "$1/MANIFEST.tsv".
#   fate/  real-world files from the FFmpeg FATE suite (fate.lst)
#   gen/   synthetic files (gen_synthetic.sh, needs a full-featured ffmpeg on PATH)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out=$(mkdir -p "$1" && cd "$1" && pwd)
mkdir -p "$out/fate"
grep -v '^#' "$here/fate.lst" | grep -v '^$' | while read -r p; do
  dst="$out/fate/${p//\//_}"
  [[ -s $dst ]] || rsync -q "rsync://fate-suite.ffmpeg.org/fate-suite/$p" "$dst"
done
rm -rf "$out/gen"
"$here/gen_synthetic.sh" "$out/gen" >/dev/null
( cd "$out" && find fate gen -type f ! -name cover.jpg | sort | while read -r f; do
    printf '%s\t%s\t%s\n' "$f" "$(stat -c %s "$f")" "$(sha256sum < "$f" | cut -c1-64)"
  done ) > "$out/MANIFEST.tsv"
echo "corpus: $(wc -l < "$out/MANIFEST.tsv") files in $out"
