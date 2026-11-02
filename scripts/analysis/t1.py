data = open(r"D:\xox360\00007000\C096DB2DDEE83F64054B\default.xex", "rb").read()
for name, hx in [("lis", "3D6083CB"), ("lis2", "3D60" + "83CB")]:
    pat = bytes.fromhex(hx)
    idx = []
    i = 0
    while True:
        i = data.find(pat, i)
        if i < 0: break
        idx.append(i)
        i += 1
    print(name, hex(len(idx[0]) if False else len(idx)), [hex(x) for x in idx[:10]])
for off in []:
    pass
