"""Find function entries the codegen missed.

Reads the guest code dump (D:/guestdump/g_82230000.bin), the registered functions
(generated/default/nba2k13_init.cpp) and lists addresses A that are
  * not registered,
  * right after an instruction that ends a flow (blr, unconditional b, or a 0 padding word),
  * not reachable from the registered function before them: no branch between that
    function's start and A targets A or anything after it (so A is not an inner label),
  * themselves a plausible instruction (non-zero, primary opcode used by code).
Writes the list to stdout and huecos_auto.txt.
"""
import re
import struct
import sys

BASE = 0x82230000
dump = open('D:/guestdump/g_82230000.bin', 'rb').read()
init = open('D:/cola-projects/project-20261028-112651-101fe126/rex/nba2k13app/generated/default/nba2k13_init.cpp',
            encoding='utf-8', errors='replace').read()
reg = sorted(set(int(m, 16) for m in re.findall(r'\{ 0x(8[0-9A-Fa-f]{7}), sub_', init)))
regset = set(reg)
end = BASE + len(dump)


def word(a):
    o = a - BASE
    return struct.unpack('>I', dump[o:o + 4])[0]


def branch_target(a, w):
    op = w >> 26
    if op == 18:  # b / bl
        li = w & 0x03FFFFFC
        if li & 0x02000000:
            li -= 0x04000000
        aa = (w >> 1) & 1
        lk = w & 1
        return (li if aa else a + li), lk, True
    if op == 16:  # bc
        bd = w & 0xFFFC
        if bd & 0x8000:
            bd -= 0x10000
        aa = (w >> 1) & 1
        lk = w & 1
        return (bd if aa else a + bd), lk, False
    return None, 0, False


OK_OPS = {7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33,
          34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 58, 59, 62, 63, 4, 5, 6}

cands = []
for i, f in enumerate(reg):
    if f < BASE or f >= end:
        continue
    nxt = reg[i + 1] if i + 1 < len(reg) else end
    maxt = f
    a = f
    while a < nxt:
        w = word(a)
        t, lk, _ = branch_target(a, w)
        if t is not None and not lk and f <= t < nxt:
            maxt = max(maxt, t)
        ends = (w == 0x4E800020) or (w >> 26 == 18 and (w & 3) == 0) or w == 0
        a += 4
        if a >= nxt:
            break
        if ends and maxt < a:
            # skip padding
            b = a
            while b < nxt and word(b) == 0:
                b += 4
            if b >= nxt:
                break
            wb = word(b)
            if (wb >> 26) in OK_OPS and b not in regset:
                cands.append(b)
            # treat b as a new start: restart the extent from it
            f = b
            maxt = b
            a = b
print(len(cands), 'candidates', file=sys.stderr)
with open('D:/guestdump/huecos_auto.txt', 'w') as fo:
    for c in cands:
        fo.write('%08X\n' % c)
for c in cands:
    if 0x82714000 <= c < 0x82716000:
        print('%08X' % c)
