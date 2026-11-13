#!/usr/bin/env python3
"""Dump the pedal's menu pages (Mix, Setup, Vocal FX, Guitar FX ...) from emulated RAM, with parameter
names, ranges and value-name lists, as JSON for tools/pa-remote.html.
Layout (firmware 1.4.00):
  page data: 8-word sub-page entries {title ptr, item list ptr, variant, 0, flags, ...}
  item list: 3 rows x 6 words {row code, 0, param L, param R, -, -}; 0x3B4 = empty cell. Rows are shown in list order.
  param descriptor: X:7E91F3 + 16*(X:7E85F1[id] & 0xFFFF); w1 min, w2 max, w8 name, w11 != 0 -> not settable, w12 value-list index
  value lists: pointer table at X:457795 + w12 -> first value string; strings are consecutive pointers.
usage: menu_dump.py [RAMDIR] > menus.json"""
import sys, os, json
D = sys.argv[1] if len(sys.argv) > 1 else 'emulation/1.4.00'
R = {}
for fn, base in (('ram_X_7E0000-7EFFFF.bin', 0x7e0000), ('ram_X_440000-47FFFF.bin', 0x440000)):
    b = open(os.path.join(D, fn), 'rb').read()
    for i in range(len(b) // 3): R[base + i] = int.from_bytes(b[3*i:3*i+3], 'big')
w = lambda a: R.get(a, 0)
sx = lambda v: v - (1 << 24) if v & 0x800000 else v
def s(a, n=32):
    o = ''
    for k in range(n):
        c = w(a + k)
        if not 0x20 <= c < 0x7f: break
        o += chr(c)
    return o
VL_BASE, VL_END = 0x457795, 0x4577cb
# value lists the format code doesn't index (format 0x95): list pointer taken from the table directly; confirmed on the unit
VL_OVERRIDE = {0x2a7: 0x4577b4}   # ROOMSENSE: AMBIENT, AMBIENT/AUTO
def param(pid):
    d = 0x7e91f3 + 16 * (w(0x7e85f1 + pid) & 0xffff)
    lo, hi = sx(w(d + 1)), sx(w(d + 2))
    p = {"id": pid, "name": s(w(d + 8)), "min": lo, "max": hi, "def": sx(w(d + 4)), "settable": w(d + 11) == 0, "fmt": w(d + 12)}
    li = VL_OVERRIDE.get(pid, VL_BASE + w(d + 12))
    if li < VL_END and 0 <= hi - lo < 64:
        first = w(li)
        p["values"] = [s(w(first + k)) for k in range(hi - lo + 1)]
    return p
def page(pd, n):
    out = []
    for k in range(n):
        t, il = w(pd + 8*k), w(pd + 8*k + 1)
        if not (0x440000 <= t < 0x480000): break
        cells = []
        for r in range(3):
            for c in (2, 3):
                pid = w(il + 6*r + c)
                cells.append(None if pid == 0x3b4 else param(pid))
        out.append({"title": s(t), "variant": w(pd + 8*k + 2), "flags": w(pd + 8*k + 4), "cells": cells})
    return out
# page-data blocks (addresses from the top-level page list, firmware 1.4.00); n = entries in the block
PAGES = {"VOCAL": (0x7e8e3a, 8), "VOCAL ADV": (0x7e8e7a, 8), "GUITAR": (0x7e8eba, 5), "GUITAR ADV": (0x7e8ee2, 16),
         "MIX": (0x7e8f6a, 6), "SETUP": (0x7e8f9a, 12)}
print(json.dumps({k: page(a, n) for k, (a, n) in PAGES.items()}, indent=1))
