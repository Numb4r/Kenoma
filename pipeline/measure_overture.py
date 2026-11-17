"""Medição do Overture Maps contra o OSM que o Kenoma já usa (0.22.2, só pipeline: nada vai para o app nem para os pacotes).

Temas `buildings` e `places` da release pública do Overture (S3 `overturemaps-us-west-2`), lidos com DuckDB direto dos
arquivos Parquet. Três recortes de ~1,3 km: o Centro de Campinas, o Ouro Verde (bairro periférico) e o entorno da Avenida
Paulista. Para cada um: prédios do OSM (o nosso `*_bldg.bin`), prédios do Overture e os que só o Overture tem (nenhuma
fonte OpenStreetMap), altura ou andares, classe ou tipo, POIs por categoria nos dois, e uma imagem (OSM em azul, só
Overture em laranja). Escreve `out/overture/medicao.json` e as imagens; o documento é `docs/overture-medicao.md`.

Uso: .venv/bin/python measure_overture.py"""
import gzip
import json
import math
from pathlib import Path

import duckdb
import numpy as np
import osmium
import shapely
from PIL import Image, ImageDraw

from build_region import ROOT, ensure_source

RELEASE = "2026-10-21.0"
S3 = f"s3://overturemaps-us-west-2/release/{RELEASE}"
OUT = ROOT / "pipeline/out/overture"
HALF = 0.0062  # graus: ~650 m de cada lado do centro
CUTS = {
    "campinas_centro": ("campinas", -22.9056, -47.0608),
    "campinas_ouro_verde": ("campinas", -22.9733, -47.1368),
    "sao_paulo_paulista": ("sao_paulo", -23.5614, -46.6559),
}
PACKS = {"campinas": ROOT / "app/assets/regions/campinas_e0_bldg.bin", "sao_paulo": ROOT / "pipeline/out/regions/sao_paulo_e0_bldg.bin"}
POI_GROUPS = ["comercio", "bares_restaurantes", "igrejas", "escolas", "pracas"]


def tile_to_lonlat(x, y, z=21):
    n = 2.0 ** z
    return x / n * 360 - 180, math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))


def read_pack(path: Path):
    """Os prédios do `BLD1` (contorno em lon/lat, tipo, andares)."""
    b = gzip.decompress(path.read_bytes()[4:])
    i = 0

    def v():
        nonlocal i
        r = s = 0
        while True:
            c = b[i]
            i += 1
            r |= (c & 0x7F) << s
            if c < 0x80:
                return r
            s += 7

    def zz():
        x = v()
        return (x >> 1) ^ -(x & 1)

    types = []
    for _ in range(v()):
        n = v()
        types.append(b[i:i + n].decode())
        i += n
    out = []
    px = py = 0
    for _ in range(v()):
        t = types[v()]
        lv = b[i]
        i += 2
        pts = []
        for j in range(v()):
            px += zz()
            py += zz()
            if j == 0:
                x0, y0 = px, py
            pts.append(tile_to_lonlat(px / 64, py / 64))
        px, py = x0, y0
        out.append((pts, t, lv))
    return out


