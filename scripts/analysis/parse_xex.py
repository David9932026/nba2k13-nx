import struct
p = r"D:\xox360\00007000\C096DB2DDEE83F64054B\default.xex"
data = open(p,'rb').read()
hdr_count = struct.unpack('>I', data[20:24])[0]
pos = 24
count = hdr_count
tables = []
while count:
    tbl = []
    nxt = None
    for i in range(count):
        key, val = struct.unpack('>2I', data[pos:pos+8]); pos += 8
        tbl.append((key,val))
        if key == 0x000003FF:
            nxt = val
    tables.append(tbl)
    if not nxt:
        break
    pos = nxt
    count = struct.unpack('>I', data[pos:pos+4])[0]
    pos += 4
for t_i, tbl in enumerate(tables):
    print("table %d:" % t_i)
    for key,val in tbl:
        print("   key=%#010x val=%#x" % (key,val))