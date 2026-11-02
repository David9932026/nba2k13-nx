import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
runs = ['base', 'nosub', 'norec', 'nomips']
frames = ['captura_%03d_%04ds.png' % (i, s) for i, s in [(50,201),(51,205),(52,209),(53,213),(54,217),(55,221),(56,225),(57,229)]]
cache = {}
def load(k, f):
    w, h, c, p = decode(os.path.join(d, 'capturas_suelo_' + k, f))
    return w, h, c, p
for f in frames:
    imgs = {k: load(k, f) for k in runs}
    w, h, c, pb = imgs['base']
    out = [f]
    for k in runs:
        _, _, _, p = imgs[k]
        neg = dif = tot = 0
        for y in range(0, h, 3):
            for x in range(0, w, 3):
                i = (y * w + x) * c
                tot += 1
                if p[i] + p[i+1] + p[i+2] < 15:
                    neg += 1
                if abs(p[i]-pb[i]) + abs(p[i+1]-pb[i+1]) + abs(p[i+2]-pb[i+2]) > 60:
                    dif += 1
        out.append('%s neg=%.1f%% dif_vs_base=%.1f%%' % (k, 100.0*neg/tot, 100.0*dif/tot))
    print(' | '.join(out))
