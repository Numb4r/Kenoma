#!/usr/bin/env python3
"""Captura um quadro de cada clima da Simulação de clima do debug, no emulador. Chame logo depois de tocar em "1 min por
clima" (é o t0): o clima i fica do segundo 60*i ao 60*i+45 (o resto é ele secando), e a captura sai aos 40 s, já formado.
Uso: workbench/capture/climas.py T0_EPOCH [passo_s]   (os ids na ordem do clima.json, que é a da simulação)"""
import json, subprocess, sys, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
t0, step = float(sys.argv[1]), float(sys.argv[2]) if len(sys.argv) > 2 else 60.0
ids = list(json.load(open(ROOT / 'app/assets/data/clima.json'))['climates'])
out = ROOT / 'workbench/catalog/climas'
out.mkdir(parents=True, exist_ok=True)
for i, cid in enumerate(ids):
    at = t0 + i * step + 40
    time.sleep(max(0.0, at - time.time()))
    png = subprocess.run(['adb', '-s', 'emulator-5554', 'exec-out', 'screencap', '-p'], capture_output=True, timeout=30).stdout
    (out / f'{cid}.png').write_bytes(png)
    print(f'{i + 1}/{len(ids)} {cid} {len(png)} bytes', flush=True)
