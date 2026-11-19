#!/usr/bin/env python3
"""Folha da família pronta ao lado do Humoth: docs/art/final/<familia>.png.

Fileiras: noite (corpo com o tom da noite e emissivos por cima) e dia (corpo sem tom, emissivos apagados), quadro 0 do
idle a 4x; depois os retratos a 2x. Rodar: python3 tools/art/creatures/familia.py hum fagulha:electric eco:humoth ...
(cada argumento depois da família é etapa:pasta; a Fagulha usa o tipo de tools/art/sparks/).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ART = Path(__file__).resolve().parent.parent
OUT = ART.parents[1] / 'docs' / 'art' / 'final'
NIGHT, DAY, INK = (38, 36, 70), (128, 126, 120), (220, 214, 236)
TONE = (150, 140, 200)  # tom da noite multiplicado no corpo
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 12)
GAP = 16


def strip0(path: Path, side: int) -> Image.Image | None:
    return Image.open(path).convert('RGBA').crop((0, 0, side, side)) if path.exists() else None


def piece(etapa: str, pasta: str) -> tuple:
    """(nome, corpo e emissivos do mapa, corpo e emissivos do retrato ou None)."""
    if etapa == 'fagulha':
        d = ART / 'sparks'
        return (f'fagulha {pasta}', (strip0(d / f'spark_{pasta}.png', 12), [strip0(d / f'spark_{pasta}_glow.png', 12)]), None)
    import json
    d = ART / 'creatures' / pasta
    meta = json.loads((d / f'{pasta}.json').read_text())
    def layers(anim: str, side: int) -> tuple:
        return strip0(d / f'{pasta}_{anim}.png', side), [e for l in ('glow', 'leds') if (e := strip0(d / f'{pasta}_{anim}_{l}.png', side))]
    return (f'{etapa} {pasta}', layers('idle', meta['frame']), layers('portrait', meta['portrait']['frame']))


def compose(body: Image.Image, ems: list, scale: int, night: bool) -> Image.Image:
    bg = Image.new('RGBA', body.size, NIGHT if night else DAY)
    b = body
    if night:
        r, g, bl, a = body.split()
        b = Image.merge('RGBA', [c.point(lambda v, t=t: v * t // 255) for c, t in zip((r, g, bl), TONE)] + [a])
    bg.alpha_composite(b)
    if night:
        for e in ems:
            bg.alpha_composite(e)
    return bg.resize((body.width * scale, body.height * scale), Image.NEAREST)


def main() -> None:
    fam, pieces = sys.argv[1], [piece(*a.split(':')) for a in sys.argv[2:]]
    rows = []
    for night in (True, False):
        rows.append([(n, compose(*m, 4, night)) for n, m, _ in pieces])
    rows.append([(n, compose(*p, 2, True)) for n, _, p in pieces if p])
    cell = lambda n, i: max(i.width, int(dr0.textlength(n, font=FONT)))
    dr0 = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    w = max(sum(cell(n, i) + GAP for n, i in r) for r in rows) + GAP
    h = sum(max(i.height for _, i in r) + 20 + GAP for r in rows) + GAP
    sheet = Image.new('RGBA', (w, h), (24, 22, 40))
    dr, y = ImageDraw.Draw(sheet), GAP
    for r in rows:
        x = GAP
        for n, i in r:
            dr.text((x, y), n, font=FONT, fill=INK)
            sheet.alpha_composite(i, (x, y + 20))
            x += cell(n, i) + GAP
        y += max(i.height for _, i in r) + 20 + GAP
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / f'{fam}.png')
    print(OUT / f'{fam}.png')


if __name__ == '__main__':
    main()
