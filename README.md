# ffmpeg_kit_flutter (EasyJoy self-hosted)

Self-hosted FFmpeg-Kit for Flutter. Runs FFmpeg & FFprobe on **Android, iOS, macOS and Windows** from a single Dart API.

- Based on [`ffmpeg_kit_flutter_new`](https://github.com/sk3llo/ffmpeg_kit_flutter) (maintained fork of the retired [arthenica/ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)).
- **All native binaries are bundled inside this repository** — no runtime/build-time network downloads, no dependency on third-party release assets staying online.
- Variant: **audio** (FFmpeg 8.1.2, LGPL v3.0) — no GPL components, safe for closed-source store distribution.

## Why self-hosted?

The original FFmpegKit was retired in Jan 2025 and its binaries were deleted in Apr 2025, breaking every project that depended on them. This repo vendors both the plugin code and the native binaries so our apps never break from upstream deletions.

## Platforms

| Platform | Min version | Architectures |
|----------|-------------|---------------|
| Android  | API 24      | arm64-v8a, armeabi-v7a, x86, x86_64 |
| iOS      | 14.0        | arm64 (device), arm64 + x86_64 (simulator) |
| macOS    | 10.15       | arm64, x86_64 |
| Windows  | 10+ (x86_64)| x86_64 |

## Audio variant — enabled external libraries

`lame` (mp3 encode), `libilbc`, `libvorbis`, `opencore-amr`, `opus`, `shine`, `soxr`, `speex`, `twolame`, `vo-amrwbenc` + all FFmpeg-native audio codecs (aac, wav/pcm, flac, mp3 decode, amr decode, …).

No video encoders, no x264/x265 (GPL), no network protocols beyond file I/O.

## Usage

```yaml
dependencies:
  ffmpeg_kit_flutter:
    git:
      url: git@github.com:EasyJoy-Technologies/ffmpeg-kit-flutter.git
      ref: main
```

```dart
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

final session = await FFmpegKit.execute('-i input.mp3 -ar 44100 output.m4a');
if (ReturnCode.isSuccess(await session.getReturnCode())) {
  // done
}
```

The Dart API is identical to the original `ffmpeg_kit_flutter` (and `ffmpeg_kit_flutter_new`) — migrating only requires changing the dependency and import package name.

## Binary layout (self-hosted)

| Platform | Location in repo | Consumed by |
|----------|------------------|-------------|
| Android  | `android/libs/maven/…/ffmpeg-kit-audio-2.2.1.aar` | Gradle local maven repo |
| iOS      | `ios/dist/ffmpeg-kit-ios-audio-8.1.2.zip` | `scripts/setup_ios.sh` (pod prepare_command) |
| macOS    | `macos/dist/ffmpeg-kit-macos-audio-8.1.2.zip` | `scripts/setup_macos.sh` (pod prepare_command) |
| Windows  | `windows/dist/ffmpeg-kit-windows-x86_64-audio-8.1.2.zip` | `windows/CMakeLists.txt` |

Binary provenance: FFmpeg 8.1.2 audio-variant builds from `sk3llo/ffmpeg_kit_flutter` release `8.1.2-audio` and Maven Central `com.antonkarpenko:ffmpeg-kit-audio:2.2.1`, vendored 2026-07. To rebuild from source, use the archived `arthenica/ffmpeg-kit` build scripts (`android.sh` / `ios.sh` / `macos.sh` with the audio library set).

## License

- Plugin code: LGPL v3.0 (see `LICENSE`)
- Bundled FFmpeg binaries: LGPL v3.0 (audio variant — contains **no** GPL components)
- Apps using this library must include an FFmpeg/LGPL attribution notice.
