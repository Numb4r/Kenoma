#!/usr/bin/env python3
"""Junta a arte das criaturas de cada família numa folha só (0.26.2): app/assets/art/creatures/atlas/<família>.png e .json.

O app lia 1680 PNGs soltos, um por um, e cada decodificação custava ~7 ms no moto g54 (11 s no total). Com a folha são 12
imagens. A fonte continua sendo as pastas de app/assets/art/creatures/<pasta>/ (copiadas por sync_creature_art.py), que
não vão mais para o APK. O JSON da folha leva o retângulo de cada PNG, o JSON da criatura e o das variantes, e o SHA-256
das fontes: o build do Android roda este script antes de empacotar (a folha só é regravada se a fonte mudou) e um teste
falha se a folha ficou velha.

uso: python3 scripts/pack_creature_atlas.py [--check]
"""
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / 'app/assets/art/creatures'
OUT = ART / 'atlas'
WIDTH = 2048  # o lado máximo de textura do g54 é 4096; 2048 deixa a altura de cada família perto de 1000
PAD = 1


def families() -> dict[str, list[str]]:
    """Família → pastas, na ordem do índice."""
    index = json.loads((ART / 'index.json').read_text())
    out: dict[str, list[str]] = {}
    for sid, entry in sorted(index['species'].items()):
        out.setdefault(sid.split('.')[0], [])
        if entry['folder'] not in out[sid.split('.')[0]]:
            out[sid.split('.')[0]].append(entry['folder'])
    return out


def source_sha(folders: list[str]) -> str:
    """O SHA-256 das fontes da família: cada PNG e JSON das pastas, pelo caminho relativo, em ordem."""
    h = hashlib.sha256()
    for folder in sorted(folders):
        for f in sorted((ART / folder).iterdir()):
            if f.suffix in ('.png', '.json'):
                h.update(f'{folder}/{f.name}\n'.encode())
                h.update(f.read_bytes())
    return h.hexdigest()


def pack(folders: list[str]) -> tuple[Image.Image, dict]:
    files = [(folder, f) for folder in sorted(folders) for f in sorted((ART / folder).glob('*.png'))]
    images = [(folder, f.name, Image.open(f).convert('RGBA')) for folder, f in files]
    # Prateleiras: das mais altas para as mais baixas, da esquerda para a direita.
    order = sorted(images, key=lambda t: (-t[2].height, t[0], t[1]))
    x = y = shelf = 0
    rects = {}
    for folder, name, im in order:
        if im.width > WIDTH:
            raise SystemExit(f'{folder}/{name}: {im.width} px, mais largo que a folha')
        if x + im.width > WIDTH:
            x, y, shelf = 0, y + shelf + PAD, 0
        rects[(folder, name)] = (x, y, im.width, im.height)
        x += im.width + PAD
        shelf = max(shelf, im.height)
    sheet = Image.new('RGBA', (WIDTH, y + shelf), (0, 0, 0, 0))
    for folder, name, im in images:
        sheet.paste(im, rects[(folder, name)][:2])
    meta = {}
    for folder in sorted(folders):
        meta[folder] = {
            'meta': json.loads((ART / folder / f'{folder}.json').read_text()),
            'variants': json.loads(p.read_text()) if (p := ART / folder / f'{folder}_variants.json').exists() else {},
            'rects': {name: list(r) for (fo, name), r in sorted(rects.items()) if fo == folder},
        }
    return sheet, meta


def main() -> None:
    check = '--check' in sys.argv
    OUT.mkdir(exist_ok=True)
    stale = []
    for fam, folders in families().items():
        sha = source_sha(folders)
        jp = OUT / f'{fam}.json'
        if jp.exists() and json.loads(jp.read_text()).get('source_sha256') == sha and (OUT / f'{fam}.png').exists():
            continue
        stale.append(fam)
        if check:
            continue
        sheet, meta = pack(folders)
        buf = io.BytesIO()
        sheet.save(buf, 'PNG', optimize=True)
        (OUT / f'{fam}.png').write_bytes(buf.getvalue())
        jp.write_text(json.dumps({'source_sha256': sha, 'size': list(sheet.size), 'folders': meta}, ensure_ascii=False, separators=(',', ':')) + '\n')
        print(f'{fam}: {len(folders)} pastas, {sheet.size[0]}×{sheet.size[1]}')
    if check and stale:
        raise SystemExit(f'folhas velhas: {", ".join(stale)} (rode scripts/pack_creature_atlas.py)')
    if not stale:
        print('folhas em dia')


if __name__ == '__main__':
    main()
