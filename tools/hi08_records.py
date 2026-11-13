#!/usr/bin/env python3
"""Walk a TC-Helicon Play sec1 image in the HI08 loader format (from sec0 disassembly):
   record = [count][addr][type] + count words (24-bit BE)
   type 0: addr < 0x10000 -> P:addr, else X:addr ; type 4: jump to addr (end)
   Optional: -x OUTDIR  writes each record as rNN_<mem>_<addr>.bin"""
import sys,os
b=open(sys.argv[1],'rb').read(); outdir=sys.argv[3] if len(sys.argv)>3 and sys.argv[2]=='-x' else None
w=lambda o:int.from_bytes(b[o:o+3],'big'); o=0; n=0
if outdir: os.makedirs(outdir,exist_ok=True)
while o+9<=len(b):
    cnt,addr,typ=w(o),w(o+3),w(o+6)
    if typ==4: print(f"rec{n:3d} @0x{o:06x} TYPE4 -> jump to P:0x{addr:06x} (count field {cnt})"); o+=9; break
    mem='P' if addr<0x10000 else 'X'
    end=o+9+cnt*3
    print(f"rec{n:3d} @0x{o:06x} type={typ} count={cnt:6d} -> {mem}:0x{addr:06x}..0x{addr+cnt-1:06x}{'  OVERRUN' if end>len(b) else ''}")
    if typ not in (0,) or end>len(b): print("   unexpected; stopping"); break
    if outdir: open(f"{outdir}/r{n:02d}_{mem}_{addr:06x}.bin",'wb').write(b[o+9:end])
    o=end; n+=1
print(f"walked to 0x{o:06x} of 0x{len(b):06x} (remaining {len(b)-o} B)")
