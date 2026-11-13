#!/usr/bin/env python3
"""Per-block DSP56300 opcode density + ASCII ratio, to classify code/data/text regions."""
import sys,re
b=open(sys.argv[1],'rb').read(); BS=int(sys.argv[2],0) if len(sys.argv)>2 else 0x4000
OPS={b'\x00\x00\x0c':'rts',b'\x0a\xf0\x80':'jmp',b'\x0b\xf0\x80':'jsr',b'\x44\xf4\x00':'movx0'}
def score(chunk):
    best=(0,0)
    for ph in range(3):
        n=sum(1 for i in range(ph,len(chunk)-2,3) if chunk[i:i+3] in OPS)
        best=max(best,(n,ph))
    return best
prev=None; start=0
rows=[]
for o in range(0,len(b),BS):
    c=b[o:o+BS]; n,ph=score(c)
    asc=sum(1 for x in c if 0x20<=x<0x7f)/len(c); z=c.count(0)/len(c); ff=c.count(0xff)/len(c)
    dens=n*1000/len(c)
    cls='CODE' if dens>4 else 'TEXT' if asc>0.6 and z<0.3 else 'FILL' if z>0.9 or ff>0.9 else 'DATA'
    rows.append((o,cls,dens,ph,asc,z))
    print(f"0x{o:06x} {cls:4s} ops/kB={dens:5.1f} phase={ph} ascii={asc:.2f} zero={z:.2f}")
