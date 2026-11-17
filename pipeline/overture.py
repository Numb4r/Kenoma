"""O Overture Maps nos pacotes (0.23.0, época 12): as regras que juntam os prédios e os places do Overture aos do OSM. Os
geradores leem só o cache local de `fetch_overture.py` (release fixada), então o mesmo cache dá o mesmo pacote.

- **Prédios:** o OSM tem prioridade. Do Overture entram só os contornos sem nenhuma fonte OpenStreetMap, fora os
  subterrâneos, e só se não cobrirem um prédio do OSM (nem outro do Overture já aceito) em mais de `OVERLAP` da área do
  menor dos dois. Tipo: o `class` do Overture (os mesmos valores do `building=*` do OSM), senão `yes`. Andares: `num_floors`,
  senão `height` em andares de 3 m, senão 0 (o app estima pelo tamanho e pelo tipo, como hoje).
- **Places:** ficam os de `confidence` >= `MIN_CONFIDENCE` que não estão fechados (`operating_status`). O grupo do jogo sai da
  categoria (`group_of`). Um place com o mesmo grupo e nome parecido (`similar`) a até `MERGE_M` de um POI do OSM é o mesmo
  lugar e fica de fora: vale o do OSM.
- **Grupos:** comércio é todo o `shopping` (e doces e padarias, como `shop=*` no OSM); bar ou restaurante é o resto de
  `food_and_drink`; escola é `place_of_learning` fora os cursos (`specialty_school`); praça é `park` e `public_plaza`;
  estádio é `stadium_arena`; igreja e templo é `place_of_worship`.
- **Biomas:** um place que sobra conta como a tag do OSM equivalente (`OSM_TAG`) na área do prédio que o contém (do OSM ou
  do Overture), com as mesmas regras de `shared/biomes.json`. Comércio comum não vira Iluminado, como no OSM: só shopping,
  supermercado, loja de departamentos e feira; igrejas e templos viram Sagrado.
"""
import math
import re
import unicodedata
from difflib import SequenceMatcher

import shapely
from shapely.strtree import STRtree

MIN_CONFIDENCE = 0.7
# O sufixo dos arquivos gerados com o Overture: `ov` na 0.23.0, `ov2` desde a 0.23.1 (sem os contornos fantasma). Muda junto com
# as regras, para nunca regerar por cima de um arquivo commitado.
TAG = "ov2"
CLOSED = {"permanently_closed", "temporarily_closed", "closed"}
MERGE_M = 30.0
NAME_RATIO = 0.8
OVERLAP = 0.3

# Os grupos do jogo (o tipo no `_traffic.bin`): comércio 6, bar ou restaurante 7, escola 8, praça ou parque 9, estádio 10.
# Igreja não tem ponto: entra no bioma (Sagrado) pelo prédio.
TRAFFIC_KIND = {"shop": 6, "bar": 7, "school": 8, "square": 9, "stadium": 10}

# A tag do OSM que um place equivale, para o bioma (só as que alguma regra de área usa).
OSM_TAG = {
    "mall": ("shop", "mall"),
    "supermarket": ("shop", "supermarket"),
    "department_store": ("shop", "department_store"),
    "marketplace": ("amenity", "marketplace"),
    "worship": ("amenity", "place_of_worship"),
    "school": ("amenity", "school"),
    "university": ("amenity", "university"),
    "college": ("amenity", "college"),
    "hospital": ("amenity", "hospital"),
    "bus_station": ("amenity", "bus_station"),
}


SWEETS = {"bakery", "candy_store", "chocolatier", "dessert_shop", "ice_cream_shop", "frozen_yoghurt_shop", "donut_shop"}
NOT_SQUARE = {"water_park", "national_park", "state_park"}


def classify(category: str | None, basic: str | None, hierarchy: list[str] | None) -> tuple[str | None, str | None]:
    """(grupo do jogo, chave de `OSM_TAG`) de um place pela taxonomia do Overture (`taxonomy.hierarchy`, do grupo mais geral
    ao mais específico; elementos inteiros, nunca pedaço de nome). `(None, None)`: o jogo não usa."""
    h = set(hierarchy or [])
    if category:
        h.add(category)
    top = hierarchy[0] if hierarchy else ""
    if "place_of_worship" in h:
        return None, "worship"
    if "stadium_arena" in h:
        return "stadium", None
    if "shopping_mall" in h:
        return "shop", "mall"
    if "department_store" in h:
        return "shop", "department_store"
    if h & {"supermarket", "hypermarket"}:
        return "shop", "supermarket"
    if h & {"farmers_market", "public_market", "flea_market", "night_market"}:
        return "shop", "marketplace"
    if top == "food_and_drink":
        return ("shop", None) if h & SWEETS else ("bar", None)
    if "place_of_learning" in h and "specialty_school" not in h:
        if "college_university" in h:
            return "school", "university"
        return "school", "school"
    if ("park" in h and not h & NOT_SQUARE and top == "sports_and_recreation") or "public_plaza" in h:
        return "square", None
    if "bus_station" in h:
        return None, "bus_station"
    if top == "health_care" and "hospital" in h:
        return None, "hospital"
    if top == "shopping":
        return "shop", None
    return None, None


