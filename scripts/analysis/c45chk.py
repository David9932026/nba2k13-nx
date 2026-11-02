import sys, glob, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
for base in ['0F5CF','0FB20','10071']:
    res=[]
    for n in [1,5,10,15,20,25,30,35]:
        fn = os.path.join(d, 'resuelta%s_1024x1024_%02d.png' % (base,n))
        if not os.path.exists(fn): continue
        r = decode(fn)
        w,h,ch,px = r[0],r[1],r[2],r[3]
        nz = sum(1 for i in range(0,len(px),ch*4) if px[i] or px[i+1] or px[i+2])*4
        res.append('%02d:%d' % (n,nz))
    print(base, ' '.join(res))
