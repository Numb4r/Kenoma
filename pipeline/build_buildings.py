"""Gera `<região>_e<época>_bldg.bin`: os prédios e as árvores do OSM que o estilo Completo do mapa (0.22.0) desenha. Só
cenário: nada da lógica lê este arquivo, ele não muda o mundo, não entra em época e pode ser regerado sem época nova (como o
`_cycle.bin`). O pacote visual, cujo SHA é mundo, não muda.

Prédios: as áreas com `building=*` (fora `no`, `construction` sem planta, `roof` vira tipo próprio), com `building:levels`,
`height` (em andares de 3 m) e se há `shop`/`amenity` de comércio na própria área. Contorno simplificado a 0,5 m, sem
buracos. Árvores: os nós `natural=tree`.

Formato `BLD2` (0.22.2), por tile z15 com índice: ver `bld_tiles.py`. (O `BLD1` da 0.22.0, um gzip só, foi convertido sem
ler o extrato de novo: `bld_tiles.py <bld1> <bld2>`.)

Uso: .venv/bin/python build_buildings.py --region campinas [--epoch 0] [--out-dir ...]"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import osmium
import shapely
from shapely.ops import transform

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from bld_tiles import write_bld2
import overture
from fetch_overture import RELEASE

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
    ap.add_argument("--overture", action="store_true", help="junta os prédios do Overture (release fixada, cache local)")
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

    def ring_units(poly):
        """O contorno simplificado a 0,5 m em 1/64 de célula z21, sem pontos repetidos. `None`: não sobra polígono."""
        if not poly.is_valid:
            poly = poly.buffer(0)
        # Simplifica em metros (escala local da longitude), sem perder a forma de prédios pequenos.
        sx = m_per_deg_lon / m_per_deg_lat
        poly = transform(lambda x, y: (x * sx, y), poly).simplify(tol_deg, preserve_topology=True)
        poly = transform(lambda x, y: (x / sx, y), poly)
        if poly.is_empty or poly.geom_type != "Polygon":
            return None
        ring = list(poly.exterior.coords)[:-1]
        if len(ring) < 3:
            return None
        units = to_units([p[0] for p in ring], [p[1] for p in ring])
        clean = [u for i, u in enumerate(units) if u != units[i - 1]]
        return clean if len(clean) >= 3 else None

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
            clean = ring_units(shapely.Polygon(pts))
            if clean is None:
                continue
            tid = types.setdefault(kind, len(types))
            shop = obj.tags.get("shop") is not None or obj.tags.get("amenity") in SHOP_AMENITY
            buildings.append((clean[0][0], clean[0][1], tid, levels_of(obj.tags), 1 if shop else 0, clean))

    n_osm = len(buildings)
    if args.overture:
        # Do Overture, só os contornos que o OSM não tem; a bandeira de comércio vem dos places (do OSM ou do Overture) dentro.
        for poly, kind, lv in overture.overture_buildings(args.region, pbf, region["bbox"], RELEASE):
            clean = ring_units(poly)
            if clean is None:
                continue
            tid = types.setdefault(kind, len(types))
            buildings.append((clean[0][0], clean[0][1], tid, lv, 0, clean))
        places = overture.overture_places(args.region, pbf, region["bbox"], RELEASE)
        shops = [(lon, lat, "") for g, _, lon, lat in places if g in ("shop", "bar")]
        polys = [shapely.Polygon(b[5]) for b in buildings]
        to_u = lambda lon, lat: to_units([lon], [lat])[0]
        for i, _ in overture.lift_to_buildings(polys, [(*to_u(lon, lat), k) for lon, lat, k in shops]):
            b = buildings[i]
            buildings[i] = (*b[:4], 1, b[5])
        print(f"{n_osm} do OSM, {len(buildings) - n_osm} do Overture")
    names = sorted(types, key=types.get)
    data = write_bld2(names, [(tid, lv, flags, pts) for _, _, tid, lv, flags, pts in buildings], sorted(trees))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}{'_ov' if args.overture else ''}_bldg.bin"
    if out.exists():
        raise SystemExit(f"{out} já existe: não regero por cima (apague à mão se for mesmo para trocar)")
    out.write_bytes(data)
    print(f"{len(buildings)} prédios ({len(types)} tipos), {len(trees)} árvores, {out.stat().st_size} bytes, "
          f"sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
