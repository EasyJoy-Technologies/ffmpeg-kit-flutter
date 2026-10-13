#!/usr/bin/env bash
# Behaviour check of the trimmed component list (see ffmpeg-build/README.md, "Verification"):
#   1. host full build  vs host trimmed build      -> must be identical (exact)
#   2. host trimmed     vs Android arm64 (qemu)     -> arch rules (compare.py)
#   3. host trimmed     vs Android armv7 NEON (qemu)
#   usage: ffmpeg-build/verify_android.sh <work-dir>
#   needs: <work-dir>/corpus (verify/corpus/make_corpus.sh), qemu-user, NDK $ANDROID_NDK_VERSION, root (unshare)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/pins.env"
source "$here/lib/common.sh"
work=$(cd "${1:?usage: verify_android.sh <work-dir>}" && pwd)
v="$here/verify"
[[ -s $work/corpus/MANIFEST.tsv ]] || die "corpus missing: run verify/corpus/make_corpus.sh $work/corpus"

step "pinned FFmpeg source"
checkout_commit "$FFMPEG_REPO" "$FFMPEG_COMMIT" "$work/ffmpeg-src" "$FFMPEG_TAG"

step "build command-line tools"
pids=()
JOBS=4 "$v/build_tools.sh" host full "$work/ffmpeg-src" "$work/tools-host-full" & pids+=($!)
JOBS=4 "$v/build_tools.sh" host trimmed "$work/ffmpeg-src" "$work/tools-host-trimmed" & pids+=($!)
for p in "${pids[@]}"; do wait "$p" || die "host tool build failed"; done
pids=()
JOBS=4 "$v/build_tools.sh" android-arm64 trimmed "$work/ffmpeg-src" "$work/tools-arm64" & pids+=($!)
JOBS=4 "$v/build_tools.sh" android-armv7-neon trimmed "$work/ffmpeg-src" "$work/tools-armv7" & pids+=($!)
for p in "${pids[@]}"; do wait "$p" || die "android tool build failed"; done

step "run corpus ($(wc -l < "$work/corpus/MANIFEST.tsv") files x 4 builds)"
t="$work/tools"
# The 2-hour file only matters for the duration scan, which is checked on the host runs; under qemu
# it would take hours and exercises the same decode path as the other mp3 files.
qskip='a_long_2h'
pids=()
JOBS=2 "$v/run_corpus.sh" "$work/corpus" "$work/res-host-full" "$t-host-full/ffmpeg" "$t-host-full/ffprobe" & pids+=($!)
JOBS=2 "$v/run_corpus.sh" "$work/corpus" "$work/res-host-trimmed" "$t-host-trimmed/ffmpeg" "$t-host-trimmed/ffprobe" & pids+=($!)
SKIP=$qskip JOBS=2 "$v/run_corpus.sh" "$work/corpus" "$work/res-arm64" "$t-arm64/ffmpeg" "$t-arm64/ffprobe" qemu-aarch64 & pids+=($!)
# 32-bit bionic aborts when a pid/tid exceeds 65535; a fresh pid namespace keeps them small.
SKIP=$qskip JOBS=2 "$v/run_corpus.sh" "$work/corpus" "$work/res-armv7" "$t-armv7/ffmpeg" "$t-armv7/ffprobe" unshare --pid --fork qemu-arm & pids+=($!)
for p in "${pids[@]}"; do wait "$p" || die "corpus run failed"; done

step "compare"
rec="$here/records/android-verify.md"
mkdir -p "$here/records"
set +e
{
  rc=0
  echo "# Android behaviour check — $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "Corpus: $(wc -l < "$work/corpus/MANIFEST.tsv") files (sha256 list: corpus/MANIFEST.tsv). FFmpeg $FFMPEG_TAG $FFMPEG_COMMIT."
  echo
  echo '```'
  python3 "$v/compare.py" exact "$work/res-host-full" "$work/res-host-trimmed" || rc=1
  python3 "$v/compare.py" arch "$work/res-host-trimmed" "$work/res-arm64" || rc=1
  python3 "$v/compare.py" arch "$work/res-host-trimmed" "$work/res-armv7" || rc=1
  echo '```'
  exit $rc
} | tee "$rec"
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 ]] && echo "verify_android: OK ($rec)" || die "verify_android: differences found (see $rec)"
