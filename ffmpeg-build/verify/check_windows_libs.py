#!/usr/bin/env python3
"""Checks the Windows bundle produced by build_windows.sh (pure Python PE reader, runs anywhere).

  check_windows_libs.py --bundle <dir with bin/ include/> --base <v1.1.0 bundle dir>

  * bin/ holds exactly the eight DLLs of v1.1.0's bundle minus the MinGW runtime and the codec /
    hardware libraries NiceNote does not use (zlib, bzip2, lzma, iconv, libva); same DLL names
  * every DLL is x86-64 and imports only Windows system DLLs and DLLs of the bundle; every symbol
    imported from a bundle DLL is exported by it
  * exports identical to v1.1.0: libffmpegkit.dll (the C API the plugin loads) completely, the
    FFmpeg DLLs except the internal avpriv_* cross-library symbols (differences are listed)
  * include/ identical to v1.1.0; avutil reports "FFmpeg version n8.1.2"
"""
import argparse, os, struct, sys

BUNDLE = ['avcodec-62.dll', 'avdevice-62.dll', 'avfilter-11.dll', 'avformat-62.dll', 'avutil-60.dll',
          'swresample-6.dll', 'swscale-9.dll', 'libffmpegkit.dll']
# Windows system DLLs the libraries may import (lower case). Everything else must come from BUNDLE.
SYSTEM = {'kernel32.dll', 'msvcrt.dll', 'user32.dll', 'gdi32.dll', 'ole32.dll', 'oleaut32.dll',
          'shlwapi.dll', 'shell32.dll', 'advapi32.dll', 'avicap32.dll', 'bcrypt.dll', 'crypt32.dll',
          'ncrypt.dll', 'secur32.dll', 'ws2_32.dll', 'psapi.dll', 'winmm.dll'}

problems, notes = [], []


class PE:
    def __init__(self, path):
        self.path = path
        self.data = open(path, 'rb').read()
        d = self.data
        if d[:2] != b'MZ':
            raise ValueError(f'{path}: not a PE file')
        pe = struct.unpack_from('<I', d, 0x3c)[0]
        if d[pe:pe + 4] != b'PE\0\0':
            raise ValueError(f'{path}: no PE signature')
        self.machine, nsec = struct.unpack_from('<HH', d, pe + 4)
        opt_size = struct.unpack_from('<H', d, pe + 20)[0]
        opt = pe + 24
        magic = struct.unpack_from('<H', d, opt)[0]
        if magic != 0x20b:
            raise ValueError(f'{path}: not PE32+')
        self.dll_characteristics = struct.unpack_from('<H', d, opt + 70)[0]
        ndirs = struct.unpack_from('<I', d, opt + 108)[0]
        self.dirs = [struct.unpack_from('<II', d, opt + 112 + 8 * i) for i in range(ndirs)]
        self.sections = []
        for i in range(nsec):
            s = opt + opt_size + 40 * i
            vsize, va, rawsize, rawptr = struct.unpack_from('<IIII', d, s + 8)
            self.sections.append((va, max(vsize, rawsize), rawptr))

    def off(self, rva):
        for va, size, raw in self.sections:
            if va <= rva < va + size:
                return raw + rva - va
        raise ValueError(f'{self.path}: rva {rva:#x} outside sections')

    def cstr(self, rva):
        o = self.off(rva)
        return self.data[o:self.data.index(b'\0', o)].decode('latin-1')

    def exports(self):
        rva, size = self.dirs[0]
        if not rva:
            return set()
        o = self.off(rva)
        n_names, names_rva = struct.unpack_from('<I', self.data, o + 24)[0], struct.unpack_from('<I', self.data, o + 32)[0]
        no = self.off(names_rva)
        return {self.cstr(struct.unpack_from('<I', self.data, no + 4 * i)[0]) for i in range(n_names)}

    def _thunks(self, rva):
        out, o = [], self.off(rva)
        while True:
            t = struct.unpack_from('<Q', self.data, o)[0]
            if not t:
                return out
            out.append(None if t >> 63 else self.cstr((t & 0x7fffffff) + 2))  # skip the hint
            o += 8

    def imports(self):
        """{dll name: [symbol or None for by-ordinal]}, including delay-load imports."""
        out = {}
        rva = self.dirs[1][0]
        if rva:
            o = self.off(rva)
            while True:
                ilt, _, _, name, iat = struct.unpack_from('<IIIII', self.data, o)
                if not name:
                    break
                out.setdefault(self.cstr(name), []).extend(self._thunks(ilt or iat))
                o += 20
        if len(self.dirs) > 13 and self.dirs[13][0]:
            o = self.off(self.dirs[13][0])
            while True:
                attrs, name, _, _, int_rva = struct.unpack_from('<IIIII', self.data, o)[:5]
                if not name:
                    break
                out.setdefault(self.cstr(name), []).extend(self._thunks(int_rva))
                o += 32
        return out


