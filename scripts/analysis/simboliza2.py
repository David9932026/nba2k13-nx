import bisect, sys, re

nm_path = r"D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt"
offs = """85ba90 2cc2b8 2d2d1c 1959fc 254a748 2d8bdc 2d2b1c 33272e0 4226ec 378c8e8 197738
f9d508 3457134 345705c 34571c8 3457264 3f59ff4 200c8e8
38321bc 3832318 3832350 3f42e58 3832368 3833f68 3f42e4c 3f42e48
7a3f68 aa655c 7a4180 1ebc5a4 7a413c 7a3f74 1ebc594 aa616c 7a3ec4
1c5726c 1c57354 1be5e90 1be5e80 1c57438 1c572c4 1be5920 1c57264
2630470 335c820 225056c 29a0f30 328756c 67df78
19d5e8 3e65774 3eb1968 3ed521c 3ec3824 3cf2908""".split()

syms = []
pat = re.compile(r'^([0-9a-fA-F]+)\s+(\S+)\s+(\S+)')
with open(nm_path, errors='replace') as f:
    for line in f:
        m = pat.match(line)
        if m:
            syms.append((int(m.group(1), 16), m.group(3)))
syms.sort()
addrs = [a for a, _ in syms]
for t in offs:
    off = int(t, 16)
    i = bisect.bisect_right(addrs, off) - 1
    if i < 0:
        print(f"{t}: (no symbol)")
        continue
    a, s = syms[i]
    print(f"{t}: {s}+0x{off-a:x}")
