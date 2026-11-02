import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
for k in sys.argv[1:]:
    carpeta = os.path.join(d, k)
    vals = []
    for n in sorted(os.listdir(carpeta)):
        if not n.endswith('.png'):
            continue
        seg = int(n.split('_')[2][:4])
        if seg < 90:
            continue
        w, h, c, p = decode(os.path.join(carpeta, n))
        neg = tot = 0
        for y in range(int(h * 0.3), h, 4):
            for x in range(0, w, 4):
                i = (y * w + x) * c
                tot += 1
                if p[i] + p[i+1] + p[i+2] < 15:
                    neg += 1
        vals.append((seg, round(100.0 * neg / tot, 1)))
    altos = [v for v in vals if v[1] >= 15]
    print(k, 'frames=%d con_negro>=15%%=%d' % (len(vals), len(altos)), ' '.join('%ds:%s' % v for v in vals))
