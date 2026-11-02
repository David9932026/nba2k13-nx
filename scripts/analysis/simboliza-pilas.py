import bisect, re, sys

nm_path = r"D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt"
syms = []
pat = re.compile(r'^([0-9a-fA-F]+)\s+(\S+)\s+(\S+)')
with open(nm_path, errors='replace') as f:
    for line in f:
        m = pat.match(line)
        if m:
            syms.append((int(m.group(1), 16), m.group(3)))
syms.sort()
addrs = [a for a, _ in syms]

cache = {}
def sym(off):
    if off in cache:
        return cache[off]
    i = bisect.bisect_right(addrs, off) - 1
    if i < 0:
        r = "(?)"
    else:
        a, s = syms[i]
        r = f"{s}+0x{off-a:x}" if off - a else s
    cache[off] = r
    return r

# read stack lines from stdin: "thread\tframes..."
counts = {}
for line in open('/tmp/pilas.txt'):
    line = line.rstrip('\n')
    if not line:
        continue
    th, _, st = line.partition('\t')
    frames = [f.strip() for f in st.split('<-')]
    sig = tuple(frames)
    counts.setdefault(th, {}).setdefault(sig, 0)
    counts[th][sig] += 1

want = ['XThread825EFC40', 'XThread825E9560', 'XThread82616000', 'GPU anillo nati']
for th in want:
    if th not in counts:
        continue
    stacks = sorted(counts[th].items(), key=lambda kv: -kv[1])[:8]
    print(f"===== {th}")
    for sig, n in stacks:
        sy = ' <- '.join(sym(int(f.replace('imagen+0x',''), 16)) for f in sig)
        print(f"  {n:6d}  {sy[:400]}")
