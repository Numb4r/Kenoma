#!/usr/bin/env python3
"""Reescreve os itens de spawn das épocas 2 e 3 (a época 3 copia a 2) com a densidade pedida. Uso:
  python3 tools/calibrate_density.py --eco 2.2 --sparks 6 0.35 --materials 2 0.33
`--eco` multiplica as chances de Eco da época 1; `--sparks N q` e `--materials N q` dão N itens com chance q em todos os biomas.
Roda sobre `assets/data/epochs.json`; depois `dart run tools/sim_caminhada.dart` mede o resultado."""
import argparse, copy, json

ap = argparse.ArgumentParser()
ap.add_argument('--eco', type=float, required=True)
ap.add_argument('--sparks', nargs=2, type=float, required=True)
ap.add_argument('--materials', nargs=2, type=float, required=True)
ap.add_argument('--ref', type=float, default=70, help='ref_length_m: comprimento andável que vale fator 1')
ap.add_argument('--maxf', type=float, default=3, help='max_factor: teto do fator')
a = ap.parse_args()
P = 'assets/data/epochs.json'
d = json.load(open(P))
e1 = next(e for e in d['epochs'] if e['id'] == 1)
base = e1['spawn']['items']
eco, spark, mat = copy.deepcopy(base[0]), base[1], base[3]
eco['chance'] = {k: round(v * a.eco, 4) for k, v in base[0]['chance'].items()}
items = [eco]
idx = 1
for kind, tpl, (n, q) in (('spark', spark, a.sparks), ('material', mat, a.materials)):
    for _ in range(int(n)):
        it = copy.deepcopy(tpl)
        it['index'] = idx
        it['chance'] = {k: q for k in tpl['chance']}
        items.append(it)
        idx += 1
for e in d['epochs']:
    if e['id'] in (2, 3):
        e['spawn']['items'] = copy.deepcopy(items)
        e['walkable']['ref_length_m'] = a.ref
        e['walkable']['max_factor'] = a.maxf
json.dump(d, open(P, 'w'), indent=2, ensure_ascii=False)
open(P, 'a').write('\n')
print('itens:', [(i['index'], i['kind']) for i in items])
