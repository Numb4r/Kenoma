#!/usr/bin/env python3
"""Monta workbench/catalog/catalog.json a partir dos dados do jogo, sem inventar nada:

- app/assets/data/ (clima.json, epochs.json, items.json, creatures.json, balance.json) e shared/biomes.json;
- catalog/formas/manifesto.json e catalog/dados.json, que o `flutter test test_workbench/render_sprites_test.dart` grava
  com as funções do próprio jogo (formas do Bestiário, nomes dos tipos, habilidades por faixa, apps do celular);
- docs/checklist-celular.md, para a aba Checklist.

Os ids saem dos ids do jogo (as notas do workbench ficam presas a eles). As imagens que existirem em catalog/ entram; as que
faltarem ficam sem imagem. Uso: python3 workbench/capture/catalogo.py"""
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAT = ROOT / 'workbench/catalog'
DATA = ROOT / 'app/assets/data'


def j(p: Path):
    return json.loads(p.read_text())


def img(rel: str) -> str | None:
    return rel if (CAT / rel).exists() else None


def clean(row: dict) -> dict:
    return {k: v for k, v in row.items() if v not in (None, '', [], {})}


def main() -> None:
    clima = j(DATA / 'clima.json')
    epochs = j(DATA / 'epochs.json')['epochs']
    model = epochs[-1]['climate']  # o modelo de clima da época mais nova
    creatures = j(DATA / 'creatures.json')
    items = j(DATA / 'items.json')['items']
    balance = j(DATA / 'balance.json')
    biomes = j(ROOT / 'shared/biomes.json')['biomes']
    forms = j(CAT / 'formas/manifesto.json')
    dados = j(CAT / 'dados.json')
    tipo = dados['tipos']
    species = {s['id']: s for s in creatures['species']}
    lore = creatures.get('bestiary', {})
    sections = []

    # Criaturas: uma linha por forma e variante.
    rows = []
    for f in forms:
        sp = species.get(f['form'], {})
        lo = lore.get(f['form'], {}) if isinstance(lore, dict) else {}
        layer = {'spark': 'Fagulha', 'eco': 'Eco', 'spirit': 'Espírito'}.get(f['layer'], f['layer'])
        if f.get('ritual'):
            layer = 'Ritual'
        rows.append(clean({
            'id': f['id'],
            'name': f['name'] + (f' ({f["variantName"]})' if f.get('variantName') else ''),
            'sub': f'{layer} · família {f["familyName"]}',
            'img': img(f['mapa']) if f.get('variant') and f.get('mapa') else img(f['bestiario']),  # 0.21.0: a variante com arte própria no mapa
            'r': 3 if f.get('variant') == 'shiny' else (2 if f.get('variant') == 'crimson' else (1 if f.get('variant') else 0)),
            'text': f.get('variantTrait') or (lo.get('about') if isinstance(lo, dict) else None),
            'tags': [t for t in [f.get('variantName'), 'só por ritual' if f.get('ritual') else None] if t],
            'fields': clean({'Tipo': tipo.get(f['type'], f['type']), 'Família': f['familyName'], 'Camada': layer, 'Variante': f.get('variantName') or 'comum',
                             'Número': f['number'], 'Desde a época': sp.get('since_epoch'), 'Sprite do mapa': f.get('mapa')}),
        }))
    for cor, nome in [('cor', 'em cor'), ('cinza', 'em escala de cinza')]:
        rows.append(clean({'id': f'folha_variantes_{cor}', 'name': f'Folha de contato das variantes ({nome})', 'sub': 'todas as formas, no tamanho do mapa',
                           'img': img(f'variantes_{cor}.png'), 'text': 'Colunas: comum, Urbana, Verde, Aquática, Residencial, Iluminada, Sagrada, Carmesim, Brilhante (test_workbench/variant_sheet_test.dart).',
                           'fields': {'Tipo': 'folha', 'Variante': 'todas'}}))
    sections.append({'id': 'formas', 'group': 'Criaturas', 'label': 'Formas', 'title': 'Famílias e formas',
                     'lede': f'Cada forma do Bestiário e cada variante ({len(rows)} linhas). Os sprites são desenhados em código e renderizados pelo próprio jogo. Desde a 0.21.0 a variante tem arte própria no mapa (valor e acessório, legível em cinza); a imagem dela é a do mapa.',
                     'layout': 'grid', 'filter': 'Tipo', 'rows': rows})

    # Habilidades de mapa, com as três faixas.
    rows = []
    for h in dados['habilidades']:
        rows.append(clean({'id': h['species'], 'name': h['name'], 'sub': h['kind'],
                           'text': h['faixas'][0]['longo'],
                           'list': [{'name': f'Níveis {b["niveis"]}', 'text': b['curto']} for b in h['faixas']],
                           'fields': {'Camada': 'Espírito' if h['species'].endswith('.spirit') else 'Eco', **{f'Faixa {i + 1}': b['curto'] for i, b in enumerate(h['faixas'])}}}))
    sections.append({'id': 'habilidades', 'group': 'Criaturas', 'label': 'Habilidades de mapa', 'title': 'Habilidades de mapa',
                     'lede': 'O que cada espécie faz no Círculo, nas três faixas de nível, com os textos do jogo.', 'layout': 'list', 'filter': 'Camada', 'rows': rows})

    # Climas, com a origem do modelo da época.
    origem = {'native': 'Nativo', 'other_region': 'Outras regiões', 'mystic': 'Místico'}
    rows = []
    for cid, c in clima['climates'].items():
        if c.get('until_epoch'):
            continue  # a Chuva Carmim e a Garoa Prismática: só as épocas até a 11; na 12 são tingimentos de evento
        cat = model['climates'].get(cid, {}).get('category')
        foto = 'eventos/clima__cold.png' if cid == 'cold' else f'climas/{cid}.png'  # o Frio, de manhã
        rows.append(clean({'id': cid, 'name': c.get('name', cid), 'sub': origem.get(cat, cat), 'img': img(foto),
                           'text': c.get('hud'), 'fields': {'Origem': origem.get(cat, cat or '—')}}))
    sections.append({'id': 'climas', 'group': 'Mundo', 'label': 'Climas', 'title': 'Climas',
                     'lede': 'Os climas da época 12: um de cada vez, tudo o que cai do céu ou cobre a vista. Capturados no emulador (Simulação de clima, no Centro), já formados no chão; o Frio de manhã.',
                     'layout': 'wide', 'filter': 'Origem', 'keepOrder': True, 'rows': rows})

    # Eventos da época 12 (por cima do clima) e as três combinações.
    eventos = j(DATA / 'eventos.json')
    names = {**{k: v.get('name', k) for k, v in clima['climates'].items()}, **{k: v.get('name', k) for k, v in eventos['events'].items()}}
    cal = model.get('calendar', [])
    origem_ev: dict[str, list[str]] = {}
    for e in cal:
        for cid in ([e['climate']] if 'climate' in e else e.get('climates', [])):
            if cid in model.get('events', {}):
                origem_ev.setdefault(cid, []).append(clima.get('events', {}).get(e['id'], {}).get('name', e['id']))
    for e in model.get('eclipses', []):
        origem_ev.setdefault(e['climate'], []).append('eclipse visível da região')
    for e in model.get('astro', []):
        origem_ev.setdefault(e['climate'], []).append('lua cheia muito perto da Terra')
    req_txt = {'day': 'dia', 'night': 'noite'}
    duas = {'crimson_moon': ('crimson_moon__chuva', 'com chuva; com sol, só o céu: crimson_moon__sol'), 'veil_prism': ('veil_prism__garoa', 'com garoa; no seco: veil_prism__seco'),
            'fog_procession': ('fog_procession', 'na Neblina; fora dela, a névoa rasa: fog_procession__sem_neblina')}
    rows = []
    for eid, e in eventos['events'].items():
        d = model['events'].get(eid, {})
        req = d.get('requires', {})
        reqs = [req_txt.get(req.get('light'), '')] + [names.get(c, c) for c in req.get('climates', [])]
        foto, nota = duas.get(eid, (eid, None))
        gif = img(f'eventos/{foto}.gif')
        origens = origem_ev.get(eid, []) + (['sorteio depois da chuva'] if eid == 'rainbow' else []) + (['sorteio raro na Tempestade e no Vendaval'] if d.get('draw') else [])
        rows.append(clean({'id': eid, 'name': e.get('name', eid), 'sub': ', '.join(origens) or 'feed assinado e debug',
                           'img': gif or img(f'eventos/{foto}.png'), 'text': e.get('hud'), 'tags': ['GIF'] if gif else None,
                           'fields': clean({'Origem': ', '.join(origens) or 'feed assinado', 'Requisito': ' ou '.join(r for r in reqs if r) or 'nenhum',
                                            'Tinge': ', '.join(names.get(c, c) for c in d.get('tint', {}).get('climates', [])) or None, 'Fotos': nota})}))
    for k, c in eventos.get('combos', {}).items():
        foto = f'eventos/combo__{k}'
        rows.append(clean({'id': f'combo__{k}', 'name': c['name'], 'sub': 'combinação', 'img': img(foto + '.gif') or img(foto + '.png'), 'text': c.get('hud'),
                           'fields': {'Clima': names.get(c['climate'], c['climate']), 'Evento': names.get(c['event'], c['event'])}}))
    sections.append({'id': 'eventos', 'group': 'Mundo', 'label': 'Eventos', 'title': 'Eventos',
                     'lede': 'Os eventos da época 12, por cima de qualquer clima (até dois), e as três combinações. Cada foto no estado certo: os noturnos à noite, os que se movem em GIF, os do feed forçados pelo debug.',
                     'layout': 'wide', 'rows': rows})

    meses = 'jan fev mar abr mai jun jul ago set out nov dez'.split()

    def when(e: dict) -> str:
        parts = []
        if 'month' in e:
            parts.append(meses[e['month'] - 1] + (f', dias {e["days"][0]} a {e["days"][1]}' if 'days' in e and e['days'][0] != e['days'][1] else (f', dia {e["days"][0]}' if 'days' in e else ', o mês todo')))
        if 'months' in e:
            parts.append(' e '.join(meses[m - 1] for m in e['months']))
        if 'anchor' in e:
            off = e.get('offset_days')
            parts.append(e['anchor'].replace('_', ' ') + (f' {off[0]:+d} a {off[1]:+d} dias' if off and off[0] != off[1] else (f' {off[0]:+d} dias' if off else '')))
        if 'hours' in e:
            parts.append(f'das {e["hours"][0]}h às {e["hours"][1]}h')
        return '; '.join(parts)

    rows = []
    for e in cal:
        cids = [e['climate']] if 'climate' in e else e.get('climates', [])
        cli = sorted({names.get(c, c) for c in cids if c not in model.get('events', {})})
        evs = sorted({names.get(c, c) for c in cids if c in model.get('events', {})})
        rows.append(clean({'id': e['id'], 'name': clima.get('events', {}).get(e['id'], {}).get('name', e['id'].replace('_', ' ')),
                           'sub': when(e), 'text': clima.get('events', {}).get(e['id'], {}).get('reason'),
                           'fields': {'Quando': when(e), 'Clima': ', '.join(cli) or 'nenhum', 'Evento': ', '.join(evs) or 'nenhum'}}))
    for e in clima.get('calendar_pending', []):
        rows.append(clean({'id': e['id'], 'name': e['name'], 'sub': 'data a definir', 'text': e.get('note'),
                           'fields': {'Quando': 'a definir', 'Evento': ', '.join(names.get(c, c) for c in e.get('climates', []))}}))
    sections.append({'id': 'calendario', 'group': 'Mundo', 'label': 'Calendário do Véu', 'title': 'Calendário do Véu',
                     'lede': 'As datas do ano, na ordem do calendário da época mais nova.', 'layout': 'list', 'keepOrder': True, 'rows': rows})

    # Biomas.
    rows = []
    for b in biomes:
        rows.append(clean({'id': b['key'], 'name': b['name'], 'img': img(f'biomas/{b["key"]}_lado_a_lado.png') or img(f'biomas/{b["key"]}.png'),
                           'sub': f'desde a época {b["since_epoch"]}' if b.get('since_epoch') else None,
                           'tags': b.get('palette'), 'fields': {'Prioridade': b.get('priority'), 'Desde a época': b.get('since_epoch', 0)}}))
    sections.append({'id': 'biomas', 'group': 'Mundo', 'label': 'Biomas', 'title': 'Biomas',
                     'lede': 'Os biomas do shared/biomes.json. À esquerda o mapa de hoje no emulador (uma célula do bioma, com a grade de biomas do debug); à direita a cena do bioma no Laboratório visual (0.21.0), que só entra no mapa quando for aprovada.',
                     'layout': 'wide', 'rows': rows})

    # Materiais.
    rows = [clean({'id': i['id'], 'name': i['name'], 'text': i.get('about'), 'fields': {'Tipo': 'material'}}) for i in items if i.get('kind') == 'material']
    sections.append({'id': 'materiais', 'group': 'Itens', 'label': 'Materiais', 'title': 'Materiais',
                     'lede': 'Os materiais do items.json. No mapa são caixinhas desenhadas em código, sem arte própria.', 'layout': 'list', 'rows': rows})

    # Veículos do Modo Viagem.
    nomes = {'foot': 'A pé', 'bike': 'Bicicleta', 'moto': 'Moto', 'car': 'Carro', 'bus': 'Ônibus'}
    rows = [clean({'id': k, 'name': nomes.get(k, k), 'fields': {'Velocidade máxima (km/h)': v.get('max_kmh'), 'Faixa de coleta (m)': v.get('band_m'),
                                                              'Fagulhas por km': v.get('sparks_per_km'), 'Velocidade na rota (km/h)': v.get('route_kmh')}})
            for k, v in balance['travel']['vehicles'].items()]
    sections.append({'id': 'veiculos', 'group': 'Sistemas', 'label': 'Veículos', 'title': 'Veículos do Modo Viagem',
                     'lede': 'Os veículos do Modo Viagem (balance.json, travel). Os "veículos especiais do tráfego" do GDD são da fase 2 e ainda não estão no jogo.',
                     'layout': 'list', 'keepOrder': True, 'rows': rows})

    # Apps do celular.
    rows = [clean({'id': a['id'], 'name': a['nome'], 'fields': {'Nível': a['nivel']}}) for a in dados['apps']]
    sections.append({'id': 'apps', 'group': 'Sistemas', 'label': 'Apps do celular', 'title': 'Apps do celular',
                     'lede': 'Os apps do celular do jogo e o nível em que abrem (balance.json, phone.apps).', 'layout': 'list', 'keepOrder': True, 'rows': rows})

    # Checklist do celular, na ordem do arquivo.
    rows, version = [], ''
    for line in (ROOT / 'docs/checklist-celular.md').read_text().splitlines():
        if line.startswith('## '):
            version = line[3:].strip()
        m = re.match(r'- \[( |x)\] `([^`]+)` \*\*(.+?)\*\* ?(.*)', line)
        if m:
            rows.append(clean({'id': m.group(2), 'name': m.group(3).rstrip('.'), 'sub': version, 'text': m.group(4).lstrip(', ').strip(),
                               'fields': {'Versão': version, 'Feito': 'sim' if m.group(1) == 'x' else 'não'}}))
    sections.append({'id': 'checklist', 'group': 'Celular', 'label': 'Checklist', 'title': 'Checklist do celular',
                     'lede': 'O que conferir no moto g54 quando a versão for instalada (docs/checklist-celular.md). Uma nota num item que falhou vira nota de bug.',
                     'layout': 'list', 'filter': 'Versão', 'keepOrder': True, 'rows': rows})

    out = {'made': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), 'sections': sections}
    (CAT / 'catalog.json').write_text(json.dumps(out, ensure_ascii=False, indent=1))
    for s in sections:
        sem = sum(1 for r in s['rows'] if s['layout'] != 'list' and 'img' not in r)
        print(f'{s["id"]}: {len(s["rows"])} linhas' + (f', {sem} sem imagem' if sem else ''))


if __name__ == '__main__':
    main()
