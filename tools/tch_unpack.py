#!/usr/bin/env python3
"""Correct unpacker for TC-Helicon Play-series firmware .syx (read-only analysis).
Message:  F0 00 01 38 00 60 <type> ... F7
  type 0x51: bootloader enter/exit marker
  type 0x52: <sub> <8-in-7 packed payload>
     sub 0x00 = data, 0x02 = section separator (27 zero bytes), 0x01 = end
Packing: groups of [flag, d0..d6]; bit (6-k) of flag is bit7 of d_k  (MSB-first).
Output: one file per contiguous run of sub-0x00 data between separators."""
import sys, os, hashlib
src, outdir = sys.argv[1], sys.argv[2]
syx = open(src, 'rb').read()
msgs = []; i = 0
while i < len(syx):
    j = syx.index(0xF7, i); msgs.append(syx[i:j+1]); i = j + 1
def un(p):
    out = bytearray()
    for g in range(0, len(p), 8):
        f = p[g]
        for k, b in enumerate(p[g+1:g+8]): out.append(b | (((f >> (6 - k)) & 1) << 7))
    return bytes(out)
secs = []; cur = None
for m in msgs:
    if m[6] == 0x52 and m[7] == 0:
        if cur is None: cur = bytearray(); secs.append(cur)
        cur += un(m[8:-1])
    else: cur = None
os.makedirs(outdir, exist_ok=True)
base = os.path.splitext(os.path.basename(src))[0].replace(' ', '_')
for n, s in enumerate(secs):
    p = os.path.join(outdir, f"{base}.sec{n}.bin"); open(p, 'wb').write(s)
    print(p, len(s), hashlib.sha256(s).hexdigest()[:16])
