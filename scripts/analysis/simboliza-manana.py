import bisect, sys, re

nm_path = r"D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt"
tops = ["85ba90","2cc2b8","3ebf7a4","2d2d1c","1959fc","3eb1cd8","3ebf67c","254a748",
        "3ec3688","2d8bdc","2d2b1c","33272e0","4226ec","378c8e8","3f755b8","197738",
        "3eb1198","3f755dc","3ec37ac","170e888","31662d0","29dec30","2d91b08","348bcb8","4224f4"]

syms = []
pat = re.compile(r'^([0-9a-fA-F]+)\s+\S+\s+(\S+)')
with open(nm_path, errors='replace') as f:
    for line in f:
        m = pat.match(line)
        if m:
            syms.append((int(m.group(1), 16), m.group(2)))
syms.sort()
addrs = [a for a, _ in syms]
print("symbols:", len(syms))

for t in tops:
    off = int(t, 16)
    i = bisect.bisect_right(addrs, off) - 1
    if i < 0:
        print(f"{t}: (no symbol)")
        continue
    a, s = syms[i]
    print(f"{t}: {s}+0x{off-a:x}")
