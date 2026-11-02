import zlib, struct, sys, os

def decode(fn):
    d = open(fn, 'rb').read()
    pos = 8
    w = h = None
    ct = 6
    idat = b''
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]
        typ = d[pos+4:pos+8]
        data = d[pos+8:pos+8+ln]
        if typ == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', data[:10])
        if typ == b'IDAT':
            idat += data
        pos += 12 + ln
    raw = zlib.decompress(idat)
    ch = 4 if ct == 6 else 3
    stride = w * ch
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(ch, stride): line[i] = (line[i] + line[i-ch]) & 255
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride): line[i] = (line[i] + ((line[i-ch] if i >= ch else 0) + prev[i]) // 2) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-ch] if i >= ch else 0
                b = prev[i]
                c = prev[i-ch] if i >= ch else 0
                pp = a + b - c
                pa = abs(pp - a); pb = abs(pp - b); pc = abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out += line
        prev = line
    return w, h, ch, out

def stats(fn):
    w, h, ch, out = decode(fn)
    mx = max(out)
    nz = sum(1 for v in out if v)
    # per-channel max for RGBA
    per = []
    for c in range(ch):
        per.append(max(out[c::ch]))
    print('%s %dx%d ch%d max=%d nonzero=%d/%d perchannel=%s' % (os.path.basename(fn), w, h, ch, mx, nz, len(out), per))

for f in sys.argv[1:]:
    try:
        stats(f)
    except Exception as e:
        print(f, 'ERROR', e)
