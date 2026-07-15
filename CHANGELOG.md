## 1.1.0 (EasyJoy self-hosted)

* **Switched variant `audio` → `min` (FFmpeg 8.1.2) to cut binary size.** The `audio` variant statically linked 10 external encoders (`lame`, `libilbc`, `libvorbis`, `opencore-amr`, `opus`, `shine`, `soxr`, `speex`, `twolame`, `vo-amrwbenc`) that consumers were not using — MP3 encoding is done in Dart, and only native AAC(m4a)/WAV/PCM encode + native decode/probe are needed. The `min` variant ships **no external libraries** while keeping all FFmpeg-native codecs, so it is strictly smaller with no loss of used functionality.
  * iOS `libavcodec` fat framework: 30.5MB → 25MB; Android AAR: 49MB → 38.5MB (per-ABI `libavcodec.so` ~11MB → ~8MB).
  * All 4 platforms swapped to the min prebuilt binaries (iOS/macOS/Windows dist zips + Android Maven `com.antonkarpenko:ffmpeg-kit-min:2.2.1`). Framework/`.so` structure is identical to `audio`, so this is a drop-in swap; the public Dart API is unchanged.
  * Sources: `sk3llo/ffmpeg_kit_flutter` release `8.1.2-min` + Maven Central `ffmpeg-kit-min:2.2.1`.
* **macOS: committed `macos/Frameworks/` are now the min binaries, shipped unsigned** (vendored on Linux CI, which cannot run `codesign`). New `scripts/sign_macos_frameworks.sh` ad-hoc signs them in place; the macOS podspec `prepare_command` now invokes it whenever `Frameworks/` already exists (idempotent), so the consuming app's CodeSign step still passes.
* `setup_ios.sh` / `setup_macos.sh` / `windows/CMakeLists.txt` / `android/build.gradle` updated to reference the `min` artifacts. No API or source changes.

## 1.0.2 (EasyJoy self-hosted)

* **macOS: pre-built frameworks are now committed to the repo** (`macos/Frameworks/`, pre-extracted from `dist/*.zip` and ad-hoc code-signed). Removed the `macos/Frameworks/` ignore in `.gitignore`.
  * Fixes `'ffmpegkit/FFmpegKitConfig.h' file not found` when the plugin is consumed as a **local `:path` dependency**: CocoaPods does not run a podspec `prepare_command` for path pods, so `setup_macos.sh` never generated `Frameworks/` and the framework headers were missing. Shipping the frameworks in-repo makes both `git` and local `:path` consumption work with zero setup.
  * The frameworks are already ad-hoc signed in-repo, so the macOS app CodeSign step still succeeds (same fix as 1.0.1, applied ahead of time).
  * `setup_macos.sh` / podspec `prepare_command` are retained as a fallback — they only regenerate `Frameworks/` when the directory is absent, so committed frameworks take precedence.
* No API or source changes; iOS/Android/Windows untouched.

## 1.0.1 (EasyJoy self-hosted)

* **macOS build fix:** the prebuilt macOS frameworks shipped unsigned, so embedding them into a signed `.app` failed with `code object is not signed at all` (Command CodeSign failed) — e.g. on `libavfilter.framework`.
  * Repackaged `dist/ffmpeg-kit-macos-audio-8.1.2.zip` without AppleDouble/`._*` resource-fork junk (previously 314 stray files) while preserving framework symlinks.
  * `scripts/setup_macos.sh` now strips any `._*`/`.DS_Store` leftovers and **ad-hoc code-signs** all 8 frameworks after unzip, so Xcode's app CodeSign step succeeds.
* No API or source changes; iOS/Android/Windows untouched.

## 1.0.0 (EasyJoy self-hosted)

* Forked from `ffmpeg_kit_flutter_new` 4.4.2 (FFmpeg 8.1.2, includes CVE-2026-8461 fix).
* Renamed package to `ffmpeg_kit_flutter`; switched default variant from full-gpl to **audio** (LGPL, no GPL components).
* All native binaries vendored into the repo (Android AAR via local maven, iOS/macOS framework zips, Windows DLL zip). No network downloads at build time.

