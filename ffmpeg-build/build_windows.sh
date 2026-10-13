#!/usr/bin/env bash
# Builds the trimmed FFmpeg + libffmpegkit.dll for Windows x86_64 with the pinned upstream
# ffmpeg-kit Windows scripts, checks it and writes windows/dist/$WINDOWS_ZIP.
#
#   usage: ffmpeg-build/build_windows.sh <work-dir>      (outside the repo; ~2 GB)
#   needs: MSYS2 MINGW64 shell with git make pkgconf mingw-w64-x86_64-toolchain
#          mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm mingw-w64-x86_64-rapidjson (header-only, used by
#          the wrapper's JSON API) python; the $BASE_REF tag (baseline)
#
# Run by .github/workflows/build-windows.yml, in the MSYS2 MINGW64 environment the published
# 8.1.2-min bundle was built in (msvcrt runtime). As on the other platforms the component list is
# the shared one; in addition (plan §2.2/§2.3) the Windows-only extras of the upstream "min" line
# are switched off to match Android/iOS/macOS — zlib, bzip2, iconv, lzma/libva (autodetected),
# Media Foundation, D3D11VA/DXVA2, SChannel — and the MinGW runtime (libgcc, libstdc++,
# winpthread) is linked statically, so the bundle is the eight DLLs and nothing else.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/pins.env"
source "$here/components.sh"
source "$here/lib/common.sh"

work=$(mkdir -p "${1:?usage: build_windows.sh <work-dir>}" && cd "$1" && pwd)
[[ ${MSYSTEM:-} == MINGW64 ]] || die "run in the MSYS2 MINGW64 environment (MSYSTEM=$MSYSTEM)"
sha256() { sha256sum "$1" | cut -c1-64; }

step "1/6 upstream scripts + sources"
up="$work/ffmpeg-kit"
checkout_commit "$UPSTREAM_REPO" "$UPSTREAM_COMMIT_WINDOWS" "$up"
git -C "$up" apply --check "$here/patches/windows-ffmpeg-configure.patch"
git -C "$up" apply "$here/patches/windows-ffmpeg-configure.patch"
# Pre-placing the sources makes the upstream downloader skip them, so the pinned commits are used.
checkout_commit "$FFMPEG_REPO" "$FFMPEG_COMMIT" "$up/src/ffmpeg" "$FFMPEG_TAG"
checkout_commit "$CPU_FEATURES_REPO" "$CPU_FEATURES_COMMIT" "$up/src/cpu-features"   # fetched, unused on Windows

step "2/6 upstream windows.sh (min line, trimmed components, static MinGW runtime)"
export NICENOTE_CONFIGURE_FLAGS="$(nicenote_component_flags) --disable-autodetect \
--disable-zlib --disable-bzlib --disable-iconv --disable-lzma --disable-mediafoundation \
--disable-d3d11va --disable-dxva2 --disable-schannel \
--extra-ldflags=-static-libgcc --extra-libs=-Wl,-Bstatic,-lwinpthread,-Bdynamic"
export NICENOTE_WRAPPER_LDFLAGS="-static-libgcc -static-libstdc++ -Wl,--exclude-libs,ALL \
-Wl,-Bstatic,-lwinpthread,-Bdynamic"
[[ -f /mingw64/include/rapidjson/document.h ]] || die "rapidjson headers missing (mingw-w64-x86_64-rapidjson)"
( cd "$up" && FFMPEGKIT_VARIANT=min ./windows.sh ) \
  || { tail -n 60 "$up/build.log" 2>/dev/null; die "windows.sh failed"; }
cp "$up"/build/logs/windows-*.log "$work/build-windows.log"
# windows.sh pipes the per-arch build through tee and reports success even when it failed
for f in avcodec-62.dll avutil-60.dll libffmpegkit.dll; do
  [[ -f $up/build/windows/x86_64/install/bin/$f ]] || die "windows.sh did not produce $f (see build-windows.log)"
