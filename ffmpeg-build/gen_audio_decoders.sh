#!/usr/bin/env bash
# Regenerates audio_decoders.txt: every decoder that the pinned FFmpeg source can build under our
# license flags (LGPL v3, no add-on libraries) and whose AVCodec.type is AVMEDIA_TYPE_AUDIO.
# The list is produced by a small program linked against a full host libavcodec, never by hand.
#   usage: gen_audio_decoders.sh <ffmpeg-source-dir> <work-dir>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src=$(cd "$1" && pwd); work=$(mkdir -p "$2" && cd "$2" && pwd)
b="$work/host-full"; rm -rf "$b"; mkdir -p "$b"; cd "$b"
"$src/configure" --enable-version3 --disable-autodetect --disable-programs --disable-doc \
  --disable-x86asm --disable-network --enable-static --disable-shared > configure.log 2>&1
make -j"$(nproc)" libavutil/libavutil.a libswresample/libswresample.a libavcodec/libavcodec.a > make.log 2>&1
names=$(sed -nE 's/^#define CONFIG_([A-Z0-9_]+)_DECODER 1$/\1/p' config_components.h | tr A-Z a-z)
{
  echo '#include <stdio.h>'
  echo '#include "libavcodec/codec.h"'
  for n in $names; do echo "extern const AVCodec ff_${n}_decoder;"; done
  echo 'int main(void) {'
  for n in $names; do echo "  if (ff_${n}_decoder.type == AVMEDIA_TYPE_AUDIO) puts(\"$n\");"; done
  echo '  return 0; }'
} > list.c
cc -I. -I"$src" list.c libavcodec/libavcodec.a libswresample/libswresample.a libavutil/libavutil.a -lm -lpthread -o list
./list | LC_ALL=C sort > "$here/audio_decoders.txt"
echo "audio_decoders.txt: $(wc -l < "$here/audio_decoders.txt") decoders (of $(echo "$names" | wc -w) buildable)"
