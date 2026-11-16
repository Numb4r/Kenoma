"""Gera `<região>_e<época>_bldg.bin`: os prédios e as árvores do OSM que o estilo Completo do mapa (0.22.0) desenha. Só
cenário: nada da lógica lê este arquivo, ele não muda o mundo, não entra em época e pode ser regerado sem época nova (como o
`_cycle.bin`). O pacote visual, cujo SHA é mundo, não muda.

Prédios: as áreas com `building=*` (fora `no`, `construction` sem planta, `roof` vira tipo próprio), com `building:levels`,
`height` (em andares de 3 m) e se há `shop`/`amenity` de comércio na própria área. Contorno simplificado a 0,5 m, sem
buracos. Árvores: os nós `natural=tree`.

Formato: `BLD1` + gzip(
  varint n_tipos; por tipo varint tamanho e bytes UTF-8;
  varint n_prédios; por prédio: varint tipo, u8 andares (0 = sem dado; 255 no máximo), u8 bandeiras (bit 0: comércio),
    varint n_pontos e os pontos em 1/64 de célula z21, em deltas com zigzag (o primeiro em relação ao primeiro ponto do
    prédio anterior, na ordem do primeiro ponto);
  varint n_árvores; por árvore x, y em 1/64 de célula z21, em deltas com zigzag, na ordem de (x, y)).

Uso: .venv/bin/python build_buildings.py --region campinas [--epoch 0] [--out-dir ...]"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

import numpy as np
import osmium
import shapely
from shapely.ops import transform

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import varint, zigzag

UNIT = 64
SIMPLIFY_M = 0.5
SHOP_AMENITY = {"bar", "pub", "restaurant", "cafe", "fast_food", "bank", "pharmacy", "marketplace"}


def levels_of(tags) -> int:
    for key, div in (("building:levels", 1.0), ("height", 3.0)):
        v = tags.get(key)
        if not v:
            continue
        try:
            n = float(v.replace(",", ".").split()[0].rstrip("m")) / div
        except ValueError:
            continue
        if n > 0:
            return max(1, min(255, round(n)))
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
    lat0 = (min_lat + max_lat) / 2
    m_per_deg_lat = 111_320.0
    m_per_deg_lon = 111_320.0 * np.cos(np.radians(lat0))
    tol_deg = SIMPLIFY_M / m_per_deg_lat

    types: dict[str, int] = {}
    buildings = []  # (x0, y0, tipo, andares, bandeiras, pontos)
    trees = set()

    def to_units(lons, lats):
        x, y = lonlat_to_tile(np.asarray(lons), np.asarray(lats), 21)
        return [(int(round(a * UNIT)), int(round(b * UNIT))) for a, b in zip(x, y)]

    fp = osmium.FileProcessor(str(pbf)).with_locations().with_areas().with_filter(osmium.filter.KeyFilter("building", "natural"))
    for obj in fp:
        if obj.is_node():
            if obj.tags.get("natural") == "tree" and obj.location.valid():
                lon, lat = obj.location.lon, obj.location.lat
                if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
                    trees.add(to_units([lon], [lat])[0])
            continue
        if not obj.is_area():
            continue
        kind = obj.tags.get("building")
        if kind is None or kind == "no":
            continue
        for outer in obj.outer_rings():
            pts = [(n.lon, n.lat) for n in outer if n.location.valid()]
            if len(pts) < 4:
                continue
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            if not (min_lon <= cx <= max_lon and min_lat <= cy <= max_lat):
                continue
            poly = shapely.Polygon(pts)
            if not poly.is_valid:
                poly = poly.buffer(0)
            # Simplifica em metros (escala local da longitude), sem perder a forma de prédios pequenos.
            sx = m_per_deg_lon / m_per_deg_lat
            poly = transform(lambda x, y: (x * sx, y), poly).simplify(tol_deg, preserve_topology=True)
            poly = transform(lambda x, y: (x / sx, y), poly)
            if poly.is_empty or poly.geom_type != "Polygon":
                continue
            ring = list(poly.exterior.coords)[:-1]
            if len(ring) < 3:
                continue
            units = to_units([p[0] for p in ring], [p[1] for p in ring])
            # Sem pontos repetidos depois do arredondamento.
            clean = [u for i, u in enumerate(units) if u != units[i - 1]]
            if len(clean) < 3:
                continue
            tid = types.setdefault(kind, len(types))
            shop = obj.tags.get("shop") is not None or obj.tags.get("amenity") in SHOP_AMENITY
            buildings.append((clean[0][0], clean[0][1], tid, levels_of(obj.tags), 1 if shop else 0, clean))

    buildings.sort(key=lambda b: (b[0], b[1]))
    body = bytearray(varint(len(types)))
    for name in sorted(types, key=types.get):
        raw = name.encode()
        body += varint(len(raw)) + raw
    body += varint(len(buildings))
    px = py = 0
    for x0, y0, tid, lv, flags, pts in buildings:
        body += varint(tid) + bytes([lv, flags]) + varint(len(pts))
        for x, y in pts:
            body += varint(zigzag(x - px)) + varint(zigzag(y - py))
            px, py = x, y
        px, py = x0, y0
    body += varint(len(trees))
    px = py = 0
    for x, y in sorted(trees):
        body += varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}_bldg.bin"
    out.write_bytes(b"BLD1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(buildings)} prédios ({len(types)} tipos), {len(trees)} árvores, {out.stat().st_size} bytes, "
          f"sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
