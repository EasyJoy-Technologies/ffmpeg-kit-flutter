#!/usr/bin/env python3
"""Checks the native libraries of a new Android build against the published 2.2.1 AAR.

For every ABI:
  * file set     = what the app actually loads from 2.2.1 (armeabi-v7a: the NEON set only)
  * ELF machine  matches the ABI
  * DT_NEEDED    only our own libraries or NDK system libraries, and no more than 2.2.1 needed
  * symbols      every undefined (non-weak) symbol is defined by a library in the DT_NEEDED list
  * JNI          the exported Java_* / JNI_OnLoad set is identical to 2.2.1, and every native
                 method declared in 2.2.1's classes.jar has an implementation
  * alignment    PT_LOAD segments aligned to 16 KB on arm64-v8a (Android 15+ 16 KB pages)
  * flags        libavutil's embedded configure line contains the NiceNote component flags
Exits non-zero on the first ABI that fails; prints a size table at the end.
"""
import argparse, os, re, subprocess, sys, tempfile, zipfile

MACHINE = {'arm64-v8a': 'AArch64', 'armeabi-v7a': 'ARM'}
TRIPLE = {'arm64-v8a': 'aarch64-linux-android', 'armeabi-v7a': 'arm-linux-androideabi'}
# NDK system libraries (API 24+). The upstream script links camera2ndk/mediandk into every FFmpeg library.
SYSTEM_LIBS = {'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libz.so', 'libandroid.so', 'libmediandk.so', 'libcamera2ndk.so'}


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


class Tools:
    def __init__(self, ndk, api):
        self.bin = os.path.join(ndk, 'toolchains/llvm/prebuilt/linux-x86_64/bin')
        self.sysroot = os.path.join(ndk, 'toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib')
        self.api = api

    def tool(self, name):
        return os.path.join(self.bin, name)

    def needed(self, so):
        out = run(self.tool('llvm-readelf'), '-d', so)
        return set(re.findall(r'\(NEEDED\)\s+Shared library: \[([^\]]+)\]', out))

    def machine(self, so):
        return re.search(r'Machine:\s+(.*)', run(self.tool('llvm-readelf'), '-h', so)).group(1).strip()

    def load_aligns(self, so):
        out = run(self.tool('llvm-readelf'), '-lW', so)
        return [int(m, 16) for m in re.findall(r'^\s+LOAD\s+(?:\S+\s+){5}\S+\s+(0x[0-9a-f]+)', out, re.M)]

    def defined(self, so):
        out = run(self.tool('llvm-nm'), '-D', '--defined-only', '--format=just-symbols', so)
        return {s.split('@')[0] for s in out.split()}

    def undefined_strong(self, so):
        out = run(self.tool('llvm-nm'), '-D', '--undefined-only', so)
        syms = set()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[-2] == 'U':
                syms.add(parts[-1].split('@')[0])
        return syms

    def system_lib(self, abi, name):
        return os.path.join(self.sysroot, TRIPLE[abi], str(self.api), name)


def loaded_set(base_names, abi):
    if abi == 'armeabi-v7a':
        return {n for n in base_names if 'neon' in n or n == 'libffmpegkit_abidetect.so'}
    return set(base_names)


