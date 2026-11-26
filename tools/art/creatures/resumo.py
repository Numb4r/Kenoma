#!/usr/bin/env python3
"""Peças do resumo da arte final para o dono, em docs/art/final/.

arquetipos_128.png      os doze retratos de 128 do Arquétipo (quadro 0), de noite com os emissivos e de dia, a 2x
<familia>_arquetipo.gif o Arquétipo animado a 4x no asfalto de noite: idle, drift, alert, flee, spawn, tuned (no fps
                        do json) e por fim o retrato animado (128 a 2x), para hum e wyrm
entidades_ajustadas.png as Entidades de Clod, Rill e Sprig a 6x, de noite e de dia, com o retrato de 96 a 3x ao lado
Rodar: python3 tools/art/creatures/resumo.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

from familia import ART, DAY, FONT, GAP, INK, NIGHT, OUT, compose, strip0

FAMS = ['hum', 'soot', 'frond', 'shade', 'wisp', 'wyrm', 'glare', 'bit', 'clod', 'rill', 'rust', 'sprig']
ANIMS = ['idle', 'drift', 'alert', 'flee', 'spawn', 'tuned']
ASPHALT, TINT, NA = (0x34, 0x39, 0x49), (0x14, 0x10, 0x33), 0.58   # o fundo e o tom da noite das folhas (K.run)


def layers(pasta: str, anim: str, side: int, frame: int = 0) -> tuple:
    """Corpo e emissivos (glow, leds) de um quadro de uma tira."""
    d = ART / 'creatures' / pasta
    def cut(suffix: str) -> Image.Image | None:
        p = d / f'{pasta}_{anim}{suffix}.png'
        return Image.open(p).convert('RGBA').crop((frame * side, 0, (frame + 1) * side, side)) if p.exists() else None
    return cut(''), [e for s in ('_glow', '_leds') if (e := cut(s))]


def sheet(rows: list, name: str) -> Path:
    """rows: listas de (rótulo, imagem). Monta a folha com o rótulo em cima de cada imagem."""
    probe = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    cell = lambda n, i: max(i.width, int(probe.textlength(n, font=FONT)))
    w = max(sum(cell(n, i) + GAP for n, i in r) for r in rows) + GAP
    h = sum(max(i.height for _, i in r) + 20 + GAP for r in rows) + GAP
    img = Image.new('RGBA', (w, h), (24, 22, 40))
    dr, y = ImageDraw.Draw(img), GAP
    for r in rows:
        x = GAP
        for n, i in r:
            dr.text((x, y), n, font=FONT, fill=INK)
            img.alpha_composite(i, (x, y + 20))
            x += cell(n, i) + GAP
        y += max(i.height for _, i in r) + 20 + GAP
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name)
    return OUT / name


def arquetipos() -> Path:
    rows = []
    for night in (True, False):
        rows.append([(f'{f} ({"noite" if night else "dia"})', compose(*layers(f'{f}_arquetipo', 'portrait', 128), 2, night)) for f in FAMS])
    return sheet(rows, 'arquetipos_128.png')


def night_frame(body: Image.Image, ems: list, scale: int, size: int) -> Image.Image:
    """Um quadro no asfalto de noite: o corpo com o tom da noite, leds e glow por cima, centrado em size."""
    mix = lambda c: tuple(int(c[i] * (1 - NA) + TINT[i] * NA) for i in range(3))
    bg = Image.new('RGBA', body.size, mix(ASPHALT) + (255,))
    r, g, b, a = body.split()
    tone = Image.merge('RGBA', [ch.point(lambda v, t=t: int(v * (1 - NA) + t * NA)) for ch, t in zip((r, g, b), TINT)] + [a])
    bg.alpha_composite(tone)
    for e in ems:
        bg.alpha_composite(e)
    big = bg.resize((body.width * scale, body.height * scale), Image.NEAREST)
    out = Image.new('RGBA', (size, size), mix(ASPHALT) + (255,))
    out.alpha_composite(big, ((size - big.width) // 2, (size - big.height) // 2))
    return out.convert('RGB')


def gif(fam: str) -> Path:
    pasta = f'{fam}_arquetipo'
    meta = json.loads((ART / 'creatures' / pasta / f'{pasta}.json').read_text())
    side, frames, times = meta['frame'], [], []
    for anim in ANIMS:
        a = meta['anims'][anim]
        for _ in range(2 if anim in ('idle', 'drift', 'alert') else 1):
            for f in range(a['frames']):
                frames.append(night_frame(*layers(pasta, anim, side, f), 4, side * 4))
                times.append(1000 // a['fps'])
    p = meta['portrait']
    for _ in range(3):
        for f in range(p['frames']):
            frames.append(night_frame(*layers(pasta, 'portrait', p['frame'], f), 2, side * 4))
            times.append(1000 // p['fps'])
    out = OUT / f'{pasta}.gif'
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=times, loop=0, disposal=2)
    return out


def entidades() -> Path:
    rows = []
    for fam in ('clod', 'rill', 'sprig'):
        pasta = f'{fam}_entidade'
        mapa, ret = layers(pasta, 'idle', 48), layers(pasta, 'portrait', 96)
        rows.append([(f'{pasta} mapa, noite', compose(*mapa, 6, True)), (f'{pasta} mapa, dia', compose(*mapa, 6, False)),
                     (f'{pasta} retrato, noite', compose(*ret, 3, True)), (f'{pasta} retrato, dia', compose(*ret, 3, False))])
    return sheet(rows, 'entidades_ajustadas.png')


if __name__ == '__main__':
    print(arquetipos())
    for fam in ('hum', 'wyrm'):
        print(gif(fam))
    print(entidades())
