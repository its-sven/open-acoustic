#!/usr/bin/env python3
"""Render a 24-bit word dump as column bitmaps (1 word = 1 column, LSB = top) to PNG strips."""
import sys, zlib, struct
def png(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
dump, base, start, count, cols, out = sys.argv[1], int(sys.argv[2], 16), int(sys.argv[3], 16), int(sys.argv[4], 16), int(sys.argv[5]), sys.argv[6]
b = open(dump, 'rb').read()
W = [int.from_bytes(b[3*i:3*i+3], 'big') for i in range((start-base), (start-base)+count)]
strips = (len(W) + cols - 1) // cols; SH = 26
rows = []
for s in range(strips):
    seg = W[s*cols:(s+1)*cols] + [0]*(cols - len(W[s*cols:(s+1)*cols]))
    for y in range(24): rows.append([0 if (v >> y) & 1 else 255 for v in seg])
    rows.append([200]*cols); rows.append([160 if (x % 64) == 0 else 230 for x in range(cols)])
png(out, cols, len(rows), rows)
print(out, cols, 'x', len(rows))