def native_methods(classes_jar):
    with tempfile.TemporaryDirectory() as d:
        with zipfile.ZipFile(classes_jar) as z:
            z.extractall(d)
        classes = []
        for root, _, files in os.walk(d):
            classes += [os.path.join(root, f) for f in files if f.endswith('.class')]
        out = run('javap', '-p', *classes)
    methods, cls = set(), None
    for line in out.splitlines():
        m = re.match(r'.*\b(?:class|interface|enum)\s+([\w.$]+)', line)
        if m and line.rstrip().endswith('{'):
            cls = m.group(1)
            continue
        m = re.search(r'\bnative\b.*\s(\w+)\(', line)
        if m and cls:
            methods.add('Java_' + cls.replace('_', '_1').replace('.', '_').replace('$', '_00024') + '_' + m.group(1).replace('_', '_1'))
    return methods


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ndk', required=True)
    ap.add_argument('--api', type=int, required=True)
    ap.add_argument('--base-aar', required=True)
    ap.add_argument('--libs', required=True)
    ap.add_argument('abis', nargs='+')
    a = ap.parse_args()
    t = Tools(a.ndk, a.api)
    fail = []
    rows = []
    with tempfile.TemporaryDirectory() as base:
        with zipfile.ZipFile(a.base_aar) as z:
            z.extractall(base)
        natives = native_methods(os.path.join(base, 'classes.jar'))
        for abi in a.abis:
            bdir, ndir = os.path.join(base, 'jni', abi), os.path.join(a.libs, abi)
            expect = loaded_set(os.listdir(bdir), abi)
            have = {f for f in os.listdir(ndir) if f.endswith('.so')}
            if have != expect:
                fail.append(f'{abi}: files differ: missing {sorted(expect - have)} extra {sorted(have - expect)}')
                continue
            ours = {n: os.path.join(ndir, n) for n in have}
            jni_new, jni_old = set(), set()
            for name, so in sorted(ours.items()):
                if t.machine(so) != MACHINE[abi]:
                    fail.append(f'{abi}/{name}: machine {t.machine(so)}')
                need = t.needed(so)
                bad = {n for n in need if n not in ours and n not in SYSTEM_LIBS}
                if bad:
                    fail.append(f'{abi}/{name}: unexpected DT_NEEDED {sorted(bad)}')
                grown = need - t.needed(os.path.join(bdir, name))
                if grown:
                    fail.append(f'{abi}/{name}: DT_NEEDED not in 2.2.1: {sorted(grown)}')
                provided = set()
                for n in need:
                    provided |= t.defined(ours[n] if n in ours else t.system_lib(abi, n))
                missing = t.undefined_strong(so) - provided
                if missing:
                    fail.append(f'{abi}/{name}: {len(missing)} unresolved symbols, e.g. {sorted(missing)[:8]}')
                if abi == 'arm64-v8a' and min(t.load_aligns(so)) < 0x4000:
                    fail.append(f'{abi}/{name}: PT_LOAD alignment {hex(min(t.load_aligns(so)))} < 16 KB')
                jni_new |= {s for s in t.defined(so) if s.startswith('Java_') or s == 'JNI_OnLoad'}
                jni_old |= {s for s in t.defined(os.path.join(bdir, name)) if s.startswith('Java_') or s == 'JNI_OnLoad'}
                rows.append((abi, name, os.path.getsize(os.path.join(bdir, name)), os.path.getsize(so)))
            if jni_new != jni_old:
                fail.append(f'{abi}: JNI exports differ: missing {sorted(jni_old - jni_new)} extra {sorted(jni_new - jni_old)}')
            unimpl = {m for m in natives if not any(s == m or s.startswith(m + '__') for s in jni_new)}
            if unimpl:
                fail.append(f'{abi}: native methods without implementation: {sorted(unimpl)}')
            avutil = next(p for n, p in ours.items() if n.startswith('libavutil'))
            conf = run('strings', avutil).replace("'", '')  # configure quotes comma lists
            for flag in ('--disable-everything', '--disable-network', '--enable-protocol=file,pipe,fd,saf'):
                if flag not in conf:
                    fail.append(f'{abi}: libavutil configure line lacks {flag}')
            print(f'{abi}: {len(ours)} libraries, {len(jni_new)} JNI exports, {len(natives)} native methods checked')
    print('\n| ABI | library | 2.2.1 bytes | new bytes |')
    print('|---|---|---:|---:|')
    tot = {}
    for abi, name, old, new in rows:
        print(f'| {abi} | {name} | {old:,} | {new:,} |')
        o, n = tot.get(abi, (0, 0))
        tot[abi] = (o + old, n + new)
    for abi, (o, n) in tot.items():
        print(f'| {abi} | **total** | {o:,} | {n:,} |')
    if fail:
        print('\nFAILED:\n  ' + '\n  '.join(fail))
        sys.exit(1)
    print('\nnative library checks OK')


if __name__ == '__main__':
    main()
