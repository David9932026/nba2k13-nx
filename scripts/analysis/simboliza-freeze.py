import bisect, sys
lines = {}
with open(r'D:\cola-projects\project-20261028-112651-101fe126\nm-final.txt', errors='ignore') as f:
    for ln in f:
        parts = ln.split()
        if len(parts) >= 3 and parts[1] in 'tTwW':
            try:
                lines[int(parts[0], 16)] = parts[2]
            except Exception:
                pass
addrs = [0x3ec7548, 0x3ec7520, 0x3ec756c, 0x3ec353c, 0x3ec3664, 0x3ec766c,
         0x199d0c, 0x2dad7c, 0x420a5c, 0x420b34, 0x4235f4, 0x26e3318, 0x85dc30,
         0x3ec76e4, 0x3e69634, 0x19f788, 0x3eb5828, 0x3ed90dc, 0x3ec3688]
keys = sorted(lines)
for a in addrs:
    i = bisect.bisect_right(keys, a) - 1
    if i >= 0:
        sym = lines[keys[i]]
        d = a - keys[i]
        print('%x = %s +0x%x' % (a, sym, d) if d else '%x = %s' % (a, sym))
    else:
        print('%x = ?' % a)
