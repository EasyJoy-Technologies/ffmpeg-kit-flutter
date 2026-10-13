#!/usr/bin/env python3
"""Synthetic samples ffmpeg cannot write itself: a DSF (DSD64) file, and the FLAC picture block used
for Ogg cover art (--picture-block <jpeg>)."""
import base64, math, os, struct, sys


def dsf(path, seconds=1, rate=2822400, channels=2, block=4096):
    n = rate * seconds                      # 1-bit samples per channel
    per_ch = bytearray(-(-n // 8 // block) * block)
    acc = 0.0                               # first-order sigma-delta of a 1 kHz sine
    for i in range(n):
        x = 0.5 * math.sin(2 * math.pi * 1000 * i / rate)
        bit = 1 if acc + x >= 0 else 0
        acc += x - (1.0 if bit else -1.0)
        if bit:
            per_ch[i >> 3] |= 1 << (i & 7)  # DSF stores LSB first
    data = bytearray()
    for b in range(0, len(per_ch), block):
        for _ in range(channels):
            data += per_ch[b:b + block]
    fmt = struct.pack('<4sQIIIIIIQII', b'fmt ', 52, 1, 0, 2, channels, rate, 1, n, block, 0)
    body = fmt + struct.pack('<4sQ', b'data', 12 + len(data)) + data
    head = struct.pack('<4sQQQ', b'DSD ', 28, 28 + len(body), 0)
    with open(path, 'wb') as f:
        f.write(head + body)


def picture_block(jpg):
    """Base64 FLAC METADATA_BLOCK_PICTURE (front cover) for a JPEG of 300x300."""
    data = open(jpg, 'rb').read()
    mime, desc = b'image/jpeg', b'cover'
    blk = struct.pack('>II', 3, len(mime)) + mime + struct.pack('>I', len(desc)) + desc
    blk += struct.pack('>IIIII', 300, 300, 24, 0, len(data)) + data
    return base64.b64encode(blk).decode('ascii')


if sys.argv[1] == '--picture-block':
    print(picture_block(sys.argv[2]))
else:
    dsf(os.path.join(sys.argv[1], 'a_dsd64.dsf'))
