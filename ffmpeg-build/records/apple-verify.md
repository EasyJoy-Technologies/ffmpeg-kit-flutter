# Apple behaviour check — 2026-10-13

Frameworks: ios/Frameworks + macos/Frameworks as committed in 704e12a (build-apple run 38451170308).
Corpus: 161 files (corpus/MANIFEST.tsv), corpus.tar.gz sha256 4b679876cdef0d97216ffbdc4ece9c8f314c829c82a1d229c0c52cea28036374.
Runner: macOS 15 arm64, Xcode 16.4, iOS 18.5 simulator; x86_64 targets under Rosetta 2.
verify_apple.sh run 38463872009 (921ffd5). The 2-hour file is skipped as under qemu.

## 1. New vs v1.1.0 frameworks, same harness, same target (compare.py exact)

```
exact base-macos-arm64 vs res-macos-arm64: 160 files compared, 0 problems, skipped: gen_a_long_2h.mp3
exact base-macos-x86_64 vs res-macos-x86_64: 160 files compared, 1 problems, skipped: gen_a_long_2h.mp3
  PROBLEM gen_a_ra144.ra: m4a ['m4a=0', '0b053cef316f'] != ['m4a=0', '939aef8fe1d1']
exact base-iossim-arm64 vs res-iossim-arm64: 160 files compared, 0 problems, skipped: gen_a_long_2h.mp3
exact base-iossim-x86_64 vs res-iossim-x86_64: 160 files compared, 1 problems, skipped: gen_a_long_2h.mp3
  PROBLEM fate_lossless-audio_luckynight-partial.wma: m4a ['m4a=0', '6df16d272baf'] != ['m4a=0', '6385d22077f8']
```

arm64 (macOS and simulator): identical in every result. The two x86_64 differences are not caused by
the build: the AAC encode of a single file occasionally comes out differently **under Rosetta with
the same binaries** — the committed frameworks gave a different luckynight-partial.wma m4a in run
38451170308 than in this run on iossim-x86_64, and the v1.1.0 frameworks differ from each other on
gen_a_ra144.ra between macos-x86_64 and iossim-x86_64. Everything else (probe, scan, wav, pcm, remux,
and every other m4a) is identical between the runs. Seen with v1.1.0 as well, x86_64 only, one file
per run at most; decoding is never affected.

## 2. New vs Linux reference (host trimmed, as verify_android.sh; compare.py arch-kit)

```
arch-kit res-host-trimmed vs res-macos-arm64: 160 files compared, 0 problems, 217 float differences within stddev 3.0 (worst 2.123), skipped: gen_a_long_2h.mp3
arch-kit res-host-trimmed vs res-macos-x86_64: 160 files compared, 0 problems, 58 float differences within stddev 3.0 (worst 0.186), skipped: gen_a_long_2h.mp3
arch-kit res-host-trimmed vs res-iossim-arm64: 160 files compared, 0 problems, 217 float differences within stddev 3.0 (worst 2.123), skipped: gen_a_long_2h.mp3
arch-kit res-host-trimmed vs res-iossim-x86_64: 160 files compared, 0 problems, 58 float differences within stddev 3.0 (worst 0.186), skipped: gen_a_long_2h.mp3
```

Same tolerances and worst values as Android arm64 (2.123, wmavoice) — the arm64 float paths behave
the same on every arm64 platform.
