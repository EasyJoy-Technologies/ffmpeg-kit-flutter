#!/usr/bin/env bash
# Builds the trimmed FFmpeg for iOS and macOS with the pinned upstream ffmpeg-kit scripts, checks it
# and puts the frameworks into ios/Frameworks (xcframeworks) and macos/Frameworks.
#
#   usage: ffmpeg-build/build_apple.sh <work-dir>      (outside the repo; ~4 GB)
#   needs: macOS, Xcode $XCODE_VERSION (DEVELOPER_DIR), autoconf automake libtool pkg-config, python3,
#          the $BASE_REF tag (API baseline for verify/check_apple_libs.py)
#
# Run by .github/workflows/build-apple.yml. As on Android, only the component list differs from the
# upstream "min" build (./ios.sh, ./macos.sh). iOS additionally changes packaging: xcframeworks with
# a natively built arm64 simulator slice instead of fat frameworks, no arm64e, no bitcode.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/pins.env"
source "$here/components.sh"
source "$here/lib/common.sh"

work=$(mkdir -p "${1:?usage: build_apple.sh <work-dir>}" && cd "$1" && pwd)
FRAMEWORKS=(ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale)
[[ $(uname) == Darwin ]] || die "needs macOS"
xcode=$(xcodebuild -version | sed -n 's/^Xcode //p')
[[ $xcode == "$XCODE_VERSION" ]] || die "Xcode $XCODE_VERSION required (set DEVELOPER_DIR), found $xcode"
sha256() { shasum -a 256 "$1" | cut -c1-64; }

step "1/6 upstream scripts + sources"
up="$work/ffmpeg-kit"
checkout_commit "$UPSTREAM_REPO" "$UPSTREAM_COMMIT_ANDROID_APPLE" "$up"
git -C "$up" apply --check "$here/patches/apple-ffmpeg-configure.patch"
git -C "$up" apply "$here/patches/apple-ffmpeg-configure.patch"
# Pre-placing the source makes the upstream downloader skip it, so the pinned commit is used.
checkout_commit "$FFMPEG_REPO" "$FFMPEG_COMMIT" "$up/src/ffmpeg" "$FFMPEG_TAG"
export NICENOTE_CONFIGURE_FLAGS="$(nicenote_component_flags)"

step "2/6 upstream ios.sh (min variant, trimmed components, xcframeworks)"
( cd "$up" && ./ios.sh -x --no-bitcode --disable-armv7 --disable-armv7s --disable-arm64e --disable-i386 \
    --disable-arm64-mac-catalyst --disable-x86-64-mac-catalyst ) \
  || { tail -n 60 "$up/build.log"; die "ios.sh failed (see $up/build.log)"; }
cp "$up/build.log" "$work/build-ios.log"

step "3/6 upstream macos.sh (min variant, trimmed components)"
( cd "$up" && ./macos.sh ) || { tail -n 60 "$up/build.log"; die "macos.sh failed (see $up/build.log)"; }
cp "$up/build.log" "$work/build-macos.log"
git -C "$up/src/ffmpeg" rev-parse HEAD | grep -qx "$FFMPEG_COMMIT" || die "FFmpeg source moved during the build"

step "4/6 components"
for d in ios-arm64 ios-arm64-simulator ios-x86_64 macos-arm64 macos-x86_64; do
  result=$(nicenote_verify_components "$up/prebuilt/apple-$d/ffmpeg/include/config_components.h") \
    || { echo "$result"; die "component check failed for $d"; }
  echo "$d: $result"
done

step "5/6 frameworks into the repo"
rm -rf "$repo/ios/Frameworks" "$repo/macos/Frameworks"
mkdir -p "$repo/ios/Frameworks" "$repo/macos/Frameworks"
for fw in "${FRAMEWORKS[@]}"; do
  cp -R "$up/prebuilt/bundle-apple-xcframework-ios/$fw.xcframework" "$repo/ios/Frameworks/"
  cp -R "$up/prebuilt/bundle-apple-framework-macos/$fw.framework" "$repo/macos/Frameworks/"
done
"$repo/scripts/sign_macos_frameworks.sh" "$repo/macos/Frameworks"

step "6/6 checks + build record"
base="$work/base"; rm -rf "$base"; mkdir -p "$base/ios"
git -C "$repo" show "$BASE_REF:$BASE_IOS_ZIP" > "$base/ios.zip"
[[ $(sha256 "$base/ios.zip") == "$BASE_IOS_ZIP_SHA256" ]] || die "$BASE_REF:$BASE_IOS_ZIP checksum mismatch"
unzip -q "$base/ios.zip" -d "$base/ios"
find "$base" -name '._*' -delete   # AppleDouble files in the published zip
git -C "$repo" archive "$BASE_REF" macos/Frameworks | tar -x -C "$base"
python3 "$here/verify/check_apple_libs.py" --ios "$repo/ios/Frameworks" --macos "$repo/macos/Frameworks" \
  --base-ios "$base/ios" --base-macos "$base/macos/Frameworks" | tee "$work/check_apple_libs.txt"

mkdir -p "$here/records"
{
  echo "# Apple build record — iOS xcframeworks + macOS frameworks"
  echo
  echo "- Built: $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion) $(uname -m)"
  echo "- Xcode $xcode ($(xcodebuild -version | sed -n 's/^Build version //p')), iOS SDK" \
       "$(xcrun --sdk iphoneos --show-sdk-version), macOS SDK $(xcrun --sdk macosx --show-sdk-version)"
  echo "- $(autoconf --version | head -1), $(automake --version | head -1), $(glibtool --version | head -1)"
  echo "- Upstream scripts: $UPSTREAM_COMMIT_ANDROID_APPLE (+ patches/apple-ffmpeg-configure.patch)"
  echo "- FFmpeg: $FFMPEG_TAG $FFMPEG_COMMIT"
  echo "- gas-preprocessor.pl (fetched by the upstream scripts): $(sha256 "$up/.tmp/gas-preprocessor.pl")"
  echo "- iOS: ./ios.sh -x --no-bitcode, device arm64 + simulator arm64/x86_64; macOS: ./macos.sh, arm64 + x86_64, ad-hoc signed"
  echo
  echo '| file | arch | bytes | sha256 |'
  echo '|---|---|---:|---|'
  ( cd "$repo" && for f in ios/Frameworks/*.xcframework/*/*.framework/* macos/Frameworks/*.framework/Versions/A/*; do
      [[ -f $f && ! -L $f && $(file -b "$f") == Mach-O* ]] || continue
      echo "| $f | $(lipo -archs "$f") | $(stat -f %z "$f") | \`$(sha256 "$f")\` |"
    done )
  echo
  echo "## Checks (verify/check_apple_libs.py)"
  echo
  echo '```'
  cat "$work/check_apple_libs.txt"
  echo '```'
} > "$here/records/apple.md"
echo "frameworks: $repo/ios/Frameworks $repo/macos/Frameworks"
echo "record: $here/records/apple.md"
