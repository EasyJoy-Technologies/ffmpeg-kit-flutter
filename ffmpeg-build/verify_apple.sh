#!/usr/bin/env bash
# Behaviour check of the frameworks in ios/Frameworks and macos/Frameworks (build_apple.sh).
# The frameworks are driven through verify/apple/nnkit_cli.m (the ffmpegkit API the app uses) with
# NiceNote's argument shapes (verify/run_corpus.sh) on four targets:
#   macos-arm64 (native)   macos-x86_64 (Rosetta)   iossim-arm64   iossim-x86_64 (simulator, Rosetta)
# Two comparisons:
#   1. here, new vs the v1.1.0 frameworks run the same way on the same target: compare.py exact.
#      This is the "nothing changed" check (same wrapper, same CPU).
#   2. on the build server, new vs the Linux reference (host trimmed build, as verify_android.sh):
#      compare.py arch-kit. Outputs identical to the reference are deleted here, and baseline outputs
#      identical to the new ones, so that only what still has to be looked at travels back.
#
#   usage: ffmpeg-build/verify_apple.sh <work-dir> <corpus.tar.gz>
#   corpus.tar.gz: corpus/ (verify/corpus/make_corpus.sh) + reference/results.tsv (host trimmed)
#   needs: macOS + Xcode with an iOS simulator runtime, Rosetta 2, GNU coreutils and bash >= 4 on
#          PATH, the $BASE_REF tag
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/pins.env"
source "$here/lib/common.sh"
work=$(mkdir -p "${1:?usage: verify_apple.sh <work-dir> <corpus.tar.gz>}" && cd "$1" && pwd)
tarball=${2:?corpus.tar.gz}
FRAMEWORKS=(ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale)
TARGETS=(macos-arm64 macos-x86_64 iossim-arm64 iossim-x86_64)
[[ $(uname) == Darwin ]] || die "needs macOS"
md5sum --version > /dev/null 2>&1 || die "GNU coreutils must be first on PATH"
arch -x86_64 /usr/bin/true || die "Rosetta 2 is not installed"

step "1/5 corpus"
rm -rf "$work/corpus" "$work/reference"
tar -xzf "$tarball" -C "$work"
[[ -s $work/reference/results.tsv ]] || die "reference/results.tsv missing in $tarball"
( cd "$work/corpus" && while IFS=$'\t' read -r f _ sha; do
    [[ $(sha256sum < "$f" | cut -c1-64) == "$sha" ]] || die "corpus: $f does not match MANIFEST.tsv"
  done < MANIFEST.tsv )
echo "corpus: $(wc -l < "$work/corpus/MANIFEST.tsv") files verified"

step "2/5 frameworks: new (repo) and baseline ($BASE_REF)"
fw="$work/fw"; rm -rf "$fw"; mkdir -p "$fw/new-iossim" "$fw/base-iossim" "$fw/base-ios-zip"
sign() { codesign --force --sign - --timestamp=none "$1" > /dev/null; }
# new: macOS as committed (signed); simulator slices copied into one directory (one rpath) and
# signed (an app build signs them on embedding; the repo keeps the iOS frameworks unsigned)
ln -s "$repo/macos/Frameworks" "$fw/new-macos"
for f in "${FRAMEWORKS[@]}"; do
  cp -R "$repo/ios/Frameworks/$f.xcframework/ios-arm64_x86_64-simulator/$f.framework" "$fw/new-iossim/"
  sign "$fw/new-iossim/$f.framework"
done
# baseline macOS: committed unsigned in v1.1.0, signed by the podspec on the consuming Mac
git -C "$repo" archive "$BASE_REF" macos/Frameworks | tar -x -C "$fw"
mv "$fw/macos/Frameworks" "$fw/base-macos"; rmdir "$fw/macos"
for f in "${FRAMEWORKS[@]}"; do sign "$fw/base-macos/$f.framework"; done
# baseline simulator: exactly what v1.1.0's setup_ios.sh produced from the published zip
# (x86_64 slice + device arm64 slice retagged as simulator, bitcode stripped)
git -C "$repo" show "$BASE_REF:$BASE_IOS_ZIP" > "$fw/base-ios.zip"
[[ $(sha256sum < "$fw/base-ios.zip" | cut -c1-64) == "$BASE_IOS_ZIP_SHA256" ]] || die "$BASE_IOS_ZIP checksum"
unzip -q "$fw/base-ios.zip" -d "$fw/base-ios-zip"
find "$fw/base-ios-zip" -name '._*' -delete
for f in "${FRAMEWORKS[@]}"; do
  src="$fw/base-ios-zip/$f.framework" dst="$fw/base-iossim/$f.framework"
  cp -R "$src" "$dst"
  lipo "$src/$f" -thin x86_64 -output "$fw/x86_64"
  lipo "$src/$f" -thin arm64 -output "$fw/arm64-dev"
  minos=$(otool -l "$fw/arm64-dev" | awk '/LC_BUILD_VERSION/{b=1} b&&/minos/{print $2; exit}')
  sdk=$(otool -l "$fw/arm64-dev" | awk '/LC_BUILD_VERSION/{b=1} b&&/sdk/{print $2; exit}')
  vtool -arch arm64 -set-build-version 7 "$minos" "$sdk" -replace -output "$fw/arm64-sim" "$fw/arm64-dev"
  lipo -create "$fw/x86_64" "$fw/arm64-sim" -output "$dst/$f"
  xcrun bitcode_strip -r "$dst/$f" -o "$dst/$f"
  sign "$dst"
