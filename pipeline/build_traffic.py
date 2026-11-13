"""Gera `<região>_e<época>_traffic.bin`: os pontos do OSM que a simulação local do tráfego lê (semáforos, pare, dê a
preferência, faixas de pedestre e entradas fora da rua: estacionamentos e garagens), do mesmo extrato da época 0. O tráfego
comum é só cenário e difere entre aparelhos: este arquivo não muda o mundo e não entra em época (como o `_noaccess.bin`).

Tipos: 0 `highway=traffic_signals`, 1 `highway=stop`, 2 `highway=give_way`, 3 `highway=crossing`, 4 entrada
(`amenity=parking|parking_entrance`, `building=garage|garages|parking`, `entrance=garage`; de uma área, o centro).
Da 0.19.0, a vida urbana: 5 ponto de ônibus (`highway=bus_stop`), 6 comércio (`shop=*`), 7 bar ou restaurante
(`amenity=bar|pub|restaurant|cafe|fast_food`), 8 escola (`amenity=school|kindergarten|college|university`), 9 praça ou
parque (`leisure=park|garden`, `place=square`). Da 0.19.1: 10 estádio (`leisure=stadium`). Da época 12 (`--epoch 12` em
diante): 11 beco, para a Shade da camada pessoal: pontos a cada 10 m ao longo de `highway=service` + `service=alley` e dos
`highway=footway|path` (fora calçada e travessia) que passam entre construções (prédio dos dois lados a até 9 m, numa grade
de prédios em z22); um ponto por célula z21. Os tipos 0 a 10 saem iguais aos das épocas anteriores.

Formato: `TRF1` + gzip(varint pontos; por ponto tipo u8 e x, y em 1/64 de célula z21, em deltas com zigzag, na ordem de
(x, y, tipo)). Uso: .venv/bin/python build_traffic.py --region campinas"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

import numpy as np
import osmium
import shapely
from rasterio.features import rasterize
from rasterio.transform import Affine

from build_region import REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile
from build_visual import varint, zigzag

UNIT = 64
HIGHWAY = {"traffic_signals": 0, "stop": 1, "give_way": 2, "crossing": 3}
ENTRY = 4
ALLEY = 11
ALLEY_FROM_EPOCH = 12
SAMPLE_M = 10  # passo ao longo do beco
SIDE_M = (4, 6, 9)  # distâncias de cada lado onde se procura prédio
BUILDING_ZOOM = 22


def kind_of(tags, is_node: bool):
    if is_node and tags.get("highway") in HIGHWAY:
        return HIGHWAY[tags.get("highway")]
    if is_node and tags.get("highway") == "bus_stop":
        return 5
    if tags.get("shop") is not None:
        return 6
    if tags.get("amenity") in ("bar", "pub", "restaurant", "cafe", "fast_food"):
        return 7
    if tags.get("amenity") in ("school", "kindergarten", "college", "university"):
        return 8
    if tags.get("leisure") == "stadium":
        return 10
    if tags.get("leisure") in ("park", "garden") or tags.get("place") == "square":
        return 9
    if tags.get("amenity") in ("parking", "parking_entrance") or tags.get("entrance") == "garage":
        return ENTRY
    if not is_node and tags.get("building") in ("garage", "garages", "parking"):
        return ENTRY
    return None


def _metres_per_cell21(lat: float) -> float:
    return 40075016.686 * np.cos(np.radians(lat)) / 2**21


def alley_points(pbf: Path, bbox: list[float]) -> list[tuple[float, float]]:
    """Os pontos de beco (lon, lat): ao longo de `service=alley` e dos caminhos estreitos entre construções."""
    min_lon, min_lat, max_lon, max_lat = bbox
    buildings, alleys, footways = [], [], []
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway", "building"))
    for obj in fp:
        if not obj.is_way():
            continue
        locs = [(n.lon, n.lat) for n in obj.nodes if n.location.valid()]
        if len(locs) < 2 or not any(min_lon <= x <= max_lon and min_lat <= y <= max_lat for x, y in locs):
            continue
        t = obj.tags
        if t.get("building") not in (None, "no") and len(locs) >= 4 and locs[0] == locs[-1]:
            buildings.append(locs)
        hw = t.get("highway")
        if hw == "service" and t.get("service") == "alley":
            alleys.append(locs)
        elif hw in ("footway", "path") and t.get("footway") not in ("sidewalk", "crossing"):
            footways.append(locs)
    # A grade dos prédios em z22 (uns 9 m).
    gx0, gy1 = lonlat_to_tile(np.array([min_lon]), np.array([min_lat]), BUILDING_ZOOM)
    gx1, gy0 = lonlat_to_tile(np.array([max_lon]), np.array([max_lat]), BUILDING_ZOOM)
    x0, y0 = int(np.floor(gx0[0])), int(np.floor(gy0[0]))
    w, h = int(np.ceil(gx1[0])) - x0 + 1, int(np.ceil(gy1[0])) - y0 + 1

    def grid_poly(locs):
        xs, ys = lonlat_to_tile(np.array([p[0] for p in locs]), np.array([p[1] for p in locs]), BUILDING_ZOOM)
        return shapely.Polygon(np.column_stack([xs - x0, ys - y0]))

    grid = np.zeros((h, w), dtype=np.uint8)
    shapes = ((g, 1) for g in (grid_poly(b) for b in buildings) if g.is_valid and not g.is_empty)
    rasterize(shapes, out=grid, transform=Affine.identity(), all_touched=True)

    def built(x22: float, y22: float) -> bool:
        i, j = int(np.floor(y22 - y0)), int(np.floor(x22 - x0))
        return 0 <= i < h and 0 <= j < w and grid[i, j] == 1

    out, seen = [], set()
    for locs, between in [(a, False) for a in alleys] + [(f, True) for f in footways]:
        xs, ys = lonlat_to_tile(np.array([p[0] for p in locs]), np.array([p[1] for p in locs]), 21)
        mpc = _metres_per_cell21(locs[0][1])
        for k in range(len(locs) - 1):
            ax, ay, bx, by = xs[k], ys[k], xs[k + 1], ys[k + 1]
            seg = float(np.hypot(bx - ax, by - ay))
            if seg == 0:
                continue
            ux, uy = (bx - ax) / seg, (by - ay) / seg
            for i in range(int(seg * mpc // SAMPLE_M) + 1):
                d = min(seg, i * SAMPLE_M / mpc)
                px, py = ax + ux * d, ay + uy * d
                if between:
                    # Prédio dos dois lados: o caminho passa entre construções.
                    sides = [any(built((px + s * -uy * m / mpc) * 2, (py + s * ux * m / mpc) * 2) for m in SIDE_M) for s in (1, -1)]
                    if not all(sides):
                        continue
                cell = (int(px), int(py))
                if cell in seen:
                    continue
                seen.add(cell)
                lon = px / 2**21 * 360 - 180
                lat = float(np.degrees(np.arctan(np.sinh(np.pi * (1 - 2 * py / 2**21)))))
                out.append((lon, lat))
    print(f"becos: {len(alleys)} service=alley, {len(footways)} footway/path, {len(buildings)} prédios, {len(out)} pontos")
    return out


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
    counts = [0] * 12

    def add(kind, lon, lat):
        if not (min_lon <= lon <= max_lon and min_lat <= lat <= max_lat):
            return
        x, y = lonlat_to_tile(np.array([lon]), np.array([lat]), 21)
        p = (int(round(x[0] * UNIT)), int(round(y[0] * UNIT)), kind)
        if p not in pts:
            pts.add(p)
            counts[kind] += 1

    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("highway", "amenity", "building", "entrance", "shop", "leisure", "place"))
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
    if args.epoch >= ALLEY_FROM_EPOCH:
        for lon, lat in alley_points(pbf, region["bbox"]):
            add(ALLEY, lon, lat)
    body = bytearray(varint(len(pts)))
    px = py = 0
    for x, y, kind in sorted(pts):
        body += bytes([kind]) + varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = args.out_dir / f"{args.region}_e{args.epoch}_traffic.bin"
    out.write_bytes(b"TRF1" + gzip.compress(bytes(body), compresslevel=9, mtime=0))
    print(f"{len(pts)} pontos (semáforo {counts[0]}, pare {counts[1]}, preferência {counts[2]}, faixa {counts[3]}, "
          f"entrada {counts[4]}, ônibus {counts[5]}, comércio {counts[6]}, bar {counts[7]}, escola {counts[8]}, "
          f"praça {counts[9]}, estádio {counts[10]}, beco {counts[11]}), {out.stat().st_size} bytes, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
