"""Dump bytes from a guest virtual address in an XEX file.

The XEX header has a table of optional headers; one of them (0x00000201) is
"Page Descriptors" and another (0x00000101) is "Execution Info" holding the
image base. Section data lives in basic blocks listed by the page descriptors;
here we just use the simple approach: XEX2 uncompressed images map file offset
to (image_base + offset_within_image) for the bulk data that follows the
headers, which is true for this title (no compression on the code section).
"""
import struct
import sys

XEX = r"D:\xox360\00007000\C096DB2DDEE83F64054B\default.xex"


def load():
    data = open(XEX, 'rb').read()
    hdr_count = struct.unpack('>I', data[20:24])[0]
    pos = 24
    count = hdr_count
    tables = []
    while count:
        tbl = {}
        nxt = None
        for _ in range(count):
            key, val = struct.unpack('>2I', data[pos:pos + 8])
            pos += 8
            tbl[key] = val
            if key == 0x000003FF:
                nxt = val
        tables.append(tbl)
        if not nxt:
            break
        pos = nxt
        count = struct.unpack('>I', data[pos:pos + 4])[0]
        pos += 4
    return data, tables


def main():
    addrs = [int(a, 16) for a in sys.argv[1:]]
    data, tables = load()
    merged = {}
    for t in tables:
        merged.update(t)
    base = merged.get(0x00000101, 0)
    print('image base: %#x  file size: %d' % (base, len(data)))

    # Some XEX files are "compressed basic blocks": the page descriptors tell
    # where each 4 KiB block went. Build a naive map: the file after the headers
    # contains the blocks in order, so try both raw-offset and block-table.
    pages_key = 0x00000201
    page_count = 0
    block_offsets = []
    if pages_key in merged:
        pd_off = merged[pages_key]
        info_len = struct.unpack('>I', data[pd_off:pd_off + 4])[0]
        page_count = struct.unpack('>I', data[pd_off + 4:pd_off + 8])[0]
        print('page descriptors: len=%d pages=%d' % (info_len, page_count))
        p = pd_off + 8
        for _ in range(page_count):
            blk, block_off = struct.unpack('>2I', data[p:])
            p += 8
            if blk == 0:
                block_offsets.append(None)
            else:
                block_offsets.append((block_off & 0xFFFFFF) << 8
                                     if (block_off & 0xF) == 0 else block_off)

    for addr in addrs:
        print('--- %#010x ---' % addr)
        # try direct offset first
        cand = []
        if page_count and base <= addr < base + page_count * 0x1000:
            idx = (addr - base) // 0x1000
            ent = block_offsets[idx]
            if ent is not None:
                cand.append(('block', ent + (addr - base) % 0x1000))
        cand.append(('direct', addr - base))
        for how, off in cand:
            if 0 <= off < len(data) - 16:
                chunk = data[off:off + 32]
                print('  %-6s off=%#x  %s' % (how, off, chunk.hex(' ')))


if __name__ == '__main__':
    main()
