import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
for sub in ['', 'dump_c45off']:
    dd = os.path.join(d, sub)
    for n in sorted(os.listdir(dd)):
        if not n.startswith('resuelta') or '1024x1024' not in n or 'alfa' in n: continue
        if not (n.startswith('resuelta10071') or n.startswith('resuelta0F5CF') or n.startswith('resuelta0FB20')): continue
        w,h,ch,px = decode(os.path.join(dd,n))
        nz = sum(1 for i in range(0,len(px),ch*4) if px[i] or px[i+1] or px[i+2])*4
        print(sub or 'ON', n, nz)
