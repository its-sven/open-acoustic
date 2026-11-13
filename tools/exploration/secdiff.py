#!/usr/bin/env python3
"""Section-aware diff across PA builds: P-RAM record (rec0) vs remainder (external image)."""
import sys,hashlib,difflib
vers=sys.argv[1:]
def load(v):
    b=open(f"PlayAcoustic_{v}.sec1.bin",'rb').read()
    cnt=int.from_bytes(b[0:3],'big'); end=6+cnt*3
    return b, b[6:end], b[end:]
D={v:load(v) for v in vers}
for v in vers:
    b,p,r=D[v]; print(f"{v}: rec0 {len(p)//3} words sha {hashlib.sha256(p).hexdigest()[:12]} | rest {len(r)} B sha {hashlib.sha256(r).hexdigest()[:12]}")
def words(x): return [x[i:i+3] for i in range(0,len(x)-2,3)]
for a,c in zip(vers,vers[1:]):
    pa,pc=words(D[a][1]),words(D[c][1])
    sm=difflib.SequenceMatcher(None,pa,pc,autojunk=False)
    same=sum(bl.size for bl in sm.get_matching_blocks())
    ops=[o for o in sm.get_opcodes() if o[0]!='equal']
    ra,rc=D[a][2],D[c][2]
    sm2=difflib.SequenceMatcher(None,ra,rc,autojunk=False) if len(ra)<1_200_000 else None
    print(f"\n{a} -> {c}: P-RAM words identical {same}/{len(pc)} ({100*same/len(pc):.1f}%), {len(ops)} changed hunks; first hunks:",
          [(t,hex(i1),hex(i2),hex(j1),hex(j2)) for t,i1,i2,j1,j2 in ops[:6]])
