#!/usr/bin/env python3
"""Checks the Apple frameworks produced by build_apple.sh.

  check_apple_libs.py --ios <ios/Frameworks> --macos <macos/Frameworks>
                      --base-ios <dir of v1.1.0 iOS .frameworks> --base-macos <v1.1.0 macos/Frameworks>

For every framework and every architecture slice:
  * slices: iOS xcframework = device arm64 + simulator arm64/x86_64 (arm64 simulator built natively,
    no arm64e); macOS = arm64 + x86_64
  * LC_BUILD_VERSION platform and minimum OS (as v1.1.0: iOS 12.1, macOS 10.15; arm64 macOS 11.0,
    arm64 simulator 14.0); no bitcode
  * install name @rpath/<name>.framework/<name>; dependencies only system libraries and the eight
    frameworks; every symbol imported from one of the eight is exported by it (same arch)
  * API: exports identical to v1.1.0 (ffmpegkit: all symbols; FFmpeg libraries: all except the
    internal avpriv_* cross-library symbols, whose differences are listed), and identical headers
  * macOS: the compiled-in configure line carries the NiceNote component flags; code signature valid
Runs on macOS (xcrun) or Linux (LLVM tools: --llvm-bin <dir>, no signature check).
"""
import argparse, os, plistlib, re, subprocess, sys

FRAMEWORKS = ['ffmpegkit', 'libavcodec', 'libavdevice', 'libavfilter', 'libavformat', 'libavutil',
              'libswresample', 'libswscale']
PLATFORMS = {'1': 'macos', '2': 'ios', '7': 'iossimulator'}
# upstream deployment targets (unchanged from v1.1.0); clang raises arm64 macOS to 11.0 and the arm64
# simulator to 14.0, the first releases of those platforms
MIN_OS = {'macos': '10.15', 'ios': '12.1', 'iossimulator': '12.1'}
MIN_OS_ARCH = {('macos', 'arm64'): '11.0', ('iossimulator', 'arm64'): '14.0'}
SYSTEM_PREFIXES = ('/usr/lib/', '/System/Library/Frameworks/')

problems, notes = [], []


class Tools:
    def __init__(self, llvm_bin):
        if llvm_bin:
            b = lambda n: [os.path.join(llvm_bin, n)]
            self.nm_cmd, self.lipo, self.objdump = b('llvm-nm'), b('llvm-lipo'), b('llvm-objdump') + ['--macho']
            self.codesign = None
        else:
            self.nm_cmd, self.lipo, self.objdump = ['xcrun', 'nm'], ['xcrun', 'lipo'], ['xcrun', 'otool']
            self.codesign = ['codesign']
        self.darwin = not llvm_bin

    def run(self, cmd):
        return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout

    def archs(self, binary):
        return sorted(self.run(self.lipo + ['-archs', binary]).split())

    def load_commands(self, binary, arch):
        flag = '-l' if self.darwin else '--private-headers'
        return self.run(self.objdump + [flag, '-arch' if self.darwin else f'--arch={arch}'] +
                        ([arch] if self.darwin else []) + [binary])

    def dylibs(self, binary, arch):
        flag = '-L' if self.darwin else '--dylibs-used'
        out = self.run(self.objdump + [flag, '-arch' if self.darwin else f'--arch={arch}'] +
                       ([arch] if self.darwin else []) + [binary])
        return [l.strip().split(' (compatibility')[0] for l in out.splitlines()[1:] if l.strip()]

    def nm(self, binary, arch, *flags):
        return self.run(self.nm_cmd + list(flags) + ['-arch' if self.darwin else f'--arch={arch}'] +
                        ([arch] if self.darwin else []) + [binary])


def exports(t, binary, arch):
    # "  T _name"  or re-exported "  I _name (indirect for _name)"
    return {l.split(' (indirect')[0].split()[-1] for l in t.nm(binary, arch, '-gU').splitlines() if l.strip()}


def imports(t, binary, arch):
    """symbol -> library leaf name, from two-level namespace binding."""
    out = {}
    for l in t.nm(binary, arch, '-m').splitlines():
        m = re.search(r'\(undefined\) (?:weak )?\w+ (\S+) \(from (\S+)\)', l)
        if m:
            out[m.group(1)] = m.group(2)
        elif '(undefined)' in l and not re.search(r'_objc_msgSend\w* \(dynamically looked up\)', l):
            problems.append(f'{binary} [{arch}]: import without library: {l.strip()}')
    return out


