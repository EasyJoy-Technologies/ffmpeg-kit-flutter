# Windows build record — windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip

- Built: 2026-10-13T22:50Z on MINGW64_NT-10.0-26100 3.6.10-e0c179b8.x86_64 (MSYS2 MINGW64)
- gcc.exe (Rev6, Built by MSYS2 project) 16.2.0, GNU ld (GNU Binutils) 2.47.20260726, NASM version 3.02 compiled on Jul  4 2026
- Upstream scripts: e8a5f4bda136bcf33597b085136bc7688b6a4e59 (+ patches/windows-ffmpeg-configure.patch)
- FFmpeg: n8.1.2 38b88335f99e76ed89ff3c93f877fdefce736c13
- MSYS2 packages: mingw-w64-x86_64-gcc 16.2.0-6 mingw-w64-x86_64-binutils 2.47-4 mingw-w64-x86_64-crt 14.0.0.r426.g4564ee4b5-1 mingw-w64-x86_64-winpthreads 14.0.0.r426.g4564ee4b5-2 mingw-w64-x86_64-nasm 3.02-1 mingw-w64-x86_64-rapidjson 1.1.0-8 

| file | bytes | sha256 |
|---|---:|---|
| windows/dist/ffmpeg-kit-windows-x86_64-nicenote-8.1.2.zip | 4993884 | `b18ec2f77dd04ab3bac6753aa157eec2dfa44b9b0ada05fa7139c1fd3155aa95` |
| bin/avcodec.lib | 144146 | `dc7de80a78bc7eddc2a3cf95c10f0f14860d5d985ca1b822cb444f5fb4e22bf0` |
| bin/avcodec-62.dll | 3567104 | `cbf875472c64ab14872084827ac4cf8f63a615314533e6e3675612458b140186` |
| bin/avdevice.lib | 14120 | `fa1d09bb48c75d524b7fd4438749302cbe98fdfe54dd7aece01673fa874ce1de` |
| bin/avdevice-62.dll | 16896 | `61aa4612cc68962c395225c9033d53c4ed2f193251683d804ae97a042f177de1` |
| bin/avfilter.lib | 57188 | `884f974c9e3ab67b5ffae3c595ee6c1ab312f6b45278b018921cea05874059fe` |
| bin/avfilter-11.dll | 433152 | `81ac0476341cdb32e71609d0c7a8f8771f1c64b1a15718ab06160d100b089e37` |
| bin/avformat.lib | 126110 | `ced88da76f229557b62a16115a3cbf3b49f2cb395c00b217bf124769174c38e6` |
| bin/avformat-62.dll | 1396224 | `8b9190d8a1d238b0f122f9a5e80830dcf978ef3ac1e89522629c97d6683db777` |
| bin/avutil.lib | 497360 | `be10bbf39a8d7ad14f57c944f99ab389e1d09973d5946dbc1bf262735441ef89` |
| bin/avutil-60.dll | 733184 | `0d7d91b0bddc4b36be2541a000595c5909c38e1b00930f324db443ef9cacc9f1` |
| bin/libffmpegkit.dll | 3672825 | `460ef13da56a906a15d3d500c2fc8051340cad996c25c24d48e592671566926a` |
| bin/swresample.lib | 19876 | `50a4f7b4163d3eea1518032837f65183bc86329ab63d34872b3cb36ec03d077c` |
| bin/swresample-6.dll | 107520 | `9f03121b5e75109d79aa25fc19c6c646cb0b17c59d2d4d63de32dadce943128f` |
| bin/swscale.lib | 33288 | `5e41d5749ad7c417b1298e279976ff8473708fc85aed5e3f69542c55efb6b6de` |
| bin/swscale-9.dll | 832512 | `14fee7be22de950874141c5c1208d8579ed05f017323dd0f7fbaae6d680cda69` |

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
