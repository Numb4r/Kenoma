"""Gera o pacote visual de uma região: ruas, água e áreas verdes só para desenhar (docs/fase0-spec.md,
seção 1, "Pacote visual"). Não muda o mundo: a grade de biomas continua sendo a única camada lógica.

Formato v2 (docs/fase0-spec.md): cada linha leva o sentido (mão única) e o nome da rua (só das principais e
secundárias, para rotular o mapa e para o tráfego respeitar a mão de direção).

Uso: python build_visual.py --region campinas [--epoch 0]
"""

import argparse
import gzip
import hashlib
import json
import math
import struct
from collections import defaultdict
from pathlib import Path

import numpy as np
import osmium
import shapely

from build_region import CACHE, OUT, PIPELINE, REGIONS_DIR, ROOT, ensure_source, lonlat_to_tile, load_rules

TILE_ZOOM = 15
EXTENT = 4096          # unidades por tile z15 (~0,25 m em Campinas)
MARGIN = 0.01          # sobra de cada tile, em tiles (~10 m): costura entre tiles sem emenda
VERSION = 2

# Classe da rua. A ordem do id é do mais largo para o mais estreito.
CLASS_NAMES = ["principal", "secundaria", "local", "pedestre"]
HIGHWAY_CLASS = {
    **dict.fromkeys(["motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link"], 0),
    **dict.fromkeys(["secondary", "secondary_link", "tertiary", "tertiary_link"], 1),
    **dict.fromkeys(["residential", "unclassified", "living_street", "service", "road"], 2),
    **dict.fromkeys(["footway", "pedestrian", "path", "steps", "cycleway", "track", "bridleway"], 3),
}
SKIP_SERVICE = {"driveway", "parking_aisle", "drive-through"}

# Sentido da linha em relação à ordem dos pontos: 0 mão dupla, 1 só no sentido dos pontos, 2 só no contrário.
ONEWAY_TWO, ONEWAY_FORWARD, ONEWAY_REVERSE = 0, 1, 2
NAMED_CLASSES = (0, 1)   # só as ruas principais e secundárias levam o nome (rótulos discretos, pacote pequeno)


def oneway_of(tags, cls: int) -> int:
    """Mão única do OSM: `oneway=yes|true|1`, `-1`, rotatória e vias expressas (implícito). Só vale para ruas de carro."""
    if cls == 3:
        return ONEWAY_TWO
    v = tags.get("oneway")
    if v in ("-1", "reverse"):
        return ONEWAY_REVERSE
    if v in ("yes", "true", "1"):
        return ONEWAY_FORWARD
    if v in ("no", "false", "0"):
        return ONEWAY_TWO
    if tags.get("junction") in ("roundabout", "circular") or tags.get("highway") in ("motorway", "motorway_link"):
        return ONEWAY_FORWARD
    return ONEWAY_TWO

KIND_WATER, KIND_GREEN = 1, 2
POLY_TOL_M = 2.0
LINE_TOL_M = 1.0


def varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def zigzag(n: int) -> int:
    return (n << 1) ^ (n >> 63)


def encode_points(pts: list[tuple[int, int]]) -> bytes:
    out = bytearray(varint(len(pts)))
    px = py = 0
    for x, y in pts:
        out += varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    return bytes(out)


def quantize(coords: np.ndarray, tx: int, ty: int) -> list[tuple[int, int]]:
    q = np.rint((coords - np.array([tx, ty])) * EXTENT).astype(np.int64)
    pts = [(int(x), int(y)) for x, y in q]
    return [p for i, p in enumerate(pts) if i == 0 or p != pts[i - 1]]


def highway_class(tags) -> int | None:
    cls = HIGHWAY_CLASS.get(tags.get("highway", ""))
    if cls is None:
        return None
    if tags.get("tunnel") not in (None, "no") or tags.get("area") == "yes":
        return None
    if tags.get("highway") == "service" and tags.get("service") in SKIP_SERVICE:
        return None
    if tags.get("indoor") or tags.get("access") == "private" and cls == 3:
        return None
    return cls