def build_version(text):
    """(platform, minos) of the first LC_BUILD_VERSION."""
    m = re.search(r'cmd LC_BUILD_VERSION.*?platform (\S+).*?minos (\S+)', text, re.S)
    if not m:
        return None, None
    # otool versions print the platform as a number, a name, or PLATFORM_NAME
    p = m.group(1).lower().replace('_', '').replace('-', '').removeprefix('platform')
    return PLATFORMS.get(p, p), m.group(2)


def binary_of(fw_dir, name):
    for p in (os.path.join(fw_dir, name), os.path.join(fw_dir, 'Versions', 'A', name)):
        if os.path.isfile(p):
            return os.path.realpath(p)
    return None


def headers_of(fw_dir):
    h = os.path.join(fw_dir, 'Headers')
    out = {}
    for root, _, files in os.walk(h, followlinks=True):
        for f in files:
            p = os.path.join(root, f)
            out[os.path.relpath(p, h)] = open(p, 'rb').read()
    return out


def check_slice(t, label, fw_dirs, platform, archs, base_dirs, base_arch):
    """fw_dirs/base_dirs: name -> framework directory. base_arch: arch -> arch in the baseline."""
    exp = {}
    for name in FRAMEWORKS:
        b = binary_of(fw_dirs[name], name)
        if not b:
            problems.append(f'{label}/{name}: binary missing')
            continue
        got = t.archs(b)
        if got != sorted(archs):
            problems.append(f'{label}/{name}: architectures {got}, expected {sorted(archs)}')
        for a in archs:
            exp[(name, a)] = exports(t, b, a)
    for name in FRAMEWORKS:
        b = binary_of(fw_dirs[name], name)
        if not b:
            continue
        base_b = binary_of(base_dirs[name], name)
        for a in archs:
            lc = t.load_commands(b, a)
            plat, minos = build_version(lc)
            want_min = MIN_OS_ARCH.get((platform, a), MIN_OS[platform])
            if plat != platform or minos != want_min:
                problems.append(f'{label}/{name} [{a}]: platform {plat} minos {minos}, expected {platform} {want_min}')
            if 'segname __LLVM' in lc:
                problems.append(f'{label}/{name} [{a}]: contains bitcode (__LLVM segment)')
            libs = t.dylibs(b, a)
            if not libs or libs[0] != f'@rpath/{name}.framework/{name}':
                problems.append(f'{label}/{name} [{a}]: install name {libs[:1]}')
            for lib in libs[1:]:
                m = re.fullmatch(r'@rpath/(\w+)\.framework/(\w+)', lib)
                if lib.startswith(SYSTEM_PREFIXES) or (m and m.group(1) == m.group(2) and m.group(1) in FRAMEWORKS):
                    continue
                problems.append(f'{label}/{name} [{a}]: unexpected dependency {lib}')
            missing = [f'{s} (from {lib})' for s, lib in imports(t, b, a).items()
                       if lib in FRAMEWORKS and s not in exp.get((lib, a), set())]
            if missing:
                problems.append(f'{label}/{name} [{a}]: {len(missing)} unresolved imports: {missing[:5]}')
            # API against v1.1.0
            ba = base_arch.get(a)
            if base_b and ba:
                base_exp = exports(t, base_b, ba)
                new_exp = exp[(name, a)]
                internal = (lambda s: s.startswith('_avpriv_')) if name != 'ffmpegkit' else (lambda s: False)
                lost = sorted(s for s in base_exp - new_exp if not internal(s))
                added = sorted(s for s in new_exp - base_exp if not internal(s))
                if lost or added:
                    problems.append(f'{label}/{name} [{a}]: exports differ from v1.1.0: '
                                    f'missing {lost[:8]}{"…" if len(lost) > 8 else ""} '
                                    f'added {added[:8]}{"…" if len(added) > 8 else ""}')
                gone = sorted(s for s in base_exp - new_exp if internal(s))
                if gone and a == archs[0]:
                    notes.append(f'{label}/{name}: internal avpriv_ exports no longer built: {" ".join(gone)}')
                old_deps = set(t.dylibs(base_b, ba)[1:])
                if old_deps != set(libs[1:]) and a == archs[0]:
                    notes.append(f'{label}/{name}: dependencies vs v1.1.0: '
                                 f'-{sorted(old_deps - set(libs[1:]))} +{sorted(set(libs[1:]) - old_deps)}')
        if base_dirs.get(name) and headers_of(fw_dirs[name]) != headers_of(base_dirs[name]):
            a_h, b_h = headers_of(fw_dirs[name]), headers_of(base_dirs[name])
            diff = sorted(k for k in set(a_h) | set(b_h) if a_h.get(k) != b_h.get(k))
            problems.append(f'{label}/{name}: headers differ from v1.1.0: {diff[:10]}')


