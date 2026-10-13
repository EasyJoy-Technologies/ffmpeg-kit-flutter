#!/usr/bin/env python3
"""Compares two run_corpus.sh result directories.

  compare.py exact <reference> <candidate>
      Same machine, same compiler: everything must be identical (exit codes, probe facts,
      duration scan, every output byte). Used for "full build" vs "trimmed build", which is the
      check that the component list changes nothing.

  compare.py arch <reference> <candidate>
      Different CPU: host C code vs Android NEON/assembly under qemu. Uses the tolerances of
      FFmpeg's own test suite (FATE), because ARM and x86 round floating point differently
      (arm64 also fuses multiply-adds):
        * exit codes, probe facts, duration scan and the ADTS remux: identical
        * pcm (decode at the source rate): byte-identical for integer decoders; for floating-point
          decoders the same sample count and a standard deviation of the difference <= FUZZ
          (FATE uses CMP=stddev with FUZZ 3 for wmavoice and similar)
        * wav (16 kHz mono): always goes through the float resampler, so the stddev rule applies
          to every codec
        * m4a (AAC encode): same exit code, size within 3 %
      Files recorded as SKIPPED in either run are listed and not compared.
"""
import os, re, sys

import numpy as np

FUZZ = 3.0  # stddev of the difference, in 16-bit LSBs
# Decoders that are pure integer arithmetic: their pcm output must be bit-exact on every CPU.
EXACT_PREFIXES = ('pcm_', 'adpcm_', 'flac', 'alac', 'ape', 'wavpack', 'tta', 'tak', 'shorten', 'mlp',
                  'truehd', 'mp4als', 'g722', 'g726', 'gsm', 'dfpwm', 'aptx', 'sbc', 'qoa')


def load(d):
    rows = {}
    with open(os.path.join(d, 'results.tsv'), encoding='utf-8') as f:
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) < 13:
                rows[p[0]] = p[1] if len(p) > 1 else 'BROKEN'
                continue
            rows[p[0]] = {'probe': p[1:3], 'scan': p[3:5], 'wav': p[5:7], 'm4a': p[7:9],
                          'pcm': p[9:11], 'remux': p[11:13]}
    return rows


def codec_of(probe_facts):
    m = re.search(r'codec=(\S+)', probe_facts)
    return m.group(1) if m else ''


def samples(path):
    data = open(path, 'rb').read()
    if path.endswith('.wav'):
        data = data[data.find(b'data') + 8:]
    return np.frombuffer(data, dtype='<i2', count=len(data) // 2).astype(np.float64)


def pcm_diff(a, b):
    """(same_length, max_abs_diff, stddev_of_diff) of two s16 outputs."""
    xa, xb = samples(a), samples(b)
    if len(xa) != len(xb):
        return False, None, None
    if not len(xa):
        return True, 0, 0.0
    d = xa - xb
    return True, int(np.abs(d).max()), float(np.sqrt((d * d).mean()))


def main():
    mode, ref, cand = sys.argv[1], sys.argv[2], sys.argv[3]
    r, c = load(ref), load(cand)
    problems, tolerated, skipped = [], [], []
    if set(r) != set(c):
        problems.append(f'file sets differ: {sorted(set(r) ^ set(c))}')
    worst = 0.0
    for name in sorted(set(r) & set(c)):
        a, b = r[name], c[name]
        if a == 'SKIPPED' or b == 'SKIPPED':
            skipped.append(name)
            continue
        if not isinstance(a, dict) or not isinstance(b, dict):
            problems.append(f'{name}: incomplete result ({a if isinstance(a, str) else b})')
            continue
        if mode == 'exact':
            if a != b:
                problems.append(f'{name}: ' + ', '.join(f'{k} {a[k]} != {b[k]}' for k in a if a[k] != b[k]))
            continue
        for k in ('probe', 'scan', 'remux'):
            if a[k] != b[k]:
                problems.append(f'{name}: {k} {a[k]} != {b[k]}')
        codec = codec_of(a['probe'][1])
        exact = codec.startswith(EXACT_PREFIXES)
        for k, ext in (('wav', '.wav'), ('pcm', '.pcm')):
            if a[k][0] != b[k][0]:
                problems.append(f'{name}: {k} exit {a[k][0]} != {b[k][0]}')
                continue
            if a[k][1] == b[k][1]:
                continue
            if k == 'pcm' and exact:
                problems.append(f'{name}: pcm differs for integer decoder {codec}')
                continue
            same_len, mx, sd = pcm_diff(os.path.join(ref, 'files', name + ext), os.path.join(cand, 'files', name + ext))
            if not same_len or sd > FUZZ:
                problems.append(f'{name}: {k} differs (codec {codec}, same length {same_len}, stddev {sd}, max {mx})')
            else:
                worst = max(worst, sd)
                tolerated.append(f'{name}: {k} stddev {sd:.3f} max {mx} ({codec})')
        if a['m4a'][0] != b['m4a'][0]:
            problems.append(f'{name}: m4a exit {a["m4a"][0]} != {b["m4a"][0]}')
        elif a['m4a'][1] != b['m4a'][1]:
            sa = os.path.getsize(os.path.join(ref, 'files', name + '.m4a'))
            sb = os.path.getsize(os.path.join(cand, 'files', name + '.m4a'))
            if abs(sa - sb) > 0.03 * max(sa, sb):
                problems.append(f'{name}: m4a size {sa} vs {sb}')
    compared = len(set(r) & set(c)) - len(skipped)
    print(f'{mode} {os.path.basename(ref)} vs {os.path.basename(cand)}: {compared} files compared, '
          f'{len(problems)} problems' + (f', {len(tolerated)} float differences within stddev {FUZZ} '
          f'(worst {worst:.3f})' if mode == 'arch' else '') + (f', skipped: {", ".join(skipped)}' if skipped else ''))
    for p in problems:
        print('  PROBLEM', p)
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
