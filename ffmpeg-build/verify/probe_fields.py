#!/usr/bin/env python3
"""Reduces ffprobe JSON to the facts NiceNote reads (mirrors lib/audio/probe/audio_probe.dart
AudioProbe.parse), plus the number of real video streams (cover art excluded), which decides
whether an import is rejected as video."""
import json, sys

try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print('PARSE_FAIL')
    sys.exit()
streams = d.get('streams', [])
video = sum(1 for s in streams if s.get('codec_type') == 'video'
            and not s.get('disposition', {}).get('attached_pic'))
a = next((s for s in streams if s.get('codec_type') == 'audio'), None)
if a is None:
    print(f'NO_AUDIO video={video}')
    sys.exit()
f = d.get('format', {})


def num(v):
    try:
        return float(v)
    except Exception:
        return None


def title(t):
    if not isinstance(t, dict):
        return None
    for k, v in t.items():
        if k.lower() == 'title' and str(v).strip():
            return v
    return None


sec = num(f.get('duration')) or num(a.get('duration')) or 0
print('dur=%d sr=%s ch=%s br=%s fmt=%s codec=%s title=%s video=%d' % (
    round(sec * 1000), a.get('sample_rate'), a.get('channels'), a.get('bit_rate') or f.get('bit_rate'),
    f.get('format_name'), a.get('codec_name'), title(f.get('tags')) or title(a.get('tags')), video))
