Pod::Spec.new do |s|
  s.name             = 'ffmpeg_kit_flutter'
  s.version          = '8.1.2'
  s.summary          = 'FFmpeg Kit for Flutter'
  s.description      = 'A Flutter plugin for running FFmpeg and FFprobe commands.'
  s.homepage         = 'https://github.com/sk3llo/ffmpeg_kit_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Anton Karpenko' => 'kapraton@gmail.com' }

  s.platform            = :ios
  s.requires_arc        = true
  s.static_framework    = true

  s.source              = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.default_subspec = 'audio'

  s.dependency          'Flutter'
  # The committed xcframeworks (ios/Frameworks, built by ffmpeg-build/build_apple.sh) ship a natively
  # built arm64 iOS-simulator slice, so arm64 must NOT be excluded for the simulator.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  s.subspec 'audio' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.ios.vendored_frameworks = 'Frameworks/ffmpegkit.xcframework',
                                 'Frameworks/libavcodec.xcframework',
                                 'Frameworks/libavdevice.xcframework',
                                 'Frameworks/libavfilter.xcframework',
                                 'Frameworks/libavformat.xcframework',
                                 'Frameworks/libavutil.xcframework',
                                 'Frameworks/libswresample.xcframework',
                                 'Frameworks/libswscale.xcframework'
    ss.ios.frameworks = 'AudioToolbox', 'CoreMedia'
    ss.libraries = 'z', 'bz2', 'c++', 'iconv'
    ss.ios.deployment_target = '14.0'
  end
end
