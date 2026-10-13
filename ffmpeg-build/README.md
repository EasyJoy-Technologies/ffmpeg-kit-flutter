# ffmpeg-build — NiceNote's trimmed FFmpeg

NiceNote only uses FFmpeg for audio: reading/probing audio files (including the audio track of
video containers), duration scans, converting to m4a/wav/pcm, and remuxing ADTS AAC into m4a.
These scripts rebuild FFmpeg **8.1.2** with exactly the components needed for that and nothing
else. The FFmpeg source, its configure options, the eight libraries and the ffmpeg-kit wrapper
are the same as in the upstream "min" build; only the component list changes.

## Files

| File | Role |
|---|---|
| `components.sh` | **The only component list** (all four platforms) and the exact check of what configure enabled |
| `audio_decoders.txt` | All audio decoders the pinned source can build — generated, never edited |
| `gen_audio_decoders.sh` | Regenerates `audio_decoders.txt` from a full host build (`AVCodec.type == AUDIO`) |
| `pins.env` | Upstream script / FFmpeg / cpu_features commits, NDK version, base AAR checksum |
| `patches/` | Minimal patches to the upstream scripts (append our flags, keep `config_components.h`) |
| `build_android.sh` | Android: pinned upstream `android.sh` → checks → AAR into `android/libs/maven` |
| `android.version` | Version of the published AAR (`com.easyjoy.nicenote:ffmpeg-kit-nicenote`) |
| `verify_android.sh` | Behaviour comparison on the test corpus (host and Android/qemu) |
| `build_apple.sh` | iOS + macOS (run by `.github/workflows/build-apple.yml`): pinned upstream `ios.sh` / `macos.sh` → checks → `ios/Frameworks`, `macos/Frameworks` |
| `verify_apple.sh` | Behaviour comparison of the Apple frameworks through the ffmpegkit API (macOS and iOS simulator) |
| `verify/` | Checkers used by the scripts above, and the corpus generator (`verify/corpus/`) |
| `records/` | Build record (tools, commits, sha256 of every artifact) and verification result, per platform |

## What is built

- **Decoders:** every audio decoder (211), no video/image/subtitle decoders.
- **Demuxers:** all, except the ones that open other files by reference (hls, concat,
  webm_dash_manifest, image2*). Network-only demuxers (rtp, rtsp, sap, sdp) disappear with
  `--disable-network`.
- **Encoders / muxers:** only what NiceNote writes (aac, alac, flac, pcm; m4a/mp4/mov, adts, wav,
  w64, aiff, caf, flac, matroska audio, raw pcm). mp3 is encoded by the app's own LAME.
- **Parsers:** all. **Bitstream filters:** 11 audio-related. **Filters:** the ones the ffmpeg CLI
  references, the auto-inserted converters, and ~25 common audio filters.
