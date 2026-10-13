#!/usr/bin/env bash
# Builds command-line ffmpeg/ffprobe for the corpus comparison (run_corpus.sh), out of tree.
#   usage: build_tools.sh <target> <full|trimmed> <ffmpeg-src> <out-dir>
#   target: host                 x86-64, C only (reference: same source, no CPU-specific code)
#           android-arm64        static, NEON, run under qemu-aarch64
#           android-armv7-neon   static, NEON, run under qemu-arm
# The Android targets use the upstream arch and optimisation flags (scripts/function-android.sh),
# so the same NEON/assembly paths as in the app libraries are exercised.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/../pins.env"
source "$here/../components.sh"
target=$1 kind=$2 src=$(cd "$3" && pwd) out=$4

# Skip when the same inputs were already built (source commit, component list, this script).
stamp=$( { echo "$target $kind $(git -C "$src" rev-parse HEAD)"
           cat "$here/../components.sh" "$here/../audio_decoders.txt" "$here/../pins.env" "$0"; } | sha256sum | cut -c1-64)
if [[ -x $out/ffmpeg && -x $out/ffprobe && $(cat "$out/.stamp" 2>/dev/null) == "$stamp" ]]; then
  echo "$target $kind: up to date"; exit 0
fi
rm -rf "$out"; mkdir -p "$out"; cd "$out"

flags=()
[[ $kind == trimmed ]] && read -r -a flags <<< "$(nicenote_component_flags)"
common=(--enable-version3 --disable-autodetect --enable-swscale --enable-static --disable-shared
        --enable-pthreads --enable-small --disable-debug --disable-doc --disable-ffplay
        --disable-zlib --disable-openssl --disable-sdl2 --disable-xlib)

case $target in
  host)
    "$src/configure" --prefix="$out/inst" "${common[@]}" --disable-x86asm "${flags[@]}" > configure.log 2>&1 ;;
  android-arm64|android-armv7-neon)
    ndk=${ANDROID_SDK_ROOT:-/opt/android-sdk}/ndk/$ANDROID_NDK_VERSION
    tc=$ndk/toolchains/llvm/prebuilt/linux-x86_64; export PATH="$tc/bin:$PATH"
    base="-fstrict-aliasing -DANDROID_NDK -fPIC -DANDROID -D__ANDROID__ -D__ANDROID_MIN_SDK_VERSION__=$ANDROID_API"
    if [[ $target == android-arm64 ]]; then
      triple=aarch64-linux-android arch=aarch64 cpu=armv8-a
      export CFLAGS="-march=armv8-a $base -flto -fuse-ld=lld -O2 -ffunction-sections -fdata-sections"
      export LDFLAGS="-march=armv8-a -Wl,--gc-sections -flto -fuse-ld=lld -O2 -static"
    else
      triple=armv7a-linux-androideabi arch=armv7-a cpu=armv7-a
      export CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=softfp $base -flto -O2 -ffunction-sections -fdata-sections"
      export LDFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=softfp -Wl,--fix-cortex-a8 -Wl,--gc-sections,--icf=safe -flto -O2 -static"
    fi
    "$src/configure" --prefix="$out/inst" --enable-cross-compile --target-os=android --arch=$arch --cpu=$cpu \
      --cross-prefix=llvm- --cc=${triple}${ANDROID_API}-clang --cxx=${triple}${ANDROID_API}-clang++ \
      --sysroot="$tc/sysroot" --ar=llvm-ar --ranlib=llvm-ranlib --strip=llvm-strip --nm=llvm-nm \
      --enable-neon --enable-asm --enable-inline-asm --enable-pic --enable-optimizations --enable-lto \
      --disable-xmm-clobber-test --disable-neon-clobber-test "${common[@]}" "${flags[@]}" > configure.log 2>&1 ;;
  *) echo "unknown target $target" >&2; exit 2 ;;
esac
if [[ $kind == trimmed ]]; then
  nicenote_verify_components config_components.h > components.log || { cat components.log; exit 1; }
fi
make -j"${JOBS:-$(nproc)}" ffmpeg ffprobe > make.log 2>&1
echo "$stamp" > .stamp
echo "$target $kind: $(ls -la ffmpeg ffprobe | awk '{print $5, $9}' | tr '\n' ' ')"
