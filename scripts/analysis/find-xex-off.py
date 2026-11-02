import struct

data = open(r"D:\xox360\00007000\C096DB2DDEE83F64054B\default.xex", "rb").read()

# sub_82967EC8 decoded as: lis r11,-31733 / mr r4,r3 / addi r10,r11,-11120 / lwz r3,32(r10)
pat = bytes.fromhex("3D6083CB") + bytes.fromhex("7C641B78") + bytes.fromhex("3D4AD450") + bytes.fromhex("806A0020")
print("pattern:", pat.hex(" "))

found = []
i = 0
while True:
    i = data.find(pat, i)
    if i < 0:
        break
    found.append(i)
    i += 1
print("matches:", [hex(x) for x in found])

for off in found:
    base_off = off - (0x82967EC8 - 0x82000000)
    print("candidate file offset of image base: %#x" % base_off)
    for addr in (0x82967F28, 0x82967F48, 0x82967F68, 0x82967F88, 0x82967EC8):
        o = base_off + (addr - 0x82000000)
        if 0 <= o < len(data) - 32:
            print("  %#010x off=%#x %s" % (addr, o, data[o:o+32].hex(" ")))
        else:
            print("  %#010x off=%#x OUT OF FILE (len %#x)" % (addr, o, len(data)))
