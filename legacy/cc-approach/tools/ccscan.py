#!/usr/bin/env python3
"""Find candidate CC map tables: arrays of 24-bit BE words (stride k words) where one field is a
strictly increasing run of small values (0..127) of length >= MINLEN."""
import sys
b=open(sys.argv[1],'rb').read(); MINLEN=int(sys.argv[2]) if len(sys.argv)>2 else 10
res=[]
for ph in range(3):
    W=[int.from_bytes(b[i:i+3],'big') for i in range(ph,len(b)-2,3)]
    for k in range(1,9):
        for f in range(k):
            i=f; 
            while i<len(W):
                j=i; seq=[]
                while j<len(W) and W[j]<128 and (not seq or W[j]>seq[-1]):
                    seq.append(W[j]); j+=k
                if len(seq)>=MINLEN and seq[-1]-seq[0]>=len(seq):   # not just 0,1,2,3 counters
                    res.append((len(seq),ph+3*i,k,seq))
                    i=j
                else: i+=k
seen=set()
for L,off,k,seq in sorted(res,key=lambda r:-r[0]):
    key=(off//60)
    if key in seen: continue
    seen.add(key)
    print(f"len={L:3d} file_off=0x{off:06x} stride={k}w  vals={seq[:40]}")
    if len(seen)>40: break
