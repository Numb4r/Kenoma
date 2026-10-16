"""Gera `<região>_e2_nowalk.bin`: as rodovias e vias expressas (motorway, trunk e seus links) do mesmo extrato da época 0.
Fagulhas, materiais e Ecos da época 2 não nascem nelas. O pacote visual junta essas vias à classe `principal`, então a
distinção vem daqui. Formato: `NWK1` + gzip(varint linhas; por linha varint pontos e pares x, y em 1/64 de célula z21,
em deltas com zigzag). Uso: .venv/bin/python build_nowalk.py --region campinas"""
import argparse
import gzip
import json
import math

import numpy as np
import osmium
import shapely

from build_region import CACHE, REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import varint, zigzag
import hashlib

BLOCKED = {"motorway", "motorway_link", "trunk", "trunk_link"}
UNIT = 64  # unidades por célula z21
LINE_TOL_M = 1.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    args = ap.parse_args()
    region = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]
    pbf = ensure_source(region["source"])
    min_lon, min_lat, max_lon, max_lat = region["bbox"]
    z = 21
    cx0, cy1 = lonlat_to_tile(np.array([min_lon]), np.array([min_lat]), z)
    cx1, cy0 = lonlat_to_tile(np.array([max_lon]), np.array([max_lat]), z)
    clip = shapely.box(cx0[0], cy0[0], cx1[0], cy1[0])
    lat0 = (min_lat + max_lat) / 2
    tol = LINE_TOL_M / (40075016.686 * math.cos(math.radians(lat0)) / 2 ** z)
    wkb = osmium.geom.WKBFactory()
    lines = []
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway"))
    for obj in fp:
        if not obj.is_way() or obj.tags.get("highway") not in BLOCKED:
            continue
        if obj.tags.get("tunnel") not in (None, "no"):
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
                    lines.append(pts)
    lines.sort()
    body = bytearray(varint(len(lines)))
    for pts in lines:
        body += varint(len(pts))
        px = py = 0
        for x, y in pts:
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
    out = ROOT / f"app/assets/regions/{args.region}_e2_nowalk.bin"
    out.write_bytes(b"NWK1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(lines)} vias bloqueadas, {out.stat().st_size} bytes, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
