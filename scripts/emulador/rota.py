#!/usr/bin/env python3
"""Toca uma rota GPX no emulador pelo `adb emu geo fix`, em velocidade de caminhada, com um ponto por segundo; ou só fixa
uma coordenada, para pôr o emulador no mesmo lugar do celular (o teste dos dois aparelhos).

  scripts/emulador/rota.py taquaral                 # a volta da Lagoa do Taquaral (rotas/taquaral.gpx)
  scripts/emulador/rota.py centro --voltas 2        # Rua 13 de Maio, ida e volta, duas vezes
  scripts/emulador/rota.py paulista --velocidade 3  # Avenida Paulista (época 12), correndo
  scripts/emulador/rota.py meu.gpx                  # qualquer GPX
  scripts/emulador/rota.py --fixo=-22.9056,-47.0608 # só fixa a posição (com "=": a coordenada começa com "-")

As rotas embutidas são de lugares públicos (OSM, extrato da época 0). Nenhuma rota perto de casa."""
import argparse
import math
import os
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADB = os.path.join(os.environ.get("ANDROID_HOME", os.path.expanduser("~/Android/Sdk")), "platform-tools", "adb")


def fix(lat: float, lon: float) -> None:
    # O geo fix recebe longitude antes da latitude.
    subprocess.run([ADB, "-e", "emu", "geo", "fix", f"{lon:.7f}", f"{lat:.7f}"], check=True, stdout=subprocess.DEVNULL)


def load(arg: str) -> list[tuple[float, float]]:
    path = Path(arg) if arg.endswith(".gpx") else HERE / "rotas" / f"{arg}.gpx"
    pts = []
    for el in ET.parse(path).getroot().iter():
        if el.tag.endswith("trkpt") or el.tag.endswith("rtept") or el.tag.endswith("wpt"):
            pts.append((float(el.get("lat")), float(el.get("lon"))))
    if len(pts) < 2:
        sys.exit(f"{path}: a rota precisa de pelo menos 2 pontos")
    return pts


def metres(a: tuple[float, float], b: tuple[float, float]) -> float:
    dy = (b[0] - a[0]) * 111320.0
    dx = (b[1] - a[1]) * 111320.0 * math.cos(math.radians(a[0]))
    return math.hypot(dx, dy)


def walk(pts: list[tuple[float, float]], speed: float) -> list[tuple[float, float]]:
    """Os pontos de segundo em segundo, andando a [speed] m/s pela rota."""
    out, carry = [pts[0]], 0.0
    for a, b in zip(pts, pts[1:]):
        seg = metres(a, b)
        d = speed - carry
        while seg > 0 and d <= seg:
            f = d / seg
            out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
            d += speed
        carry = seg - (d - speed) if seg > 0 else carry
    out.append(pts[-1])
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("rota", nargs="?", help="taquaral, centro, paulista ou um arquivo .gpx")
    ap.add_argument("--fixo", help="só fixa a posição: --fixo=lat,lon")
    ap.add_argument("--velocidade", type=float, default=1.4, help="m/s (padrão 1,4: caminhada)")
    ap.add_argument("--voltas", type=int, default=1)
    a = ap.parse_args()
    if a.fixo:
        lat, lon = (float(v) for v in a.fixo.split(","))
        fix(lat, lon)
        print(f"emulador fixo em {lat}, {lon}")
        return
    if not a.rota:
        ap.error("diga a rota ou --fixo")
    steps = walk(load(a.rota), a.velocidade)
    total = len(steps) * a.voltas
    print(f"{a.rota}: {len(steps)} s por volta a {a.velocidade} m/s, {a.voltas} volta(s). Ctrl+C para parar.")
    n = 0
    for _ in range(a.voltas):
        for lat, lon in steps:
            t0 = time.monotonic()
            fix(lat, lon)
            n += 1
            if n % 30 == 0:
                print(f"  {n}/{total} s")
            time.sleep(max(0.0, 1.0 - (time.monotonic() - t0)))


if __name__ == "__main__":
    main()
