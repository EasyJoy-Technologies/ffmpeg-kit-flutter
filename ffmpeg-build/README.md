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

## Rollback

Tag `v1.1.0` of this repository is the untrimmed build (Maven `ffmpeg-kit-min:2.2.1`).
