#!/bin/bash
set -e

# Ad-hoc code-sign the committed macOS frameworks (LGPL) in place.
#
# Why: modern Xcode requires embedded frameworks to be signed, otherwise the consuming macOS app's
# CodeSign step fails with "code object is not signed at all". ffmpeg-build/build_apple.sh signs
# the frameworks when it builds them; this script is idempotent and safe to re-run.
#
# Invoked automatically by the macOS podspec prepare_command; can also be run
# manually: `scripts/sign_macos_frameworks.sh <path-to-Frameworks-dir>`.

FRAMEWORKS_DIR="${1:-./Frameworks}"
FRAMEWORKS="ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"

if [ ! -d "$FRAMEWORKS_DIR" ]; then
  echo "sign_macos_frameworks: directory not found: $FRAMEWORKS_DIR" >&2
  exit 1
fi

# Remove AppleDouble/resource-fork junk that can break bundle validation & signing.
find "$FRAMEWORKS_DIR" -name '._*' -delete 2>/dev/null || true
find "$FRAMEWORKS_DIR" -name '.DS_Store' -delete 2>/dev/null || true

for fw in $FRAMEWORKS; do
  FW_PATH="$FRAMEWORKS_DIR/${fw}.framework"
  [ -d "$FW_PATH" ] || continue
  # Strip bitcode (harmless if already stripped) then ad-hoc sign.
  BIN="$FW_PATH/${fw}"
  [ -f "$BIN" ] && xcrun bitcode_strip -r "$BIN" -o "$BIN" 2>/dev/null || true
  codesign --force --sign - --timestamp=none "$FW_PATH"
done
