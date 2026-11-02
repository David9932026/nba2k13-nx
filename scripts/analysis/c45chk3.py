import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
def nzset(fn):
    w,h,ch,px = decode(fn); s=set()
    for i in range(0,len(px),ch):
        if px[i] or px[i+1] or px[i+2]: s.add(i//ch)
    return s
off = nzset(os.path.join(d,'dump_c45off','resuelta10071_1024x1024_03.png'))
leb = nzset(os.path.join(d,'resuelta0FB20_1024x1024_03.png'))
kd  = nzset(os.path.join(d,'resuelta0F5CF_1024x1024_03.png'))
print('off(10071)=%d  on_lebron=%d  on_durant=%d' % (len(off),len(leb),len(kd)))
print('off & lebron=%d  off - lebron=%d  (off-lebron) & durant=%d' % (len(off&leb), len(off-leb), len((off-leb)&kd)))
print('lebron & durant overlap=%d' % len(leb&kd))