done
rm -f "$fw/x86_64" "$fw/arm64-dev" "$fw/arm64-sim"

step "3/5 test program (verify/apple/nnkit_cli.m)"
bin="$work/bin"; rm -rf "$bin"
for set in new base; do
  mkdir -p "$bin/$set-macos" "$bin/$set-iossim"
  xcrun --sdk macosx clang -fobjc-arc -O1 -Wall -arch arm64 -arch x86_64 -mmacosx-version-min=10.15 \
    -F "$fw/$set-macos" -framework ffmpegkit -framework Foundation -Wl,-rpath,"$fw/$set-macos" \
    "$here/verify/apple/nnkit_cli.m" -o "$bin/$set-macos/ffmpeg"
  xcrun --sdk iphonesimulator clang -fobjc-arc -O1 -Wall -arch arm64 -arch x86_64 \
    -mios-simulator-version-min=14.0 -F "$fw/$set-iossim" -framework ffmpegkit -framework Foundation \
    -Wl,-rpath,"$fw/$set-iossim" "$here/verify/apple/nnkit_cli.m" -o "$bin/$set-iossim/ffmpeg"
  for d in macos iossim; do cp "$bin/$set-$d/ffmpeg" "$bin/$set-$d/ffprobe"; done
done

step "4/5 corpus runs (${TARGETS[*]}; new and baseline)"
# newest iOS runtime not newer than the SDK of the selected Xcode (runners carry runtimes of other Xcodes)
runtime=$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
v = lambda s: [int(x) for x in s.split(".")][:2]
sdk = v(sys.argv[1])
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and v(r["version"]) <= sdk]
print(max(rs, key=lambda r: v(r["version"]))["identifier"])' "$(xcrun --sdk iphonesimulator --show-sdk-version)")
udid=$(xcrun simctl create nn-verify com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$runtime")
trap 'xcrun simctl shutdown "$udid" > /dev/null 2>&1 || true; xcrun simctl delete "$udid" > /dev/null 2>&1 || true' EXIT
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b > /dev/null
echo "simulator: $runtime ($udid)"
# The 2-hour file is skipped as under qemu: its duration scan is checked on the host, and its
# outputs (~1.5 GB, float mp3 decode) would have to travel back for the comparison.
skip='a_long_2h'
for target in "${TARGETS[@]}"; do
  for set in new base; do
    case $target in
      macos-*)  tools="$bin/$set-macos";  runner=(arch "-${target#macos-}") ;;
      iossim-*) tools="$bin/$set-iossim"; runner=(xcrun simctl spawn "--arch=${target#iossim-}" "$udid") ;;
    esac
    out="$work/res-$target"; [[ $set == base ]] && out="$work/base-$target"
    SKIP=$skip JOBS=3 "$here/verify/run_corpus.sh" "$work/corpus" "$out" "$tools/ffmpeg" "$tools/ffprobe" "${runner[@]}"
    missing=$(grep -c MISSING "$out/results.tsv" || true)
    [[ $missing -eq 0 ]] || die "$target ($set): $missing files without a result"
  done
done

step "5/5 new vs $BASE_REF (exact), then keep only outputs still to be compared"
# recorded, not fatal: the build server reads exact.txt together with the arch-kit comparison
for target in "${TARGETS[@]}"; do
  python3 "$here/verify/compare.py" exact "$work/base-$target" "$work/res-$target" || true
done | tee "$work/exact.txt"
for target in "${TARGETS[@]}"; do
  python3 "$here/verify/prune_outputs.py" "$work/res-$target/results.tsv" "$work/base-$target"
  python3 "$here/verify/prune_outputs.py" "$work/reference/results.tsv" "$work/res-$target"
done
echo "results: $work/exact.txt ${TARGETS[*]/#/$work/res-} ${TARGETS[*]/#/$work/base-}"
