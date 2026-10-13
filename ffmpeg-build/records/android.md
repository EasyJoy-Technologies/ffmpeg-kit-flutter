# Android build record — com.easyjoy.nicenote:ffmpeg-kit-nicenote:8.1.2-1

- Built: 2026-10-13T04:29Z on Linux 6.12.111+deb13-cloud-amd64 x86_64
- Upstream scripts: 984fa2dba93f93cd768dccb3033e6f175c46d3b5 (+ patches/android-ffmpeg-configure.patch)
- FFmpeg: n8.1.2 38b88335f99e76ed89ff3c93f877fdefce736c13 · cpu_features v0.8.0
- NDK 28.2.13676358, API 24
- Java layer: classes.jar from 2.2.1 (sha256 bd5bd9f847b16d1f38f016e078b74ec578f04e728974a43e2e53b31820d3bb6f)

| file | bytes | sha256 |
|---|---:|---|
| ffmpeg-kit-nicenote-8.1.2-1.aar | 7069131 | `aa1e753b6c044d5e7ef0d3410ddd4c03cbd9c5b137a4c96def576e4f08e94594` |
| ffmpeg-kit-nicenote-8.1.2-1.pom | 1696 | `d570919504e286e0e7e2c2b98b89629b9fe4a9cbbaca8eace7d7848616f00634` |
| arm64-v8a/libavcodec.so | 3135728 | `ba7d263e238edaf0a203995511e1b9b5893276c76be629949fd1ce1841a267f1` |
| arm64-v8a/libavdevice.so | 12608 | `2ad9d05e855229c36ff658908581919c08fd681dbb62c6219ed6d454dba490c2` |
| arm64-v8a/libavfilter.so | 383592 | `502778092c65619c68edb2f0bfbcce7a7071489b05671ba6aeb1964aa1e89417` |
| arm64-v8a/libavformat.so | 1419896 | `f64f8b190bd837d7ac806cea69285bb2d97f4d0426526a0b239cf46658ce852a` |
| arm64-v8a/libavutil.so | 560416 | `35c14c6fd3b3e0bccac327bb2a2f96d5f6d38831e9485f01660a5228813c1083` |
| arm64-v8a/libffmpegkit_abidetect.so | 33120 | `fa06d4a6a257212d7aa517db55709469e8d61029f5b8811aa8f5c5dfaad9c13c` |
| arm64-v8a/libffmpegkit.so | 469704 | `08d8a86c30577905c4fb86c9523de1e249745895f3568d1c223fb5d09a7c35d2` |
| arm64-v8a/libswresample.so | 75320 | `8f9d7409b21d4f1cce9c30fc896c76952b082b73e6396f45ca0bf02bf9174508` |
| arm64-v8a/libswscale.so | 546352 | `12eee6732c6c33477f99e82884da479677dc952d740dbbe29065166be8d7b5f1` |
| armeabi-v7a/libavcodec_neon.so | 3130720 | `a894a64c9adc234d3afe4e4c82ce54f10971bbc2082286a3be41794eab3c1c6a` |
| armeabi-v7a/libavdevice_neon.so | 10388 | `316328ac43c27e4aaf204909046a7c2e9932d6d98e586558f6d7b64655c4fd89` |
| armeabi-v7a/libavfilter_neon.so | 331056 | `50ad3864b44336068c3a0c6197289a6f3c69c380fdb64a0fbb3938b4291429ed` |
| armeabi-v7a/libavformat_neon.so | 1352452 | `58d4e3ae6e7461ee7023d7934430cea073e0bac37aefb93d43f388b5db269571` |
| armeabi-v7a/libavutil_neon.so | 456996 | `9a4b5544427a6716beff0427f441489efd9a8874f39716a9e67a1bbe8e3f5ee2` |
| armeabi-v7a/libffmpegkit_abidetect.so | 19740 | `8e969a3e8f6624db15df44042f3131452457f328a9ed48b74b55e0549edb3f59` |
| armeabi-v7a/libffmpegkit_armv7a_neon.so | 469684 | `6daf3151f08640389a96eb12b3fe5975486b089062c63bdfa30f65b50ed8a301` |
| armeabi-v7a/libswresample_neon.so | 73412 | `4163a6127ec03fc8c69af8e93dc39d5b022697c84bca0ba7d625670592664061` |
| armeabi-v7a/libswscale_neon.so | 513092 | `cb53f67ca4d7471d9ff0de47a373adaaa73a83c3723b08725fda2ac3f7445f3e` |

## Checks (verify/check_android_libs.py)

arm64-v8a: 9 libraries, 19 JNI exports, 18 native methods checked
armeabi-v7a: 9 libraries, 19 JNI exports, 18 native methods checked

| ABI | library | 2.2.1 bytes | new bytes |
|---|---|---:|---:|
| arm64-v8a | libavcodec.so | 8,651,472 | 3,135,728 |
| arm64-v8a | libavdevice.so | 55,296 | 12,608 |
| arm64-v8a | libavfilter.so | 2,888,400 | 383,592 |
| arm64-v8a | libavformat.so | 2,182,384 | 1,419,896 |
| arm64-v8a | libavutil.so | 554,824 | 560,416 |
| arm64-v8a | libffmpegkit.so | 463,704 | 469,704 |
| arm64-v8a | libffmpegkit_abidetect.so | 30,232 | 33,120 |
| arm64-v8a | libswresample.so | 72,280 | 75,320 |
| arm64-v8a | libswscale.so | 535,936 | 546,352 |
| armeabi-v7a | libavcodec_neon.so | 8,544,368 | 3,130,720 |
| armeabi-v7a | libavdevice_neon.so | 45,828 | 10,388 |
| armeabi-v7a | libavfilter_neon.so | 2,587,344 | 331,056 |
| armeabi-v7a | libavformat_neon.so | 2,079,268 | 1,352,452 |
| armeabi-v7a | libavutil_neon.so | 454,436 | 456,996 |
| armeabi-v7a | libffmpegkit_abidetect.so | 16,988 | 19,740 |
| armeabi-v7a | libffmpegkit_armv7a_neon.so | 461,044 | 469,684 |
| armeabi-v7a | libswresample_neon.so | 70,628 | 73,412 |
| armeabi-v7a | libswscale_neon.so | 510,740 | 513,092 |
| arm64-v8a | **total** | 15,434,528 | 6,636,736 |
| armeabi-v7a | **total** | 14,770,644 | 6,357,540 |

native library checks OK
