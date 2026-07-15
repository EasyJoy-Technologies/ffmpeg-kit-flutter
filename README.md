# ffmpeg_kit_flutter (EasyJoy self-hosted)

Self-hosted FFmpeg-Kit for Flutter. Runs FFmpeg & FFprobe on **Android, iOS, macOS and Windows** from a single Dart API.

- Based on [`ffmpeg_kit_flutter_new`](https://github.com/sk3llo/ffmpeg_kit_flutter) (maintained fork of the retired [arthenica/ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)).
- **All native binaries are bundled inside this repository** — no runtime/build-time network downloads, no dependency on third-party release assets staying online.
- Variant: **min** (FFmpeg 8.1.2, LGPL v3.0) — no external libraries, no GPL components, smallest binary footprint, safe for closed-source store distribution.

## Why self-hosted?

The original FFmpegKit was retired in Jan 2025 and its binaries were deleted in Apr 2025, breaking every project that depended on them. This repo vendors both the plugin code and the native binaries so our apps never break from upstream deletions.

## Platforms

| Platform | Min version | Architectures |
|----------|-------------|---------------|
| Android  | API 24      | arm64-v8a, armeabi-v7a, x86, x86_64 |
| iOS      | 14.0        | arm64 (device), arm64 + x86_64 (simulator) |
| macOS    | 10.15       | arm64, x86_64 |
| Windows  | 10+ (x86_64)| x86_64 |

## Min variant — enabled codecs

**No external libraries.** Ships FFmpeg's built-in native codecs only: `aac` encode/decode, `wav`/`pcm` encode/decode, `flac` encode/decode, plus native decoders for `mp3`, `amr`, `vorbis`, `opus`, and the rest of FFmpeg's native set — sufficient for recording/transcoding to m4a(AAC)/wav/pcm and probing/decoding common audio inputs.

MP3 **encoding** is intentionally out of scope here: consumers that need it encode MP3 in Dart (e.g. a `lame` Dart binding), so the heavy `lame`/`shine`/`twolame`/`opencore-amr`/`opus`/`speex`/`soxr`/`vorbis`/`ilbc`/`vo-amrwbenc` external encoders bundled by the `audio` variant are not needed.

No video encoders, no x264/x265 (GPL), no network protocols beyond file I/O.

> Migrated from the `audio` variant to `min` (2026-07) to cut binary size — the extra `audio` external encoders were unused.

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
| Android  | `android/libs/maven/…/ffmpeg-kit-min-2.2.1.aar` | Gradle local maven repo |
| iOS      | `ios/dist/ffmpeg-kit-ios-min-8.1.2.zip` | `scripts/setup_ios.sh` (pod prepare_command) |
| macOS    | `macos/dist/ffmpeg-kit-macos-min-8.1.2.zip` + committed `macos/Frameworks/` | `scripts/setup_macos.sh` / `scripts/sign_macos_frameworks.sh` (pod prepare_command) |
| Windows  | `windows/dist/ffmpeg-kit-windows-x86_64-min-8.1.2.zip` | `windows/CMakeLists.txt` |

Binary provenance: FFmpeg 8.1.2 min-variant builds from `sk3llo/ffmpeg_kit_flutter` release `8.1.2-min` and Maven Central `com.antonkarpenko:ffmpeg-kit-min:2.2.1`, vendored 2026-07. To rebuild from source, use the archived `arthenica/ffmpeg-kit` build scripts (`android.sh` / `ios.sh` / `macos.sh` with the min library set).

> **macOS note:** the committed `macos/Frameworks/` are the min binaries shipped **unsigned** (vendored on Linux CI, which cannot run `codesign`). The podspec `prepare_command` ad-hoc signs them in place on the consuming Mac via `scripts/sign_macos_frameworks.sh`; you can also run that script manually. Without signing, the consuming macOS app's CodeSign step would fail with "code object is not signed at all".

## License

- Plugin code: LGPL v3.0 (see `LICENSE`)
- Bundled FFmpeg binaries: LGPL v3.0 (audio variant — contains **no** GPL components)
- Apps using this library must include an FFmpeg/LGPL attribution notice.
