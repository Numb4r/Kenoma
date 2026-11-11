"""Gera `<região>_e<época>_relief.bin`: a altura do terreno da região, do SRTM de 30 m (1 segundo de arco), numa grade
z20 (uma amostra a cada duas células z21, ~35 m, perto da resolução do SRTM), suavizada. A altura de uma célula z21 sai por
interpolação bilinear no app (`app/lib/data/relief_pack.dart`). **É mundo:** água, neblina e vento saem daqui, então o
SHA-256 do arquivo entra na época (`relief_packs`) e ele nunca é regerado por cima.

Fonte: os tiles `.hgt` do SRTMGL1 no espelho público `elevation-tiles-prod` (skadi). Vazios do SRTM são preenchidos
pela média dos vizinhos; depois um filtro gaussiano (sigma de 1,2 amostra) tira o ruído de 1 m do radar.

Formato: `REL1` + `zoom u8, x0 u32, y0 u32, largura u32, altura u32` (little-endian; x0 e y0 em células z20) +
gzip(alturas em decímetros, i16 little-endian, linha por linha, cada linha em deltas para a anterior e a primeira coluna
de cada linha em delta para a de cima). Uso: .venv/bin/python build_relief.py --region campinas --epoch 9"""
import argparse
import gzip
import hashlib
import json
import math
import struct
import urllib.request
from pathlib import Path

import numpy as np

from build_region import CACHE, REGIONS_DIR, ROOT, lonlat_to_tile

SKADI = "https://s3.amazonaws.com/elevation-tiles-prod/skadi/{ns}{lat:02d}/{ns}{lat:02d}{ew}{lon:03d}.hgt.gz"
ZOOM = 20
SIGMA = 1.2


def tile(lat: int, lon: int) -> np.ndarray:
    """O tile SRTM de 1 grau cujo canto sudoeste é (lat, lon): 3601 x 3601, a linha 0 ao norte."""
    name = f"{'S' if lat < 0 else 'N'}{abs(lat):02d}{'W' if lon < 0 else 'E'}{abs(lon):03d}.hgt.gz"
    path = CACHE / "srtm" / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        url = SKADI.format(ns="S" if lat < 0 else "N", lat=abs(lat), ew="W" if lon < 0 else "E", lon=abs(lon))
        print(f"baixando {url}")
        tmp = path.with_suffix(".part")
        urllib.request.urlretrieve(url, tmp)
        tmp.rename(path)
    return np.frombuffer(gzip.decompress(path.read_bytes()), dtype=">i2").reshape(3601, 3601).astype(np.float64)


def gaussian(a: np.ndarray, sigma: float) -> np.ndarray:
    r = int(math.ceil(3 * sigma))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    p = np.pad(a, r, mode="edge")
    p = np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 1, p)
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 0, p)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", required=True)
    ap.add_argument("--epoch", type=int, required=True, help="a época que passa a listar este arquivo")
    ap.add_argument("--out-dir", type=Path, default=REGIONS_DIR)
    args = ap.parse_args()
    out = args.out_dir / f"{args.region}_e{args.epoch}_relief.bin"
    if out.exists():
        raise SystemExit(f"{out} já existe: relevo é mundo, não se regera por cima. Use outra época.")
    min_lon, min_lat, max_lon, max_lat = json.loads((ROOT / "pipeline/regions.json").read_text())[args.region]["bbox"]
    fx0, fy1 = lonlat_to_tile(np.array([min_lon]), np.array([min_lat]), ZOOM)
    fx1, fy0 = lonlat_to_tile(np.array([max_lon]), np.array([max_lat]), ZOOM)
    x0, y0 = int(math.floor(fx0[0])) - 1, int(math.floor(fy0[0])) - 1
    w, h = int(math.ceil(fx1[0])) + 2 - x0, int(math.ceil(fy1[0])) + 2 - y0
    # O centro de cada amostra, em graus.
    n = 2 ** ZOOM
    lon = (x0 + np.arange(w) + 0.5) / n * 360.0 - 180.0
    lat = np.degrees(np.arctan(np.sinh(math.pi * (1 - 2 * (y0 + np.arange(h) + 0.5) / n))))
    grid = np.zeros((h, w))
    tiles = {}
    lon2, lat2 = np.meshgrid(lon, lat)
    tl, tn = np.floor(lat2).astype(int), np.floor(lon2).astype(int)
    for la in np.unique(tl):
        for lo in np.unique(tn):
            m = (tl == la) & (tn == lo)
            if not m.any():
                continue
            t = tiles.setdefault((la, lo), tile(int(la), int(lo)))
            void = t <= -1000
            if void.any():  # vazios: a média do que há em volta (poucos, em água e sombra de radar)
                filled = t.copy()
                filled[void] = np.nan
                for _ in range(8):
                    nb = np.nanmean(np.stack([np.roll(filled, s, a) for s in (-1, 1) for a in (0, 1)]), axis=0)
                    filled = np.where(np.isnan(filled), nb, filled)
                t = np.nan_to_num(filled, nan=float(np.nanmean(filled)))
                tiles[(la, lo)] = t
            # Bilinear: a linha 0 é o norte (lat + 1), 3600 intervalos por grau.
            r = (la + 1 - lat2[m]) * 3600
            c = (lon2[m] - lo) * 3600
            r0, c0 = np.clip(np.floor(r).astype(int), 0, 3599), np.clip(np.floor(c).astype(int), 0, 3599)
            fr, fc = r - r0, c - c0
            grid[m] = (t[r0, c0] * (1 - fr) * (1 - fc) + t[r0, c0 + 1] * (1 - fr) * fc + t[r0 + 1, c0] * fr * (1 - fc) + t[r0 + 1, c0 + 1] * fr * fc)
    grid = gaussian(grid, SIGMA)
    dm = np.clip(np.round(grid * 10), -32768, 32767).astype(np.int32)
    delta = dm.copy()
    delta[:, 1:] = dm[:, 1:] - dm[:, :-1]
    delta[1:, 0] = dm[1:, 0] - dm[:-1, 0]
    assert np.abs(delta).max() < 32768
    body = gzip.compress(delta.astype("<i2").tobytes(), compresslevel=9, mtime=0)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out.write_bytes(b"REL1" + struct.pack("<BIIII", ZOOM, x0, y0, w, h) + body)
    print(f"{w} x {h} amostras z{ZOOM}, de {dm.min() / 10:.1f} a {dm.max() / 10:.1f} m, {out.stat().st_size} bytes, "
          f"sha256 {hashlib.sha256(out.read_bytes()).hexdigest()}")
    # Conferência: a Lagoa do Taquaral (uns 630 m) e o Castelo (uns 720 m).
    for name, la, lo in (("Lagoa do Taquaral", -22.8745, -47.0500), ("Castelo", -22.8880, -47.0780), ("Centro", -22.9056, -47.0608)):
        if min_lat <= la <= max_lat and min_lon <= lo <= max_lon:
            x, y = lonlat_to_tile(np.array([lo]), np.array([la]), ZOOM)
            print(f"  {name}: {dm[int(y[0]) - y0, int(x[0]) - x0] / 10:.1f} m")


if __name__ == "__main__":
    main()
