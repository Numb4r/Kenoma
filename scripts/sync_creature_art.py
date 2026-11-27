#!/usr/bin/env python3
"""Copia a arte pronta das criaturas (tools/art/creatures/<nome>/) para app/assets/art/creatures/ (0.25.1).

Só entra a pasta completa (json, variantes, retrato e folha de conferência). Copia os PNG e os JSON, sem as fontes
(.aseprite, .lua) nem a folha. Reescreve o índice (espécie -> pasta e gatilho de nascer da família) e refaz as folhas de
cada família (pack_creature_atlas.py, 0.26.2), que é o que vai no APK. Rodar de novo é seguro.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC, DST = ROOT / 'tools/art/creatures', ROOT / 'app/assets/art/creatures'
SPAWN = {'hum': 'lightning_lamp', 'rill': 'puddle', 'clod': 'ground', 'wisp': 'fog', 'soot': 'manhole', 'frond': 'crack', 'wyrm': 'crater_crack',
         'glare': 'glint_rainbow', 'bit': 'static_sign', 'rust': 'grate', 'sprig': 'whirl'}  # GDD: de onde cada família nasce


def main() -> None:
    species = json.loads((ROOT / 'app/assets/data/creatures.json').read_text())['species']
    by_name = {s['name'].lower(): s['id'] for s in species}
    index_path = DST / 'index.json'
    index = json.loads(index_path.read_text())
    out = {}
    for d in sorted(p for p in SRC.iterdir() if p.is_dir()):
        n = d.name
        if not all((d / f).exists() for f in (f'{n}.json', f'{n}_variants.json', f'{n}_portrait.png', f'{n}_folha.png')):
            print(f'incompleta, fica de fora: {n}')
            continue
        # As etapas altas ainda sem nome moram em <familia>_entidade e <familia>_arquetipo (docs/art/estilo-criaturas.md).
        fam, _, stage = n.partition('_')
        sid = by_name.get(n) or {'entidade': f'{fam}.major', 'arquetipo': f'{fam}.archetype'}.get(stage)
        if sid not in {s['id'] for s in species}:
            sid = None
        if sid is None:
            print(f'sem espécie com o nome {n}')
            continue
        target = DST / n
        target.mkdir(parents=True, exist_ok=True)
        for f in d.iterdir():
            if f.suffix in ('.png', '.json') and '_folha' not in f.name and '_src' not in f.name:
                shutil.copy2(f, target / f.name)
        entry = {'folder': n}
        if sid.split('.')[0] in SPAWN:
            entry['spawn'] = SPAWN[sid.split('.')[0]]
        out[sid] = entry
    index['species'] = dict(sorted(out.items()))
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(out)} espécies com arte: {", ".join(sorted(out))}')
    # 0.26.2: o APK leva só as folhas de cada família (as pastas ficam de fonte, fora do pubspec).
    subprocess.run([sys.executable, str(ROOT / 'scripts/pack_creature_atlas.py')], check=True)


if __name__ == '__main__':
    main()
