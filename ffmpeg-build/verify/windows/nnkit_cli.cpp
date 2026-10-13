// Command-line front end over libffmpegkit.dll, loaded and called exactly like the Flutter plugin
// does (windows/ffmpeg_kit_flutter_plugin.cpp: LoadLibraryA + the C API), so verify/run_corpus.sh can
// drive the shipped Windows bundle like the ffmpeg / ffprobe programs (verify_windows.sh).
// The program name selects the tool: install it twice, as ffmpeg.exe and ffprobe.exe, next to the
// DLLs.
//   stdout: ffprobe's report (ffmpeg-kit logs it at AV_LOG_STDERR, -16)
//   stderr: every other log line
//   exit:   the session return code, as the app sees it
#include <windows.h>
#include <fcntl.h>
#include <io.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr int kAvLogStderr = -16;  // Level.h LevelAVLogStdErr / fftools AV_LOG_STDERR
constexpr int kLogTimeoutMs = 60000;

using CreateFn = char* (*)(const char**, int);
using ExecuteFn = void (*)(long);
using LogsFn = char* (*)(long, int);
using ReturnCodeFn = int (*)(long);
using FreeFn = void (*)(void*);
using StrategyFn = void (*)(int);

// Minimal reader for the JSON ffmpegkit_c_api.cpp writes with rapidjson: an array of
// {"sessionId":n,"level":n,"message":"..."} objects, or one session object.
struct Reader {
    const char* p;
    void ws() { while (*p == ' ' || *p == '\n' || *p == '\r' || *p == '\t') ++p; }
    bool eat(char c) { ws(); if (*p != c) return false; ++p; return true; }
    std::string str() {
        std::string out;
        ++p;  // opening quote
        while (*p && *p != '"') {
            if (*p != '\\') { out += *p++; continue; }
            ++p;
            switch (*p) {
                case 'n': out += '\n'; break;
                case 't': out += '\t'; break;
                case 'r': out += '\r'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'u': {  // rapidjson only escapes control characters this way
                    out += static_cast<char>(std::strtol(std::string(p + 1, 4).c_str(), nullptr, 16));
                    p += 4;
                    break;
                }
                default: out += *p;  // \" \\ \/
            }
            ++p;
        }
        if (*p) ++p;  // closing quote
        return out;
    }
    long long num() { char* end; long long v = std::strtoll(p, &end, 10); p = end; return v; }
    void value_skip() { ws(); if (*p == '"') str(); else while (*p && *p != ',' && *p != '}' && *p != ']') ++p; }
};

struct LogLine { int level; std::string message; };

std::vector<LogLine> parse_logs(const char* json) {
    std::vector<LogLine> out;
    Reader r{json};
    if (!r.eat('[')) return out;
    while (r.eat('{')) {
        LogLine line{0, {}};
        do {
            r.ws();
            std::string key = r.str();
            r.eat(':');
            r.ws();
            if (key == "level") line.level = static_cast<int>(r.num());
            else if (key == "message") line.message = r.str();
            else r.value_skip();
        } while (r.eat(','));
        r.eat('}');
        out.push_back(std::move(line));
        r.eat(',');
    }
    return out;
}

long session_id(const char* json) {
    const char* k = std::strstr(json, "\"sessionId\":");
    return k ? std::strtol(k + 12, nullptr, 10) : -1;
}

template <typename T> T load(HMODULE lib, const char* name) {
    auto fn = reinterpret_cast<T>(reinterpret_cast<void*>(GetProcAddress(lib, name)));
    if (!fn) { std::fprintf(stderr, "nnkit_cli: %s not exported\n", name); std::exit(254); }
    return fn;
}

}  // namespace

int main(int argc, char** argv) {
    std::string tool = argv[0];
    tool = tool.substr(tool.find_last_of("/\\") + 1);
    if (tool.size() > 4 && _stricmp(tool.c_str() + tool.size() - 4, ".exe") == 0) tool.resize(tool.size() - 4);
    const bool probe = _stricmp(tool.c_str(), "ffprobe") == 0;
    if (!probe && _stricmp(tool.c_str(), "ffmpeg") != 0) {
        std::fprintf(stderr, "nnkit_cli: install as ffmpeg.exe or ffprobe.exe (got %s)\n", argv[0]);
        return 2;
    }
    _setmode(_fileno(stdout), _O_BINARY);  // the report is compared byte for byte
    HMODULE lib = LoadLibraryA("libffmpegkit.dll");
    if (!lib) { std::fprintf(stderr, "nnkit_cli: LoadLibrary failed (%lu)\n", GetLastError()); return 253; }
    auto free_fn = load<FreeFn>(lib, "ffmpegkit_free");
    load<StrategyFn>(lib, "ffmpegkit_set_log_redirection_strategy")(4);  // NeverPrintLogs

    std::vector<const char*> args(argv + 1, argv + argc);
    char* created = load<CreateFn>(lib, probe ? "ffmpegkit_create_ffprobe_session" : "ffmpegkit_create_ffmpeg_session")(
        args.data(), static_cast<int>(args.size()));
    const long id = created ? session_id(created) : -1;
    if (created) free_fn(created);
    if (id < 0) { std::fprintf(stderr, "nnkit_cli: no session\n"); return 252; }
    load<ExecuteFn>(lib, probe ? "ffmpegkit_ffprobe_execute" : "ffmpegkit_ffmpeg_execute")(id);

    char* logs = load<LogsFn>(lib, "ffmpegkit_session_get_all_logs_json")(id, kLogTimeoutMs);
    if (logs) {
        for (const LogLine& l : parse_logs(logs)) {
            std::fwrite(l.message.data(), 1, l.message.size(), l.level == kAvLogStderr ? stdout : stderr);
        }
        free_fn(logs);
    }
    std::fflush(stdout);
    return load<ReturnCodeFn>(lib, "ffmpegkit_session_get_return_code")(id);
}
