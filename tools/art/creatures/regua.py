#!/usr/bin/env python3
"""Confere a régua (docs/art/estilo-criaturas.md, "A régua em números") na arte final das criaturas e das Fagulhas.

Criatura: tools/art/creatures/<especie>/, etapa pelo quadro do mapa (28 Eco, 36 Espírito, 48 Entidade, 64 Arquétipo).
Mede o quadro 0 do idle (corpo + leds + glow) e o quadro 0 do retrato. Fagulha: tools/art/sparks/spark_<tipo>.png, quadro 0,
só as de tipo listado em REFEITAS_FAGULHA. Pastas em PENDENTES (famílias ainda sem a arte final) só são listadas.
Sai com código 1 se algo ficar abaixo do piso. Rodar: python3 tools/art/creatures/regua.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

ART = Path(__file__).resolve().parent.parent
OUTLINE = (0x1A, 0x14, 0x24)
ETAPA = {12: 'fagulha', 28: 'eco', 36: 'espirito', 48: 'entidade', 64: 'arquetipo'}
# cores, detalhe e cores emissivas são mínimos; contorno é teto; emissivo é a faixa. r*: retrato (contorno até 0,22).
PISO = {
    'fagulha': dict(cores=6, detalhe=0.85, contorno=0.45, emissivo=(0.15, 0.50), ecores=2, rcores=10, rdetalhe=0.40, remissivo=0.10),
    'eco': dict(cores=10, detalhe=0.80, contorno=0.28, emissivo=(0.06, 0.14), ecores=3, rcores=14, rdetalhe=0.40, remissivo=0.05),
    'espirito': dict(cores=12, detalhe=0.75, contorno=0.28, emissivo=(0.09, 0.18), ecores=3, rcores=16, rdetalhe=0.45, remissivo=0.07),
    'entidade': dict(cores=14, detalhe=0.70, contorno=0.26, emissivo=(0.12, 0.24), ecores=3, rcores=16, rdetalhe=0.50, remissivo=0.09),
    'arquetipo': dict(cores=14, detalhe=0.65, contorno=0.24, emissivo=(0.16, 0.40), ecores=4, rcores=16, rdetalhe=0.50, remissivo=0.14),
}
REFEITAS_FAGULHA = {'electric', 'fire', 'plant'}
PENDENTES = {
    'bitling', 'bouldkin', 'brookkin', 'fairkin', 'glimlet', 'glitchkin', 'gratekin',
    'hollowkin', 'kilnshade', 'pebblet', 'prismkin', 'rillet', 'rootseer', 'rustling', 'shadekin',
    'sprigglet', 'umbrel', 'wellmirror', 'wisplet', 'wyrmkin', 'wyrmlet',
    # etapas altas em produção: entram na régua quando a família for integrada
    'shade_entidade', 'shade_arquetipo', 'wisp_entidade', 'wisp_arquetipo', 'wyrm_entidade', 'wyrm_arquetipo',
}


def frame0(path: Path, side: int) -> list:
    """Quadro 0 de uma tira como grade de (r, g, b) ou None."""
    im = Image.open(path).convert('RGBA').crop((0, 0, side, side))
    px = im.load()
    return [[px[x, y][:3] if px[x, y][3] > 0 else None for x in range(side)] for y in range(side)]


def measure(body: list, ems: list) -> dict:
    side = len(body)
    op = out = inner = det = lit = 0
    cols, ecols = set(), set()
    for y in range(side):
        for x in range(side):
            lights = [e[y][x] for e in ems if e[y][x] is not None]
            if lights:
                lit += 1
                ecols.update(lights)
            c = body[y][x]
            if c is None:
                continue
            op += 1
            cols.add(c)
            if c == OUTLINE:
                out += 1
                continue
            inner += 1
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = x + dx, y + dy
                q = body[qy][qx] if 0 <= qx < side and 0 <= qy < side else None
                if q is not None and q != OUTLINE and q != c:
                    det += 1
                    break
    n = max(op, 1)
    return dict(opacos=op, cores=len(cols), detalhe=det / max(inner, 1), contorno=out / n, emissivo=lit / n, ecores=len(ecols))


def check(m: dict, p: dict, retrato: bool) -> list:
    bad = []
    cores, detalhe = (p['rcores'], p['rdetalhe']) if retrato else (p['cores'], p['detalhe'])
    contorno, emin = (0.22, p['remissivo']) if retrato else (p['contorno'], p['emissivo'][0])
    if m['cores'] < cores:
        bad.append(f'cores {m["cores"]} < {cores}')
    if m['detalhe'] < detalhe:
        bad.append(f'detalhe {m["detalhe"]:.2f} < {detalhe}')
    if m['contorno'] > contorno:
        bad.append(f'contorno {m["contorno"]:.2f} > {contorno}')
    if not emin <= m['emissivo'] <= p['emissivo'][1]:
        bad.append(f'emissivo {m["emissivo"]:.2f} fora de {emin}..{p["emissivo"][1]}')
    if not retrato and m['ecores'] < p['ecores']:
        bad.append(f'cores emissivas {m["ecores"]} < {p["ecores"]}')
    return bad


def line(name: str, m: dict, bad: list) -> str:
    s = f'{name}: opacos {m["opacos"]}, cores {m["cores"]}, detalhe {m["detalhe"]:.2f}, contorno {m["contorno"]:.2f}, emissivo {m["emissivo"]:.2f}, cores emissivas {m["ecores"]}'
    return s + ('  ABAIXO DO PISO: ' + '; '.join(bad) if bad else '')


def main() -> int:
    fails, pend = 0, []
    for d in sorted(p for p in (ART / 'creatures').iterdir() if (p / f'{p.name}.json').exists()):
        n = d.name
        if n in PENDENTES:
            pend.append(n)
            continue
        meta = json.loads((d / f'{n}.json').read_text())
        etapa = ETAPA.get(meta['frame'])
        if etapa is None or etapa == 'fagulha':
            print(f'{n}: quadro {meta["frame"]} fora da régua')
            fails += 1
            continue
        for kind, anim, side in (('mapa', 'idle', meta['frame']), ('retrato', 'portrait', meta['portrait']['frame'])):
            em = [frame0(d / f'{n}_{anim}_{layer}.png', side) for layer in ('leds', 'glow') if (d / f'{n}_{anim}_{layer}.png').exists()]
            m = measure(frame0(d / f'{n}_{anim}.png', side), em)
            bad = check(m, PISO[etapa], kind == 'retrato')
            fails += bool(bad)
            print(line(f'{n} {etapa} {kind}', m, bad))
    sparks = ART / 'sparks'
    for t in sorted(REFEITAS_FAGULHA):
        m = measure(frame0(sparks / f'spark_{t}.png', 12), [frame0(sparks / f'spark_{t}_glow.png', 12)])
        bad = check(m, PISO['fagulha'], False)
        fails += bool(bad)
        print(line(f'spark_{t} fagulha mapa', m, bad))
    print(f'pendentes (sem arte final ainda): {", ".join(pend)}')
    print('ok' if not fails else f'{fails} abaixo do piso')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