def keep_place(confidence: float | None, status: str | None, min_confidence: float = MIN_CONFIDENCE) -> bool:
    """O filtro de confiança e de fechado."""
    return confidence is not None and confidence >= min_confidence and (status or "").lower() not in CLOSED


def norm_name(name: str | None) -> str:
    s = unicodedata.normalize("NFKD", name or "").encode("ascii", "ignore").decode().lower()
    return " ".join(re.sub(r"[^a-z0-9]+", " ", s).split())


def similar(a: str | None, b: str | None) -> bool:
    """Nome parecido: igual sem acento, pontuação e caixa; um dentro do outro (com 4 letras ou mais); ou razão >= 0,8."""
    x, y = norm_name(a), norm_name(b)
    if not x or not y:
        return False
    if x == y:
        return True
    if min(len(x), len(y)) >= 4 and (x in y or y in x):
        return True
    return SequenceMatcher(None, x, y).ratio() >= NAME_RATIO


def metres(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    k = 111_320.0
    return math.hypot((lon2 - lon1) * k * math.cos(math.radians((lat1 + lat2) / 2)), (lat2 - lat1) * k)


def merge_places(osm: list[tuple[str, float, float, str | None]], ov: list[tuple[str, float, float, str | None]]):
    """[osm] e [ov]: (grupo, lon, lat, nome). Devolve os índices de [ov] que não têm par no OSM (mesmo grupo, nome parecido,
    a até `MERGE_M`)."""
    cell = MERGE_M / 111_320.0  # graus de latitude; a longitude usa a mesma grade (só é mais fina que o raio)
    grid: dict[tuple[int, int], list[int]] = {}
    for i, (_, lon, lat, _) in enumerate(osm):
        grid.setdefault((int(lon // cell), int(lat // cell)), []).append(i)
    out = []
    for j, (g, lon, lat, name) in enumerate(ov):
        gx, gy = int(lon // cell), int(lat // cell)
        dup = False
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-1, 0, 1):
                for i in grid.get((gx + dx, gy + dy), ()):
                    og, olon, olat, oname = osm[i]
                    if og == g and metres(lon, lat, olon, olat) <= MERGE_M and similar(name, oname):
                        dup = True
                        break
                if dup:
                    break
            if dup:
                break
        if not dup:
            out.append(j)
    return out


def levels_from(height: float | None, floors: int | None) -> int:
    if floors is not None and floors > 0:
        return max(1, min(255, int(floors)))
    if height is not None and height > 0:
        return max(1, min(255, round(height / 3.0)))
    return 0


def new_footprints(osm_polys: list, ov_polys: list) -> list[int]:
    """Os índices de [ov_polys] (na ordem dada) que não duplicam um contorno do OSM nem um do Overture aceito antes: duplica
    quem cobre mais de `OVERLAP` da área do menor dos dois. Polígono inválido ou vazio fica de fora."""
    def dup(p, q) -> bool:
        return p.intersection(q).area > OVERLAP * min(p.area, q.area)

    fixed = [p if p.is_valid else p.buffer(0) for p in ov_polys]
    osm_tree = STRtree(osm_polys) if osm_polys else None
    ov_tree = STRtree(fixed) if fixed else None
    kept = [False] * len(fixed)
    for j, p in enumerate(fixed):
        if p.is_empty or p.area == 0:
            continue
        if osm_tree is not None and any(dup(p, osm_polys[i]) for i in osm_tree.query(p)):
            continue
        if any(kept[i] and dup(p, fixed[i]) for i in ov_tree.query(p) if i < j):
            continue
        kept[j] = True
    return [j for j, k in enumerate(kept) if k]


def lift_to_buildings(polys: list, places: list[tuple[float, float, str]]) -> list[tuple[int, str]]:
    """[places]: (lon, lat, chave de `OSM_TAG`). Devolve (índice do prédio que contém o place, chave), na ordem dos places;
    o place fora de qualquer prédio não conta."""
    if not polys:
        return []
    tree = STRtree(polys)
    out = []
    for lon, lat, key in places:
        pt = shapely.Point(lon, lat)
        hits = sorted(i for i in tree.query(pt, predicate="within"))
        if hits:
            out.append((int(hits[0]), key))
    return out


# ---- Leitura do cache da release (fetch_overture.py) e do OSM: cada resultado fica guardado ao lado do cache. ----

def _cache_dir(release: str):
    from build_region import CACHE
    return CACHE / "overture" / release


def _rows(sql: str):
    import duckdb
    con = duckdb.connect()
    con.execute("LOAD spatial;")
    return con.execute(sql).fetchall()


def _osm_building_rings(pbf, bbox):
    """Os contornos externos dos prédios do OSM do extrato (lon/lat), com o centro dentro da bbox, como o `build_buildings.py`."""
    import osmium
    min_lon, min_lat, max_lon, max_lat = bbox
    out = []
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_areas().with_filter(osmium.filter.KeyFilter("building"))
    for obj in fp:
        if not obj.is_area() or obj.tags.get("building") in (None, "no"):
            continue
        for outer in obj.outer_rings():
            pts = [(n.lon, n.lat) for n in outer if n.location.valid()]
            if len(pts) < 4:
                continue
            cx, cy = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
            if min_lon <= cx <= max_lon and min_lat <= cy <= max_lat:
                poly = shapely.Polygon(pts)
                out.append(poly if poly.is_valid else poly.buffer(0))
    return out


def overture_buildings(region: str, pbf, bbox, release: str):
    """Os prédios do Overture que entram: [(polígono lon/lat, tipo, andares)], em ordem de `id`. Os ids aceitos ficam em
    `<região>_buildings_new.txt`, para os três geradores usarem os mesmos."""
    from fetch_overture import cache_paths
    src, _ = cache_paths(region, release)
    if not src.exists():
        raise SystemExit(f"sem {src}: rode fetch_overture.py --region {region}")
    min_lon, min_lat, max_lon, max_lat = bbox
    rows = []
    for oid, wkb, height, floors, cls in _rows(
            f"SELECT id, wkb, height, num_floors, class FROM '{src}' WHERE NOT from_osm AND NOT coalesce(is_underground, false) ORDER BY id"):
        g = shapely.from_wkb(bytes(wkb))
        for part in getattr(g, "geoms", [g]):
            if part.geom_type != "Polygon":
                continue
            c = part.centroid
            if min_lon <= c.x <= max_lon and min_lat <= c.y <= max_lat:
                rows.append((f"{oid}#{len(rows)}", shapely.Polygon(part.exterior.coords), cls or "yes", levels_from(height, floors)))
    ids_path = _cache_dir(release) / f"{region}_buildings_new.txt"
    if ids_path.exists():
        keep = set(ids_path.read_text().split())
        chosen = [r for r in rows if r[0] in keep]
    else:
        idx = new_footprints(_osm_building_rings(pbf, bbox), [r[1] for r in rows])
        chosen = [rows[i] for i in idx]
        ids_path.write_text("\n".join(r[0] for r in chosen) + "\n")
    print(f"overture: {len(rows)} contornos sem fonte OSM, {len(chosen)} não cobrem um prédio já existente ({len(rows) - len(chosen)} cobrem)")
    chosen = _without_ghosts(region, pbf, bbox, release, chosen)
    return [(p, t, lv) for _, p, t, lv in chosen]


def _without_ghosts(region: str, pbf, bbox, release: str, chosen: list):
    """0.23.1: tira os fantasmas ([ghost_filter]) de [chosen] ((id, polígono, tipo, andares)). Os ids que ficam vão para
    `<região>_buildings_final.txt` e as contagens por regra para `<região>_ghosts.json`."""
    import json
    import numpy as np
    from build_region import lonlat_to_tile
    path = _cache_dir(release) / f"{region}_buildings_final.txt"
    if path.exists():
        keep = set(path.read_text().split())
        out = [r for r in chosen if r[0] in keep]
        print(f"overture: {len(out)} entram, sem os fantasmas ({json.loads((_cache_dir(release) / f'{region}_ghosts.json').read_text())})")
        return out
    lat0 = (bbox[1] + bbox[3]) / 2
    m2 = 111_320.0 ** 2 * np.cos(np.radians(lat0))
    osm = _osm_building_rings(pbf, bbox)
    by_tile: dict[tuple[int, int], list[float]] = {}

    def tile_of(p):
        c = p.centroid
        x, y = lonlat_to_tile(np.array([c.x]), np.array([c.y]), 15)
        return int(x[0]), int(y[0])

    for p in osm + [r[1] for r in chosen]:
        by_tile.setdefault(tile_of(p), []).append(p.area * m2)
    medians = {k: float(np.median(v)) for k, v in by_tile.items()}
    no_build = _osm_tagged_areas(pbf, bbox, NO_BUILD)
    big_ok = _osm_tagged_areas(pbf, bbox, BIG_OK)
    pois = [(lon, lat) for _, lon, lat, _ in _osm_pois(pbf, bbox)]
    idx, counts = ghost_filter([r[1] for r in chosen], no_build, big_ok, pois, lambda p: medians[tile_of(p)], m2)
    out = [chosen[i] for i in idx]
    counts.update({"antes": len(chosen), "entram": len(out), "areas_agua_parque_praca": len(no_build), "areas_que_confirmam": len(big_ok)})
    (_cache_dir(release) / f"{region}_ghosts.json").write_text(json.dumps(counts, indent=1))
    path.write_text("\n".join(r[0] for r in out) + "\n")
    print(f"overture: fantasmas {counts}")
    return out


OSM_POI_KEYS = ("shop", "amenity", "leisure", "place", "name")


def osm_group(tags) -> tuple[str | None, str | None]:
    """(grupo, chave de `OSM_TAG`) de um POI do OSM, com as regras do `build_traffic.py` e as igrejas."""
    a, s, le = tags.get("amenity"), tags.get("shop"), tags.get("leisure")
    if a == "place_of_worship":
        return None, "worship"
    if le == "stadium":
        return "stadium", None
    if s is not None:
        return "shop", s if s in ("mall", "supermarket", "department_store") else None
    if a == "marketplace":
        return "shop", "marketplace"
    if a in ("bar", "pub", "restaurant", "cafe", "fast_food"):
        return "bar", None
    if a in ("school", "kindergarten", "college", "university"):
        return "school", a if a in ("school", "college", "university") else "school"
    if le in ("park", "garden") or tags.get("place") == "square":
        return "square", None
    if a in ("bus_station", "hospital"):
        return None, a
    return None, None


def _osm_pois(pbf, bbox):
    import osmium
    min_lon, min_lat, max_lon, max_lat = bbox
    out = []
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_filter(osmium.filter.KeyFilter("shop", "amenity", "leisure", "place"))
    for obj in fp:
        g, k = osm_group(obj.tags)
        if g is None and k is None:
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
        if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
            out.append((g or k, lon, lat, obj.tags.get("name")))
    return out


def overture_places(region: str, pbf, bbox, release: str, min_confidence: float = MIN_CONFIDENCE):
    """Os places do Overture que entram, sem par no OSM: [(grupo do jogo, chave de `OSM_TAG`, lon, lat)], em ordem de `id`.
    Guardados em `<região>_places_new_<confiança>.json`; os números do filtro em `<região>_places_stats.json`."""
    import json
    from fetch_overture import cache_paths
    _, src = cache_paths(region, release)
    out_path = _cache_dir(release) / f"{region}_places_new_{min_confidence:.2f}.json"
    if out_path.exists():
        return [tuple(r) for r in json.loads(out_path.read_text())]
    min_lon, min_lat, max_lon, max_lat = bbox
    rows = _rows(f"SELECT id, lon, lat, confidence, operating_status, category, basic_category, hierarchy, name FROM '{src}' ORDER BY id")
    inside = [r for r in rows if min_lon <= r[1] <= max_lon and min_lat <= r[2] <= max_lat]
    stats = {"total": len(inside), "closed": sum(1 for r in inside if (r[4] or "").lower() in CLOSED)}
    for c in (0.5, 0.7, 0.9):
        stats[f"kept_{c}"] = sum(1 for r in inside if keep_place(r[3], r[4], c))
    cand = []
    for _, lon, lat, conf, status, cat, basic, hier, name in inside:
        if not keep_place(conf, status, min_confidence):
            continue
        g, k = classify(cat, basic, hier)
        if g is not None or k is not None:
            cand.append((g, k, lon, lat, name))
    osm = _osm_pois(pbf, bbox)
    keep = merge_places(osm, [(g or k, lon, lat, name) for g, k, lon, lat, name in cand])
    result = [cand[i][:4] for i in keep]
    stats.update({"mapped": len(cand), "osm_pois": len(osm), "merged_with_osm": len(cand) - len(keep), "new": len(result)})
    groups: dict[str, int] = {}
    for g, k, _, _ in result:
        groups[g or k] = groups.get(g or k, 0) + 1
    stats["new_by_group"] = dict(sorted(groups.items()))
    (_cache_dir(release) / f"{region}_places_stats.json").write_text(json.dumps(stats, indent=1))
    out_path.write_text(json.dumps(result))
    print(f"overture places: {json.dumps(stats)}")
    return result


# ---- 0.23.1: contornos fantasma. Os contornos de IA erram: o que só o Overture tem sai quando cai sobre água, parque ou praça
# do OSM, ou quando é grande demais para a região sem confirmação do OSM. ----

GHOST_COVER = 0.5  # parte do contorno sobre água, parque ou praça do OSM que já o descarta
BIG_MIN_M2 = 500.0  # abaixo disto nunca é "grande demais"
BIG_FACTOR = 8.0  # grande demais: mais que isto vezes a mediana dos prédios do tile z15 dele
# Áreas do OSM onde o contorno de IA é quase sempre engano.
NO_BUILD = {("natural", "water"), ("landuse", "reservoir"), ("landuse", "basin"), ("waterway", "riverbank"),
            ("leisure", "park"), ("leisure", "garden"), ("leisure", "playground"),
            ("place", "square"), ("highway", "pedestrian")}
# Áreas do OSM onde um prédio grande é esperado: confirmam o contorno grande.
BIG_OK = {("landuse", v) for v in ("industrial", "commercial", "retail", "railway", "institutional", "education", "military", "farmyard")} | \
         {("amenity", v) for v in ("school", "university", "college", "hospital", "marketplace", "bus_station", "place_of_worship")} | \
         {("aeroway", "aerodrome")}


def ghost_filter(polys: list, no_build: list, big_ok: list, pois: list[tuple[float, float]], tile_median, m2_per_deg2: float):
    """Os índices de [polys] (lon/lat) que ficam, e quantos saem por regra: `agua_parque_praca` (metade ou mais sobre [no_build])
    e `grande` (mais de `BIG_MIN_M2` e de `BIG_FACTOR` vezes `tile_median(polígono)` m², sem área de [big_ok] nem POI do OSM
    ([pois]) que confirme)."""
    nb_tree = STRtree(no_build) if no_build else None
    ok_tree = STRtree(big_ok) if big_ok else None
    poi_tree = STRtree([shapely.Point(x, y) for x, y in pois]) if pois else None
    keep, counts = [], {"agua_parque_praca": 0, "grande": 0}
    for i, p in enumerate(polys):
        if nb_tree is not None:
            hits = [no_build[j] for j in nb_tree.query(p)]
            if hits and shapely.union_all([p.intersection(h) for h in hits]).area >= GHOST_COVER * p.area:
                counts["agua_parque_praca"] += 1
                continue
        m2 = p.area * m2_per_deg2
        if m2 > BIG_MIN_M2 and m2 > BIG_FACTOR * tile_median(p):
            c = p.representative_point()
            confirmed = (ok_tree is not None and any(big_ok[j].contains(c) for j in ok_tree.query(c))) or \
                        (poi_tree is not None and len(poi_tree.query(p, predicate="contains")) > 0)
            if not confirmed:
                counts["grande"] += 1
                continue
        keep.append(i)
    return keep, counts


def _osm_tagged_areas(pbf, bbox, pairs: set):
    """As áreas do OSM com alguma das tags de [pairs] (lon/lat), dentro da bbox."""
    import osmium
    keys = sorted({k for k, _ in pairs})
    clip = shapely.box(*bbox)
    wkb = osmium.geom.WKBFactory()
    out = []
    fp = osmium.FileProcessor(str(pbf)).with_locations().with_areas().with_filter(osmium.filter.KeyFilter(*keys))
    for obj in fp:
        if not obj.is_area() or not any((k, obj.tags.get(k)) in pairs for k in keys):
            continue
        try:
            g = shapely.from_wkb(wkb.create_multipolygon(obj))
        except (RuntimeError, osmium.InvalidLocationError):
            continue
        if not g.is_valid:
            g = g.buffer(0)
        if g.intersects(clip):
            out.append(g)
    return out
