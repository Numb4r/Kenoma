"""Testes das regras do Overture (0.23.0). Uso: .venv/bin/python test_overture.py (ou pytest)."""
import hashlib

import shapely

import overture as ov
from bld_tiles import write_bld2


def sq(x, y, s=0.0001):
    return shapely.box(x, y, x + s, y + s)


def test_confidence_filter():
    assert ov.keep_place(0.7, "open")
    assert ov.keep_place(0.95, None)
    assert not ov.keep_place(0.69, "open")
    assert not ov.keep_place(None, "open")
    assert not ov.keep_place(0.99, "permanently_closed")
    assert not ov.keep_place(0.99, "temporarily_closed")
    assert ov.keep_place(0.55, "open", 0.5) and not ov.keep_place(0.85, "open", 0.9)


def test_category_mapping():
    def c(*h):
        return ov.classify(h[-1], None, list(h))
    assert c("shopping", "fashion_and_apparel_store", "clothing_store") == ("shop", None)
    assert c("shopping", "specialty_store", "pharmacy_and_drug_store", "pharmacy") == ("shop", None)
    assert c("shopping", "shopping_mall") == ("shop", "mall")
    assert c("shopping", "department_store") == ("shop", "department_store")
    assert c("shopping", "market", "farmers_market") == ("shop", "marketplace")
    assert c("food_and_drink", "restaurant", "brazilian_restaurant") == ("bar", None)
    assert c("food_and_drink", "alcoholic_beverage_venue", "bar") == ("bar", None)
    assert c("food_and_drink", "casual_eatery", "bakery") == ("shop", None)
    assert c("lifestyle_services", "personal_or_beauty_service", "barber") == (None, None)
    assert c("cultural_and_historic", "place_of_worship", "christian_place_of_worship", "roman_catholic_place_of_worship") == (None, "worship")
    assert c("cultural_and_historic", "place_of_worship", "buddhist_place_of_worship") == (None, "worship")
    assert c("cultural_and_historic", "religious_organization") == (None, None)
    assert c("education", "place_of_learning", "school", "elementary_school") == ("school", "school")
    assert c("education", "place_of_learning", "college_university") == ("school", "university")
    assert c("education", "place_of_learning", "specialty_school", "driving_school") == (None, None)
    assert c("sports_and_recreation", "park") == ("square", None)
    assert c("sports_and_recreation", "park", "playground") == ("square", None)
    assert c("sports_and_recreation", "park", "water_park") == (None, None)
    assert c("community_and_government", "public_facility", "public_plaza") == ("square", None)
    assert c("travel_and_transportation", "parking") == (None, None)
    assert c("arts_and_entertainment", "stadium_arena", "stadium", "soccer_stadium") == ("stadium", None)
    assert c("health_care", "hospital") == (None, "hospital")
    assert c("lifestyle_services", "animal_or_pet_service", "veterinary_care", "animal_hospital") == (None, None)
    assert c("health_care", "outpatient_care_facility", "dental_clinic") == (None, None)
    assert ov.classify(None, None, None) == (None, None)


def test_similar_names():
    assert ov.similar("Padaria Pão de Açúcar", "padaria pao de acucar")
    assert ov.similar("Bar do Zé", "Bar do Ze - Centro")
    assert ov.similar("Drogasil", "Drogasill")
    assert not ov.similar("Drogasil", "Pague Menos")
    assert not ov.similar(None, "Drogasil") and not ov.similar("", "")


def test_merge_within_30m():
    lon, lat = -47.06, -22.90
    d = 1 / 111_320  # um metro de latitude em graus
    osm = [("shop", lon, lat, "Loja Azul"), ("bar", lon, lat, "Bar Azul")]
    ovp = [
        ("shop", lon, lat + 29 * d, "Loja Azul"),      # 29 m, mesmo nome: duplicado
        ("shop", lon, lat + 31 * d, "Loja Azul"),      # 31 m: outro lugar
        ("shop", lon, lat + 5 * d, "Mercado Verde"),   # perto, outro nome: outro lugar
        ("school", lon, lat, "Loja Azul"),             # outro grupo: outro lugar
        ("bar", lon + 10 * d, lat, "bar azul"),        # 10 m, mesmo nome sem caixa: duplicado
    ]
    assert ov.merge_places(osm, ovp) == [1, 2, 3]


def test_no_duplicate_buildings():
    osm = [sq(0, 0), sq(0.001, 0)]
    ovp = [
        sq(0.00002, 0.00002),        # cobre 64% do prédio do OSM: duplicado
        sq(0.00009, 0),              # encosta 10%: entra
        sq(0.002, 0),                # longe: entra
        sq(0.00201, 0.00001),        # cobre 81% do anterior do Overture: duplicado
        shapely.Polygon(),           # vazio: fora
    ]
    kept = ov.new_footprints(osm, ovp)
    assert kept == [1, 2]
    allp = osm + [ovp[i] for i in kept]
    for i, a in enumerate(allp):
        for b in allp[i + 1:]:
            assert a.intersection(b).area <= ov.OVERLAP * min(a.area, b.area)


def test_lift_to_buildings():
    polys = [sq(0, 0, 1), sq(5, 5, 1)]
    assert ov.lift_to_buildings(polys, [(0.5, 0.5, "worship"), (3, 3, "mall"), (5.5, 5.5, "mall")]) == [(0, "worship"), (1, "mall")]


def test_same_input_same_bytes():
    bs = [(0, 2, 1, [(100, 100), (200, 100), (200, 200)]), (1, 0, 0, [(9000, 9000), (9100, 9000), (9100, 9100)])]
    a = write_bld2(["yes", "house"], bs, [(50, 50)])
    b = write_bld2(["yes", "house"], list(reversed(bs)), [(50, 50)])
    assert hashlib.sha256(a).digest() == hashlib.sha256(b).digest()


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok", name)