def tree(root):
    out = {}
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f)
            out[os.path.relpath(p, root).replace(os.sep, '/')] = open(p, 'rb').read()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--base', required=True)
    o = ap.parse_args()
    bin_new, bin_base = os.path.join(o.bundle, 'bin'), os.path.join(o.base, 'bin')

    dlls = sorted(f for f in os.listdir(bin_new) if f.lower().endswith('.dll'))
    if dlls != sorted(BUNDLE):
        problems.append(f'bin/ DLLs {dlls}, expected {sorted(BUNDLE)}')
    base_dlls = sorted(f for f in os.listdir(bin_base) if f.lower().endswith('.dll'))
    notes.append(f'DLLs no longer shipped: {" ".join(sorted(set(base_dlls) - set(dlls)))}')
    others = sorted(f for f in os.listdir(bin_new) if not f.lower().endswith('.dll'))
    base_others = sorted(f for f in os.listdir(bin_base) if not f.lower().endswith('.dll'))
    if others != base_others:
        notes.append(f'other files in bin/: {others} (v1.1.0: {base_others})')

    pes = {}
    for f in dlls:
        try:
            pes[f] = PE(os.path.join(bin_new, f))
        except ValueError as e:
            problems.append(str(e))
    exports = {f.lower(): pe.exports() for f, pe in pes.items()}
    for f, pe in sorted(pes.items()):
        if pe.machine != 0x8664:
            problems.append(f'{f}: machine {pe.machine:#x}, expected x86-64')
        for dll, syms in sorted(pe.imports().items()):
            low = dll.lower()
            if low in exports:
                missing = sorted(s for s in syms if s and s not in exports[low])
                if missing:
                    problems.append(f'{f}: {len(missing)} imports not exported by {dll}: {missing[:5]}')
            elif low not in SYSTEM:
                problems.append(f'{f}: imports {dll}, which is neither a system DLL nor in the bundle')
        base_path = os.path.join(bin_base, f)
        if os.path.exists(base_path):
            base_exp = PE(base_path).exports()
            new_exp = pe.exports()
            internal = (lambda s: False) if f == 'libffmpegkit.dll' else (lambda s: s.startswith('avpriv_'))
            lost = sorted(s for s in base_exp - new_exp if not internal(s))
            added = sorted(s for s in new_exp - base_exp if not internal(s))
            if lost or added:
                problems.append(f'{f}: exports differ from v1.1.0: missing {lost[:8]}{"…" if len(lost) > 8 else ""}'
                                f' added {added[:8]}{"…" if len(added) > 8 else ""}')
            gone = sorted(s for s in base_exp - new_exp if internal(s))
            if gone:
                notes.append(f'{f}: internal avpriv_ exports no longer built: {" ".join(gone)}')
            old_imp = {d.lower() for d in PE(base_path).imports()}
            new_imp = {d.lower() for d in pe.imports()}
            if old_imp != new_imp:
                notes.append(f'{f}: imports vs v1.1.0: -{sorted(old_imp - new_imp)} +{sorted(new_imp - old_imp)}')

    if 'avutil-60.dll' in pes and b'FFmpeg version n8.1.2\0' not in pes['avutil-60.dll'].data:
        problems.append('avutil-60.dll: version string is not "FFmpeg version n8.1.2"')
    inc_new, inc_base = tree(os.path.join(o.bundle, 'include')), tree(os.path.join(o.base, 'include'))
    if inc_new != inc_base:
        diff = sorted(k for k in set(inc_new) | set(inc_base) if inc_new.get(k) != inc_base.get(k))
        problems.append(f'include/ differs from v1.1.0: {diff[:10]}')

    for n in notes:
        print('  note:', n)
    for p in problems:
        print('  PROBLEM', p)
    print(f'check_windows_libs: {len(pes)} DLLs: ' + ('OK' if not problems else f'{len(problems)} problems'))
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
