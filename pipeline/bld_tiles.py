"""O formato `BLD2` dos prédios por tile (0.22.2): o app lê só os tiles em volta da câmera. Usado pelo `build_buildings.py` e
para converter um `BLD1` (o arquivo inteiro num gzip só) sem ler o extrato de novo.

`BLD2` + u8 zoom do tile (15) + varint n_tipos (cada um: varint tamanho e UTF-8) + u32 n_tiles + o índice, n_tiles × (u32 x,
u32 y, u32 deslocamento, u32 tamanho, u32 primeiro prédio) em ordem de (x, y) + as cargas. Cada carga é gzip(varint
n_prédios; por prédio varint tipo, u8 andares, u8 bandeiras, varint n_pontos e os pontos em 1/64 de célula z21 em deltas
com zigzag, o primeiro em relação ao canto do tile e cada prédio seguinte em relação ao primeiro ponto do anterior; varint
n_árvores e as árvores em deltas a partir do canto do tile). O prédio fica no tile do centro dele; o índice do prédio no
arquivo (o "primeiro prédio" do tile mais a posição) é o mesmo em qualquer aparelho."""
import gzip
import struct
from collections import defaultdict

from build_visual import varint, zigzag

UNIT = 64
TILE_ZOOM = 15
CELLS = 1 << (21 - TILE_ZOOM)  # células z21 por tile


def read_bld1(data: bytes):
    b = gzip.decompress(data[4:])
    i = 0

    def v():
        nonlocal i
        r = s = 0
        while True:
            c = b[i]
            i += 1
            r |= (c & 0x7F) << s
            if c < 0x80:
                return r
            s += 7

    def zz():
        x = v()
        return (x >> 1) ^ -(x & 1)

    types = []
    for _ in range(v()):
        n = v()
        types.append(b[i:i + n].decode())
        i += n
    buildings = []
    px = py = 0
    for _ in range(v()):
        t = v()
        lv, fl = b[i], b[i + 1]
        i += 2
        pts = []
        for j in range(v()):
            px += zz()
            py += zz()
            if j == 0:
                x0, y0 = px, py
            pts.append((px, py))
        px, py = x0, y0
        buildings.append((t, lv, fl, pts))
    trees = []
    px = py = 0
    for _ in range(v()):
        px += zz()
        py += zz()
        trees.append((px, py))
    return types, buildings, trees


def write_bld2(types: list[str], buildings, trees) -> bytes:
    """[buildings]: (tipo, andares, bandeiras, pontos em 1/64 de célula z21); [trees]: (x, y) na mesma unidade."""
    span = CELLS * UNIT
    by_tile = defaultdict(lambda: ([], []))
    for bd in buildings:
        pts = bd[3]
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        by_tile[(int(cx // span), int(cy // span))][0].append(bd)
    for t in trees:
        by_tile[(t[0] // span, t[1] // span)][1].append(t)
    header = bytearray(b"BLD2") + bytes([TILE_ZOOM]) + varint(len(types))
    for name in types:
        raw = name.encode()
        header += varint(len(raw)) + raw
    keys = sorted(by_tile)
    payloads = []
    first = 0
    index = []
    for (tx, ty) in keys:
        bs, ts = by_tile[(tx, ty)]
        bs.sort(key=lambda bd: (bd[3][0][0], bd[3][0][1]))
        ox, oy = tx * span, ty * span
        body = bytearray(varint(len(bs)))
        px, py = ox, oy
        for t, lv, fl, pts in bs:
            body += varint(t) + bytes([lv, fl]) + varint(len(pts))
            x0, y0 = pts[0]
            for x, y in pts:
                body += varint(zigzag(x - px)) + varint(zigzag(y - py))
                px, py = x, y
            px, py = x0, y0
        body += varint(len(ts))
        px, py = ox, oy
        for x, y in sorted(ts):
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
        blob = gzip.compress(bytes(body), compresslevel=9, mtime=0)
        index.append((tx, ty, sum(len(p) for p in payloads), len(blob), first))
        payloads.append(blob)
        first += len(bs)
    header += struct.pack("<I", len(keys))
    for e in index:
        header += struct.pack("<IIIII", *e)
    return bytes(header) + b"".join(payloads)


if __name__ == "__main__":
    import hashlib
    import sys
    from pathlib import Path

    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    types, bs, ts = read_bld1(src.read_bytes())
    out = write_bld2(types, bs, ts)
    dst.write_bytes(out)
    n = struct.unpack_from("<I", out, 5 + len(b"".join(varint(len(t.encode())) + t.encode() for t in types)) + len(varint(len(types))))[0]
    print(f"{len(bs)} prédios, {len(ts)} árvores, {n} tiles, {len(out)} bytes, sha256 {hashlib.sha256(out).hexdigest()}")
