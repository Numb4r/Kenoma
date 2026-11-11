"""Gera `<região>_e<época>_traffic.bin`: os pontos do OSM que a simulação local do tráfego lê (semáforos, pare, dê a
preferência, faixas de pedestre e entradas fora da rua: estacionamentos e garagens), do mesmo extrato da época 0. O tráfego
comum é só cenário e difere entre aparelhos: este arquivo não muda o mundo e não entra em época (como o `_noaccess.bin`).

Tipos: 0 `highway=traffic_signals`, 1 `highway=stop`, 2 `highway=give_way`, 3 `highway=crossing`, 4 entrada
(`amenity=parking|parking_entrance`, `building=garage|garages|parking`, `entrance=garage`; de uma área, o centro).

Formato: `TRF1` + gzip(varint pontos; por ponto tipo u8 e x, y em 1/64 de célula z21, em deltas com zigzag, na ordem de
(x, y, tipo)). Uso: .venv/bin/python build_traffic.py --region campinas"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

import numpy as np
import osmium

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import varint, zigzag

UNIT = 64
HIGHWAY = {"traffic_signals": 0, "stop": 1, "give_way": 2, "crossing": 3}
ENTRY = 4


def kind_of(tags, is_node: bool):
    if is_node and tags.get("highway") in HIGHWAY:
        return HIGHWAY[tags.get("highway")]
    if tags.get("amenity") in ("parking", "parking_entrance") or tags.get("entrance") == "garage":
        return ENTRY
    if not is_node and tags.get("building") in ("garage", "garages", "parking"):
        return ENTRY
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--epoch", type=int, default=0, help="a época do extrato que este arquivo acompanha")
    ap.add_argument("--out-dir", type=Path, default=REGIONS_DIR, help="fora de assets para regiões baixáveis")
    args = ap.parse_args()
    region = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]
    pbf = ensure_source(region["source"])
    min_lon, min_lat, max_lon, max_lat = region["bbox"]
    pts = set()
    counts = [0] * 5

    def add(kind, lon, lat):
        if not (min_lon <= lon <= max_lon and min_lat <= lat <= max_lat):
            return
        x, y = lonlat_to_tile(np.array([lon]), np.array([lat]), 21)
        p = (int(round(x[0] * UNIT)), int(round(y[0] * UNIT)), kind)
        if p not in pts:
            pts.add(p)
            counts[kind] += 1

    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway", "amenity", "building", "entrance"))
    for obj in fp:
        if obj.is_node():
            kind = kind_of(obj.tags, True)
            if kind is not None and obj.location.valid():
                add(kind, obj.location.lon, obj.location.lat)
        elif obj.is_way():
            kind = kind_of(obj.tags, False)
            if kind is None:
                continue
            locs = [(n.lon, n.lat) for n in obj.nodes if n.location.valid()]
            if locs:
                add(kind, sum(p[0] for p in locs) / len(locs), sum(p[1] for p in locs) / len(locs))
    body = bytearray(varint(len(pts)))
    px = py = 0
    for x, y, kind in sorted(pts):
        body += bytes([kind]) + varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}_traffic.bin"
    out.write_bytes(b"TRF1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(pts)} pontos (semáforo {counts[0]}, pare {counts[1]}, preferência {counts[2]}, faixa {counts[3]}, "
          f"entrada {counts[4]}), {out.stat().st_size} bytes, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
