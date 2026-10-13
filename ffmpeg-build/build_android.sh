#!/usr/bin/env bash
# Builds the trimmed FFmpeg for Android (arm64-v8a + armeabi-v7a NEON) with the pinned upstream
# ffmpeg-kit scripts, verifies it, and publishes the AAR into android/libs/maven.
#
#   usage: ffmpeg-build/build_android.sh <work-dir>        (work dir lives outside the repo; ~3 GB)
#   env:   ANDROID_SDK_ROOT (default /opt/android-sdk)
#
# Only the component list differs from the upstream "min" build (./android.sh --enable-android-media-codec).
# The Java layer (classes.jar, manifest) is taken byte-for-byte from the published 2.2.1 AAR; only
# the native libraries under jni/ are replaced.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
source "$here/pins.env"
source "$here/components.sh"
source "$here/lib/common.sh"

work=$(mkdir -p "${1:?usage: build_android.sh <work-dir>}" && cd "$1" && pwd)
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-/opt/android-sdk}
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
ndk_rev=$(sed -nE 's/^Pkg\.Revision *= *//p' "$ANDROID_NDK_ROOT/source.properties")
[[ $ndk_rev == "$ANDROID_NDK_VERSION" ]] || die "NDK $ANDROID_NDK_VERSION not found (got '$ndk_rev')"

AAR_GROUP=com.easyjoy.nicenote
AAR_ARTIFACT=ffmpeg-kit-nicenote
AAR_VERSION=$(sed -nE 's/^AAR_VERSION=//p' "$here/android.version")
ABIS=(arm64-v8a armeabi-v7a)

step "1/6 upstream scripts + sources"
up="$work/ffmpeg-kit"
checkout_commit "$UPSTREAM_REPO" "$UPSTREAM_COMMIT_ANDROID_APPLE" "$up"
git -C "$up" apply --check "$here/patches/android-ffmpeg-configure.patch"
git -C "$up" apply "$here/patches/android-ffmpeg-configure.patch"
# Pre-placing the sources makes the upstream downloader skip them, so the pinned commits are used.
checkout_commit "$FFMPEG_REPO" "$FFMPEG_COMMIT" "$up/src/ffmpeg"
checkout_commit "$CPU_FEATURES_REPO" "$CPU_FEATURES_COMMIT" "$up/src/cpu-features"

step "2/6 upstream android.sh (min variant, trimmed components)"
export NICENOTE_CONFIGURE_FLAGS="$(nicenote_component_flags saf)"
( cd "$up" && ./android.sh --enable-android-media-codec \
    --disable-arm-v7a --disable-x86 --disable-x86-64 --no-archive ) \
  || { tail -n 40 "$up/build.log"; die "android.sh failed (see $up/build.log)"; }
git -C "$up/src/ffmpeg" rev-parse HEAD | grep -qx "$FFMPEG_COMMIT" || die "FFmpeg source moved during the build"

step "3/6 components"
for d in android-arm64 android-arm-neon; do
  inc="$up/prebuilt/$d/ffmpeg/include"
  result=$(nicenote_verify_components "$inc/config_components.h" saf) || { echo "$result"; die "component check failed for $d"; }
  echo "$d: $result"
done

step "4/6 native library checks"
libs="$up/android/libs"
python3 "$here/verify/check_android_libs.py" --ndk "$ANDROID_NDK_ROOT" --api "$ANDROID_API" \
  --base-aar "$repo/$BASE_AAR" --libs "$libs" "${ABIS[@]}" | tee "$work/check_android_libs.txt"

step "5/6 AAR"
dest="$repo/android/libs/maven/${AAR_GROUP//.//}/$AAR_ARTIFACT/$AAR_VERSION"
python3 "$here/verify/make_aar.py" --base-aar "$repo/$BASE_AAR" --base-sha256 "$BASE_AAR_SHA256" \
  --libs "$libs" --abis "${ABIS[@]}" --group "$AAR_GROUP" --artifact "$AAR_ARTIFACT" \
  --version "$AAR_VERSION" --out "$dest"

step "6/6 build record"
mkdir -p "$here/records"
{
  echo "# Android build record — $AAR_GROUP:$AAR_ARTIFACT:$AAR_VERSION"
  echo
  echo "- Built: $(date -u +%Y-%m-%dT%H:%MZ) on $(uname -srm)"
  echo "- Upstream scripts: $UPSTREAM_COMMIT_ANDROID_APPLE (+ patches/android-ffmpeg-configure.patch)"
  echo "- FFmpeg: $FFMPEG_TAG $FFMPEG_COMMIT · cpu_features $CPU_FEATURES_TAG"
  echo "- NDK $ndk_rev, API $ANDROID_API"
  echo "- Java layer: classes.jar from 2.2.1 (sha256 $BASE_AAR_SHA256)"
  echo
  echo '| file | bytes | sha256 |'
  echo '|---|---:|---|'
  ( cd "$dest" && for f in *.aar *.pom; do echo "| $f | $(stat -c %s "$f") | \`$(sha256sum "$f" | cut -c1-64)\` |"; done )
  for abi in "${ABIS[@]}"; do
    ( cd "$libs/$abi" && for f in *.so; do echo "| $abi/$f | $(stat -c %s "$f") | \`$(sha256sum "$f" | cut -c1-64)\` |"; done )
  done
  echo
  echo "## Checks (verify/check_android_libs.py)"
  echo
  cat "$work/check_android_libs.txt"
} > "$here/records/android.md"
echo "AAR: $dest"
echo "record: $here/records/android.md"
