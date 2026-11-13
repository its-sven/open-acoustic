#!/usr/bin/env python3
"""Dump parameter descriptors from emulated RAM: desc = X:7E91F3 + 16*(X:7E85F1[id] & 0xFFFF).
usage: dump_params.py [RAMDIR=emulation/1.4.00] > out.txt"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else 'emulation/1.4.00'
R={}
for fn,base in ((os.path.join(D,'ram_X_7E0000-7EFFFF.bin'),0x7e0000),(os.path.join(D,'ram_X_440000-47FFFF.bin'),0x440000),(os.path.join(D,'ram_X_030000-039FFF.bin'),0x030000)):
    b=open(fn,'rb').read()
    for i in range(len(b)//3): R[base+i]=int.from_bytes(b[3*i:3*i+3],'big')
w=lambda a:R.get(a,0)
def s(a,n=32):
    out=''
    for k in range(n):
        c=w(a+k)
        if not (0x20<=c<0x7f): break
        out+=chr(c)
    return out
STRIDE=16
seen={}
for pid in range(0,0x400):
    raw=w(0x7e85f1+pid); idx=raw&0xffff; d=0x7e91f3+STRIDE*idx
    f=[w(d+k) for k in range(STRIDE)]
    names=[(k,s(x)) for k,x in enumerate(f) if 0x440000<=x<0x480000 and len(s(x))>=2]
    print(f"0x{pid:03x} idx={idx:4d} hi={raw>>16:3d} " + " ".join(f"{x:06x}" for x in f[:10]) + "  " + " | ".join(f"[{k}]{n}" for k,n in names))
