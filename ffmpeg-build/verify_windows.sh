#!/usr/bin/env bash
# Behaviour check of windows/dist/$WINDOWS_ZIP (build_windows.sh), as verify_apple.sh does for Apple:
# the bundle is loaded the way the Flutter plugin loads it (verify/windows/nnkit_cli.cpp: LoadLibraryA
# + the C API, DLLs rebased with editbin like windows/CMakeLists.txt) and run with NiceNote's
# argument shapes (verify/run_corpus.sh), together with the v1.1.0 bundle:
#   1. here, new vs v1.1.0 on the same machine: compare.py exact (expected differences: the probe
#      titles with non-ASCII text, which v1.1.0 reported as '?', see build_windows.sh)
#   2. on the build server, new vs the Linux reference: compare.py arch-kit
# Outputs identical to the reference (new) or to the new results (v1.1.0) are deleted here.
#
#   usage: ffmpeg-build/verify_windows.sh <work-dir> <corpus.tar.gz>
#   needs: MSYS2 MINGW64 shell (g++, python), Visual Studio (editbin), the $BASE_REF tag
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/pins.env"
source "$here/lib/common.sh"
work=$(mkdir -p "${1:?usage: verify_windows.sh <work-dir> <corpus.tar.gz>}" && cd "$1" && pwd)
tarball=${2:?corpus.tar.gz}
[[ ${MSYSTEM:-} == MINGW64 ]] || die "run in the MSYS2 MINGW64 environment"
export PYTHONUTF8=1   # MINGW64 python defaults to cp1252 and cannot print the Chinese titles

step "1/5 corpus"
rm -rf "$work/corpus" "$work/reference"
tar -xzf "$tarball" -C "$work"
[[ -s $work/reference/results.tsv ]] || die "reference/results.tsv missing in $tarball"
( cd "$work/corpus" && while IFS=$'\t' read -r f _ sha; do
    [[ $(sha256sum < "$f" | cut -c1-64) == "$sha" ]] || die "corpus: $f does not match MANIFEST.tsv"
  done < MANIFEST.tsv )
echo "corpus: $(wc -l < "$work/corpus/MANIFEST.tsv") files verified"

step "2/5 bundles: new ($WINDOWS_ZIP) and baseline ($BASE_REF)"
rm -rf "$work/new" "$work/base"
git -C "$repo" show "$BASE_REF:$BASE_WINDOWS_ZIP" > "$work/base.zip"
[[ $(sha256sum < "$work/base.zip" | cut -c1-64) == "$BASE_WINDOWS_ZIP_SHA256" ]] || die "$BASE_WINDOWS_ZIP checksum"
python3 -c 'import sys, zipfile; [zipfile.ZipFile(z).extractall(d) for z, d in zip(sys.argv[1::2], sys.argv[2::2])]' \
  "$repo/windows/dist/$WINDOWS_ZIP" "$work/new" "$work/base.zip" "$work/base"
# windows/CMakeLists.txt rebases every DLL (ASLR off, compact range) before the app ships them
vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
editbin=$("$vswhere" -latest -products '*' -find 'VC/Tools/MSVC/**/bin/Hostx64/x64/editbin.exe' | head -1 | tr -d '\r')
[[ -n $editbin ]] || die "editbin.exe not found"
for set in new base; do   # MSYS2 must not turn the /OPTIONS into paths
  ( cd "$work/$set/bin" && MSYS2_ARG_CONV_EXCL='*' "$(cygpath -u "$editbin")" /NOLOGO /HIGHENTROPYVA:NO /DYNAMICBASE:NO /REBASE:BASE=0x10000000 ./*.dll )
done

step "3/5 test program (verify/windows/nnkit_cli.cpp)"
g++ -std=c++17 -O1 -Wall -static -o "$work/nnkit_cli.exe" "$here/verify/windows/nnkit_cli.cpp"
for set in new base; do
  cp "$work/nnkit_cli.exe" "$work/$set/bin/ffmpeg.exe"
  cp "$work/nnkit_cli.exe" "$work/$set/bin/ffprobe.exe"
done
for set in new base; do   # loads the DLLs and runs one session (a load failure shows in every result)
  rc=0; "$work/$set/bin/ffprobe.exe" -version > "$work/$set-version.txt" 2>&1 || rc=$?
  echo "$set: ffprobe -version -> $rc, $(head -c 60 "$work/$set-version.txt")"
done

step "4/5 corpus runs (new and baseline)"
# The 2-hour file is skipped as on the other targets: its duration scan is checked on the host.
for set in new base; do
  out="$work/res-windows-x86_64"; [[ $set == base ]] && out="$work/base-windows-x86_64"
  SKIP=a_long_2h JOBS=3 "$here/verify/run_corpus.sh" "$work/corpus" "$out" \
    "$work/$set/bin/ffmpeg.exe" "$work/$set/bin/ffprobe.exe"
  missing=$(grep -c MISSING "$out/results.tsv" || true)
  [[ $missing -eq 0 ]] || die "$set: $missing files without a result"
done

step "5/5 new vs $BASE_REF (exact), then keep only outputs still to be compared"
python3 "$here/verify/compare.py" exact "$work/base-windows-x86_64" "$work/res-windows-x86_64" \
  | tee "$work/exact.txt" || true
python3 "$here/verify/prune_outputs.py" "$work/res-windows-x86_64/results.tsv" "$work/base-windows-x86_64"
python3 "$here/verify/prune_outputs.py" "$work/reference/results.tsv" "$work/res-windows-x86_64"
echo "results: $work/exact.txt $work/res-windows-x86_64 $work/base-windows-x86_64"
