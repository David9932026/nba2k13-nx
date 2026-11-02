import bisect, re

nm_path = r"D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt"
syms = []
pat = re.compile(r'^([0-9a-fA-F]+)\s+(\S+)\s+(\S+)')
with open(nm_path, errors='replace') as f:
    for line in f:
        m = pat.match(line)
        if m:
            syms.append((int(m.group(1), 16), m.group(2), m.group(3)))
syms.sort()
addrs = [a for a, _, _ in syms]

def sym(off):
    i = bisect.bisect_right(addrs, off) - 1
    if i < 0:
        return "(?)"
    a, t, s = syms[i]
    return f"{s}+0x{off-a:x}" if off - a else s

offs = """378c8e8 3789fe4 378d608 378dd70 376d81c 38321bc 3832318 3832350 3832368 3833f68 3834dc4 3cc1370 3cdb70c
2ad2960 2ad2a78 aa4960 aa4914 aa45ac 1d4bed4
1c14f3c 527b0c 527ee4 528180 234c7e4 234c7b4 234c7cc 196388 196308 1963b8 1984ec 2d8e4c
420474 4205e4 421598
3eb0f2c 3ebc694 374f9c8 3e602d4 3c9ad10 3b65678 37a897c 37aa8c0 37c7660 3828960
3e65774 19d5e8 2fcba90 2e792d8 26b19dc 2e792d8 11db424 31662d0 348bcb8 348b418 2757428 108244c 2ebafc 239570 19079c 200c920 11db50c 11db4ac
528180 82E19428""".split()
for t in offs:
    print(f"{t}: {sym(int(t, 16))}")
