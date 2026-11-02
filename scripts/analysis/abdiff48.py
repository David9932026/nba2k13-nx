import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
for n in sorted(os.listdir(d+r'\capturas_c48on')):
    a=os.path.join(d,'capturas_c48on',n); b=os.path.join(d,'capturas_c48off',n)
    if not os.path.exists(b): continue
    wa,ha,ca,pa=decode(a); wb,hb,cb,pb=decode(b)
    if (wa,ha)!=(wb,hb): print(n,'size differ'); continue
    diff=0
    for i in range(0,len(pa),ca*8):
        if abs(pa[i]-pb[i])+abs(pa[i+1]-pb[i+1])+abs(pa[i+2]-pb[i+2])>30: diff+=1
    print(n, wa, ha, 'diff%%=%.2f' % (100.0*diff/(len(pa)/(ca*8))))