- **Protocols:** file, pipe, fd (+ saf on Android, ffmpeg-kit's content:// support).

`nicenote_verify_components` compares the generated `config_components.h` with this list *exactly*
(nothing missing, nothing extra; the few components configure adds or drops by itself are listed
in `components.sh`). FFmpeg's configure silently ignores misspelled names, so this check is what
guarantees the list is real.

## Android

```sh
ffmpeg-build/verify/corpus/make_corpus.sh <work>/corpus     # once; ~160 files, ~50 MB
ffmpeg-build/build_android.sh <work>/android                # ~20 min, 8 cores
ffmpeg-build/verify_android.sh <work>                       # ~1–2 h (qemu)
```

- arm64-v8a and armeabi-v7a (NEON set only — the app excludes the non-NEON fallback, which can
  never load because Flutter itself requires NEON). No x86/x86_64: the app ships ARM only.
- The AAR keeps the Java layer of `com.antonkarpenko:ffmpeg-kit-min:2.2.1` **byte for byte**
  (`classes.jar`, manifest; checksum pinned in `pins.env`); only `jni/` is replaced.
- `verify/check_android_libs.py` checks every library: ABI, `DT_NEEDED`, that every undefined symbol
  resolves against its dependencies or the NDK system libraries, the JNI export set (identical to
  2.2.1, and every `native` method in `classes.jar` implemented), 16 KB page alignment on arm64,
  and that the compiled-in configure line carries our flags.

## Verification (verify_android.sh)

1. **Host full vs host trimmed** — same compiler, C only: every result must be identical
   (exit codes, the probe facts NiceNote reads, duration scan, every output byte). This is the
   check that the component list changes nothing.
2. **Host trimmed vs Android arm64 / armv7 NEON (qemu)** — static command-line tools built with the
   upstream arch flags, so the NEON/assembly paths run. Probe facts, duration scan and the ADTS
   remux must be identical; integer decoders must decode bit-exactly; floating-point output
   (float decoders, and the 16 kHz resampled WAV for every codec) may differ by a standard
   deviation of at most 3 LSB with the same sample count — the tolerance FFmpeg's own test suite
   uses (`CMP=stddev`, `FUZZ=3`). arm64 differs more than armv7 on a few speech codecs because
   clang fuses multiply-adds on arm64; the same holds for the published 2.2.1 libraries.
   The 2-hour file is skipped under qemu (hours of emulation; same decode path as the other mp3s).

The result is written to `records/android-verify.md`.

The corpus is FFmpeg FATE samples (`verify/corpus/fate.lst`) plus generated files
(`gen_synthetic.sh`): every common audio format, cover art, Chinese tags, multichannel, 24-bit,
DSD, a 2-hour file, video containers, broken files and non-audio files. `MANIFEST.tsv` in the
corpus directory records the sha256 of each input.

## Apple (GitHub Actions)

```sh
gh workflow run build-apple.yml --ref ffmpeg-build \
   -f corpus_ref=<temporary branch with corpus.tar.gz> -f corpus_sha256=<sha256>
gh run download <run-id>        # frameworks.tar.gz, logs.tar.gz, results.tar.gz
```

- Manual workflow, Xcode 16.4 (the SDKs the published 8.1.2-min frameworks were built with). The
  frameworks come back as an artifact (kept 1 day), are checked again and committed from the build
  server; afterwards the run, its logs, the artifact and the temporary corpus branch are deleted.
  `-f build=false` only runs the behaviour check on the committed frameworks.
- iOS: xcframeworks, device `arm64` and simulator `arm64` (built natively, no longer the device
  slice retagged) + `x86_64`. No `arm64e` (a Flutter app process is arm64) and no bitcode.
  Committed in `ios/Frameworks`, so no `setup_ios.sh` / `prepare_command` step any more.
- macOS: `arm64` + `x86_64`, ad-hoc signed at build time (`scripts/sign_macos_frameworks.sh`).
- `verify/check_apple_libs.py`: slices, platform and minimum OS (iOS 12.1, macOS 10.15 as before),
  no bitcode, install names, dependencies only system libraries and the eight frameworks, every
  imported symbol exported by the library it is bound to, and the symbols each library defines plus
  all headers identical to v1.1.0. (The FFmpeg libraries also re-export symbols of the other FFmpeg
  libraries they link; those follow the component list and are only checked to cover what is
  imported through them.)
- `verify_apple.sh` runs NiceNote's command shapes through the ffmpegkit API
  (`verify/apple/nnkit_cli.m`) on macOS arm64 / x86_64 and the iOS simulator arm64 / x86_64:
  1. against the **v1.1.0 frameworks** run the same way on the same target: `compare.py exact`;
  2. against the Linux reference: `compare.py arch-kit` (the arch rules; failing exit codes and the
     `-progress` duration value are ffmpeg-kit's, not the build's, and are compared in kind only).

  The results are recorded in `records/apple-verify.md`.

## Rollback

Tag `v1.1.0` of this repository is the untrimmed build (Maven `ffmpeg-kit-min:2.2.1`).
