"""Gera `<região>_e<época>_noaccess.bin`: o que só a rota do Modo Viagem lê, do mesmo extrato da época 0. O pacote visual
não guarda `access`, nem quais caminhos aceitam bicicleta, nem os viadutos; este arquivo traz as vias do pacote visual
(as mesmas de `highway_class`) com algum desses bits. Individual: não muda o mundo e não entra em época.

Bits (as mesmas regras de `accessMask` em `app/lib/world/fallback/osm_rules.dart`):
  1 a pé fechado: `foot`, senão `access`, em `no` ou `private`
  2 bicicleta fechada: `bicycle`, senão `vehicle`, senão `access`, em `no` ou `private`; escada, calçada e calçadão sem
    `bicycle=yes|designated|permissive`
  4 motorizado fechado: `motor_vehicle`, senão `vehicle`, senão `access`, em `no` ou `private`
  8 viaduto ou ponte (`bridge` diferente de `no`): o cruzamento sem vértice comum não vira esquina

Formato: `NAC1` + gzip(varint linhas; por linha bits u8, varint pontos e pares x, y em 1/64 de célula z21, em deltas
com zigzag). Uso: .venv/bin/python build_noaccess.py --region campinas"""
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

FOOT, BIKE, MOTOR, BRIDGE = 1, 2, 4, 8
CLOSED = {"no", "private"}
BIKE_OK = {"yes", "designated", "permissive"}
UNIT = 64  # unidades por célula z21
LINE_TOL_M = 1.0


def mode_closed(tags, keys) -> bool:
    """A chave mais específica que existe decide."""
    for k in keys:
        v = tags.get(k)
        if v is not None:
            return v in CLOSED
    return False


def access_mask(tags) -> int:
    m = 0
    if mode_closed(tags, ("foot", "access")):
        m |= FOOT
    if mode_closed(tags, ("bicycle", "vehicle", "access")) or (
            tags.get("highway") in ("steps", "footway", "pedestrian") and tags.get("bicycle") not in BIKE_OK):
        m |= BIKE
    if mode_closed(tags, ("motor_vehicle", "vehicle", "access")):
        m |= MOTOR
    if tags.get("bridge") not in (None, "no"):
        m |= BRIDGE
    return m


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--epoch", type=int, default=0, help="a época do extrato e do pacote visual que este arquivo acompanha")
    ap.add_argument("--out-dir", type=Path, default=REGIONS_DIR, help="fora de assets para regiões baixáveis")
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
    counts = {FOOT: 0, BIKE: 0, MOTOR: 0, BRIDGE: 0}
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway"))
    for obj in fp:
        if not obj.is_way():
            continue
        tags = obj.tags
        if highway_class(tags) is None:
            continue
        mask = access_mask(tags)
        if mask == 0:
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
                    lines.append((mask, pts))
                    for bit in counts:
                        counts[bit] += bool(mask & bit)
    lines.sort()
    body = bytearray(varint(len(lines)))
    for mask, pts in lines:
        body += bytes([mask]) + varint(len(pts))
        px = py = 0
        for x, y in pts:
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}_noaccess.bin"
    out.write_bytes(b"NAC1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(lines)} linhas (a pé {counts[FOOT]}, bicicleta {counts[BIKE]}, motorizado {counts[MOTOR]}, "
          f"viaduto {counts[BRIDGE]}), {out.stat().st_size} bytes, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
