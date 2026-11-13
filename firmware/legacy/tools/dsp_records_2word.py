#!/usr/bin/env python3
"""Walk DSP56300-style bootstrap records [count24, addr24, count*word24] (big-endian)."""
import sys
b=open(sys.argv[1],'rb').read()
w=lambda o:int.from_bytes(b[o:o+3],'big')
o=int(sys.argv[2],0) if len(sys.argv)>2 else 0; n=0
while o+6<=len(b):
    cnt,addr=w(o),w(o+3); end=o+6+cnt*3
    print(f"rec{n:3d} @file 0x{o:06x}  count=0x{cnt:06x} ({cnt} words, {cnt*3} B)  load=0x{addr:06x}..0x{addr+cnt-1:06x}  ends 0x{end:06x}{'  <-- OVERRUN' if end>len(b) else ''}")
    if cnt==0 or end>len(b): break
    o=end; n+=1
print(f"file len 0x{len(b):06x}, walked to 0x{o:06x}, remaining {len(b)-o} B")
