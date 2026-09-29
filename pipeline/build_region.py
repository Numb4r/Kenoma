"""Gera o pacote de biomas de uma região (docs/fase0-spec.md, seção 1).

Uso: python build_region.py --region campinas [--epoch 0]
"""

import argparse
import gzip
import hashlib
import json
import math
import struct
import urllib.request
from collections import defaultdict
from pathlib import Path

import numpy as np
import osmium
import rasterio
import shapely
from pyproj import Transformer
from rasterio.features import rasterize
from rasterio.transform import Affine

ROOT = Path(__file__).resolve().parent.parent
PIPELINE = ROOT / "pipeline"
CACHE = PIPELINE / "cache"
OUT = PIPELINE / "out"
REGIONS_DIR = ROOT / "app" / "assets" / "regions"

METRIC_CRS = "EPSG:31983"  # SIRGAS 2000 / UTM 23S, cobre Campinas

PREVIEW_COLORS = {
    0: (40, 36, 48),     # Vazio
    1: (150, 150, 160),  # Urbano
    2: (70, 150, 80),    # Verde
    3: (60, 110, 200),   # Água
    4: (215, 190, 140),  # Residencial
}


def lonlat_to_tile(lon: np.ndarray, lat: np.ndarray, zoom: int) -> tuple[np.ndarray, np.ndarray]:
    """Coordenada de tile slippy map em ponto flutuante."""
    n = 2 ** zoom
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - np.arcsinh(np.tan(np.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def load_rules(biomes: dict) -> tuple[dict, list[str]]:
    """Mapeia (tag, valor) para a lista de (bioma, geometria, buffer)."""
    rules: dict[tuple[str, str], list[tuple[int, str, float]]] = defaultdict(list)
    for biome in biomes["biomes"]:
        for rule in biome["osm"]:
            for value in rule["values"]:
                rules[(rule["tag"], value)].append(
                    (biome["id"], rule["geometry"], float(rule.get("buffer_m", 0))))
    keys = sorted({tag for tag, _ in rules})
    return rules, keys


def ensure_source(url: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / url.rsplit("/", 1)[-1]
    if not path.exists():
        print(f"baixando {url} para {path}")
        tmp = path.with_suffix(".part")
        urllib.request.urlretrieve(url, tmp)
        tmp.rename(path)
    return path


def collect(pbf: Path, rules: dict, keys: list[str], bbox: list[float]) -> dict[int, list]:
    """Lê o OSM e devolve as geometrias em lon/lat por bioma. Linhas já saem bufferizadas."""
    clip = shapely.box(*bbox)
    to_metric = Transformer.from_crs("EPSG:4326", METRIC_CRS, always_xy=True)
    to_geo = Transformer.from_crs(METRIC_CRS, "EPSG:4326", always_xy=True)
    wkb = osmium.geom.WKBFactory()
    geoms: dict[int, list] = defaultdict(list)

    fp = (osmium.FileProcessor(str(pbf))
          .with_locations()
          .with_areas()
          .with_filter(osmium.filter.KeyFilter(*keys)))
    for obj in fp:
        if obj.is_area():
            kind = "area"
        elif obj.is_way():
            kind = "line"
        else:
            continue
        matches = [m for tag in keys if (v := obj.tags.get(tag)) is not None
                   for m in rules.get((tag, v), ()) if m[1] == kind]
        if not matches:
            continue
        try:
            raw = wkb.create_multipolygon(obj) if kind == "area" else wkb.create_linestring(obj)
        except (RuntimeError, osmium.InvalidLocationError):
            continue  # geometria quebrada no OSM
        geom = shapely.from_wkb(raw)
        if not geom.intersects(clip):
            continue
        for biome_id, _, buffer_m in matches:
            if kind == "line":
                metric = shapely.transform(geom, to_metric.transform, interleaved=False)
                geom_out = shapely.transform(metric.buffer(buffer_m),
                                             to_geo.transform, interleaved=False)
            else:
                geom_out = geom
            geoms[biome_id].append(geom_out)
    return geoms


def build_grid(geoms: dict[int, list], biomes: dict, bbox: list[float], zoom: int):
    """Rasteriza pelo centro da célula, da menor para a maior prioridade."""
    min_lon, min_lat, max_lon, max_lat = bbox
    fx0, fy0 = lonlat_to_tile(np.array([min_lon]), np.array([max_lat]), zoom)
    fx1, fy1 = lonlat_to_tile(np.array([max_lon]), np.array([min_lat]), zoom)
    x0, y0 = int(fx0[0]), int(fy0[0])
    width, height = int(fx1[0]) - x0 + 1, int(fy1[0]) - y0 + 1

    def to_grid(x, y):
        tx, ty = lonlat_to_tile(x, y, zoom)
        return tx - x0, ty - y0

    grid = np.zeros((height, width), dtype=np.uint8)
    for biome in sorted(biomes["biomes"], key=lambda b: b["priority"]):
        shapes = [(shapely.transform(g, to_grid, interleaved=False), biome["id"])
                  for g in geoms.get(biome["id"], [])]
        if shapes:
            rasterize(shapes, out=grid, transform=Affine.identity(), all_touched=False)
    return grid, x0, y0


def encode(grid: np.ndarray, x0: int, y0: int, zoom: int) -> bytes:
    height, width = grid.shape
    header = struct.pack("<4sHBIIII", b"VEU1", 1, zoom, x0, y0, width, height)
    assert len(header) == 23
    # mtime=0 deixa o gzip reprodutível, e com ele o SHA-256.
    return header + gzip.compress(grid.tobytes(), compresslevel=9, mtime=0)


def decode(data: bytes) -> tuple[np.ndarray, int, int, int]:
    magic, version, zoom, x0, y0, width, height = struct.unpack("<4sHBIIII", data[:23])
    assert magic == b"VEU1" and version == 1
    grid = np.frombuffer(gzip.decompress(data[23:]), dtype=np.uint8).reshape(height, width)
    return grid, zoom, x0, y0


def write_preview(grid: np.ndarray, path: Path) -> None:
    lut = np.zeros((256, 3), dtype=np.uint8)
    for biome_id, rgb in PREVIEW_COLORS.items():
        lut[biome_id] = rgb
    rgb = lut[grid].transpose(2, 0, 1)
    with rasterio.open(path, "w", driver="PNG", width=grid.shape[1], height=grid.shape[0],
                       count=3, dtype="uint8") as dst:
        dst.write(rgb)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", required=True)
    parser.add_argument("--epoch", type=int, default=0)
    args = parser.parse_args()

    region = json.loads((PIPELINE / "regions.json").read_text())[args.region]
    biomes = json.loads((ROOT / "shared" / "biomes.json").read_text())
    rules, keys = load_rules(biomes)

    pbf = ensure_source(region["source"])
    geoms = collect(pbf, rules, keys, region["bbox"])
    grid, x0, y0 = build_grid(geoms, biomes, region["bbox"], region["zoom"])

    data = encode(grid, x0, y0, region["zoom"])
    assert np.array_equal(decode(data)[0], grid)

    REGIONS_DIR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bin_path = REGIONS_DIR / f"{args.region}_e{args.epoch}.bin"
    bin_path.write_bytes(data)
    preview_path = OUT / f"{args.region}_preview.png"
    write_preview(grid, preview_path)

    counts = np.bincount(grid.ravel(), minlength=len(PREVIEW_COLORS))
    names = {b["id"]: b["name"] for b in biomes["biomes"]}
    print(f"grade {grid.shape[1]}x{grid.shape[0]} em z{region['zoom']}, origem ({x0}, {y0})")
    for biome_id, count in enumerate(counts[:len(names)]):
        print(f"  {names[biome_id]:<12} {100 * count / grid.size:5.1f}%")
    print(f"{bin_path.relative_to(ROOT)}  {len(data) / 1e6:.2f} MB")
    print(f"{preview_path.relative_to(ROOT)}")
    print(f"sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
