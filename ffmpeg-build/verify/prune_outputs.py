#!/usr/bin/env python3
"""Deletes the output files of a run_corpus.sh result that are identical (same md5) to a reference
result, so only the outputs compare.py still has to look at are kept (they are what gets shipped
back from CI).

  prune_outputs.py <reference results.tsv> <result dir>
"""
import os, sys

COLUMNS = {'wav': (5, 6, '.wav'), 'm4a': (7, 8, '.m4a'), 'pcm': (9, 10, '.pcm'), 'remux': (11, 12, '.remux.m4a')}


def load(path):
    rows = {}
    for line in open(path, encoding='utf-8'):
        p = line.rstrip('\n').split('\t')
        rows[p[0]] = p
    return rows


def main():
    ref, res = load(sys.argv[1]), sys.argv[2]
    cand = load(os.path.join(res, 'results.tsv'))
    kept = removed = kept_bytes = 0
    for name, row in cand.items():
        base = ref.get(name)
        for _, md5_col, ext in COLUMNS.values():
            f = os.path.join(res, 'files', name + ext)
            if not os.path.exists(f):
                continue
            same = base is not None and len(base) > md5_col and len(row) > md5_col and base[md5_col] == row[md5_col]
            if same:
                os.remove(f)
                removed += 1
            else:
                kept += 1
                kept_bytes += os.path.getsize(f)
    print(f'prune {os.path.basename(res)}: {removed} outputs identical to the reference removed, '
          f'{kept} kept ({kept_bytes / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
