"""Gera as fixtures do oráculo do fallback sob demanda (app/test/fixtures/fallback/).

Para cada tile z15 grava `<tx>_<ty>.json.gz`, no formato da resposta da Overpass, só com o que `overpassQuery` pediria
(mesmas tags, mesmas caixas), e `<tx>_<ty>.grid`, o recorte de 64x64 células de `campinas_e0.bin`. A seleção imita a da
Overpass: uma way entra se tem nó ou segmento na caixa; uma relation entra se tem way membro assim. A geometria vem
inteira. O teste em Dart confere que as caixas gravadas aqui aparecem na consulta.

Uso (a leitura do extrato leva alguns minutos, por isso o recorte fica em `--store`):
  .venv/bin/python export_fixture.py --pbf /caminho/sudeste-latest.osm.pbf --store /tmp/loja.pkl [--tiles 12134:18552 ...]
"""

import argparse
import gzip
import json
import math
import pickle
from pathlib import Path

import numpy as np
import osmium
import shapely

from build_region import ROOT, decode, load_rules
from build_visual import HIGHWAY_CLASS

OUT_DIR = ROOT / "app/test/fixtures/fallback"
REGION = json.loads((ROOT / "pipeline/regions.json").read_text())["campinas"]
BIOMES = json.loads((ROOT / "shared/biomes.json").read_text())

# Tags que o app lê; o resto da resposta da Overpass só faria a fixture crescer.
EXTRA_TAGS = {"type", "area", "tunnel", "service", "indoor", "access", "oneway", "junction", "name"}

MARGIN_M = 30.0        # margem da caixa além do maior buffer

TILES: list[tuple[int, int, str]] = [
    (12100, 18526, "centro de Campinas, denso"),
    (12099, 18518, "Barão Geraldo e Unicamp"),
    (12095, 18532, "residencial, DIC"),
    (12102, 18520, "rodovia Dom Pedro"),
    (12095, 18525, "rodovia Anhanguera"),
    (12101, 18523, "Lagoa do Taquaral, relation de água"),
    (12100, 18523, "Parque Portugal, relation com buracos"),
    (12109, 18520, "mata com 21 buracos"),
]


def tile_bounds(tx: int, ty: int) -> tuple[float, float, float, float]:
    """(oeste, sul, leste, norte) do tile z15."""
    n = 2 ** 15

    def lat(y: float) -> float:
        return math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))

    return tx / n * 360 - 180, lat(ty + 1), (tx + 1) / n * 360 - 180, lat(ty)


def boxes(tx: int, ty: int, biomes: dict) -> list[tuple[float, float, float, float]]:
    """As caixas da consulta (oeste, sul, leste, norte) em graus, arredondadas como em `overpassQuery`."""
    w, s, e, n = tile_bounds(tx, ty)
    max_buffer = max(float(r.get("buffer_m", 0)) for b in biomes["biomes"] for r in b["osm"])
    d = max_buffer + MARGIN_M
    dlat = d / 110540.0
    dlon = d / (111320.0 * math.cos(math.radians(max(abs(s), abs(n)))))
    return [(round(w - dlon, 7), round(s - dlat, 7), round(e + dlon, 7), round(n + dlat, 7))]


def query_tags() -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    """(tag -> valores) das regras de área e das de linha, com as classes de rua nas linhas."""
    area: dict[str, set[str]] = {}
    line: dict[str, set[str]] = {"highway": set(HIGHWAY_CLASS)}
    for biome in BIOMES["biomes"]:
        for rule in biome["osm"]:
            target = area if rule["geometry"] == "area" else line
            target.setdefault(rule["tag"], set()).update(rule["values"])
    return area, line


def matches(tags, table: dict[str, set[str]]) -> bool:
    return any((v := tags.get(k)) is not None and v in vals for k, vals in table.items())


def build_store(pbf: Path) -> dict:
    """Lê do extrato as ways e relations que alguma consulta poderia pedir, perto da região."""
    area, line = query_tags()
    keys = [*area, *line, *EXTRA_TAGS]
    relations = {}
    needed: set[int] = set()
    for obj in osmium.FileProcessor(str(pbf), osmium.osm.RELATION):
        tags = obj.tags
        if tags.get("type") not in ("multipolygon", "boundary") or not matches(tags, area):
            continue
        members = [(m.type, m.ref, m.role) for m in obj.members]
        relations[obj.id] = ({t.k: t.v for t in tags if t.k in keys}, members)
        needed.update(ref for kind, ref, _ in members if kind == "w")
    print(f"{len(relations)} relations candidatas, {len(needed)} ways membros", flush=True)

    min_lon, min_lat, max_lon, max_lat = REGION["bbox"]
    pad = 1.0
    x0, x1 = int((min_lon - pad) * 1e7), int((max_lon + pad) * 1e7)
    y0, y1 = int((min_lat - pad) * 1e7), int((max_lat + pad) * 1e7)
    ways = {}
    seen = 0
    fp = (osmium.FileProcessor(str(pbf), osmium.osm.NODE | osmium.osm.WAY).with_locations()
          .with_filter(osmium.filter.EntityFilter(osmium.osm.WAY)))
    for way in fp:
        seen += 1
        tags = way.tags
        member = way.id in needed
        if not member and not matches(tags, area) and not matches(tags, line):
            continue
        nodes = [(n.x, n.y) if n.location.valid() else None for n in way.nodes]
        if not member and not any(p and x0 <= p[0] <= x1 and y0 <= p[1] <= y1 for p in nodes):
            continue
        ways[way.id] = ({t.k: t.v for t in tags if t.k in keys}, nodes)
    print(f"{seen} ways lidas, {len(ways)} guardadas", flush=True)
    return {"relations": relations, "ways": ways}