def configure_line_ok(t, fw_dirs, arch):
    """The configure line compiled into libavutil must carry our component flags."""
    b = binary_of(fw_dirs['libavutil'], 'libavutil')
    data = open(b, 'rb').read()
    lines = re.findall(rb'--cross-prefix=[^\x00]*', data)
    return lines and all(b'--disable-everything' in l and b'--enable-decoder=' in l for l in lines), len(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ios', required=True)
    ap.add_argument('--macos', required=True)
    ap.add_argument('--base-ios', required=True)
    ap.add_argument('--base-macos', required=True)
    ap.add_argument('--llvm-bin')
    o = ap.parse_args()
    t = Tools(o.llvm_bin)
    base_ios = {n: os.path.join(o.base_ios, f'{n}.framework') for n in FRAMEWORKS}
    base_macos = {n: os.path.join(o.base_macos, f'{n}.framework') for n in FRAMEWORKS}

    # iOS: one xcframework per library, two slices each
    want = {'ios-arm64': (['arm64'], ''), 'ios-arm64_x86_64-simulator': (['arm64', 'x86_64'], 'simulator')}
    slices = {}
    for name in FRAMEWORKS:
        xc = os.path.join(o.ios, f'{name}.xcframework')
        try:
            info = plistlib.load(open(os.path.join(xc, 'Info.plist'), 'rb'))
        except OSError:
            problems.append(f'ios/{name}.xcframework: missing')
            continue
        got = {l['LibraryIdentifier']: (sorted(l['SupportedArchitectures']), l.get('SupportedPlatformVariant', ''))
               for l in info['AvailableLibraries'] if l.get('SupportedPlatform') == 'ios'}
        if got != want or len(info['AvailableLibraries']) != 2:
            problems.append(f'ios/{name}.xcframework: slices {got}, expected {want}')
        for lid in want:
            slices.setdefault(lid, {})[name] = os.path.join(xc, lid, f'{name}.framework')
    if len(slices) == 2 and all(len(v) == len(FRAMEWORKS) for v in slices.values()):
        check_slice(t, 'ios-device', slices['ios-arm64'], 'ios', ['arm64'], base_ios, {'arm64': 'arm64'})
        # v1.1.0 had no real arm64 simulator slice (it was the device slice retagged), so compare to that
        check_slice(t, 'ios-simulator', slices['ios-arm64_x86_64-simulator'], 'iossimulator', ['arm64', 'x86_64'],
                    base_ios, {'arm64': 'arm64', 'x86_64': 'x86_64'})
    mac = {n: os.path.join(o.macos, f'{n}.framework') for n in FRAMEWORKS}
    check_slice(t, 'macos', mac, 'macos', ['arm64', 'x86_64'], base_macos, {'arm64': 'arm64', 'x86_64': 'x86_64'})

    for label, dirs, arch in (('ios-device', slices.get('ios-arm64'), 'arm64'), ('macos', mac, 'arm64')):
        if dirs:
            ok, n = configure_line_ok(t, dirs, arch)
            if not ok:
                problems.append(f'{label}: configure line without the NiceNote component flags ({n} found)')
    if t.codesign:
        for name in FRAMEWORKS:
            r = subprocess.run(t.codesign + ['--verify', '--strict', mac[name]], capture_output=True, text=True)
            if r.returncode:
                problems.append(f'macos/{name}: code signature: {r.stderr.strip()}')

    for n in notes:
        print('  note:', n)
    for p in problems:
        print('  PROBLEM', p)
    print(f'check_apple_libs: {len(FRAMEWORKS)} frameworks x (iOS device, iOS simulator, macOS): '
          + ('OK' if not problems else f'{len(problems)} problems'))
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
