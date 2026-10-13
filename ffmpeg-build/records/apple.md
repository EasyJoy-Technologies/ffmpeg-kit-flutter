# Apple build record — iOS xcframeworks + macOS frameworks

- Built: 2026-10-13T19:11Z on macOS 15.7.9 arm64
- Xcode 16.4 (16F6), iOS SDK 18.5, macOS SDK 15.5
- autoconf (GNU Autoconf) 2.73, automake (GNU automake) 1.18.1, glibtool (GNU libtool) 2.6.2
- Upstream scripts: 984fa2dba93f93cd768dccb3033e6f175c46d3b5 (+ patches/apple-ffmpeg-configure.patch)
- FFmpeg: n8.1.2 38b88335f99e76ed89ff3c93f877fdefce736c13
- gas-preprocessor.pl (fetched by the upstream scripts): ed085dd43ed95759a2b84afc3b1f9b0b64114b586d0d4b16fbe164b4369ae844
- iOS: ./ios.sh -x --no-bitcode, device arm64 + simulator arm64/x86_64; macOS: ./macos.sh, arm64 + x86_64, ad-hoc signed

| file | arch | bytes | sha256 |
|---|---|---:|---|
| ios/Frameworks/ffmpegkit.xcframework/ios-arm64_x86_64-simulator/ffmpegkit.framework/ffmpegkit | x86_64 arm64 | 1149768 | `d759e670dfcbcb6114c1bed717d4d6131dbe93a9325ff8551e22085a9ca9caf4` |
| ios/Frameworks/ffmpegkit.xcframework/ios-arm64/ffmpegkit.framework/ffmpegkit | arm64 | 542696 | `664b95b85c8ee75d9805aa0ca818d041f04cf1a454bc4f44785cae5a91d27fee` |
| ios/Frameworks/libavcodec.xcframework/ios-arm64_x86_64-simulator/libavcodec.framework/libavcodec | x86_64 arm64 | 6727480 | `76c1e3f6b3017657511ea1f0d690fc26a8fd22e95618d133e08a19ac49c313b8` |
| ios/Frameworks/libavcodec.xcframework/ios-arm64/libavcodec.framework/libavcodec | arm64 | 3096080 | `fe56617e178568f337b67ba9d2d7151c9aa0cfb137bf263c9dd692d3fcbc25b9` |
| ios/Frameworks/libavdevice.xcframework/ios-arm64_x86_64-simulator/libavdevice.framework/libavdevice | x86_64 arm64 | 85000 | `e87dc5dee19575f8514dfe9339efbd7eee42e871c5a208abec405ad85be52ecd` |
| ios/Frameworks/libavdevice.xcframework/ios-arm64/libavdevice.framework/libavdevice | arm64 | 68072 | `50953ff32545fdd2bc5612bb8f3b7ff541d285b84ff1c9c744341d7e32bb4864` |
| ios/Frameworks/libavfilter.xcframework/ios-arm64_x86_64-simulator/libavfilter.framework/libavfilter | x86_64 arm64 | 770712 | `1d8fb89f6e351b41f14aa32729405aca8edf064be62f28b2a07c39c68c46771f` |
| ios/Frameworks/libavfilter.xcframework/ios-arm64/libavfilter.framework/libavfilter | arm64 | 390936 | `943fc94d9a2b626e5a47cda76feb3cba240d5024396f08089954d78f6e6db258` |
| ios/Frameworks/libavformat.xcframework/ios-arm64_x86_64-simulator/libavformat.framework/libavformat | x86_64 arm64 | 2874872 | `5b0a2d046d9bf90f38a7c8849f6599999fb246822d249ca768cd164f020d4a50` |
| ios/Frameworks/libavformat.xcframework/ios-arm64/libavformat.framework/libavformat | arm64 | 1405784 | `d4d7e9647844e103b453b6617470fafc0378453e536b9005e2d8cdfa5b5557b8` |
| ios/Frameworks/libavutil.xcframework/ios-arm64_x86_64-simulator/libavutil.framework/libavutil | x86_64 arm64 | 1030280 | `f9ceba0b9acf69757c9814e888bee3aff78de96a9c7684596e79e92177b80d79` |
| ios/Frameworks/libavutil.xcframework/ios-arm64/libavutil.framework/libavutil | arm64 | 550896 | `36487e6d5ee9f9d31c65a7f284dfcc902bb8b99b976ce78ab50ac0ab97165ab0` |
| ios/Frameworks/libswresample.xcframework/ios-arm64_x86_64-simulator/libswresample.framework/libswresample | x86_64 arm64 | 185688 | `4a65d644eb17a6327d9ed81ac7181076753f1f99c106107e12fb38cc0d11f791` |
| ios/Frameworks/libswresample.xcframework/ios-arm64/libswresample.framework/libswresample | arm64 | 119200 | `579b670fde0c4bc994c5a574af0de78ecdda39e852fa30b68ff14dab8e79034c` |
| ios/Frameworks/libswscale.xcframework/ios-arm64_x86_64-simulator/libswscale.framework/libswscale | x86_64 arm64 | 1095976 | `bcf005ec2b637b06a1dd4f670e537387bdd42e682254253e5de3c06c336b75f1` |
| ios/Frameworks/libswscale.xcframework/ios-arm64/libswscale.framework/libswscale | arm64 | 534664 | `a6628b4d7cbb7bb11246d382ebcebf7ac442986ca271863cd17883bc4d0ed8a7` |
| macos/Frameworks/ffmpegkit.framework/Versions/A/ffmpegkit | x86_64 arm64 | 1137536 | `ff9253549c43d68ab8da89e7613b6a37d78e792c18377c6f7d7d7bf9a5d3e277` |
| macos/Frameworks/libavcodec.framework/Versions/A/libavcodec | x86_64 arm64 | 6464192 | `bcaf412021401b5acbefb6ba43c035165832ab5cc0da01330763a1ad153be579` |
| macos/Frameworks/libavdevice.framework/Versions/A/libavdevice | x86_64 arm64 | 135920 | `4759676523d6a4d1bd49547b288d30f43739b3bc30aaf2580c49df4e3dd50c12` |
| macos/Frameworks/libavfilter.framework/Versions/A/libavfilter | x86_64 arm64 | 821600 | `89d0a893ef7d98cdd9dac9e12dcf59f9963fe6efe7500c3f11c3feac6c48f550` |
| macos/Frameworks/libavformat.framework/Versions/A/libavformat | x86_64 arm64 | 2925440 | `195778ecf83bd6f3ff60329b5c4e8cdf38a874522728c2cc58da7619d86d323f` |
| macos/Frameworks/libavutil.framework/Versions/A/libavutil | x86_64 arm64 | 1081232 | `a0976af89fd82d185e139469e9306ec31a5050a600e8013d2eb0734791a01bbe` |
| macos/Frameworks/libswresample.framework/Versions/A/libswresample | x86_64 arm64 | 236608 | `750326aabce90de12209a3856e8a00d1a5ef5f8066d367cfd5001efb8b2e2fb9` |
| macos/Frameworks/libswscale.framework/Versions/A/libswscale | x86_64 arm64 | 1179712 | `c185373a97f1be0a585f973b7dd8ece695cac1f31454f2b3fba770c998520c6e` |