def line_of(nodes) -> shapely.LineString | None:
    pts = [(p[0] / 1e7, p[1] / 1e7) for p in nodes if p is not None]
    if len(pts) == 0:
        return None
    return shapely.LineString(pts if len(pts) > 1 else pts * 2)


class Index:
    """Busca espacial das ways da loja, com o mesmo critério de caixa da Overpass."""

    def __init__(self, store: dict) -> None:
        self.ids = []
        geoms = []
        for way_id, (_, nodes) in store["ways"].items():
            g = line_of(nodes)
            if g is not None:
                self.ids.append(way_id)
                geoms.append(g)
        self.geoms = np.array(geoms)
        self.tree = shapely.STRtree(self.geoms)
        self.relations_of: dict[int, list[int]] = {}
        for rel_id, (_, members) in store["relations"].items():
            for kind, ref, _ in members:
                if kind == "w":
                    self.relations_of.setdefault(ref, []).append(rel_id)

    def hits(self, box) -> set[int]:
        found = self.tree.query(shapely.box(*box), predicate="intersects")
        return {self.ids[i] for i in found}


def geometry(nodes) -> list:
    """`null` marca nó fora do extrato: a posição inválida do osmium."""
    return [p and {"lat": p[1] / 1e7, "lon": p[0] / 1e7} for p in nodes]


def element_way(way_id: int, store: dict) -> dict:
    tags, nodes = store["ways"][way_id]
    return {"type": "way", "id": way_id, "geometry": geometry(nodes), "tags": tags}


def element_relation(rel_id: int, store: dict) -> dict:
    tags, members = store["relations"][rel_id]
    out = []
    for kind, ref, role in members:
        # Membro node vem com lat/lon na Overpass; o app só olha as ways, então a fixture não os leva. Way sem geometria
        # é membro fora do extrato: a relation fica incompleta, como no osmium.
        if kind == "w":
            member = {"type": "way", "ref": ref, "role": role}
            if ref in store["ways"]:
                member["geometry"] = geometry(store["ways"][ref][1])
            out.append(member)
    return {"type": "relation", "id": rel_id, "members": out, "tags": tags}


def select(store: dict, index: Index, query_boxes: list) -> list[dict]:
    """O que a Overpass devolveria para as caixas: ways por tag, relations por tag e por membro."""
    area, line = query_tags()
    hit: set[int] = set()
    for box in query_boxes:
        hit |= index.hits(box)
    way_ids = [w for w in sorted(hit) if matches(store["ways"][w][0], area) or matches(store["ways"][w][0], line)]
    rel_ids = sorted({r for w in hit for r in index.relations_of.get(w, ())})
    return [element_way(w, store) for w in way_ids] + [element_relation(r, store) for r in rel_ids]


def write_fixture(tx: int, ty: int, store: dict, index: Index, grid: np.ndarray, x0: int, y0: int, out_dir: Path) -> int:
    query_boxes = boxes(tx, ty, BIOMES)
    payload = {"version": 0.6, "generator": "pipeline/export_fixture.py", "query_boxes": query_boxes,
               "elements": select(store, index, query_boxes)}
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    out_dir.mkdir(parents=True, exist_ok=True)
    gz_path = out_dir / f"{tx}_{ty}.json.gz"
    gz_path.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
    cx, cy = tx * 64 - x0, ty * 64 - y0
    assert cx >= 0 and cy >= 0 and cy + 64 <= grid.shape[0] and cx + 64 <= grid.shape[1], "tile fora da região"
    (out_dir / f"{tx}_{ty}.grid").write_bytes(grid[cy:cy + 64, cx:cx + 64].tobytes())
    return gz_path.stat().st_size


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pbf", type=Path, required=True)
    parser.add_argument("--store", type=Path, required=True, help="pickle com o recorte do extrato")
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    parser.add_argument("--tiles", nargs="*", default=None, help="tx:ty; padrão: os blocos de TILES")
    args = parser.parse_args()

    if args.store.exists():
        store = pickle.loads(args.store.read_bytes())
    else:
        store = build_store(args.pbf)
        args.store.write_bytes(pickle.dumps(store, protocol=pickle.HIGHEST_PROTOCOL))
    index = Index(store)
    grid, _, x0, y0 = decode((ROOT / "app/assets/regions/campinas_e0.bin").read_bytes())
    tiles = [tuple(map(int, t.split(":"))) for t in args.tiles] if args.tiles is not None else [t[:2] for t in TILES]
    total = 0
    for tx, ty in tiles:
        size = write_fixture(tx, ty, store, index, grid, x0, y0, args.out_dir)
        total += size
        print(f"{tx}_{ty}: {size} bytes")
    print(f"{len(tiles)} blocos, {total} bytes")


if __name__ == "__main__":
    main()
