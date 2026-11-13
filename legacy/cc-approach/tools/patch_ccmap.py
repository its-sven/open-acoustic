#!/usr/bin/env python3
"""Patch a TC-Helicon Play Acoustic 1.4.00 .syx: MIDI CC map entries and same-length display strings.

Analysis/test tool. Writes a NEW file; never modifies the input. Flashing is the user's decision.

CC map in 1.4.00: 4 entries of {param_id, cc} (24-bit BE words) at sec1 offset 0xA6BB7, followed by
the map pointer (0x7E89A5) and size (4). See ANALYSIS-v2.md sections 11-14.
Strings are stored one character per 24-bit word (00 00 'c'), NUL-terminated. A string edit must keep
the length and must match exactly one whole string in the image.

usage: patch_ccmap.py IN.syx OUT.syx [CC=PARAM ...] [--str "OLD=>NEW" ...]
"""
import sys, hashlib

MAP_SEC1_OFF = 0xA6BB7
EXPECT = bytes.fromhex('00007500001e00007800001f0002850000720002a800001c7e89a5000004')

def split_msgs(syx):
    msgs, i = [], 0
    while i < len(syx):
        j = syx.index(0xF7, i); msgs.append(bytearray(syx[i:j + 1])); i = j + 1
    return msgs

def unpack(p):
    out = bytearray()
    for g in range(0, len(p), 8):
        f = p[g]
        for k, b in enumerate(p[g + 1:g + 8]): out.append(b | (((f >> (6 - k)) & 1) << 7))
    return out

def pack(data, layout, orig_payload):
    """Re-pack 8-in-7 MSB-first with the original group sizes; flag bits of padding positions
    in a short final group are copied from the original so nothing else changes."""
    out = bytearray(); pos = 0
    for gi, n in enumerate(layout):
        chunk = data[pos:pos + n]; pos += n
        f = orig_payload[gi * 8] & sum(1 << (6 - k) for k in range(n, 7))
        for k, b in enumerate(chunk): f |= ((b >> 7) & 1) << (6 - k)
        out.append(f); out += bytes(b & 0x7F for b in chunk)
    assert pos == len(data)
    return out

def enc24(s):  # one char per 24-bit word
    return b''.join(b'\x00\x00' + bytes([c]) for c in s.encode('ascii'))

def main():
    args = sys.argv[1:]
    if len(args) < 3: print(__doc__); sys.exit(1)
    src, dst, rest = args[0], args[1], args[2:]
    cc_req, str_req = {}, []
    it = iter(rest)
    for a in it:
        if a == '--str':
            old, new = next(it).split('=>')
            if len(old) != len(new): sys.exit(f"string edit must keep length: {old!r} -> {new!r}")
            str_req.append((old, new))
        else:
            cc, pid = a.split('='); cc_req[int(cc, 0)] = int(pid, 0)

    syx = open(src, 'rb').read()
    msgs = split_msgs(syx)
    runs, cur = [], None
    for n, m in enumerate(msgs):
        if m[6] == 0x52 and m[7] == 0:
            if cur is None: cur = []; runs.append(cur)
            cur.append(n)
        else: cur = None
    sec1_msgs = runs[1]

    # decoded sec1 + index: sec1 byte -> (msg, unpacked index)
    un = {n: unpack(msgs[n][8:-1]) for n in sec1_msgs}
    sec1 = bytearray(); loc = []
    for n in sec1_msgs:
        for i in range(len(un[n])): loc.append((n, i))
        sec1 += un[n]
    new = bytearray(sec1)

    # CC map edits
    if cc_req:
        if bytes(sec1[MAP_SEC1_OFF:MAP_SEC1_OFF + len(EXPECT)]) != EXPECT:
            sys.exit("CC map bytes not as expected (wrong build?)")
        for e in range(4):
            o = MAP_SEC1_OFF + 6 * e
            cc = int.from_bytes(sec1[o + 3:o + 6], 'big')
            if cc in cc_req: new[o:o + 3] = cc_req.pop(cc).to_bytes(3, 'big')
        if cc_req: sys.exit(f"CC(s) not in the existing map: {sorted(cc_req)} (existing: 28,30,31,114)")

    # string edits: exact whole-string match (NUL word before and after), unique
    for old, rep in str_req:
        pat = b'\x00\x00\x00' + enc24(old) + b'\x00\x00\x00'
        hits = []; i = sec1.find(pat)
        while i >= 0:
            if i % 3 == 0 or True: hits.append(i)
            i = sec1.find(pat, i + 1)
        if len(hits) != 1: sys.exit(f"string {old!r}: expected exactly 1 match, found {len(hits)}")
        o = hits[0] + 3
        new[o:o + 3 * len(rep)] = enc24(rep)
        print(f"string at sec1+0x{o:06x}: {old!r} -> {rep!r}")

    # write back changed bytes, re-pack touched messages
    touched = set()
    for k in range(len(sec1)):
        if new[k] != sec1[k]:
            n, i = loc[k]; un[n][i] = new[k]; touched.add(n)
    for n in sorted(touched):
        payload = msgs[n][8:-1]
        layout = [min(7, len(payload) - g - 1) for g in range(0, len(payload), 8)]
        rebuilt = msgs[n][:8] + pack(un[n], layout, payload) + bytes([0xF7])
        assert len(rebuilt) == len(msgs[n])
        msgs[n] = rebuilt

    out = b''.join(msgs)
    assert len(out) == len(syx)
    open(dst, 'wb').write(out)
    diff = [i for i in range(len(syx)) if syx[i] != out[i]]
    print(f"wrote {dst}  ({len(out)} B, sha256 {hashlib.sha256(out).hexdigest()})")
    print(f"messages changed: {sorted(touched)}; file bytes changed: {len(diff)}")
    for e in range(4):
        o = MAP_SEC1_OFF + 6 * e
        print(f"  CC map entry {e}: param 0x{int.from_bytes(new[o:o+3],'big'):03x}  CC {int.from_bytes(new[o+3:o+6],'big')}")

if __name__ == '__main__':
    main()
