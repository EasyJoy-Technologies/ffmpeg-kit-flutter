# Windows behaviour check — 2026-10-13

Bundle: windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip (sha256
21acd71746f2d34ff7738b634fa97b7b97dcf338f9a3ede54a7033dacd692c3f), build-windows run 38482529153
(64ce178), which also ran verify_windows.sh. Corpus: 161 files, corpus.tar.gz sha256
4b679876cdef0d97216ffbdc4ece9c8f314c829c82a1d229c0c52cea28036374. Runner: windows-2025, MSYS2
MINGW64; DLLs rebased with editbin as the plugin does. The 2-hour file is skipped as on the other
targets. Both comparisons were evaluated on the build server from the run's results (the runner's
python could not print the Chinese titles; fixed since with PYTHONUTF8=1).

## 1. New vs v1.1.0 bundle, same harness, same machine (compare.py exact)

```
exact base-windows-x86_64 vs res-windows-x86_64: 160 files compared, 7 problems, skipped: gen_a_long_2h.mp3
  PROBLEM gen_A_UPPER.MP3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0']
  PROBLEM gen_a_cbr.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0']
  PROBLEM gen_a_cover.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0']
  PROBLEM gen_a_id3v24_zh.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=96000 fmt=mp3 codec=mp3 title=???????????? ID3v2.4 video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=96000 fmt=mp3 codec=mp3 title=中文标题 ID3v2.4 video=0']
  PROBLEM gen_a_noext: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0']
  PROBLEM gen_a_wv_apetag_zh.wv: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=337689 fmt=wv codec=wavpack title=APE ???????????? video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=337689 fmt=wv codec=wavpack title=APE 标签标题 video=0']
  PROBLEM gen_e_trunc.mp3: probe ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=?????? ?????? Title video=0'] != ['probe=0', 'dur=6000 sr=44100 ch=2 br=128000 fmt=mp3 codec=mp3 title=测试 标题 Title video=0']
```

The seven differences are the intended fix (patches/windows-wrapper-log-sanitize.patch): the v1.1.0
wrapper replaced every non-ASCII byte of a log line with "?" because avutil_log_sanitize() compared
signed chars, so Chinese titles in ffprobe's report read "??????". Everything else is identical.

## 2. New vs Linux reference (compare.py arch-kit)

```
arch-kit res-host-trimmed vs res-windows-x86_64: 160 files compared, 0 problems, 203 float differences within stddev 3.0 (worst 2.003), skipped: gen_a_long_2h.mp3
```

The titles now match the reference (and Android/Apple). Floats within the FATE tolerance.