done
git -C "$up/src/ffmpeg" rev-parse HEAD | grep -qx "$FFMPEG_COMMIT" || die "FFmpeg source moved during the build"

step "3/6 components"
result=$(nicenote_verify_components "$up/build/windows/x86_64/ffmpeg-build/config_components.h") \
  || { echo "$result"; die "component check failed"; }
echo "windows-x86_64: $result"

step "4/6 zip"
bundle="$up/prebuilt/bundle-windows/x86_64"
[[ -f $bundle/bin/libffmpegkit.dll ]] || die "bundle missing: $bundle"
rm -f "$repo"/windows/dist/*.zip
python3 - "$bundle" "$repo/windows/dist/$WINDOWS_ZIP" <<'PY'
# bin/ + include/ at the root, forward slashes (CMake's tar), fixed order and timestamps
import os, sys, zipfile
root, out = sys.argv[1:]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for top in ('bin', 'include'):
        for d, dirs, files in sorted(os.walk(os.path.join(root, top))):
            dirs.sort()
            for f in sorted(files):
                p = os.path.join(d, f)
                info = zipfile.ZipInfo(os.path.relpath(p, root).replace(os.sep, '/'), (2026, 1, 1, 0, 0, 0))
                setattr(info, 'ext' 'ernal_attr', 0o644 << 16)  # unix permissions
                info.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(info, open(p, 'rb').read())
PY

step "5/6 checks"
base="$work/base"; rm -rf "$base"; mkdir -p "$base"
git -C "$repo" show "$BASE_REF:$BASE_WINDOWS_ZIP" > "$work/base.zip"
[[ $(sha256 "$work/base.zip") == "$BASE_WINDOWS_ZIP_SHA256" ]] || die "$BASE_REF:$BASE_WINDOWS_ZIP checksum mismatch"
new="$work/new"; rm -rf "$new"; mkdir -p "$new"
python3 -c 'import sys, zipfile; [zipfile.ZipFile(z).extractall(d) for z, d in zip(sys.argv[1::2], sys.argv[2::2])]' \
  "$work/base.zip" "$base" "$repo/windows/dist/$WINDOWS_ZIP" "$new"
python3 "$here/verify/check_windows_libs.py" --bundle "$new" --base "$base" | tee "$work/check_windows_libs.txt"

step "6/6 build record"
mkdir -p "$here/records"
{
  echo "# Windows build record — windows/dist/$WINDOWS_ZIP"
  echo
  echo "- Built: $(date -u +%Y-%m-%dT%H:%MZ) on $(uname -s) $(uname -r) (MSYS2 $MSYSTEM)"
  echo "- $(gcc --version | head -1), $(ld --version | head -1), $(nasm --version | head -1)"
  echo "- Upstream scripts: $UPSTREAM_COMMIT_WINDOWS (+ patches/windows-ffmpeg-configure.patch)"
  echo "- FFmpeg: $FFMPEG_TAG $FFMPEG_COMMIT"
  echo "- MSYS2 packages: $(pacman -Q mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils mingw-w64-x86_64-crt-git mingw-w64-x86_64-winpthreads mingw-w64-x86_64-nasm mingw-w64-x86_64-rapidjson 2>/dev/null | tr '\n' ' ')"
  echo
  echo '| file | bytes | sha256 |'
  echo '|---|---:|---|'
  echo "| windows/dist/$WINDOWS_ZIP | $(stat -c %s "$repo/windows/dist/$WINDOWS_ZIP") | \`$(sha256 "$repo/windows/dist/$WINDOWS_ZIP")\` |"
  ( cd "$new" && for f in bin/*; do echo "| $f | $(stat -c %s "$f") | \`$(sha256 "$f")\` |"; done )
  echo
  echo "## Checks (verify/check_windows_libs.py)"
  echo
  echo '```'
  cat "$work/check_windows_libs.txt"
  echo '```'
} > "$here/records/windows.md"
echo "zip: $repo/windows/dist/$WINDOWS_ZIP"
echo "record: $here/records/windows.md"
