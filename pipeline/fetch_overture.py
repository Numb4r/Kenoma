"""Baixa do S3 o recorte do Overture Maps de uma região (0.23.0), na release fixada da época: os temas `buildings` e `places`
em `cache/overture/<release>/<região>_{buildings,places}.parquet`, só as colunas que o pipeline usa, em ordem de `id`.
Os geradores (`build_buildings.py`, `build_region.py`, `build_traffic.py` com `--overture`) só leem esse cache: sem rede, e
com o mesmo cache o pacote sai byte a byte igual.

Uso: .venv/bin/python fetch_overture.py --region campinas"""
import argparse
import json

import duckdb

from build_region import CACHE, ROOT

RELEASE = "2026-10-21.0"  # a mesma da medição da 0.22.2; a época 12 registra esta data
S3 = "s3://overturemaps-us-west-2/release"


def cache_paths(region: str, release: str = RELEASE):
    d = CACHE / "overture" / release
    return d / f"{region}_buildings.parquet", d / f"{region}_places.parquet"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--release", default=RELEASE)
    args = ap.parse_args()
    w, s, e, n = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]["bbox"]
    bld, plc = cache_paths(args.region, args.release)
    bld.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2';")
    box = f"bbox.xmax >= {w} AND bbox.xmin <= {e} AND bbox.ymax >= {s} AND bbox.ymin <= {n}"
    con.execute(f"""COPY (SELECT id, ST_AsWKB(geometry) AS wkb, height, num_floors, class, subtype, is_underground,
                  list_contains(list_transform(sources, lambda x: x.dataset), 'OpenStreetMap') AS from_osm,
                  list_transform(sources, lambda x: x.dataset) AS datasets
                  FROM read_parquet('{S3}/{args.release}/theme=buildings/type=building/*', hive_partitioning=1)
                  WHERE {box} ORDER BY id) TO '{bld}' (FORMAT parquet)""")
    con.execute(f"""COPY (SELECT id, ST_X(ST_Centroid(geometry)) AS lon, ST_Y(ST_Centroid(geometry)) AS lat, confidence,
                  operating_status, basic_category, taxonomy.primary AS category, taxonomy.hierarchy AS hierarchy,
                  names.primary AS name, list_transform(sources, lambda x: x.dataset) AS datasets
                  FROM read_parquet('{S3}/{args.release}/theme=places/type=place/*', hive_partitioning=1)
                  WHERE {box} ORDER BY id) TO '{plc}' (FORMAT parquet)""")
    for p in (bld, plc):
        cnt = con.execute(f"SELECT count(*) FROM '{p}'").fetchone()[0]
        print(f"{p.name}: {cnt} linhas, {p.stat().st_size} bytes")


if __name__ == "__main__":
    main()
