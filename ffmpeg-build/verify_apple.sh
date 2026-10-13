#!/usr/bin/env bash
# Behaviour check of the frameworks build_apple.sh put into ios/Frameworks and macos/Frameworks.
# The shipped ffmpegkit is driven through verify/apple/nnkit_cli.m with NiceNote's argument shapes
# (verify/run_corpus.sh) on four targets:
#   macos-arm64 (native)   macos-x86_64 (Rosetta)   iossim-arm64   iossim-x86_64 (simulator, Rosetta)
# The results are compared with the Linux reference (host trimmed build, the one verify_android.sh
# uses) on the build server with compare.py arch; outputs identical to the reference are deleted
# here so that only the ones compare.py has to look at travel back.
#
#   usage: ffmpeg-build/verify_apple.sh <work-dir> <corpus.tar.gz>
#   corpus.tar.gz: corpus/ (verify/corpus/make_corpus.sh) + reference/results.tsv (host trimmed)
#   needs: macOS + Xcode with an iOS simulator runtime, Rosetta 2, GNU coreutils and bash >= 4 on PATH
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/lib/common.sh"
work=$(mkdir -p "${1:?usage: verify_apple.sh <work-dir> <corpus.tar.gz>}" && cd "$1" && pwd)
tarball=${2:?corpus.tar.gz}
FRAMEWORKS=(ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale)
TARGETS=(macos-arm64 macos-x86_64 iossim-arm64 iossim-x86_64)
[[ $(uname) == Darwin ]] || die "needs macOS"
md5sum --version > /dev/null 2>&1 || die "GNU coreutils must be first on PATH"
arch -x86_64 /usr/bin/true || die "Rosetta 2 is not installed"

step "1/4 corpus"
rm -rf "$work/corpus" "$work/reference"
tar -xzf "$tarball" -C "$work"
[[ -s $work/reference/results.tsv ]] || die "reference/results.tsv missing in $tarball"
( cd "$work/corpus" && while IFS=$'\t' read -r f _ sha; do
    [[ $(sha256sum < "$f" | cut -c1-64) == "$sha" ]] || die "corpus: $f does not match MANIFEST.tsv"
  done < MANIFEST.tsv )
echo "corpus: $(wc -l < "$work/corpus/MANIFEST.tsv") files verified"

step "2/4 test program (verify/apple/nnkit_cli.m)"
bin="$work/bin"; rm -rf "$bin"; mkdir -p "$bin/macos" "$bin/iossim" "$bin/iossim-fw"
mac_fw="$repo/macos/Frameworks"
xcrun --sdk macosx clang -fobjc-arc -O1 -Wall -arch arm64 -arch x86_64 -mmacosx-version-min=10.15 \
  -F "$mac_fw" -framework ffmpegkit -framework Foundation -Wl,-rpath,"$mac_fw" \
  "$here/verify/apple/nnkit_cli.m" -o "$bin/macos/ffmpeg"
# The simulator slices live in one directory per xcframework: copy them into one directory for a
# single rpath, and ad-hoc sign the copies (an app build signs them on embedding; the repo keeps
# the iOS frameworks unsigned).
for fw in "${FRAMEWORKS[@]}"; do
  cp -R "$repo/ios/Frameworks/$fw.xcframework/ios-arm64_x86_64-simulator/$fw.framework" "$bin/iossim-fw/"
  codesign --force --sign - --timestamp=none "$bin/iossim-fw/$fw.framework"
done
xcrun --sdk iphonesimulator clang -fobjc-arc -O1 -Wall -arch arm64 -arch x86_64 \
  -mios-simulator-version-min=14.0 -F "$bin/iossim-fw" -framework ffmpegkit -framework Foundation \
  -Wl,-rpath,"$bin/iossim-fw" "$here/verify/apple/nnkit_cli.m" -o "$bin/iossim/ffmpeg"
for d in macos iossim; do cp "$bin/$d/ffmpeg" "$bin/$d/ffprobe"; done

step "3/4 corpus runs (${TARGETS[*]})"
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
  case $target in
    macos-*)  tools="$bin/macos";  runner=(arch "-${target#macos-}") ;;
    iossim-*) tools="$bin/iossim"; runner=(xcrun simctl spawn "--arch=${target#iossim-}" "$udid") ;;
  esac
  SKIP=$skip JOBS=3 "$here/verify/run_corpus.sh" "$work/corpus" "$work/res-$target" \
    "$tools/ffmpeg" "$tools/ffprobe" "${runner[@]}"
  missing=$(grep -c MISSING "$work/res-$target/results.tsv" || true)
  [[ $missing -eq 0 ]] || die "$target: $missing files without a result"
done

step "4/4 keep only outputs that differ from the reference"
for target in "${TARGETS[@]}"; do
  python3 "$here/verify/prune_outputs.py" "$work/reference/results.tsv" "$work/res-$target"
done
echo "results: ${TARGETS[*]/#/$work/res-}"