def osm_pois(pbf: Path, boxes: dict):
    """POIs do OSM por grupo em cada recorte (nós e o centro das áreas), com as mesmas regras do `build_traffic.py` mais
    `amenity=place_of_worship`."""
    counts = {k: dict.fromkeys(POI_GROUPS, 0) for k in boxes}

    def group(tags):
        if tags.get("shop") is not None:
            return "comercio"
        a = tags.get("amenity")
        if a in ("bar", "pub", "restaurant", "cafe", "fast_food"):
            return "bares_restaurantes"
        if a == "place_of_worship":
            return "igrejas"
        if a in ("school", "kindergarten", "college", "university"):
            return "escolas"
        if tags.get("leisure") in ("park", "garden") or tags.get("place") == "square":
            return "pracas"
        return None

    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("amenity", "shop", "leisure", "place"))
    for obj in fp:
        g = group(obj.tags)
        if g is None:
            continue
        if obj.is_node():
            if not obj.location.valid():
                continue
            lon, lat = obj.location.lon, obj.location.lat
        elif obj.is_way():
            locs = [(n.lon, n.lat) for n in obj.nodes if n.location.valid()]
            if not locs:
                continue
            lon, lat = sum(p[0] for p in locs) / len(locs), sum(p[1] for p in locs) / len(locs)
        else:
            continue
        for k, (w, s, e, n) in boxes.items():
            if w <= lon <= e and s <= lat <= n:
                counts[k][g] += 1
    return counts


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2';")
    boxes = {k: (lon - HALF, lat - HALF, lon + HALF, lat + HALF) for k, (_, lat, lon) in CUTS.items()}
    packs = {r: read_pack(p) for r, p in PACKS.items()}
    result = {"release": RELEASE, "half_deg": HALF, "cuts": {}}
    for key, (region, lat, lon) in CUTS.items():
        w, s, e, n = boxes[key]
        osm = [(pts, t, lv) for pts, t, lv in packs[region] if w <= sum(p[0] for p in pts) / len(pts) <= e and s <= sum(p[1] for p in pts) / len(pts) <= n]
        q = f"""SELECT ST_AsWKB(geometry) AS g, height, num_floors, class, subtype,
                       list_contains(list_transform(sources, lambda x: x.dataset), 'OpenStreetMap') AS from_osm
                FROM read_parquet('{S3}/theme=buildings/type=building/*', hive_partitioning=1)
                WHERE bbox.xmin > {w} AND bbox.xmax < {e} AND bbox.ymin > {s} AND bbox.ymax < {n}"""
        ov = con.execute(q).fetchall()
        only = [r for r in ov if not r[5]]
        q2 = f"""SELECT basic_category, taxonomy.hierarchy[1] AS top FROM read_parquet('{S3}/theme=places/type=place/*', hive_partitioning=1)
                 WHERE bbox.xmin > {w} AND bbox.xmax < {e} AND bbox.ymin > {s} AND bbox.ymax < {n}"""
        pl = dict.fromkeys(POI_GROUPS, 0)
        total_places = 0
        for cat, top in con.execute(q2).fetchall():
            total_places += 1
            cat = cat or ""
            if top == "shopping":
                pl["comercio"] += 1
            elif top == "food_and_drink":
                pl["bares_restaurantes"] += 1
            elif "place_of_worship" in cat or "church" in cat:
                pl["igrejas"] += 1
            elif top == "education":
                pl["escolas"] += 1
            elif any(x in cat for x in ("park", "plaza", "square")):
                pl["pracas"] += 1
        result["cuts"][key] = {
            "center": [lat, lon],
            "osm_buildings": len(osm),
            "osm_with_levels": sum(1 for o in osm if o[2] > 0),
            "osm_with_type": sum(1 for o in osm if o[1] != "yes"),
            "overture_buildings": len(ov),
            "overture_from_osm": len(ov) - len(only),
            "overture_only": len(only),
            "overture_with_height_or_floors": sum(1 for r in ov if r[1] is not None or r[2] is not None),
            "overture_only_with_height_or_floors": sum(1 for r in only if r[1] is not None or r[2] is not None),
            "overture_with_class_or_subtype": sum(1 for r in ov if r[3] is not None or r[4] is not None),
            "overture_places_total": total_places,
            "overture_places": pl,
        }
        # A imagem: OSM em azul, só Overture em laranja, sobre fundo claro.
        size = 1000
        img = Image.new("RGB", (size, size), (238, 236, 230))
        d = ImageDraw.Draw(img)

        def xy(px, py):
            return ((px - w) / (e - w) * size, (n - py) / (n - s) * size)

        for r in only:
            g = shapely.from_wkb(bytes(r[0]))
            for poly in getattr(g, "geoms", [g]):
                if poly.geom_type == "Polygon":
                    d.polygon([xy(*c) for c in poly.exterior.coords], fill=(232, 120, 40))
        for pts, _, _ in osm:
            d.polygon([xy(*c) for c in pts], fill=(52, 96, 190))
        d.rectangle([0, 0, 520, 34], fill=(255, 255, 255))
        d.text((8, 10), f"{key}  OSM {len(osm)} (azul)  so Overture {len(only)} (laranja)  {RELEASE}", fill=(20, 20, 20))
        img.save(OUT / f"{key}.png")
        print(key, json.dumps(result["cuts"][key], ensure_ascii=False), flush=True)
    # Quanto somaria aos pacotes: os prédios só do Overture nas regiões inteiras, no tamanho médio de um prédio no BLD1.
    regions = json.loads((ROOT / "pipeline/regions.json").read_text())
    result["regions"] = {}
    for region, path in PACKS.items():
        w, s, e, n = regions[region]["bbox"]
        cnt = con.execute(f"""SELECT count(*) FROM read_parquet('{S3}/theme=buildings/type=building/*', hive_partitioning=1)
              WHERE bbox.xmin > {w} AND bbox.xmax < {e} AND bbox.ymin > {s} AND bbox.ymax < {n}
              AND NOT list_contains(list_transform(sources, lambda x: x.dataset), 'OpenStreetMap')""").fetchone()[0]
        per = path.stat().st_size / max(1, len(packs[region]))
        result["regions"][region] = {"overture_only": cnt, "bytes_per_building": round(per, 1), "estimated_bytes": round(cnt * per)}
        print(region, result["regions"][region], flush=True)
    pbf = ensure_source(regions["campinas"]["source"])
    poi = osm_pois(pbf, boxes)
    for k in CUTS:
        result["cuts"][k]["osm_places"] = poi[k]
    (OUT / "medicao.json").write_text(json.dumps(result, ensure_ascii=False, indent=1))
    print(json.dumps(poi, ensure_ascii=False))


if __name__ == "__main__":
    main()
