import sys, os, glob
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
for f in sorted(glob.glob(os.path.join(d, 'resuelta0B*_160x300_01.png'))):
    w, h, c, p = decode(f)
    nz = sum(1 for i in range(0, w * h * c, c) if p[i] or p[i + 1] or p[i + 2])
    mx = max(p[i] for i in range(0, w * h * c, c)) if p else 0
    print(os.path.basename(f), w, h, c, 'nonzero_rgb=%d/%d' % (nz, w * h), 'maxR=%d' % mx)
