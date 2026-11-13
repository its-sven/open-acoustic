import sys
R={}
for fn,base in (('x_7e0000.bin',0x7e0000),('x_440000.bin',0x440000),('x_030000.bin',0x030000)):
    b=open(fn,'rb').read()
    for i in range(len(b)//3): R[base+i]=int.from_bytes(b[3*i:3*i+3],'big')
w=lambda a:R.get(a,0)
def s(a,n=40):
    out=''
    for k in range(n):
        c=w(a+k)
        if not (0x20<=c<0x7f): break
        out+=chr(c)
    return out
def desc(pid):
    idx=w(0x7e85f1+pid)&0xffff; d=0x7e91f3+8*idx
    f=[w(d+k) for k in range(8)]
    names=[s(x) for x in f if 0x440000<=x<0x480000 and len(s(x))>=2]
    return idx,d,f,names
for pid in [int(x,16) for x in sys.argv[1:]]:
    idx,d,f,names=desc(pid)
    print(f"param 0x{pid:03x}: idx={idx} desc@{d:06x} words={[hex(x) for x in f]} names={names}")
