# Android build record — com.easyjoy.nicenote:ffmpeg-kit-nicenote:8.1.2-1

- Built: 2026-10-13T18:51Z on Linux 6.12.111+deb13-cloud-amd64 x86_64
- Upstream scripts: 984fa2dba93f93cd768dccb3033e6f175c46d3b5 (+ patches/android-ffmpeg-configure.patch)
- FFmpeg: n8.1.2 38b88335f99e76ed89ff3c93f877fdefce736c13 · cpu_features v0.8.0
- NDK 28.2.13676358, API 24
- Java layer: classes.jar from 2.2.1 (sha256 bd5bd9f847b16d1f38f016e078b74ec578f04e728974a43e2e53b31820d3bb6f)

| file | bytes | sha256 |
|---|---:|---|
| ffmpeg-kit-nicenote-8.1.2-1.aar | 7070265 | `af0544ad997b04e4231faf6c955af97147646027683d27b7d0aeba67911910c3` |
| ffmpeg-kit-nicenote-8.1.2-1.pom | 1696 | `d570919504e286e0e7e2c2b98b89629b9fe4a9cbbaca8eace7d7848616f00634` |
| arm64-v8a/libavcodec.so | 3135728 | `224597c22e326e3c28529d1053c42242553b4b9e4c39e7899ae020b9a07f2a91` |
| arm64-v8a/libavdevice.so | 12608 | `574f20367648abced81b5f1f1af8675f07db0d0efa494d3372fda665b472e923` |
| arm64-v8a/libavfilter.so | 383608 | `2ce58247d72226c8f79f8083362dc6526ba1494eeaf1aa6b59a146f3581daf4c` |
| arm64-v8a/libavformat.so | 1419912 | `6c0b286673eb58d3ae8159982d1f3b61ca6e5dbdf591f0071db6c7260cb76c5b` |
| arm64-v8a/libavutil.so | 560432 | `b7b22f81f32e64501d372f1c6edd47f8208780ecc78e1ab81d522b5705c27afa` |
| arm64-v8a/libffmpegkit_abidetect.so | 33120 | `ea022d4047091029e6ed8ba0dae63acd821b72634be9439377131d9adbf9a5c2` |
| arm64-v8a/libffmpegkit.so | 469720 | `2f0475abb93cf1a5540d60f4f93938f0d194a4849caa01562e8ee213323dfc22` |
| arm64-v8a/libswresample.so | 75336 | `d9518e0da36ca8179537beebbb6c4cf7c8b40b9d0c29f3b35ddb8a4c350ac774` |
| arm64-v8a/libswscale.so | 546352 | `ad9bfb6dab56dfe196cad1239109649bd931e577cdf76700678b124a5867375a` |
| armeabi-v7a/libavcodec_neon.so | 3130720 | `bdcfb6c12fde54804be1a4d3c27b5f724535b8705bca450f3ff366623843e14c` |
| armeabi-v7a/libavdevice_neon.so | 10404 | `b6fbda1030e1afd18bf6dbaf3a30e42b37a9b8dfed9b7ce19d69048b5009204e` |
| armeabi-v7a/libavfilter_neon.so | 331056 | `89283a314452e1c56fbb43505d81485e556f644fc67ed124c37d9c03d2b95121` |
| armeabi-v7a/libavformat_neon.so | 1352468 | `81d1f9f73cee9f60a3c85a39534705ddc9f712a1af39eb71922d0d22a7fbd3ec` |
| armeabi-v7a/libavutil_neon.so | 457012 | `0b668fbd30b1646a806652bf223cfd49b230d2a41267aeb53a33c60e12a5d36b` |
| armeabi-v7a/libffmpegkit_abidetect.so | 19740 | `fce5c7159b98158639d440552b5e0dd9047e983f44f6649d89015d7d881ef77f` |
| armeabi-v7a/libffmpegkit_armv7a_neon.so | 469732 | `785cba4fb51a29d4a4d1d5c66cd87379d3f53d49dae8067fd8cbef9ecec4c3f5` |
| armeabi-v7a/libswresample_neon.so | 73428 | `872218aa6a50f94fd2bd23071c65e7e2fcd137b79cf8df6991ae1debdf909aa3` |
| armeabi-v7a/libswscale_neon.so | 513108 | `db2c9996b87bcbf86b0588da60f61e4b2a840a7e1d173c105ed2d7d2e057c338` |

## Checks (verify/check_android_libs.py)

arm64-v8a: 9 libraries, 19 JNI exports, 18 native methods checked
armeabi-v7a: 9 libraries, 19 JNI exports, 18 native methods checked

| ABI | library | 2.2.1 bytes | new bytes |
|---|---|---:|---:|
| arm64-v8a | libavcodec.so | 8,651,472 | 3,135,728 |
| arm64-v8a | libavdevice.so | 55,296 | 12,608 |
| arm64-v8a | libavfilter.so | 2,888,400 | 383,608 |
| arm64-v8a | libavformat.so | 2,182,384 | 1,419,912 |
| arm64-v8a | libavutil.so | 554,824 | 560,432 |
| arm64-v8a | libffmpegkit.so | 463,704 | 469,720 |
| arm64-v8a | libffmpegkit_abidetect.so | 30,232 | 33,120 |
| arm64-v8a | libswresample.so | 72,280 | 75,336 |
| arm64-v8a | libswscale.so | 535,936 | 546,352 |
| armeabi-v7a | libavcodec_neon.so | 8,544,368 | 3,130,720 |
| armeabi-v7a | libavdevice_neon.so | 45,828 | 10,404 |
| armeabi-v7a | libavfilter_neon.so | 2,587,344 | 331,056 |
| armeabi-v7a | libavformat_neon.so | 2,079,268 | 1,352,468 |
| armeabi-v7a | libavutil_neon.so | 454,436 | 457,012 |
| armeabi-v7a | libffmpegkit_abidetect.so | 16,988 | 19,740 |
| armeabi-v7a | libffmpegkit_armv7a_neon.so | 461,044 | 469,732 |
| armeabi-v7a | libswresample_neon.so | 70,628 | 73,428 |
| armeabi-v7a | libswscale_neon.so | 510,740 | 513,108 |
| arm64-v8a | **total** | 15,434,528 | 6,636,816 |
| armeabi-v7a | **total** | 14,770,644 | 6,357,668 |

native library checks OK
