import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = r'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'

def px(p, w, c, x, y):
    i = (y * w + x) * c
    return p[i] + p[i + 1] + p[i + 2]

def score(path):
    w, h, c, p = decode(path)
    # seam of a 640x360 quadrant: column 639|640 for y<360 and row 359|360 for x<640
    seam = ref = 0
    n = 0
    for y in range(0, 360, 2):
        seam += abs(px(p, w, c, 639, y) - px(p, w, c, 640, y))
        ref += abs(px(p, w, c, 600, y) - px(p, w, c, 601, y)) + abs(px(p, w, c, 680, y) - px(p, w, c, 681, y))
        n += 1
    for x in range(0, 640, 2):
        seam += abs(px(p, w, c, x, 359) - px(p, w, c, x, 360))
        ref += abs(px(p, w, c, x, 320) - px(p, w, c, x, 321)) + abs(px(p, w, c, x, 400) - px(p, w, c, x, 401))
        n += 1
    return seam / n, ref / (2 * n)

for modo in ('c48off', 'c48on'):
    malas = 0
    lineas = []
    for name in sorted(os.listdir(os.path.join(d, 'capturas_' + modo))):
        s, r = score(os.path.join(d, 'capturas_' + modo, name))
        mala = s > 3 * r + 6
        malas += mala
        lineas.append('%s seam=%.1f ref=%.1f %s' % (name, s, r, 'SEAM' if mala else ''))
    print(modo, 'frames_with_seam=%d of %d' % (malas, len(lineas)))
    for l in lineas:
        if l.endswith('SEAM'):
            print('  ', l)
