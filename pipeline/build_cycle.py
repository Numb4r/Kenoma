"""Gera `<região>_e<época>_cycle.bin`: as ciclovias do mesmo extrato da época 0, para os ciclistas da simulação local.
O pacote visual não guarda a ciclovia e o SHA dele é mundo (fixado nas épocas desde a 2), então a classe nova vem neste
arquivo ao lado, como o `_noaccess.bin` e o `_traffic.bin`: é cenário, não muda o mundo e não entra em época.

Bits por linha: 1 ciclovia própria (`highway=cycleway`), 2 ciclofaixa numa rua (`cycleway`, `cycleway:left`,
`cycleway:right` ou `cycleway:both` diferente de `no` e de `none` numa via do pacote visual).

Formato: `CYC1` + gzip(varint linhas; por linha bits u8, varint pontos e pares x, y em 1/64 de célula z21, em deltas com
zigzag). Uso: .venv/bin/python build_cycle.py --region campinas"""
import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import osmium
import shapely

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import highway_class, varint, zigzag

TRACK, LANE = 1, 2
UNIT = 64
LINE_TOL_M = 1.0
NO = (None, "no", "none")


def cycle_bit(tags) -> int:
    if tags.get("highway") == "cycleway":
        return TRACK
    if highway_class(tags) is not None and any(tags.get(k) not in NO for k in ("cycleway", "cycleway:left", "cycleway:right", "cycleway:both")):
        return LANE
    return 0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--epoch", type=int, default=0, help="a época do extrato que este arquivo acompanha")
    ap.add_argument("--out-dir", type=Path, default=REGIONS_DIR, help="fora de assets para regiões baixáveis")
    args = ap.parse_args()
    region = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]
    pbf = ensure_source(region["source"])
    min_lon, min_lat, max_lon, max_lat = region["bbox"]
    z = 21
    cx0, cy1 = lonlat_to_tile(np.array([min_lon]), np.array([min_lat]), z)
    cx1, cy0 = lonlat_to_tile(np.array([max_lon]), np.array([max_lat]), z)
    clip = shapely.box(cx0[0], cy0[0], cx1[0], cy1[0])
    tol = LINE_TOL_M / (40075016.686 * math.cos(math.radians((min_lat + max_lat) / 2)) / 2 ** z)
    wkb = osmium.geom.WKBFactory()
    lines = []
    counts = {TRACK: 0, LANE: 0}
    meters = {TRACK: 0.0, LANE: 0.0}
    mpc = 40075016.686 * math.cos(math.radians((min_lat + max_lat) / 2)) / 2 ** z
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway"))
    for obj in fp:
        if not obj.is_way():
            continue
        bit = cycle_bit(obj.tags)
        if bit == 0:
            continue
        try:
            geom = shapely.from_wkb(wkb.create_linestring(obj))
        except (RuntimeError, osmium.InvalidLocationError):
            continue
        geom = shapely.transform(geom, lambda x, y: lonlat_to_tile(x, y, z), interleaved=False)
        if not geom.intersects(clip):
            continue
        geom = geom.intersection(clip).simplify(tol, preserve_topology=False)
        for g in getattr(geom, "geoms", [geom]):
            if g.geom_type == "LineString" and not g.is_empty:
                pts = [(int(round(x * UNIT)), int(round(y * UNIT))) for x, y in g.coords]
                pts = [p for i, p in enumerate(pts) if i == 0 or p != pts[i - 1]]
                if len(pts) >= 2:
                    lines.append((bit, pts))
                    counts[bit] += 1
                    meters[bit] += g.length * mpc
    lines.sort()
    body = bytearray(varint(len(lines)))
    for bit, pts in lines:
        body += bytes([bit]) + varint(len(pts))
        px = py = 0
        for x, y in pts:
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}_cycle.bin"
    out.write_bytes(b"CYC1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(lines)} linhas (ciclovia {counts[TRACK]}, {meters[TRACK] / 1000:.1f} km; ciclofaixa {counts[LANE]}, {meters[LANE] / 1000:.1f} km), "
          f"{out.stat().st_size} bytes, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
