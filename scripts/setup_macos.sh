#!/bin/bash
set -e

# Unzip the self-hosted macOS frameworks bundled in this repo (audio variant, LGPL).
MACOS_ZIP="./dist/ffmpeg-kit-macos-audio-8.1.2.zip"
mkdir -p Frameworks
unzip -o "$MACOS_ZIP" -d Frameworks
rm -rf Frameworks/__MACOSX

# Remove AppleDouble/resource-fork junk that can break bundle validation & signing.
find Frameworks -name '._*' -delete 2>/dev/null || true
find Frameworks -name '.DS_Store' -delete 2>/dev/null || true

FRAMEWORKS="ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"

# Delete bitcode from all frameworks.
for fw in $FRAMEWORKS; do
  xcrun bitcode_strip -r "Frameworks/${fw}.framework/${fw}" -o "Frameworks/${fw}.framework/${fw}"
done

# Ad-hoc code-sign each framework so Xcode's app CodeSign step does not fail with
# "code object is not signed at all". The prebuilt frameworks ship unsigned; without
# this, embedding them into a signed .app fails on modern Xcode/macOS.
for fw in $FRAMEWORKS; do
  codesign --force --sign - --timestamp=none "Frameworks/${fw}.framework"
done
