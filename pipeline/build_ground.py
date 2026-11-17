"""Gera `<região>_e0_ground.bin` (0.23.1): o uso do solo do OSM que o chão do estilo Completo desenha por cima do chão neutro
do bioma. Só cenário, como o `_cycle.bin`: não muda o mundo, não entra em época e pode ser regerado sem época nova.

Tipos (a ordem do desenho, do maior para o mais específico): 0 lote residencial (`landuse=residential`), 1 área comercial
(`landuse=commercial|retail`), 2 terreno baldio (`landuse=brownfield|greenfield|construction`), 3 estacionamento
(`amenity=parking` de superfície: fora `parking=multi-storey|underground|rooftop`), 4 piso de pedestre (`highway=pedestrian`
e `area:highway=pedestrian` em área, `place=square`), 5 a zona da calçada portuguesa (`mosaic_zone` de `regions.json`, o
Centro; o OSM de Campinas não tem a área do bairro). Só o contorno externo, simplificado a 0,5 m.

Formato `GRD1` + gzip(varint n_áreas; por área u8 tipo, varint n_pontos e os pontos em 1/64 de célula z21, em deltas com
zigzag a partir do primeiro ponto da área anterior). Uso: .venv/bin/python build_ground.py --region campinas"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

import numpy as np
import osmium
import shapely

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import varint, zigzag

UNIT = 64
SIMPLIFY_DEG = 0.5 / 111_320
RULES = [
    (0, "landuse", {"residential"}),
    (1, "landuse", {"commercial", "retail"}),
    (2, "landuse", {"brownfield", "greenfield", "construction"}),
    (3, "amenity", {"parking"}),
    (4, "highway", {"pedestrian"}),
    (4, "area:highway", {"pedestrian"}),
    (4, "place", {"square"}),
]
MOSAIC = 5


def kind_of(tags):
    for kind, key, values in RULES:
        if tags.get(key) in values:
            if kind == 3 and tags.get("parking") in ("multi-storey", "underground", "rooftop"):
                return None
            return kind
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--out-dir", type=Path, default=REGIONS_DIR)
    args = ap.parse_args()
    region = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]
    pbf = ensure_source(region["source"])
    clip = shapely.box(*region["bbox"])
    wkb = osmium.geom.WKBFactory()
    areas = []  # (tipo, anel lon/lat)
    keys = sorted({k for _, k, _ in RULES})
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_areas().with_filter(osmium.filter.KeyFilter(*keys))
    for obj in fp:
        if not obj.is_area():
            continue
        kind = kind_of(obj.tags)
        if kind is None:
            continue
        try:
            g = shapely.from_wkb(wkb.create_multipolygon(obj))
        except (RuntimeError, osmium.InvalidLocationError):
            continue
        if not g.intersects(clip):
            continue
        for part in getattr(g, "geoms", [g]):
            ring = shapely.Polygon(part.exterior.coords).simplify(SIMPLIFY_DEG, preserve_topology=True)
            if not ring.is_empty and ring.geom_type == "Polygon":
                areas.append((kind, list(ring.exterior.coords)[:-1]))
    if "mosaic_zone" in region:
        areas.append((MOSAIC, [tuple(p) for p in region["mosaic_zone"]]))
    # Ordem estável: pelo tipo e pelo primeiro ponto.
    out = []
    for kind, ring in areas:
        xs, ys = lonlat_to_tile(np.array([p[0] for p in ring]), np.array([p[1] for p in ring]), 21)
        pts = [(int(round(x * UNIT)), int(round(y * UNIT))) for x, y in zip(xs, ys)]
        pts = [p for i, p in enumerate(pts) if p != pts[i - 1]]
        if len(pts) >= 3:
            out.append((kind, pts))
    out.sort(key=lambda a: (a[0], a[1][0], len(a[1])))
    body = bytearray(varint(len(out)))
    px = py = 0
    for kind, pts in out:
        body += bytes([kind]) + varint(len(pts))
        x0, y0 = pts[0]
        for x, y in pts:
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
        px, py = x0, y0
    data = b"GRD1" + gzip.compress(bytes(body), compresslevel=9, mtime=0)
    dst = args.out_dir / f"{args.region}_e0_ground.bin"
    if dst.exists():
        raise SystemExit(f"{dst} já existe: não regero por cima")
    dst.write_bytes(data)
    counts = [sum(1 for k, _ in out if k == i) for i in range(6)]
    print(f"{len(out)} áreas (residencial {counts[0]}, comercial {counts[1]}, baldio {counts[2]}, estacionamento {counts[3]}, "
          f"pedestre {counts[4]}, calçada portuguesa {counts[5]}), {len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
