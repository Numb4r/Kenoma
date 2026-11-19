"""Monta as folhas de conceito das criaturas (docs/art/conceitos/).

Entrada, por família em tools/art/creatures/conceitos/<familia>/:
  <familia>_<etapa>_mapa.png          corpo, um quadro, no tamanho do mapa
  <familia>_<etapa>_mapa_emissivo.png o que brilha aceso, mesmo quadro (opcional)
  <familia>_<etapa>_retrato.png       corpo do retrato (96, ou maior no Arquétipo)
  <familia>_<etapa>_retrato_emissivo.png
etapa: fagulha, eco, espirito, entidade, arquetipo.

Saída: docs/art/conceitos/<familia>.png, ecos.png, arquetipos.png e escada.png.
Rodar da raiz do repo (ou worktree): python3 tools/art/creatures/conceitos/folhas.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
OUT = REPO / "docs" / "art" / "conceitos"
HUMOTH = HERE.parent / "humoth"

FAMILIES = ["hum", "soot", "rill", "frond", "clod", "rust", "glare", "shade", "wisp", "bit", "sprig", "wyrm"]
STAGES = ["fagulha", "eco", "espirito", "entidade", "arquetipo"]
STAGE_NAME = {"fagulha": "Fagulha", "eco": "Eco", "espirito": "Espírito", "entidade": "Entidade Maior", "arquetipo": "Arquétipo"}
NIGHT = (38, 36, 70)    # asfalto de noite, o fundo da folha do Humoth
DAY = (128, 126, 120)   # concreto de dia
INK = (220, 214, 236)
GAP = 16
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 11)


def seed_hum_eco() -> None:
    """O Eco do Hum é o Humoth como está: quadro 0 do idle e do retrato, emissivos juntos."""
    d = HERE / "hum"
    d.mkdir(exist_ok=True)
    for src, fw, dst in (("idle", 28, "mapa"), ("portrait", 96, "retrato")):
        crop = lambda p: Image.open(p).convert("RGBA").crop((0, 0, fw, Image.open(p).height))
        crop(HUMOTH / f"humoth_{src}.png").save(d / f"hum_eco_{dst}.png")
        em = crop(HUMOTH / f"humoth_{src}_glow.png")
        em.alpha_composite(crop(HUMOTH / f"humoth_{src}_leds.png"))
        em.save(d / f"hum_eco_{dst}_emissivo.png")


def load(fam: str, stage: str, kind: str) -> Image.Image | None:
    base = HERE / fam / f"{fam}_{stage}_{kind}"
    body = Path(f"{base}.png")
    if not body.exists():
        return None
    im = Image.open(body).convert("RGBA")
    em = Path(f"{base}_emissivo.png")
    if em.exists():
        im.alpha_composite(Image.open(em).convert("RGBA"))
    return im


def up(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def strip(cells: list[tuple[str, Image.Image | None]], k: int, bg: tuple[int, int, int]) -> Image.Image:
    """Uma fileira com os sprites ampliados k vezes, pés numa linha só, e o rótulo em cima."""
    ims = [(lbl, up(im, k) if im else None) for lbl, im in cells]
    cell = lambda lbl, im: max(im.width if im else 28 * k, int(FONT.getlength(lbl)))
    w = sum(cell(lbl, im) + GAP for lbl, im in ims) + GAP
    h = max((im.height for _, im in ims if im), default=28 * k) + 2 * GAP + 12
    row = Image.new("RGBA", (w, h), bg + (255,))
    draw = ImageDraw.Draw(row)
    x = GAP
    for lbl, im in ims:
        cw = cell(lbl, im)
        draw.text((x, 4), lbl, fill=INK, font=FONT)
        if im:
            row.alpha_composite(im, (x, h - GAP - im.height))
        else:
            draw.rectangle((x, h - GAP - 28 * k, x + 28 * k, h - GAP), outline=(90, 80, 120))
        x += cw + GAP
    return row


def stack(rows: list[Image.Image], title: str) -> Image.Image:
    w = max(r.width for r in rows)
    sheet = Image.new("RGBA", (w, sum(r.height for r in rows) + 24), NIGHT + (255,))
    ImageDraw.Draw(sheet).text((GAP, 6), title, fill=INK, font=FONT)
    y = 24
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    return sheet


def label(fam: str, stage: str, im: Image.Image | None) -> str:
    return f"{fam} {STAGE_NAME[stage]}" + (f" {im.width}x{im.height}" if im else " (falta)")


def family_sheet(fam: str) -> Image.Image:
    maps = [(label(fam, s, load(fam, s, "mapa")), load(fam, s, "mapa")) for s in STAGES]
    ports = [(label(fam, s, load(fam, s, "retrato")), load(fam, s, "retrato")) for s in STAGES]
    return stack([
        strip(maps, 2, NIGHT),        # perto do tamanho real na tela
        strip(maps, 4, NIGHT),
        strip(maps, 4, DAY),
        strip(ports, 2, NIGHT),
    ], f"{fam}: Fagulha, Eco, Espírito, Entidade Maior, Arquétipo (mapa 2x e 4x, noite e dia; retrato 2x)")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    seed_hum_eco()
    present = [f for f in FAMILIES if (HERE / f).is_dir()]
    for fam in present:
        family_sheet(fam).convert("RGB").save(OUT / f"{fam}.png")
    for stage, name in (("eco", "ecos"), ("arquetipo", "arquetipos")):
        maps = [(label(f, stage, load(f, stage, "mapa")), load(f, stage, "mapa")) for f in present]
        ports = [(label(f, stage, load(f, stage, "retrato")), load(f, stage, "retrato")) for f in present]
        stack([strip(maps, 4, NIGHT), strip(maps, 4, DAY), strip(ports, 2, NIGHT)],
              f"{STAGE_NAME[stage]} de todas as famílias (o Hum é a régua)").convert("RGB").save(OUT / f"{name}.png")
    rows = [strip([(label(f, s, load(f, s, "mapa")), load(f, s, "mapa")) for s in STAGES], 3, NIGHT) for f in present]
    stack(rows, "Escada de tom: cada família da Fagulha ao Arquétipo, no tamanho do mapa (3x)").convert("RGB").save(OUT / "escada.png")
    print("folhas:", ", ".join(present), "->", OUT)


if __name__ == "__main__":
    main()
