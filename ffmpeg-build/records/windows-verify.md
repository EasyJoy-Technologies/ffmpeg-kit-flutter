# Windows behaviour check — 2026-10-13

Bundle: windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip as committed in 21aa116
(build-windows run 38479664171). Corpus: 161 files, corpus.tar.gz sha256
4b679876cdef0d97216ffbdc4ece9c8f314c829c82a1d229c0c52cea28036374. Runner: windows-2025, MSYS2
MINGW64. verify_windows.sh run 38481359458 (7ef8855); DLLs rebased with editbin as the plugin does.
The 2-hour file is skipped as on the other targets.

## 1. New vs v1.1.0 bundle, same harness, same machine (compare.py exact)

```
exact base-windows-x86_64 vs res-windows-x86_64: 160 files compared, 0 problems, skipped: gen_a_long_2h.mp3
```

## 2. New vs Linux reference (compare.py arch-kit)

```
arch-kit res-host-trimmed vs res-windows-x86_64: 160 files compared, 7 problems, 203 float differences within stddev 3.0 (worst 2.003), skipped: gen_a_long_2h.mp3
  PROBLEM gen_A_UPPER.MP3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0']
  PROBLEM gen_a_cbr.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0']
  PROBLEM gen_a_cover.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0']
  PROBLEM gen_a_id3v24_zh.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=96000 fmt=mp3 codec=mp3 title=中文标题 ID3v2.4 video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=96000 fmt=mp3 codec=mp3 title=???????????? ID3v2.4 video=0']
  PROBLEM gen_a_noext: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0']
  PROBLEM gen_a_wv_apetag_zh.wv: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=337689 fmt=wv codec=wavpack title=APE 标签标题 video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=337689 fmt=wv codec=wavpack title=APE ???????????? video=0']
  PROBLEM gen_e_trunc.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0']
```

The 7 problems are one pre-existing wrapper bug, present in v1.1.0 in the same way (comparison 1 is
identical): every non-ASCII byte of a log line becomes "?" on Windows — here the UTF-8 (Chinese)
title in ffprobe's report. windows/src/FFmpegKitConfig.cpp avutil_log_sanitize() takes a plain
`char`, which is signed on x86, so bytes >= 0x80 compare "< 0x08". The Android and Apple wrappers
use `uint8_t` and keep the text (their runs above show the titles intact). Decoding, durations and
every output are unaffected (floats within the FATE tolerance, worst 2.003).
