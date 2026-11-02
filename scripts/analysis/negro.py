import sys, os
sys.path.insert(0, r'D:\cola-projects\project-20261028-112651-101fe126')
from chequea_png import decode
d = sys.argv[1]
for n in sorted(os.listdir(d)):
    if not n.endswith('.png'):
        continue
    w, h, c, p = decode(os.path.join(d, n))
    neg = tot = 0
    # lower 60% of the frame, where the floor is in broadcast view
    for y in range(int(h * 0.4), h, 4):
        for x in range(0, w, 4):
            i = (y * w + x) * c
            tot += 1
            if p[i] + p[i + 1] + p[i + 2] < 24:
                neg += 1
    print(n, 'negro_inferior=%.1f%%' % (100.0 * neg / tot))
