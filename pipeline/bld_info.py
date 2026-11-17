"""Resumo de um `BLD2`: tiles, o maior tile, prédios e árvores. Uso: .venv/bin/python bld_info.py <arquivo>"""
import gzip
import struct
import sys
from pathlib import Path


def info(data: bytes) -> dict:
    assert data[:4] == b"BLD2"
    i = 5

    def v():
        nonlocal i
        r = s = 0
        while True:
            c = data[i]
            i += 1
            r |= (c & 0x7F) << s
            if c < 0x80:
                return r
            s += 7

    for _ in range(v()):
        size = v()
        i += size
    n = struct.unpack_from("<I", data, i)[0]
    i += 4
    index = [struct.unpack_from("<IIIII", data, i + 20 * k) for k in range(n)]
    base = i + 20 * n
    buildings = trees = 0
    for _, _, off, size, _ in index:
        b = gzip.decompress(data[base + off:base + off + size])
        j = 0

        def w():
            nonlocal j
            r = s = 0
            while True:
                c = b[j]
                j += 1
                r |= (c & 0x7F) << s
                if c < 0x80:
                    return r
                s += 7

        nb = w()
        for _ in range(nb):
            w()
            j += 2
            for _ in range(2 * w()):
                w()
        buildings += nb
        trees += w()
    return {"tiles": n, "max_tile": max(e[3] for e in index), "buildings": buildings, "trees": trees, "bytes": len(data)}


if __name__ == "__main__":
    print(info(Path(sys.argv[1]).read_bytes()))
