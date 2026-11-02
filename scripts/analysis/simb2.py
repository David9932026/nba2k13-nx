import bisect
lines = {}
with open(r'D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt', errors='ignore') as f:
    for ln in f:
        parts = ln.split()
        if len(parts) >= 3 and parts[1] in 'tTwW':
            try: lines[int(parts[0], 16)] = parts[2]
            except: pass
keys = sorted(lines)
for a in [0x3ec7538,0x3ec7494,0x3ec7540,0x3ec7550,0x3749dcc,0xf9f6a8,0x37d1360,0x37d1368,0x383605c]:
    i = bisect.bisect_right(keys, a) - 1
    if i >= 0:
        sym = lines[keys[i]]; d = a - keys[i]
        print('%x = %s +0x%x' % (a, sym, d) if d else '%x = %s' % (a, sym))