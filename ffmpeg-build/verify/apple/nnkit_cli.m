// Command-line front end over the shipped ffmpegkit.framework, so verify/run_corpus.sh can drive
// the real Apple libraries exactly like the ffmpeg / ffprobe programs (verify_apple.sh).
// The program name selects the tool: install it twice, as "ffmpeg" and as "ffprobe".
//   stdout: ffprobe's report (ffmpeg-kit logs it at AV_LOG_STDERR, -16)
//   stderr: every other log line
//   exit:   the session return code, as the app sees it
#import <Foundation/Foundation.h>
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#import <ffmpegkit/FFprobeKit.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *tool = [[NSString stringWithUTF8String:argv[0]] lastPathComponent];
        NSMutableArray<NSString *> *args = [NSMutableArray array];
        for (int i = 1; i < argc; i++) {
            [args addObject:[NSString stringWithUTF8String:argv[i]]];
        }
        [FFmpegKitConfig setLogRedirectionStrategy:LogRedirectionStrategyNeverPrintLogs];

        id<Session> session;
        if ([tool isEqualToString:@"ffprobe"]) {
            session = [FFprobeKit executeWithArguments:args];
        } else if ([tool isEqualToString:@"ffmpeg"]) {
            session = [FFmpegKit executeWithArguments:args];
        } else {
            fprintf(stderr, "nnkit_cli: install as \"ffmpeg\" or \"ffprobe\" (got %s)\n", argv[0]);
            return 2;
        }
        for (Log *log in [session getAllLogsWithTimeout:60000]) {
            fputs([[log getMessage] UTF8String], [log getLevel] == (int)LevelAVLogStdErr ? stdout : stderr);
        }
        ReturnCode *rc = [session getReturnCode];
        if (rc == nil) {
            fprintf(stderr, "nnkit_cli: no return code (state %ld)\n", (long)[session getState]);
            return 255;
        }
        return [rc getValue];
    }
}