# Upstream history (ffmpeg_kit_flutter_new)

## 4.4.2

* Fixes the native binary wiring for the CVE-2026-8461 (MagicYUV / "PixelSmash") security patch: Android now pulls `com.antonkarpenko:ffmpeg-kit-*:2.2.1` and iOS/macOS fetch the FFmpeg 8.1.2 frameworks (the 8.1.2 rebuild was previously only wired for Windows). Please upgrade from any earlier version.

## 4.4.1

* **Security (CVE-2026-8461):** updated **FFmpeg to v8.1.2** (arthenica `n8.1.2`) to fix a heap out-of-bounds write in the MagicYUV decoder ("PixelSmash", CVSS 8.8). All platforms (Android/iOS/macOS/Windows) rebuilt against FFmpeg 8.1.2; no API changes.

## 4.4.0

* Updated **FFmpeg to v8.1.1** (arthenica `n8.1.1`), up from 8.0.0.
* iOS/macOS `.xcframework`s, the Android Maven library (`com.antonkarpenko:ffmpeg-kit-*`), and the Windows binaries are now built against FFmpeg 8.1.1.

## 4.3.2

* Android: broadened the bundled ProGuard/R8 consumer rules to keep **all** `com.antonkarpenko.ffmpegkit.**` classes (plus `-dontwarn`), not just the JNI entry points. Fully prevents R8 from stripping FFmpegKit in release builds — fixes the release-only white screen / `channel-error` (FFmpegKit failing to initialise, which cascades into errors like `shared_preferences` `getAll`). Closes #158.

## 4.3.1

