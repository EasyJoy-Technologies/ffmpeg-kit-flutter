# Windows build record — windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip

- Built: 2026-10-13T23:18Z on MINGW64_NT-10.0-26100 3.6.10-e0c179b8.x86_64 (MSYS2 MINGW64)
- gcc.exe (Rev6, Built by MSYS2 project) 16.2.0, GNU ld (GNU Binutils) 2.47.20260726, NASM version 3.02 compiled on Jul  4 2026
- Upstream scripts: e8a5f4bda136bcf33597b085136bc7688b6a4e59 (+ patches/windows-ffmpeg-configure.patch, patches/windows-wrapper-log-sanitize.patch)
- FFmpeg: n8.1.2 38b88335f99e76ed89ff3c93f877fdefce736c13
- MSYS2 packages: mingw-w64-x86_64-gcc 16.2.0-6 mingw-w64-x86_64-binutils 2.47-4 mingw-w64-x86_64-crt 14.0.0.r426.g4564ee4b5-1 mingw-w64-x86_64-winpthreads 14.0.0.r426.g4564ee4b5-2 mingw-w64-x86_64-nasm 3.02-1 mingw-w64-x86_64-rapidjson 1.1.0-8 

| file | bytes | sha256 |
|---|---:|---|
| windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip | 4993967 | `21acd71746f2d34ff7738b634fa97b7b97dcf338f9a3ede54a7033dacd692c3f` |
| bin/avcodec.lib | 144146 | `dc7de80a78bc7eddc2a3cf95c10f0f14860d5d985ca1b822cb444f5fb4e22bf0` |
| bin/avcodec-62.dll | 3567104 | `fc150aa4ae269cfb98db935b38efd855a71a2aae0cdf11b4572bd22bdb2fdc6b` |
| bin/avdevice.lib | 14120 | `fa1d09bb48c75d524b7fd4438749302cbe98fdfe54dd7aece01673fa874ce1de` |
| bin/avdevice-62.dll | 16896 | `17b2552b639bdebb828215dd700025deabc8bb142f697d821c57918f8e464a19` |
| bin/avfilter.lib | 57188 | `884f974c9e3ab67b5ffae3c595ee6c1ab312f6b45278b018921cea05874059fe` |
| bin/avfilter-11.dll | 433152 | `2a5e582e970470373e27eb8b8a0902ce7f285d260a46e317fa5984203c24b777` |
| bin/avformat.lib | 126110 | `ced88da76f229557b62a16115a3cbf3b49f2cb395c00b217bf124769174c38e6` |
| bin/avformat-62.dll | 1396224 | `e4071245431d75e4628e7e684bb31d244d42114f384ae9d4357e798db45cfc97` |
| bin/avutil.lib | 497360 | `be10bbf39a8d7ad14f57c944f99ab389e1d09973d5946dbc1bf262735441ef89` |
| bin/avutil-60.dll | 733184 | `27d35393bdeba7b1d5356b683439cc22d164e82f7fe2975184bd67aeb6cd5912` |
| bin/libffmpegkit.dll | 3672825 | `68890371216adb057ad76fae8aa399992120402d61b2bffca8af60023c676863` |
| bin/swresample.lib | 19876 | `50a4f7b4163d3eea1518032837f65183bc86329ab63d34872b3cb36ec03d077c` |
| bin/swresample-6.dll | 107520 | `563e3e952e2bedceff5d0e43a5f9599c6c86fffcdb90b243a2edacc50d9e7fdd` |
| bin/swscale.lib | 33288 | `5e41d5749ad7c417b1298e279976ff8473708fc85aed5e3f69542c55efb6b6de` |
| bin/swscale-9.dll | 832512 | `b9f377bf684073ad0c927621e7b195eae49219711c2e8820322c7da307b84a0b` |

## Checks (verify/check_windows_libs.py)

```
  note: DLLs no longer shipped: libbz2-1.dll libgcc_s_seh-1.dll libiconv-2.dll liblzma-5.dll libstdc++-6.dll libva.dll libva_win32.dll libwinpthread-1.dll zlib1.dll
  note: avcodec-62.dll: internal avpriv_ exports no longer built: avpriv_elbg_do avpriv_elbg_free avpriv_h264_has_num_reorder_frames
  note: avcodec-62.dll: imports vs v1.1.0: -['libiconv-2.dll', 'liblzma-5.dll', 'libva.dll', 'ole32.dll', 'zlib1.dll'] +[]
  note: avdevice-62.dll: imports vs v1.1.0: -['avcodec-62.dll', 'avfilter-11.dll', 'avicap32.dll', 'gdi32.dll', 'ole32.dll', 'oleaut32.dll', 'shlwapi.dll', 'user32.dll'] +[]
  note: avfilter-11.dll: imports vs v1.1.0: -['avcodec-62.dll', 'avformat-62.dll', 'libgcc_s_seh-1.dll', 'libstdc++-6.dll', 'libva.dll', 'libwinpthread-1.dll', 'user32.dll'] +[]
  note: avformat-62.dll: imports vs v1.1.0: -['crypt32.dll', 'libbz2-1.dll', 'libiconv-2.dll', 'ncrypt.dll', 'secur32.dll', 'ws2_32.dll', 'zlib1.dll'] +[]
  note: avutil-60.dll: imports vs v1.1.0: -['libva.dll', 'libva_win32.dll', 'libwinpthread-1.dll', 'user32.dll'] +[]
  note: libffmpegkit.dll: imports vs v1.1.0: -['libgcc_s_seh-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll'] +[]
check_windows_libs: 8 DLLs: OK
```
