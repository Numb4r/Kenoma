"""O impacto do Overture num pacote de região (0.23.0): células z18 que mudam de bioma (o bioma da z18 é a moda das 8 × 8
células z21, empate pela maior prioridade), células z21 que mudam, pontos do `_traffic.bin` por tipo e células z20 com
âncora da Shade (comércio, bar, beco) e do Hum (semáforo, ponto de ônibus), e o tamanho dos arquivos.

Uso: .venv/bin/python overture_impact.py <antes.bin> <depois.bin> <antes_traffic.bin> <depois_traffic.bin> [arquivos...]"""
import gzip
import json
import sys
from pathlib import Path

import numpy as np

from build_region import ROOT, decode
from build_visual import varint  # noqa: F401  (mesmo módulo de varints do formato)

KINDS = ["semáforo", "pare", "preferência", "faixa", "entrada", "ônibus", "comércio", "bar", "escola", "praça", "estádio", "beco"]
SHADE, POLE = {6, 7, 11}, {0, 5}


def z18(grid: np.ndarray, prio: dict[int, int]) -> np.ndarray:
    h, w = grid.shape[0] // 8 * 8, grid.shape[1] // 8 * 8
    blocks = grid[:h, :w].reshape(h // 8, 8, w // 8, 8).transpose(0, 2, 1, 3).reshape(h // 8, w // 8, 64)
    ids = sorted(prio)
    counts = np.stack([(blocks == i).sum(-1) for i in ids], -1)  # (H, W, n)
    # Empate pela maior prioridade: soma uma fração pela prioridade.
    score = counts * 16 + np.array([prio[i] for i in ids])
    return np.array(ids)[score.argmax(-1)]


def traffic(path: Path):
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

    pts = []
    x = y = 0
    for _ in range(v()):
        k = b[i]
        i += 1
        x += zz()
        y += zz()
        pts.append((k, x, y))
    return pts


def main() -> None:
    a, b, ta, tb, *files = map(Path, sys.argv[1:])
    biomes = json.loads((ROOT / "shared/biomes.json").read_text())["biomes"]
    prio = {x["id"]: x["priority"] for x in biomes}
    names = {x["id"]: x["name"] for x in biomes}
    ga, gb = decode(a.read_bytes())[0], decode(b.read_bytes())[0]
    assert ga.shape == gb.shape
    za, zb = z18(ga, prio), z18(gb, prio)
    changed = za != zb
    nonvoid = (za != 0) | (zb != 0)
    out = {
        "z18_cells": int(za.size), "z18_changed": int(changed.sum()), "z18_changed_pct": round(100 * changed.mean(), 3),
        "z18_nonvoid": int(nonvoid.sum()), "z18_changed_pct_of_nonvoid": round(100 * changed.sum() / max(1, nonvoid.sum()), 3),
        "z21_changed_pct": round(100 * (ga != gb).mean(), 3),
        "z18_transitions": {}, "z21_share_before": {}, "z21_share_after": {},
    }
    for f, t in zip(za[changed], zb[changed]):
        key = f"{names[int(f)]} -> {names[int(t)]}"
        out["z18_transitions"][key] = out["z18_transitions"].get(key, 0) + 1
    out["z18_transitions"] = dict(sorted(out["z18_transitions"].items(), key=lambda kv: -kv[1]))
    for i, n in names.items():
        out["z21_share_before"][n] = round(100 * (ga == i).mean(), 2)
        out["z21_share_after"][n] = round(100 * (gb == i).mean(), 2)
    pa, pb = traffic(ta), traffic(tb)
    out["points_before"] = {KINDS[k]: sum(1 for p in pa if p[0] == k) for k in range(len(KINDS))}
    out["points_after"] = {KINDS[k]: sum(1 for p in pb if p[0] == k) for k in range(len(KINDS))}

    def cells(pts, kinds):  # células z20: x, y em 1/64 de z21
        return {(x // 128, y // 128) for k, x, y in pts if k in kinds}

    for label, kinds in (("shade", SHADE), ("hum", POLE)):
        ca, cb = cells(pa, kinds), cells(pb, kinds)
        out[f"z20_{label}_cells"] = {"before": len(ca), "after": len(cb), "gained": len(cb - ca), "lost": len(ca - cb)}
    out["files"] = {f.name: f.stat().st_size for f in [a, b, ta, tb, *files]}
    print(json.dumps(out, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
