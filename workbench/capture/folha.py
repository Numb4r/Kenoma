#!/usr/bin/env python3
"""Folhas de contato do catálogo do workbench, uma por aba com imagem (catalog/folhas/<aba>.png), para o criativo conferir
a olho. Uso: python3 workbench/capture/folha.py [aba ...]"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CAT = Path(__file__).resolve().parents[1] / 'catalog'


def sheet(sec: dict) -> Path | None:
    rows = [r for r in sec['rows'] if r.get('img')]
    if not rows:
        return None
    wide = sec['layout'] == 'wide'
    w, h = (180, 400) if wide else (110, 110)
    cols = 8 if wide else 12
    out = Image.new('RGB', (cols * w, ((len(rows) + cols - 1) // cols) * (h + 14)), (18, 14, 26))
    d = ImageDraw.Draw(out)
    for i, r in enumerate(rows):
        im = Image.open(CAT / r['img']).convert('RGBA')
        im.thumbnail((w - 6, h - 6), Image.NEAREST if not wide else Image.BILINEAR)
        x, y = (i % cols) * w, (i // cols) * (h + 14)
        out.paste(im, (x + 3, y + 3), im)
        d.text((x + 3, y + h), r['id'][:26], fill=(201, 184, 255))
    (CAT / 'folhas').mkdir(exist_ok=True)
    path = CAT / 'folhas' / f'{sec["id"]}.png'
    out.save(path)
    return path


if __name__ == '__main__':
    cat = json.loads((CAT / 'catalog.json').read_text())
    for s in cat['sections']:
        if len(sys.argv) > 1 and s['id'] not in sys.argv[1:]:
            continue
        p = sheet(s)
        if p:
            print(p)