## Checks (verify/check_apple_libs.py)

```
  note: ios-device/libavcodec: 59 fewer re-exported symbols of other FFmpeg libraries
  note: ios-device/libavcodec: internal avpriv_ exports no longer built: _avpriv_elbg_do _avpriv_elbg_free _avpriv_h264_has_num_reorder_frames
  note: ios-device/libavdevice: 31 fewer re-exported symbols of other FFmpeg libraries
  note: ios-device/libavdevice: dependencies vs v1.1.0: -['@rpath/libavfilter.framework/libavfilter', '@rpath/libswscale.framework/libswscale'] +[]
  note: ios-device/libavfilter: 75 fewer re-exported symbols of other FFmpeg libraries
  note: ios-device/libavfilter: dependencies vs v1.1.0: -['@rpath/libavcodec.framework/libavcodec', '@rpath/libavformat.framework/libavformat'] +[]
  note: ios-device/libavformat: 68 fewer re-exported symbols of other FFmpeg libraries
  note: ios-simulator/libavcodec: 59 fewer re-exported symbols of other FFmpeg libraries
  note: ios-simulator/libavcodec: internal avpriv_ exports no longer built: _avpriv_elbg_do _avpriv_elbg_free _avpriv_h264_has_num_reorder_frames
  note: ios-simulator/libavdevice: 31 fewer re-exported symbols of other FFmpeg libraries
  note: ios-simulator/libavdevice: dependencies vs v1.1.0: -['@rpath/libavfilter.framework/libavfilter', '@rpath/libswscale.framework/libswscale'] +[]
  note: ios-simulator/libavfilter: 75 fewer re-exported symbols of other FFmpeg libraries
  note: ios-simulator/libavfilter: dependencies vs v1.1.0: -['@rpath/libavcodec.framework/libavcodec', '@rpath/libavformat.framework/libavformat'] +[]
  note: ios-simulator/libavformat: 68 fewer re-exported symbols of other FFmpeg libraries
  note: macos/libavcodec: 59 fewer re-exported symbols of other FFmpeg libraries
  note: macos/libavcodec: internal avpriv_ exports no longer built: _avpriv_elbg_do _avpriv_elbg_free _avpriv_h264_has_num_reorder_frames
  note: macos/libavdevice: 31 fewer re-exported symbols of other FFmpeg libraries
  note: macos/libavdevice: dependencies vs v1.1.0: -['@rpath/libavfilter.framework/libavfilter', '@rpath/libswscale.framework/libswscale'] +[]
  note: macos/libavfilter: 75 fewer re-exported symbols of other FFmpeg libraries
  note: macos/libavfilter: dependencies vs v1.1.0: -['@rpath/libavcodec.framework/libavcodec', '@rpath/libavformat.framework/libavformat'] +[]
  note: macos/libavformat: 68 fewer re-exported symbols of other FFmpeg libraries
check_apple_libs: 8 frameworks x (iOS device, iOS simulator, macOS): OK
```