* Android: ship ProGuard/R8 **consumer rules** (`consumer-rules.pro`, applied automatically via `consumerProguardFiles`) that keep the FFmpegKit JNI bindings — `FFmpegKitConfig` native/callback methods and `AbiDetect`. Prevents release-mode crashes such as `Bad JNI version returned from JNI_OnLoad` without requiring any ProGuard rules in your app. Thanks @niclasEX (#133).

## 4.3.0

* Fixed **iOS Simulator on Apple Silicon** (`arm64`) support — required for Xcode 26 / iOS 26+ simulators. Builds previously failed with *"The following target(s) do not support arm64 architecture, which is a requirement for Apple Silicon iOS 26+ simulators"*.
* The downloaded iOS `.framework` bundles are now converted to `.xcframework`s at build time (`scripts/setup_ios.sh`), exposing a native `ios-arm64_x86_64-simulator` slice alongside the `ios-arm64_arm64e` device slice. The simulator `arm64` slice is produced by retagging the device `arm64` slice's Mach-O build-version platform to `iOS-Simulator` via `vtool`.
* The iOS podspec now vendors `.xcframework`s and no longer excludes `arm64` for the simulator (`EXCLUDED_ARCHS[sdk=iphonesimulator*]` is now `i386` only).
* If you previously added `config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"` to your app's `ios/Podfile` `post_install` hook as a workaround, **remove it** — it now prevents the simulator `arm64` slice from linking.

## 4.2.2

* Fixed the Windows release build: `windows/ffmpeg_kit_flutter_plugin_c_api.cpp` included the generated public header from the wrong package directory (`ffmpeg_kit_flutter_new_full` instead of `ffmpeg_kit_flutter_new`), so building the published package on Windows failed to find the header. Thanks [@Nicoeevee](https://github.com/Nicoeevee) ([#159](https://github.com/sk3llo/ffmpeg_kit_flutter/pull/159)).

## 4.2.1

* Fixed iOS/macOS `pod install` failure introduced in 4.2.0: the setup scripts (`scripts/setup_ios.sh`, `scripts/setup_macos.sh`, `scripts/setup_android.sh`) were published with Windows CRLF line endings, causing `/bin/bash^M: bad interpreter: No such file or directory`. Scripts are now forced to LF via `.gitattributes` so the published package is always packaged with Unix line endings (fixes [#153](https://github.com/sk3llo/ffmpeg_kit_flutter/issues/153)).

## 4.2.0

* Added **Windows** support (x86_64) with a genuine `full-gpl` FFmpeg 8.0 build (all 27 external libraries, GPL components enabled).
* Native libraries are downloaded from the `8.0.0-full-gpl` release; for local development point `FFMPEGKIT_LOCAL_DIR` (CMake cache var or environment) at a locally built bundle.
* The bundled MinGW DLLs are rebased/ASLR-adjusted at build time and the full runtime dependency closure (gnutls, gmp, nettle, libxml2, lame, …) is shipped so the plugin loads standalone.

## 4.1.0

* Fixed the FFmpeg 8.0 compatibility issue across all platforms. The problem was that `all_channel_counts` was being set AFTER the filter was created, but FFmpeg 8.0 requires it to be set DURING filter creation.

## 4.0.0

* FFmpeg `v8.0.0` with [all the sweet perks](https://ffmpeg.org/index.html#news)

## 3.2.0

* Upgraded `freetype` from **2.13.0** to **2.13.3**
* Upgraded `harfbuzz` from **8.0.1** to **11.3.3**
* Upgraded `fontconfig` from **2.16.2** to 2.17.1
* Added support for `harfbuzz` library in order to support `drawtext` filter
* Fixed missing `libunibreak` for `libass.sh`

## 3.1.0

* Updated README.md with new package links
* Uploaded new binary with Kotlin 1.8.22
* Downgraded required Kotlin version in `example` project to 1.8.22
* Formatted code

## 3.0.2

* Updated README.md with new package links

## 3.0.1

* Updated README.md with link to Minimal-GPL

## 3.0.0

* FFmpeg `v7.1.1`
* Multiple upgrade of internal libraries:
    - `Nettle` - from `3.8.2` to `3.10.2`
    - `SDL` from `2.0.0` to `3.2.16`
    - `Libxml2` from `2.11.4` to `2.14.0`
    - `SRT` from `1.5.2` to `1.5.4`
    - `Leptonica` from `1.83.1` to `1.85.0`
    - `GnuTLS` from `3.7.9` to `3.8.9`
* Cleaned up iOS and Macos .podspec code
* Bumped Kotlin version to 2.2.0
* Fixed iOS and MacOS dowload scripts and added Videotoolbox support
* New Android Full-GPL Maven Central dependency
* Got rid of obsolete `ffmpeg_kit_flutter_android` package
* Updated `example` project with Hardware, Software and Videotoolbox encoding commands

## 2.0.0

* Uploaded updated Android .aar, compatible with Google 16 KB requirement
* Updated `setup_ios.sh` script
* Removed resource shrinking for Android
* Updated `setup_ios.sh` script
* Updated `setup_android.sh` script to include latest FFmpeg 7.0 kit
* Upgraded `ffmpeg_kit_flutter_android` to 1.7.0
* Merged @nischhalcodetrade fix for .aar post processing

## 1.6.1

* Removed manual packaging of prebuilt dependencies for Android
* Cleaned up unnecessary logs

## 1.6.0

* Added new seamless Android .aar support

## 1.5.0

* Added MacOS support by directly downloading and unpacking frameworks

## 1.4.1

* Updated README.md

## 1.4.0

* Added build.bat jni
* Updated Gradle script in order to be able to download and unpack .aar on Windows.

## 1.3.0

* Moved from FFmpeg `http` to `full_gpl` for Android
* Added downloading and unpacking of 6.0.2 `full-gpl` .aar

## 1.2.1

* Added displaying of Android platform to pub.dev
* Fixed static analysis issues

## 1.2.0

* New example project
* Resurrected Android by creating new `ffmpeg_kit_flutter_android` library with `com.arthenica:ffmpeg-kit-https:6.0-2.LTS` implementation
* iOS deployment target is increased to 14.0
* Upgraded plugin_platform_interface version

## 1.1.0

* Moved from `https` to `full-gpl` binding for MacOS
* Upgraded Flutter and Dart versions

## 1.0.0

* Initial release
* Fixed Android and MacOS bindings
* Upgraded FFmpegKitFlutterPlugin.java to work with Flutter 3.29