def collect(pbf: Path, rules: dict, keys: list[str], bbox: list[float]):
    """Devolve (ruas, polígonos) em coordenadas de tile z15 fracionárias, já simplificados e cortados no bbox."""
    min_lon, min_lat, max_lon, max_lat = bbox
    pad = 0.1
    near = (min_lon - pad, min_lat - pad, max_lon + pad, max_lat + pad)
    lat0 = (min_lat + max_lat) / 2
    tile_m = 40075016.686 * math.cos(math.radians(lat0)) / 2 ** TILE_ZOOM
    poly_tol, line_tol = POLY_TOL_M / tile_m, LINE_TOL_M / tile_m

    def to_tile(x, y):
        return lonlat_to_tile(x, y, TILE_ZOOM)

    cx0, cy1 = lonlat_to_tile(np.array([min_lon]), np.array([min_lat]), TILE_ZOOM)
    cx1, cy0 = lonlat_to_tile(np.array([max_lon]), np.array([max_lat]), TILE_ZOOM)
    clip = shapely.box(cx0[0], cy0[0], cx1[0], cy1[0])
    wkb = osmium.geom.WKBFactory()
    all_keys = sorted(set(keys) | {"highway"})

    roads: list[tuple[int, object, str, int]] = []
    polys: list[tuple[int, object]] = []
    seen = 0
    fp = (osmium.FileProcessor(str(pbf)).with_locations().with_areas().with_filter(osmium.filter.KeyFilter(*all_keys)))
    for obj in fp:
        tags = obj.tags
        if obj.is_way() and "highway" in tags:
            cls = highway_class(tags)
            if cls is None:
                continue
            nodes = obj.nodes
            probe = (nodes[0], nodes[len(nodes) // 2], nodes[-1])
            if not any(n.location.valid() and near[0] <= n.location.lon <= near[2] and near[1] <= n.location.lat <= near[3] for n in probe):
                continue
            try:
                geom = shapely.from_wkb(wkb.create_linestring(obj))
            except (RuntimeError, osmium.InvalidLocationError):
                continue
            geom = shapely.transform(geom, to_tile, interleaved=False)
            if not geom.intersects(clip):
                continue
            geom = geom.intersection(clip).simplify(line_tol, preserve_topology=False)
            if not geom.is_empty:
                name = (tags.get("name") or "").strip() if cls in NAMED_CLASSES else ""
                roads.append((cls, geom, name, oneway_of(tags, cls)))
            seen += 1
            continue
        # água e verde: as mesmas regras do mapa lógico (shared/biomes.json), biomas 2 e 3
        kind_geom = "area" if obj.is_area() else ("line" if obj.is_way() else None)
        if kind_geom is None:
            continue
        matches = [m for tag in keys if (v := tags.get(tag)) is not None
                   for m in rules.get((tag, v), ()) if m[1] == kind_geom and m[0] in (2, 3)]
        if not matches:
            continue
        try:
            raw = wkb.create_multipolygon(obj) if kind_geom == "area" else wkb.create_linestring(obj)
        except (RuntimeError, osmium.InvalidLocationError):
            continue
        geom = shapely.from_wkb(raw)
        if not geom.intersects(shapely.box(*bbox)):
            continue
        biome_id, _, buffer_m = matches[0]
        geom = shapely.transform(geom, to_tile, interleaved=False)
        if kind_geom == "line":
            geom = geom.buffer(buffer_m / tile_m / 2)  # largura total = buffer do bioma
        geom = geom.buffer(0).intersection(clip)
        geom = geom.simplify(poly_tol, preserve_topology=True)
        if not geom.is_empty:
            polys.append((KIND_WATER if biome_id == 3 else KIND_GREEN, geom))
    print(f"ruas {len(roads)}, polígonos {len(polys)}")
    return roads, polys


def parts(geom, want: str):
    """Pedaços simples de uma geometria: 'line' (LineString) ou 'poly' (Polygon)."""
    if geom.is_empty:
        return
    if hasattr(geom, "geoms"):
        for g in geom.geoms:
            yield from parts(g, want)
    elif want == "line" and geom.geom_type == "LineString":
        yield geom
    elif want == "poly" and geom.geom_type == "Polygon":
        yield geom


def build_tiles(roads, polys) -> dict[tuple[int, int], tuple[list, list]]:
    tiles: dict[tuple[int, int], tuple[list, list]] = defaultdict(lambda: ([], []))
    for cls, geom, name, oneway in roads:
        for line in parts(geom, "line"):
            minx, miny, maxx, maxy = line.bounds
            for ty in range(math.floor(miny - MARGIN), math.floor(maxy + MARGIN) + 1):
                for tx in range(math.floor(minx - MARGIN), math.floor(maxx + MARGIN) + 1):
                    box = shapely.box(tx - MARGIN, ty - MARGIN, tx + 1 + MARGIN, ty + 1 + MARGIN)
                    if not line.intersects(box):
                        continue
                    for piece in parts(line.intersection(box), "line"):
                        pts = quantize(np.asarray(piece.coords), tx, ty)
                        if len(pts) >= 2:
                            tiles[(tx, ty)][0].append((cls, oneway, name, pts))
    for kind, geom in polys:
        for poly in parts(geom, "poly"):
            minx, miny, maxx, maxy = poly.bounds
            for ty in range(math.floor(miny - MARGIN), math.floor(maxy + MARGIN) + 1):
                for tx in range(math.floor(minx - MARGIN), math.floor(maxx + MARGIN) + 1):
                    box = shapely.box(tx - MARGIN, ty - MARGIN, tx + 1 + MARGIN, ty + 1 + MARGIN)
                    if not poly.intersects(box):
                        continue
                    # O polígono vai inteiro, sem corte na borda do tile: um corte apareceria como uma
                    # linha de contorno no meio da área quando o app desenha a borda.
                    rings = [quantize(np.asarray(r.coords)[:-1], tx, ty) for r in [poly.exterior, *poly.interiors]]
                    rings = [r for r in rings if len(r) >= 3]
                    if rings:
                        tiles[(tx, ty)][1].append((kind, rings))
    return tiles


def encode_tile(lines, polys, name_ids) -> bytes:
    out = bytearray(varint(len(lines)))
    for cls, oneway, name, pts in lines:
        out += bytes([cls, oneway]) + varint(name_ids.get(name, 0)) + encode_points(pts)
    out += varint(len(polys))
    for kind, rings in polys:
        out += bytes([kind]) + varint(len(rings))
        for ring in rings:
            out += encode_points(ring)
    return bytes(out)


def encode(tiles) -> bytes:
    # Tabela de nomes no começo do stream: ids de 1 em diante, em ordem alfabética (o arquivo sai igual byte a byte).
    names = sorted({n for lines, _ in tiles.values() for _, _, n, _ in lines if n})
    name_ids = {n: i + 1 for i, n in enumerate(names)}
    body = bytearray(varint(len(names)))
    for n in names:
        raw = n.encode("utf-8")
        body += varint(len(raw)) + raw
    for (tx, ty) in sorted(tiles):
        payload = encode_tile(*tiles[(tx, ty)], name_ids)
        body += struct.pack("<III", tx, ty, len(payload)) + payload
    header = struct.pack("<4sHBHI", b"VIS1", VERSION, TILE_ZOOM, EXTENT, len(tiles))
    # mtime=0 deixa o gzip reprodutível, e com ele o SHA-256.
    return header + gzip.compress(bytes(body), compresslevel=9, mtime=0)


def read_varint(buf: bytes, i: int) -> tuple[int, int]:
    n = shift = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        if not b & 0x80:
            return n, i
        shift += 7


def decode_points(buf: bytes, i: int) -> tuple[list[tuple[int, int]], int]:
    n, i = read_varint(buf, i)
    pts, x, y = [], 0, 0
    for _ in range(n):
        dx, i = read_varint(buf, i)
        dy, i = read_varint(buf, i)
        x += (dx >> 1) ^ -(dx & 1)
        y += (dy >> 1) ^ -(dy & 1)
        pts.append((x, y))
    return pts, i


def decode(data: bytes):
    magic, version, zoom, extent, count = struct.unpack("<4sHBHI", data[:13])
    assert magic == b"VIS1" and version == VERSION and zoom == TILE_ZOOM and extent == EXTENT
    body = gzip.decompress(data[13:])
    names = [""]
    n_names, i = read_varint(body, 0)
    for _ in range(n_names):
        ln, i = read_varint(body, i)
        names.append(body[i:i + ln].decode("utf-8"))
        i += ln
    tiles = {}
    for _ in range(count):
        tx, ty, ln = struct.unpack("<III", body[i:i + 12])
        i += 12
        end, j = i + ln, i
        n, j = read_varint(body, j)
        lines = []
        for _ in range(n):
            cls, oneway = body[j], body[j + 1]
            nid, j = read_varint(body, j + 2)
            pts, j = decode_points(body, j)
            lines.append((cls, oneway, names[nid], pts))
        n, j = read_varint(body, j)
        polys = []
        for _ in range(n):
            kind = body[j]
            nr, j = read_varint(body, j + 1)
            rings = []
            for _ in range(nr):
                pts, j = decode_points(body, j)
                rings.append(pts)
            polys.append((kind, rings))
        assert j == end
        tiles[(tx, ty)] = (lines, polys)
        i = end
    return tiles


def write_preview(tiles, path: Path, step_m: float = 12.0) -> None:
    import rasterio
    from rasterio.features import rasterize
    from rasterio.transform import Affine
    xs = [t[0] for t in tiles]
    ys = [t[1] for t in tiles]
    x0, y0 = min(xs), min(ys)
    w, h = max(xs) - x0 + 1, max(ys) - y0 + 1
    px = int(round(1039 / step_m))  # pixels por tile
    transform = Affine(1 / px, 0, x0, 0, 1 / px, y0)
    layers = {"green": [], "water": [], "road": [[], [], [], []]}
    for (tx, ty), (lines, polys) in tiles.items():
        for kind, rings in polys:
            geoms = [shapely.Polygon([((tx + x / EXTENT), (ty + y / EXTENT)) for x, y in r]) for r in rings]
            outer = geoms[0].buffer(0)
            for hole in geoms[1:]:
                outer = outer.difference(hole.buffer(0))
            layers["water" if kind == KIND_WATER else "green"].append(outer)
        for cls, _oneway, _name, pts in lines:
            layers["road"][cls].append(shapely.LineString([((tx + x / EXTENT), (ty + y / EXTENT)) for x, y in pts]))
    img = np.zeros((h * px, w * px, 3), dtype=np.uint8)
    img[:] = (40, 36, 48)
    shape = (h * px, w * px)
    def paint(geoms, color):
        if not geoms:
            return
        mask = rasterize([(g, 1) for g in geoms], out_shape=shape, transform=transform, all_touched=True)
        img[mask == 1] = color
    paint(layers["green"], (70, 110, 80))
    paint(layers["water"], (60, 110, 200))
    for cls, color in [(3, (120, 120, 130)), (2, (170, 170, 180)), (1, (220, 200, 140)), (0, (255, 160, 90))]:
        paint(layers["road"][cls], color)
    with rasterio.open(path, "w", driver="PNG", width=shape[1], height=shape[0], count=3, dtype="uint8") as dst:
        dst.write(img.transpose(2, 0, 1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", required=True)
    parser.add_argument("--epoch", type=int, default=0)
    args = parser.parse_args()

    region = json.loads((PIPELINE / "regions.json").read_text())[args.region]
    biomes = json.loads((ROOT / "shared" / "biomes.json").read_text())
    rules, keys = load_rules(biomes)

    pbf = ensure_source(region["source"])
    roads, polys = collect(pbf, rules, keys, region["bbox"])
    tiles = build_tiles(roads, polys)
    data = encode(tiles)
    assert decode(data).keys() == tiles.keys()

    REGIONS_DIR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    path = REGIONS_DIR / f"{args.region}_e{args.epoch}_vis.bin"
    path.write_bytes(data)
    n_named = sum(1 for v in tiles.values() for l in v[0] if l[2])
    n_oneway = sum(1 for v in tiles.values() for l in v[0] if l[1])
    print(f"{n_named} polilinhas com nome, {n_oneway} de mão única")
    n_lines = sum(len(v[0]) for v in tiles.values())
    n_polys = sum(len(v[1]) for v in tiles.values())
    print(f"{len(tiles)} tiles z{TILE_ZOOM}, {n_lines} polilinhas, {n_polys} polígonos")
    print(f"{path.relative_to(ROOT)}  {len(data) / 1e6:.2f} MB")
    write_preview(decode(data), OUT / f"{args.region}_vis_preview.png")
    print(f"sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
