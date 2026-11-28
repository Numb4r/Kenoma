"""O lote no Véu (0.29.0): peças do lote, porta do Véu, vazio, borda, ícones e a folha de conferência.
Roda da raiz do repo: tools/art/rodar.sh tools/art/lot/build_lot.py
Saídas: app/assets/art/ui/lot/*.png, app/assets/art/ui/icons/lot_*.png, app/assets/art/map/veil_door*.png,
tools/art/lot/out/folha.png e o texto do carimbo da porta (VEIL_STAMPS abaixo)."""
import os, random
from PIL import Image, ImageDraw

ROOT = os.getcwd()
LOT = f'{ROOT}/app/assets/art/ui/lot'
ICO = f'{ROOT}/app/assets/art/ui/icons'
MAP = f'{ROOT}/app/assets/art/map'
OUT = f'{ROOT}/tools/art/lot/out'
VEIL_STAMPS = f'{OUT}/veil_door_stamps.txt'  # as linhas que a thread principal cola em map_style.dart
for d in (LOT, ICO, MAP, OUT): os.makedirs(d, exist_ok=True)

# chave -> hex. As reusadas vêm de mapPalette (map_style.dart); as novas estão marcadas.
P = {
    'outline': '1a1424',
    'veil_void_dark': '0d0a16', 'veil_void': '120e1a', 'veil_void_light': '1e1830',      # novas
    'fold_dark': '3a3550', 'fold': '48425e', 'fold_light': '585272',                       # novas
    'plank_dark': '6a4628', 'plank': '9a6a3e', 'plank_light': 'b88350',                    # novas
    'lot_wall_top_light': 'beb8aa', 'lot_wall_top': 'a8a092', 'lot_wall_face': '6e6658',   # novas
    'lot_wall_face_dark': '4e483e',                                                        # nova
    'rug_dark': '234a70', 'rug': '2f5fa8', 'rug_light': '3b6c9a',                          # novas
    'lit_dark': 'adabb9', 'lit': 'c2c0cc', 'lit_light': 'd4d2dc',
    'roof_tile_dark': '8a4431', 'roof_tile': 'b05a40', 'roof_tile_light': 'cc7655',
    'gate_dark': '44505e', 'gate': '5e6e7e', 'pole': '3d4254', 'pole_head': 'c9cdd8',
    'home_veil_light': 'c9b8ff', 'home_veil': '9b7bff', 'home_veil_dark': '5a4a9e',
    'home_door': '9a6a3e', 'home_door_dark': '6a4628',
    'window_on': 'ffd98a', 'window_off': '1f2334', 'lane': 'c9c4a8',
    'canopy_dark': '1f5a3a', 'canopy': '2c7048', 'canopy_light': '45905a',
    'flower_white': 'f0eee0', 'flower_yellow': 'f2d15a', 'sign_blue': '2f5fa8',
    'fence': 'beb8aa', 'fence_dark': '8c867a', 'dirt_dark': '5f5443',
    'grass_dark': '2f7446', 'grass': '429658', 'grass_light': '5fb26a',
    'wall_bare': '74523f', 'wall_bare_shade': '523a30', 'wall_res_shade': '403630',
    'roof_metal_dark': '7e8a94', 'roof_metal': '9aa7b0', 'roof_metal_light': 'b4c0c8',
    # cores soltas da spec, fora de mapPalette (listadas na legenda)
    'lot_wall_baseboard': '403630', 'window_core': 'fff0b8', 'forge_mouth': 'a82e1c', 'veil_spark': 'ece6ff',
}
H = {k: v for k, v in P.items()}
O = P['outline']


class C:
    """Tela de pixels: lista de listas de hex ou None."""
    def __init__(s, w, h): s.w, s.h = w, h; s.g = [[None] * w for _ in range(h)]
    def p(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h: s.g[y][x] = P.get(c, c) if c else None
    def r(s, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w): s.p(xx, yy, c)
    def at(s, x, y): return s.g[y][x] if 0 <= x < s.w and 0 <= y < s.h else None
    def frame(s, x, y, w, h, c):
        s.r(x, y, w, 1, c); s.r(x, y + h - 1, w, 1, c); s.r(x, y, 1, h, c); s.r(x + w - 1, y, 1, h, c)
    def outline(s, only=None):
        """Contorno de 1 px por fora (4 vizinhos)."""
        new = []
        for y in range(s.h):
            for x in range(s.w):
                if s.g[y][x] is None and any(s.at(x + dx, y + dy) not in (None,) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    new.append((x, y))
        for x, y in new: s.g[y][x] = O
    def inline(s):
        """Contorno de 1 px por dentro: borda da silhueta (a tela conta como vazio)."""
        new = []
        for y in range(s.h):
            for x in range(s.w):
                if s.g[y][x] is not None and any(s.at(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    new.append((x, y))
        for x, y in new: s.g[y][x] = O
    def rows(s, art, x0, y0, legend):
        for j, row in enumerate(art):
            for i, ch in enumerate(row):
                if ch != '.': s.p(x0 + i, y0 + j, legend[ch])
    def paste(s, o, x, y):
        for j in range(o.h):
            for i in range(o.w):
                if o.g[j][i]: s.p(x + i, y + j, o.g[j][i])
    def copy(s):
        n = C(s.w, s.h); n.g = [r[:] for r in s.g]; return n
    def mirror(s):
        n = C(s.w, s.h); n.g = [r[::-1] for r in s.g]; return n
    def rot90(s):  # horário
        n = C(s.h, s.w)
        for y in range(s.h):
            for x in range(s.w): n.g[x][s.h - 1 - y] = s.g[y][x]
        return n
    def img(s):
        im = Image.new('RGBA', (s.w, s.h), (0, 0, 0, 0))
        for y in range(s.h):
            for x in range(s.w):
                if s.g[y][x]: im.putpixel((x, y), tuple(int(s.g[y][x][i:i + 2], 16) for i in (0, 2, 4)) + (255,))
        return im
    def save(s, path): s.img().save(path)


def fromimg(im):
    im = im.convert('RGBA'); c = C(*im.size)
    for y in range(c.h):
        for x in range(c.w):
            r, g, b, a = im.getpixel((x, y))
            if a: c.g[y][x] = '%02x%02x%02x' % (r, g, b)
    return c


def put(name, c, folder=LOT): c.save(f'{folder}/{name}.png'); return c


A = {}  # todos os sprites gerados, por nome (folha e conferência)

# ---------------------------------------------------------------- 1. Porta do Véu
def veil_door(open_w=0):
    c = C(16, 24)
    c.r(0, 1, 16, 3, 'home_door'); c.r(0, 3, 16, 1, 'home_door_dark')      # verga de 3 px
    for y in range(4, 22):
        c.r(0, y, 3, 1, 'home_door'); c.r(13, y, 3, 1, 'home_door')
        c.p(2, y, 'home_door_dark'); c.p(13, y, 'home_door_dark')
    c.r(0, 1, 16, 1, 'home_door'); c.r(0, 4, 3, 18, 'home_door'); c.r(2, 4, 1, 18, 'home_door_dark')
    c.r(0, 22, 16, 2, 'fence_dark')                                        # soleira
    c.r(3, 4, 10, 18, 'veil_void')
    for x in range(16): c.p(x, 0, O)
    if open_w == 0:
        zig = [7, 8, 8, 7]
        for k, y in enumerate(range(4, 22)):
            x = zig[k % 4]
            c.p(x - 1, y, 'home_veil'); c.p(x + 1, y, 'home_veil'); c.p(x, y, 'home_veil_light')
            if k % 3 == 0: c.p(x - 2, y, 'home_veil_dark'); c.p(x + 2, y, 'home_veil_dark')
    else:
        x0 = 8 - open_w // 2
        for k, y in enumerate(range(4, 22)):
            w = open_w - (2 if open_w >= 5 and (k < 2 or k > 15) else 0)
            xs = 8 - w // 2
            for x in range(xs, xs + w):
                edge = x in (xs, xs + w - 1) and w > 2
                c.p(x, y, 'home_veil' if edge else 'home_veil_light')
            if open_w == 10 and w >= 6:
                for x in (7, 8): c.p(x, y, 'veil_spark')
            if open_w == 10 and w >= 6:
                c.p(xs + 1, y, 'home_veil') if w == 10 else None
    return c

doors = {'veil_door': veil_door(0)}
for i, w in ((1, 2), (2, 5), (3, 10)): doors[f'veil_door_open_{i}'] = veil_door(w)
for n, c in doors.items(): put(n, c, MAP); A[n] = c
inv = {v: k for k, v in P.items()}
LETTER = {'outline': 'O', 'home_door': 'p', 'home_door_dark': 'q', 'fence_dark': 'f', 'veil_void': 'v', 'home_veil_light': 'L',
          'home_veil': 'V', 'home_veil_dark': 'T', 'veil_spark': 'E'}
with open(VEIL_STAMPS, 'w') as f:
    for n, c in doors.items():
        f.write(f'# {n} (16 x 24)\n')
        for row in c.g: f.write(''.join(LETTER[inv[x]] if x else '.' for x in row) + '\n')
        f.write('\n')
    f.write('# legenda: letra -> chave de mapPalette\n')
    for k, v in LETTER.items():
        f.write(f'{v} -> {k}' + ('  (NOVA, fora de mapPalette: #ece6ff)' if k == 'veil_spark' else '') + '\n')
    f.write('\n# a Porta do Véu so usa chaves existentes de mapPalette, mais `veil_spark` (#ece6ff, nova).\n')

# ---------------------------------------------------------------- 2. Vazio, borda, dobra
rnd = random.Random(29)
def noisy(w, h, base, tones):
    c = C(w, h); c.r(0, 0, w, h, base)
    for y in range(h):
        for x in range(w):
            v = rnd.random(); acc = 0
            for pct, t in tones:
                acc += pct
                if v < acc: c.p(x, y, t); break
    return c

void = noisy(32, 32, 'veil_void', [(0.03, 'veil_void_light'), (0.03, 'veil_void_dark')])
for (x, y) in ((3, 4), (20, 2), (9, 19), (26, 22)):                      # 4 fios diagonais de 3 px por módulo
    for k in range(3): void.p(x + k, y + k, 'home_veil_dark')
A['void'] = put('void', void)
fold = noisy(32, 32, 'fold', [(0.04, 'fold_dark'), (0.04, 'fold_light')])
A['fold'] = put('fold', fold)

T = [4, 4, 3, 3, 4, 4, 4, 3, 3, 3, 4, 4, 3, 3, 4, 4]       # espessura roída do fold_dark por posição ao longo da borda
def ring(d, a):
    """cor da borda à profundidade d (1 = colada no lote) e posição a ao longo dela."""
    t = T[a]
    if d <= t: return 'fold_dark'
    if d == t + 1: return 'home_veil_light'
    if d == t + 2: return 'home_veil' if a % 5 < 3 else 'veil_void'
    if d <= t + 5: return 'home_veil_dark' if (a + d) % 2 == 0 else 'veil_void'
    return 'veil_void'
edge_n = C(16, 16)
for y in range(16):
    for x in range(16): edge_n.p(x, y, ring(16 - y, x))
corner = C(16, 16)
for y in range(16):
    for x in range(16):
        u, v = 15 - x, 15 - y
        corner.p(x, y, ring(max(u, v) + 1, min(u, v)))
e = edge_n; k = corner
for n in ('n', 'l', 's', 'o'):
    A[f'edge_{n}'] = put(f'edge_{n}', e); e = e.rot90()
for n in ('no', 'nl', 'sl', 'so'):
    A[f'edge_corner_{n}'] = put(f'edge_corner_{n}', k); k = k.rot90()

# ---------------------------------------------------------------- 4. Pisos
pl = C(16, 16)
for b in range(4):
    pl.r(0, b * 4, 16, 3, 'plank'); pl.r(0, b * 4 + 3, 16, 1, 'plank_dark')
    ex = 5 if b % 2 == 0 else 11
    pl.r(ex, b * 4, 1, 3, 'plank_dark')
for x, y in ((1, 0), (9, 1), (3, 6), (13, 10)): pl.p(x, y, 'plank_light')
A['floor_plank_h'] = put('floor_plank_h', pl); A['floor_plank_v'] = put('floor_plank_v', pl.rot90())
tl = C(16, 16)
for ty in (0, 8):
    for tx in (0, 8):
        tl.r(tx, ty, 7, 7, 'lit'); tl.r(tx + 7, ty, 1, 8, 'lit_dark'); tl.r(tx, ty + 7, 8, 1, 'lit_dark'); tl.p(tx, ty, 'lit_light')
A['floor_tile'] = put('floor_tile', tl)

# ---------------------------------------------------------------- 5/6. Paredes, portas, janelas (16 x 28)
def wall_top(mask):
    T_ = [[False] * 16 for _ in range(16)]
    for y in range(4, 12):
        for x in range(4, 12): T_[y][x] = True
    for bit, (xs, ys) in ((1, (range(4, 12), range(0, 4))), (2, (range(12, 16), range(4, 12))),
                          (4, (range(4, 12), range(12, 16))), (8, (range(0, 4), range(4, 12)))):
        if mask & bit:
            for y in ys:
                for x in xs: T_[y][x] = True
    return T_

def wall(mask, kind=None):
    c = C(16, 28); t = wall_top(mask)
    def tt(x, y): return t[min(max(y, 0), 15)][min(max(x, 0), 15)]   # fora da casa, repete a borda (braço continua)
    kind_o = [[None] * 16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if t[y][x] and not all(tt(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))): kind_o[y][x] = 'o'
    for y in range(16):
        for x in range(16):
            if not t[y][x]: continue
            if kind_o[y][x]: c.p(x, y, 'outline')
            elif (y > 0 and kind_o[y - 1][x]) or (x > 0 and kind_o[y][x - 1]): c.p(x, y, 'lot_wall_top_light')
            else: c.p(x, y, 'lot_wall_top')
    for x in range(16):
        ys = [y for y in range(16) if t[y][x]]
        if not ys: continue
        lt = max(ys)
        for k in range(12):
            y = lt + 1 + k
            if y >= 28: break
            if k == 11: col = 'outline'
            elif k == 10: col = 'lot_wall_baseboard'
            elif k % 4 == 3: col = 'lot_wall_face_dark'
            else:
                band = k // 4; off = 0 if band != 1 else 4
                col = 'lot_wall_face_dark' if (x + off) % 8 == 0 else 'lot_wall_face'
            c.p(x, y, col)
    # laterais livres: o contorno da face
    base = c.copy()
    for x in range(16):
        for y in range(12, 28):
            if base.g[y][x] and base.g[y][x] != O and not (x > 0 and base.g[y][x - 1]) and x > 0: c.p(x, y, 'outline')
            if base.g[y][x] and base.g[y][x] != O and not (x < 15 and base.g[y][x + 1]) and x < 15: c.p(x, y, 'outline')
    # face: onde ha topo mais abaixo na coluna, as laterais livres viram contorno so no tope das colunas vizinhas
    return c

def lateral_fix(c, mask):
    return c

W = [wall(m) for m in range(16)]
for m, c in enumerate(W): A[f'wall_{m:02d}'] = put(f'wall_{m:02d}', c)

def with_top(base, f):
    c = base.copy(); f(c); return c

# portas e janelas: mascaras L+O = 10 (horizontal), N+S = 5 (vertical)
def door_h(open_=False):
    c = W[10].copy()
    c.p(3, 12, 'outline')
    for y in range(12, 23):
        c.p(3, y, 'outline'); c.p(12, y, 'outline')
        for x in range(4, 12):
            if open_: c.p(x, y, 'window_off')
            else: c.p(x, y, 'plank_dark' if x >= 9 else 'plank')
    if open_:
        for y in range(12, 23): c.p(4, y, 'plank'); c.p(5, y, 'plank_dark')
    else:
        c.p(10, 18, 'pole_head')
    return c
A['door_h'] = put('door_h', door_h()); A['door_h_open'] = put('door_h_open', door_h(True))
dv = W[5].copy()
for y in range(3, 13):
    for x in range(4, 12):
        edge = y in (3, 12) or x in (4, 11)
        dv.p(x, y, 'outline' if edge else ('plank_dark' if y >= 9 else 'plank'))
A['door_v'] = put('door_v', dv)

def window_h(on):
    c = W[10].copy()
    c.frame(4, 14, 8, 6, 'lot_wall_top_light')
    c.r(5, 15, 6, 4, 'window_on' if on else 'window_off')
    if on: c.r(7, 16, 2, 2, 'window_core')
    return c
def window_v(on):
    c = W[5].copy()
    c.r(7, 5, 2, 6, 'window_on' if on else 'window_off')
    return c
for n in ('off', 'on'):
    A[f'window_h_{n}'] = put(f'window_h_{n}', window_h(n == 'on')); A[f'window_v_{n}'] = put(f'window_v_{n}', window_v(n == 'on'))

# ---------------------------------------------------------------- 7. Lampião, vela
def lamp(on):
    c = C(16, 24)
    c.r(5, 21, 6, 2, 'pole'); c.r(7, 9, 2, 12, 'pole')
    c.r(5, 2, 6, 7, 'pole'); c.r(5, 2, 6, 1, 'pole_head')
    c.r(6, 4, 4, 4, 'window_on' if on else 'window_off')
    if on: c.r(7, 5, 2, 2, 'window_core')
    c.outline(); return c
def candle(on):
    c = C(16, 14)
    c.r(3, 10, 10, 2, 'fence'); c.r(4, 12, 8, 1, 'fence_dark'); c.r(3, 11, 1, 1, 'fence_dark')
    for x, h in ((4, 4), (7, 6), (10, 3)):
        c.r(x, 10 - h, 2, h, 'flower_white'); c.r(x + 1, 10 - h, 1, h, 'lane')
        if on: c.r(x, 10 - h - 2, 1, 2, 'window_on')
    c.outline(); return c
for n in ('off', 'on'):
    A[f'lamp_{n}'] = put(f'lamp_{n}', lamp(n == 'on')); A[f'candle_{n}'] = put(f'candle_{n}', candle(n == 'on'))

# ---------------------------------------------------------------- 8. Tapete, vaso, quadro, mesa
def rug():
    c = C(48, 32)
    c.frame(1, 0, 46, 32, 'outline')
    c.r(2, 1, 44, 2, 'lane'); c.r(2, 29, 44, 2, 'lane'); c.r(2, 1, 2, 30, 'lane'); c.r(44, 1, 2, 30, 'lane')
    c.r(4, 3, 40, 26, 'rug')
    for x in (8, 39): c.r(x, 3, 1, 26, 'rug_dark')
    for x in (10, 37): c.r(x, 3, 1, 26, 'rug_dark')
    for k in range(4):                                                   # losango 12 x 8 (8 x 12 no vertical)
        c.r(24 - 6 + (3 - k) * 1 + 0, 16 - 4 + k, 12 - 2 * (3 - k), 1, 'rug_light') if False else None
    for j in range(8):
        half = (j if j < 4 else 7 - j) * 2 + 2
        c.r(24 - half, 12 + j, half * 2, 1, 'rug_light')
    for y in range(4, 28, 2): c.p(0, y, 'lane'); c.p(47, y, 'lane')   # franja nas pontas curtas
    return c
rg = rug(); A['rug_h'] = put('rug_h', rg); A['rug_v'] = put('rug_v', rg.rot90())

vase = C(16, 22)
leaf = ['....lll.....', '..lllmmml...', '.lllmmmmmm..', '.lmmmlmmmmm.', 'lmmmmmmmlmmm', 'lmmlmmmmmmmd',
        'mmmmmmmmmmdd', '.mmmmdmmmmdd', '.mmdmmmmmddd', '..ddmmmmddd.', '..dddmmddd..', '....ddmd....', '.....dd.....']
vase.rows(leaf, 2, 1, {'l': 'canopy_light', 'm': 'canopy', 'd': 'canopy_dark'})
vase.r(3, 14, 10, 1, 'roof_tile_light'); vase.r(4, 15, 8, 6, 'roof_tile'); vase.r(4, 15, 2, 6, 'roof_tile_light')
vase.r(10, 15, 2, 6, 'roof_tile_dark'); vase.r(4, 20, 8, 1, 'roof_tile_dark'); vase.r(4, 15, 8, 1, 'roof_tile_dark')
vase.outline(); A['vase'] = put('vase', vase)

pic = C(8, 8); pic.frame(0, 0, 8, 8, 'home_door_dark'); pic.r(1, 1, 6, 6, 'flower_white')
for x, y in ((2, 4), (3, 4), (2, 5)): pic.p(x, y, 'sign_blue')
for x, y in ((5, 2), (5, 3)): pic.p(x, y, 'flower_yellow')
A['picture'] = put('picture', pic)

def table(w, d, side):
    """tampo w x d de plank, levantado 6 px, dois pés 3 x 6."""
    c = C(w + 2, d + 6 + (1 if side == 's' else 2))
    top = 1 if side == 's' else 1
    c.r(1, top, w, d, 'plank'); c.r(1, top, w, 1, 'plank_light'); c.r(1, top + d - 1, w, 1, 'plank_dark')
    return c
ts = C(32, 22)
ts.r(1, 2, 30, 13, 'plank'); ts.r(1, 2, 30, 1, 'plank_light'); ts.r(1, 14, 30, 1, 'plank_dark')
ts.r(3, 15, 3, 6, 'plank_dark'); ts.r(26, 15, 3, 6, 'plank_dark'); ts.outline()
A['table_s'] = put('table_s', ts)
tL = C(16, 38)
tL.r(1, 1, 14, 30, 'plank'); tL.r(1, 1, 14, 1, 'plank_light'); tL.r(1, 29, 14, 2, 'plank_dark')
tL.r(2, 31, 3, 6, 'plank_dark'); tL.r(11, 31, 3, 6, 'plank_dark'); tL.outline()
A['table_l'] = put('table_l', tL)

# ---------------------------------------------------------------- 9. Estações
def box(c, x, y, w, d, h, top, face, tl=None, fd=None):
    """topo d linhas e face h linhas; contorno por dentro."""
    c.r(x, y, w, d, top); c.r(x, y, w, 1, tl or top); c.r(x, y, 1, d, tl or top)
    c.r(x, y + d, w, h, face)
    if fd: c.r(x, y + d + h - 2, w, 1, fd)
    c.frame(x, y, w, d + h, 'outline'); c.r(x + 1, y + d, w - 2, 1, 'outline') if False else None

def bricks(c, x, y, w, h, line, off=0):
    for k in range(0, h, 4):
        if k: c.r(x, y + k - 1, w, 1, line)
    for k in range(0, h, 4):
        for xx in range(x + (off if (k // 4) % 2 == 0 else off + 4), x + w, 8):
            for yy in range(y + k, min(y + k + 3, y + h)): c.p(xx, yy, line)

def finish(variants, name, front, side, face_rect, dark, extra=None):
    """grava _s, _l, _o (espelho do lado) e _n (costas: face escura com um risco a cada 4 px)."""
    A[f'{name}_s'] = put(f'{name}_s', front); A[f'{name}_l'] = put(f'{name}_l', side)
    A[f'{name}_o'] = put(f'{name}_o', side.mirror())
    n = front.copy(); x, y, w, h = face_rect
    n.r(x, y, w, h, dark)
    for yy in range(y + 3, y + h, 4): n.r(x, yy, w, 1, 'outline')
    A[f'{name}_n'] = put(f'{name}_n', n)

def forge():
    def draw(view):
        c = C(32, 44)
        box(c, 0, 12, 32, 20, 12, 'wall_bare', 'wall_bare_shade')
        bricks(c, 1, 13, 30, 18, 'wall_bare_shade'); bricks(c, 1, 32, 30, 11, 'wall_res_shade')
        cx = 22 if view == 's' else 4
        c.r(cx, 3, 6, 15, 'wall_bare_shade'); c.r(cx, 0, 6, 3, 'wall_bare'); c.frame(cx, 0, 6, 18, 'outline')
        c.r(cx + 1, 1, 4, 1, 'wall_bare_shade') if False else None
        for yy in (7, 11, 15): c.r(cx + 1, yy, 4, 1, 'wall_res_shade')
        if view == 's':
            c.r(12, 34, 8, 6, 'forge_mouth'); c.frame(11, 33, 10, 8, 'outline'); c.r(13, 38, 6, 1, 'roof_tile_light')
        else:
            c.r(12, 35, 8, 4, 'pole'); [c.r(x, 35, 1, 4, 'gate') for x in (13, 15, 17, 19)]; c.frame(11, 34, 10, 6, 'outline')
        return c
    finish(None, 'forge', draw('s'), draw('l'), (12, 34, 8, 6), 'wall_res_shade')
forge()

def plants(c, cols, rows, x0, y0, cw, ch, shift_set=()):
    for j in range(rows):
        for i in range(cols):
            px, py = x0 + i * cw + (cw - 6) // 2, y0 + j * ch + (ch - 6) // 2
            sh = 1 if (i + j) % 2 == 0 and shift_set else 0
            shape = ['..gg..', '.gGGg.', 'gGgGGg', 'gGGgGd', '.dGGd.', '..dd..']
            top, bot = shape[:3], shape[3:]
            leg = {'g': 'grass_light', 'G': 'grass', 'd': 'grass_dark'}
            c.rows(top, px + sh, py, leg); c.rows(bot, px, py + 3, leg)
def garden(b=False):
    def draw(view):
        w, d = (32, 48) if view == 's' else (48, 32)
        c = C(w, d + 4)
        c.r(0, 0, w, d + 4, 'plank_dark'); c.r(2, 2, w - 4, d - 4, 'dirt_dark')
        c.r(0, d, w, 4, 'plank'); c.r(0, d, w, 1, 'plank_light'); c.r(0, d + 3, w, 1, 'plank_dark')
        cols, rows = (2, 3) if view == 's' else (3, 2)
        plants(c, cols, rows, 2, 2, (w - 4) // cols, (d - 4) // rows, shift_set=(1,) if b else ())
        c.inline(); return c
    nm = 'garden_b' if b else 'garden'
    s, l = draw('s'), draw('l')
    A[f'{nm}_s'] = put(f'{nm}_s', s); A[f'{nm}_l'] = put(f'{nm}_l', l); A[f'{nm}_o'] = put(f'{nm}_o', l.mirror())
    n = s.copy(); n.r(1, 49, 30, 2, 'plank_dark'); n.r(1, 50, 30, 1, 'outline'); A[f'{nm}_n'] = put(f'{nm}_n', n)
garden(); garden(True)

def circle(c, cx, cy, r, col, hi=None, sh=None):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx + .5) ** 2 + (y - cy + .5) ** 2 <= r * r:
                col_ = col
                if hi and x - cx + y - cy < -r * .7: col_ = hi
                if sh and x - cx + y - cy > r * .7: col_ = sh
                c.p(x, y, col_)
def still():
    def draw(view):
        c = C(32, 44)
        c.r(2, 30, 20, 13, 'pole'); c.r(2, 30, 20, 2, 'gate'); c.r(2, 40, 20, 3, 'gate_dark')
        c.frame(2, 30, 20, 13, 'outline'); c.r(8, 36, 8, 3, 'outline'); c.r(9, 37, 6, 1, 'roof_tile_light')
        circle(c, 12, 22, 8, 'roof_tile', 'roof_tile_light', 'roof_tile_dark')
        circ = C(32, 44)
        if view == 's':
            c.r(18, 14, 8, 2, 'roof_tile'); c.r(18, 14, 8, 1, 'roof_tile_light'); c.r(25, 14, 2, 14, 'roof_tile'); c.r(25, 27, 2, 3, 'roof_tile_dark')
            c.r(23, 34, 6, 8, 'fence'); c.r(23, 34, 6, 1, 'fence_dark'); c.r(28, 34, 1, 8, 'fence_dark'); c.frame(23, 34, 6, 8, 'outline')
            c.r(24, 31, 1, 1, 'window_off') if False else None
        else:
            c.r(10, 5, 4, 8, 'roof_tile'); c.r(9, 3, 6, 3, 'roof_tile_light'); c.r(15, 3, 1, 3, 'roof_tile_dark')
            c.r(2 + 22, 36, 6, 6, 'fence'); c.frame(24, 35, 6, 7, 'outline')
        # contorno da caldeira e do cano
        for y in range(44):
            for x in range(32):
                if c.g[y][x] in (P['roof_tile'], P['roof_tile_light'], P['roof_tile_dark']):
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if c.at(x + dx, y + dy) is None: c.g[y + dy][x + dx] = '_o'
        for y in range(44):
            for x in range(32):
                if c.g[y][x] == '_o': c.g[y][x] = O
        return c
    finish(None, 'still', draw('s'), draw('l'), (4, 31, 16, 11), 'gate_dark')
still()

def cellar():
    def draw(view):
        c = C(32, 40)
        c.r(1, 30, 30, 4, 'plank_dark'); c.r(1, 30, 30, 1, 'plank'); c.r(3, 34, 4, 6, 'plank_dark'); c.r(25, 34, 4, 6, 'plank_dark')
        c.frame(1, 30, 30, 4, 'outline'); c.frame(3, 34, 4, 6, 'outline'); c.frame(25, 34, 4, 6, 'outline')
        xs = (2, 18) if view == 's' else (10, 10)
        ys = (0, 0) if view == 's' else (0, 11)
        for k, x in enumerate(xs if view == 's' else (10,)):
            y0 = 2
            c.r(x + 1, y0, 12, 20, 'plank_dark'); c.r(x + 1, y0, 12, 1, 'plank'); c.r(x + 1, y0, 2, 20, 'plank')
            c.r(x + 1, y0 + 5, 12, 1, 'gate'); c.r(x + 1, y0 + 15, 12, 1, 'gate')
            c.frame(x + 1, y0, 12, 20, 'outline')
            circle(c, x + 7, 24, 6, 'plank', 'plank_light', 'plank_dark')
            for yy in range(18, 30):
                for xx in range(x + 1, x + 13):
                    if c.g[yy][xx] == P['plank'] and (xx - x - 7 + .5) ** 2 + (yy - 24 + .5) ** 2 > 28 and False: pass
            c.frame(x + 1, 18, 12, 12, '_') if False else None
            for a in range(360):
                import math
                xx = int(round(x + 7 + 6 * math.cos(math.radians(a)) - .5)); yy = int(round(24 + 6 * math.sin(math.radians(a)) - .5))
                if 0 <= xx < 32 and 0 <= yy < 40: c.g[yy][xx] = P['gate']
            c.r(x + 5, 23, 4, 2, 'plank_dark')
        return c
    finish(None, 'cellar', draw('s'), draw('l'), (3, 31, 26, 2), 'plank_dark')
cellar()

def archive():
    def draw(view):
        c = C(32, 44)
        box(c, 0, 12, 32, 20, 12, 'roof_metal_light', 'roof_metal')
        c.r(1, 13, 30, 18, 'roof_metal_light'); c.r(1, 32, 30, 11, 'roof_metal_dark')
        if view == 's':
            for row in (0, 1):
                for col in range(3):
                    x, y = 2 + col * 10, 33 + row * 5
                    c.r(x, y, 8, 4, 'roof_metal'); c.frame(x, y, 8, 4, 'roof_metal') if False else None
                    c.r(x, y, 8, 1, 'roof_metal_light'); c.r(x + 3, y + 2, 2, 1, 'pole_head')
            x, y = 12, 33                                              # gaveta aberta com 3 fichas
            c.r(x, y, 8, 4, 'window_off')
            for i in range(3): c.r(x + 1 + i * 2 + (i), y, 2, 4, 'flower_white') if False else c.r(x + 1 + i * 2, y, 1 if False else 2, 3 + (i % 2), 'flower_white')
            c.r(x, y + 3, 8, 1, 'roof_metal')
            for yy in range(14, 30, 4): c.r(4, yy, 10, 1, 'roof_metal') if False else None
        else:
            c.r(12, 34, 8, 6, 'roof_metal'); c.frame(12, 34, 8, 6, 'roof_metal_dark'); c.r(14, 36, 4, 2, 'flower_white')
            for yy in (14, 18, 22, 26): c.r(2, yy, 28, 1, 'roof_metal')
        c.frame(0, 12, 32, 32, 'outline'); return c
    finish(None, 'archive', draw('s'), draw('l'), (2, 33, 28, 9), 'roof_metal_dark')
archive()

def sealworks(b=False):
    def draw(view):
        dy = 2 if b else 0
        c = C(32, 42)
        c.r(2, 30, 28, 4, 'gate'); c.r(2, 34, 28, 8, 'gate_dark'); c.r(2, 30, 28, 1, 'pole_head'); c.frame(2, 30, 28, 12, 'outline')
        if view == 's':
            for x in (5, 23): c.r(x, 8 + dy, 4, 22 - dy, 'gate'); c.r(x + 3, 8 + dy, 1, 22 - dy, 'gate_dark'); c.frame(x, 8 + dy, 4, 22 - dy, 'outline')
            c.r(3, 6 + dy, 26, 5, 'gate'); c.r(3, 6 + dy, 26, 1, 'pole_head'); c.r(3, 10 + dy, 26, 1, 'gate_dark'); c.frame(3, 6 + dy, 26, 5, 'outline')
        else:
            c.r(12, 8 + dy, 8, 22 - dy, 'gate'); c.r(18, 8 + dy, 2, 22 - dy, 'gate_dark'); c.frame(12, 8 + dy, 8, 22 - dy, 'outline')
            c.r(10, 6 + dy, 12, 5, 'gate'); c.r(10, 6 + dy, 12, 1, 'pole_head'); c.frame(10, 6 + dy, 12, 5, 'outline')
        # parafuso e volante de 8 px no topo
        c.r(15, 11 + dy, 2, 12, 'pole'); c.r(15, 11 + dy, 1, 12, 'gate')
        if view == 's':
            circle(c, 16, 3 + dy, 4, 'pole_head', None, 'gate'); c.r(15, 2 + dy, 2, 2, 'outline')
        else:
            c.r(15, 0 + dy, 2, 8, 'pole_head'); c.frame(14, dy, 4, 8, 'outline'); c.r(15, 1 + dy, 2, 6, 'pole_head')
        c.r(13, 23, 6, 1, 'gate_dark')
        circle(c, 16, 28, 2, 'home_veil'); c.r(14, 26, 5, 5, None)
        c.r(14, 26, 5, 5, 'home_veil'); c.p(14, 26, None); c.p(18, 26, None); c.p(14, 30, None); c.p(18, 30, None)
        c.p(15, 27, 'home_veil_light'); c.p(16, 27, 'home_veil_light')
        return c
    nm = 'sealworks_b' if b else 'sealworks'
    s, l = draw('s'), draw('l')
    A[f'{nm}_s'] = put(f'{nm}_s', s); A[f'{nm}_l'] = put(f'{nm}_l', l); A[f'{nm}_o'] = put(f'{nm}_o', l.mirror())
    n = s.copy(); n.r(3, 35, 26, 6, 'outline') if False else n.r(3, 35, 26, 6, 'gate_dark')
    for yy in range(38, 41, 4): n.r(3, yy, 26, 1, 'outline')
    A[f'{nm}_n'] = put(f'{nm}_n', n)
sealworks(); sealworks(True)

def workbench():
    def draw(view):
        w, d = (32, 16) if view == 's' else (16, 32)
        c = C(w, d + 12)
        c.r(0, 0, w, d, 'plank'); c.r(0, 0, w, 1, 'plank_light'); c.r(0, 0, 1, d, 'plank_light')
        for k in range(4, d, 4): c.r(0, k, w, 1, 'plank_dark')
        c.r(0, d, w, 3, 'plank_dark')
        xs = (2, 18) if view == 's' else (2,)
        for x in xs:
            c.r(x, d + 3, 12, 9, 'plank'); c.r(x + 8, d + 3, 4, 9, 'plank_dark'); c.frame(x, d + 3, 12, 9, 'outline')
            c.r(x + 1, d + 7, 10, 1, 'plank_dark')
        c.frame(0, 0, w, d + 3, 'outline')
        for a in range(0, 360, 10):
            import math
            c.p(int(round(10 + 3 * math.cos(math.radians(a)))), int(round(8 + 3 * math.sin(math.radians(a)) + (0 if view == 's' else 4))), 'flower_white')
        fx = 21 if view == 's' else 7
        c.r(fx, 4 if view == 's' else 6, 3, 5, 'fence'); c.r(fx, 4 if view == 's' else 6, 3, 1, 'fence_dark')
        return c
    finish(None, 'workbench', draw('s'), draw('l'), (3, 20, 8, 6), 'plank_dark')
workbench()

def chest():
    c = C(16, 18)
    for y, (a, b) in enumerate([(4, 11), (2, 13), (1, 14), (1, 14), (1, 14)], start=1):
        c.r(a, y, b - a + 1, 1, 'plank_light')
    c.r(1, 6, 14, 11, 'plank'); c.r(1, 6, 14, 1, 'plank_light'); c.r(12, 7, 3, 10, 'plank_dark'); c.r(1, 16, 14, 1, 'plank_dark')
    c.r(1, 6, 14, 1, 'plank_dark')
    for x in (3, 11): c.r(x, 1 if False else 2, 2, 15, 'gate')
    c.p(3, 2, None); c.p(4, 2, None) if False else None
    c.r(7, 6, 2, 3, 'pole_head')
    c.outline(); return c
ch = chest()
for k in ('s', 'n'): A[f'chest_{k}'] = put(f'chest_{k}', ch)
chl = ch.copy(); A['chest_l'] = put('chest_l', chl); A['chest_o'] = put('chest_o', chl.mirror())
nb = ch.copy(); nb.r(7, 6, 2, 3, 'plank_dark'); nb.r(1, 10, 14, 1, 'outline')
A['chest_n'] = put('chest_n', nb)

def shelf():
    def draw(view):
        w, d = (32, 16) if view == 's' else (16, 32)
        c = C(w, d + 18)
        c.r(0, 0, w, d, 'plank'); c.r(0, 0, w, 1, 'plank_light'); c.r(0, 0, 1, d, 'plank_light')
        if view == 's':
            for cx in (0, 16):
                for cy in (16, 25):
                    c.r(cx, cy, 16, 9, 'plank'); c.r(cx + 1, cy + 1, 14, 7, 'plank_dark'); c.frame(cx, cy, 16, 9, 'outline')
            # objetos do ícone: livros, frasco, planta
            for x, col in ((2, 'flower_white'), (4, 'roof_tile'), (6, 'sign_blue'), (8, 'flower_yellow')): c.r(x, 18, 2, 6, col)
            c.r(19, 19, 3, 5, 'fence'); c.r(24, 22, 5, 2, 'flower_white'); c.r(26, 19, 2, 3, 'grass'); c.r(25, 20, 1, 2, 'grass_light')
            c.r(3, 28, 4, 4, 'flower_white'); c.r(9, 28, 4, 4, 'rug'); c.r(20, 28, 4, 4, 'roof_tile'); c.r(26, 27, 3, 5, 'fence')
        else:
            for cy in (d, d + 9):
                c.r(0, cy, 16, 9, 'plank'); c.r(1, cy + 1, 14, 7, 'plank_dark'); c.frame(0, cy, 16, 9, 'outline')
            c.r(2, d + 3, 3, 5, 'flower_white'); c.r(6, d + 4, 4, 4, 'roof_tile'); c.r(3, d + 12, 4, 4, 'fence'); c.r(9, d + 12, 4, 4, 'rug')
        c.frame(0, 0, w, d + 1, 'outline'); return c
    finish(None, 'shelf', draw('s'), draw('l'), (2, 17, 28, 15), 'plank_dark')
shelf()

def sanctum():
    def draw(view):
        c = C(16, 28)
        art_ = ['....pppppppp....', '..pppppppppppp..', '.pppppppppppppp.', 'pppppppppppppppp']
        for y, (a, b) in enumerate([(5, 10), (3, 12), (2, 13), (1, 14)], start=1):
            c.r(a, y, b - a + 1, 1, 'plank')
        c.r(1, 5, 14, 22, 'plank'); c.r(1, 5, 2, 22, 'plank_light') if view == 's' else None
        c.r(13, 5, 2, 22, 'plank_dark')
        c.r(1, 24, 14, 3, 'plank_light'); c.r(1, 26, 14, 1, 'plank_dark')
        if view == 's':
            for y, (a, b) in enumerate([(6, 9), (4, 11), (3, 12)], start=3): c.r(a, y, b - a + 1, 1, 'plank_dark')
            c.r(3, 6, 10, 18, 'plank_dark')
            circle(c, 8, 15, 2, 'home_veil'); c.r(6, 13, 5, 5, None)
            c.r(6, 13, 5, 5, 'home_veil'); [c.p(x, y, None) for x, y in ((6, 13), (10, 13), (6, 17), (10, 17))]
            c.p(7, 14, 'home_veil_light'); c.p(8, 14, 'home_veil_light')
        else:
            for x in range(3, 14, 3): c.r(x, 8, 1, 15, 'plank_dark')
        c.outline(); return c
    s, l = draw('s'), draw('l')
    A['sanctum_s'] = put('sanctum_s', s); A['sanctum_l'] = put('sanctum_l', l); A['sanctum_o'] = put('sanctum_o', l.mirror())
    n = s.copy(); n.r(3, 6, 10, 18, 'plank_dark'); n.r(3, 6, 10, 1, 'plank_dark')
    for yy in range(9, 24, 4): n.r(3, yy, 10, 1, 'outline')
    A['sanctum_n'] = put('sanctum_n', n)
sanctum()

# ---------------------------------------------------------------- 10. Ícones 16 x 16
def icon_from(c, fit=14):
    """tira o contorno, recorta, reduz por vizinho mais próximo, centra e refaz o contorno."""
    g = c.copy()
    for y in range(g.h):
        for x in range(g.w):
            if g.g[y][x] == O: g.g[y][x] = None
    xs = [x for y in range(g.h) for x in range(g.w) if g.g[y][x]]; ys = [y for y in range(g.h) for x in range(g.w) if g.g[y][x]]
    box_ = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    im = g.img().crop(box_)
    s = min(fit / im.width, fit / im.height)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((nw, nh), Image.NEAREST)
    out = C(16, 16); out.paste(fromimg(im), (16 - nw) // 2, (16 - nh) // 2); out.outline(); return out

def icon(name, c): A['icon_' + name] = put(name, c, ICO)
for nm, src in (('lot_floor_plank', A['floor_plank_h']), ('lot_floor_tile', A['floor_tile']), ('lot_rug', A['rug_h']),
                ('lot_chest', A['chest_s']), ('lot_candle', A['candle_on']), ('lot_picture', A['picture'])):
    icon(nm, icon_from(src, 14 if nm not in ('lot_picture',) else 12))

c = C(16, 16)                                    # parede
c.r(1, 3, 14, 4, 'lot_wall_top'); c.r(1, 3, 14, 1, 'lot_wall_top_light'); c.r(1, 7, 14, 6, 'lot_wall_face')
c.r(1, 10, 14, 1, 'lot_wall_face_dark'); c.r(5, 7, 1, 3, 'lot_wall_face_dark'); c.r(11, 11, 1, 2, 'lot_wall_face_dark'); c.r(1, 12, 14, 1, 'lot_wall_baseboard')
c.inline(); icon('lot_wall', c)
c = C(16, 16)                                    # porta
c.r(3, 1, 10, 14, 'lot_wall_top'); c.r(5, 3, 6, 12, 'plank'); c.r(9, 3, 2, 12, 'plank_dark'); c.p(9, 9, 'pole_head')
c.frame(3, 1, 10, 14, 'outline'); c.frame(4, 2, 8, 13, 'lot_wall_face_dark') if False else None
c.outline(); icon('lot_door', c)
c = C(16, 16)                                    # janela
c.r(2, 2, 12, 12, 'lot_wall_face'); c.frame(4, 4, 8, 8, 'lot_wall_top_light'); c.r(5, 5, 6, 6, 'window_on'); c.r(7, 7, 2, 2, 'window_core')
c.r(7, 5, 2, 6, 'window_on') if False else None; c.frame(2, 2, 12, 12, 'outline'); c.r(8, 5, 1, 6, 'lot_wall_top_light'); icon('lot_window', c)
c = C(16, 16)                                    # lampião
c.r(5, 13, 6, 2, 'pole'); c.r(7, 8, 2, 5, 'pole'); c.r(4, 1, 8, 7, 'pole'); c.r(4, 1, 8, 1, 'pole_head'); c.r(5, 3, 6, 4, 'window_on'); c.r(7, 4, 2, 2, 'window_core')
c.outline(); icon('lot_lamp', c)
c = C(16, 16)                                    # vaso
c.rows(['..lll.....', '.lmmmml...', 'lmmlmmmmd.', 'mmmmmmmmdd', '.mddmmdd..', '...dmd....'], 3, 1, {'l': 'canopy_light', 'm': 'canopy', 'd': 'canopy_dark'})
c.r(3, 8, 10, 1, 'roof_tile_light'); c.r(4, 9, 8, 5, 'roof_tile'); c.r(4, 9, 2, 5, 'roof_tile_light'); c.r(10, 9, 2, 5, 'roof_tile_dark'); c.r(4, 13, 8, 1, 'roof_tile_dark')
c.outline(); icon('lot_vase', c)
c = C(16, 16)                                    # mesa
c.r(1, 3, 14, 6, 'plank'); c.r(1, 3, 14, 1, 'plank_light'); c.r(1, 8, 14, 1, 'plank_dark'); c.r(2, 9, 3, 5, 'plank_dark'); c.r(11, 9, 3, 5, 'plank_dark')
c.outline(); icon('lot_table', c)
c = C(16, 16)                                    # bancada
c.r(1, 3, 14, 5, 'plank'); c.r(1, 3, 14, 1, 'plank_light'); c.r(1, 7, 14, 1, 'plank_dark'); c.r(2, 8, 5, 6, 'plank'); c.r(9, 8, 5, 6, 'plank'); c.r(5, 8, 2, 6, 'plank_dark'); c.r(12, 8, 2, 6, 'plank_dark')
for x, y in ((4, 4), (5, 4), (6, 4), (4, 5), (6, 5), (5, 5)): c.p(x, y, 'flower_white') if (x, y) != (5, 5) else None
c.r(10, 1, 2, 3, 'fence'); c.outline(); icon('lot_workbench', c)

# ---------------------------------------------------------------- Folha de conferência (4x, dia e noite)
NIGHT = (0x14, 0x10, 0x33); EMIS = {P[k] for k in ('home_veil_light', 'home_veil', 'window_on', 'window_core', 'veil_spark', 'forge_mouth')}

def bg_tile(w, h, tile):
    c = C(w, h)
    for y in range(h):
        for x in range(w): c.g[y][x] = tile.g[y % tile.h][x % tile.w]
    return c

def build_scene():
    Wd, Hd = 290, 900
    s = bg_tile(Wd, Hd, fold); lab = []
    y = 3
    def L(t): nonlocal y; lab.append((4, y, t)); y += 8
    def row_h(ns, x0, yy, gap=3):
        for n in ns: s.paste(A[n], x0, yy); x0 += A[n].w + gap
        return x0
    L('1 degraus: vazio dobra tabua topo ladrilho | tapete')
    xs = 4
    for t in (void, fold, pl, W[10], tl):
        for yy in range(16):
            for xx in range(16):
                cc = t.g[yy % t.h][xx % t.w]
                s.g[y + yy][xs + xx] = cc if cc else P['fold']
        xs += 18
    for yy in range(16):
        for xx in range(48):
            s.g[y + yy][xs + xx] = A['floor_plank_h'].g[yy][xx % 16]
    s.paste(A['rug_h'], xs - 0, y - 8)
    y += 26
    L('4 tabua 4x4 | ladrilho 4x4 | borda')
    for j in range(4):
        for i in range(4):
            s.paste(A['floor_plank_h'], 4 + i * 16, y + j * 16); s.paste(A['floor_tile'], 76 + i * 16, y + j * 16)
    # ring de borda: vazio + borda em volta de um 3x3 de dobra (para ver a costura)
    bx, by = 160, y - 8
    for j in range(5):
        for i in range(5):
            if j in (0, 4) or i in (0, 4):
                n = {(0, 0): 'edge_corner_no', (4, 0): 'edge_corner_nl', (0, 4): 'edge_corner_so', (4, 4): 'edge_corner_sl'}.get((i, j))
                n = n or ('edge_n' if j == 0 else 'edge_s' if j == 4 else 'edge_o' if i == 0 else 'edge_l')
                s.paste(A[n], bx + i * 16, by + j * 16)
    y += 68
    L('5 paredes 00..15, "8" de teste')
    for m in range(16): s.paste(A[f'wall_{m:02d}'], 4 + m * 17, y)
    y += 30
    grid = [[6, 14, 12], [5, None, 5], [7, 10, 13], [5, None, 5], [3, 11, 9]]
    for j, rw in enumerate(grid):
        for i, m in enumerate(rw):
            if m is not None: s.paste(A[f'wall_{m:02d}'], 4 + i * 16, y + j * 16)
    xx = 64
    for n in ('door_h', 'door_h_open', 'door_v', 'window_h_off', 'window_h_on', 'window_v_off', 'window_v_on'): s.paste(A[n], xx, y + 4); xx += 17
    xx = 64
    for n in ('lamp_off', 'lamp_on', 'candle_off', 'candle_on', 'vase', 'picture', 'table_s', 'table_l'): s.paste(A[n], xx, y + 40); xx += A[n].w + 3
    y += 5 * 16 + 4
    L('7 veil_door | bus_stop | Conjurador 24px | aberturas | borda')
    bs = fromimg(Image.open(f'{MAP}/bus_stop.png'))
    s.paste(bs, 4, y + max(0, 24 - bs.h))
    s.paste(A['veil_door'], 4 + bs.w + 4, y)
    cj = C(12, 24); cj.r(3, 0, 6, 7, 'fold_light'); cj.r(1, 7, 10, 17, 'fold_light'); cj.inline()
    s.paste(cj, 4 + bs.w + 24, y)
    xx = 4 + bs.w + 42
    for n in ('veil_door_open_1', 'veil_door_open_2', 'veil_door_open_3'): s.paste(A[n], xx, y); xx += 18
    y += 28
    L('5 estacoes: ic.0.28 | s l o n')
    icons_ = {'forge': 'station_forge', 'garden': 'station_garden', 'still': 'station_still', 'cellar': 'station_cellar',
              'archive': 'station_archive', 'sealworks': 'station_sealworks', 'shelf': 'furniture_shelf', 'sanctum': 'furniture_sanctum'}
    for nm, ic in icons_.items():
        s.paste(fromimg(Image.open(f'{ICO}/{ic}.png')), 1, y)
        xx = 19
        for v in 'slon': s.paste(A[f'{nm}_{v}'], xx, y); xx += A[f'{nm}_{v}'].w + 3
        y += max(A[f'{nm}_s'].h, A[f'{nm}_l'].h) + 3
    nm_row = ['workbench', 'chest']
    for nm in nm_row:
        xx = 19
        for v in 'slon': s.paste(A[f'{nm}_{v}'], xx, y); xx += A[f'{nm}_{v}'].w + 3
        y += max(A[f'{nm}_s'].h, A[f'{nm}_l'].h) + 3
    L('icones lot_*')
    xx = 4
    for n in ('lot_floor_plank', 'lot_floor_tile', 'lot_rug', 'lot_chest', 'lot_candle', 'lot_picture', 'lot_wall', 'lot_door', 'lot_window', 'lot_lamp', 'lot_vase', 'lot_table', 'lot_workbench'):
        s.paste(A['icon_' + n], xx, y); xx += 17
    y += 20
    L('garden/sealworks quadros b')
    xx = 4
    for n in ('garden_b_s', 'sealworks_b_s', 'garden_b_l'): s.paste(A[n], xx, y); xx += A[n].w + 3
    y += 56
    return s, lab, y

def sheet():
    sc, lab, hh = build_scene()
    day = sc.img().crop((0, 0, 290, hh)).convert('RGBA')
    night = day.copy(); px = night.load(); dp = day.load()
    for y in range(night.height):
        for x in range(night.width):
            r, g, b, a = dp[x, y]
            hx = '%02x%02x%02x' % (r, g, b)
            if hx in EMIS: continue
            px[x, y] = tuple(round(v * .42 + n * .58) for v, n in zip((r, g, b), NIGHT)) + (255,)
    # halos: lampião e vela acesos, um brilho suave de window_on por cima
    ov = Image.new('RGBA', night.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for y in range(night.height):
        for x in range(night.width):
            if dp[x, y][:3] == (0xff, 0xd9, 0x8a) and 'lamp_on' or False: pass
    night = Image.alpha_composite(night, ov)
    # halo: ao redor dos pixels window_on (dos _on), raio 6 px
    halo = Image.new('RGBA', night.size, (0, 0, 0, 0)); hp = halo.load()
    pts = [(x, y) for y in range(day.height) for x in range(day.width) if dp[x, y][:3] == (0xff, 0xd9, 0x8a)]
    for (x0, y0) in pts[::3]:
        for y in range(y0 - 7, y0 + 8):
            for x in range(x0 - 7, x0 + 8):
                if 0 <= x < night.width and 0 <= y < night.height:
                    dd = ((x - x0) ** 2 + (y - y0) ** 2) ** .5
                    if dd < 7:
                        a = int(34 * (1 - dd / 7))
                        pr = hp[x, y]; hp[x, y] = (255, 217, 138, min(255, pr[3] + a))
    night = Image.alpha_composite(night, halo)
    # emissivos por cima de tudo
    n2 = night.load()
    for y in range(day.height):
        for x in range(day.width):
            r, g, b, a = dp[x, y]
            if '%02x%02x%02x' % (r, g, b) in EMIS: n2[x, y] = (r, g, b, 255)
    sheet_ = Image.new('RGBA', (day.width * 2 + 8, hh), (26, 20, 36, 255))
    sheet_.paste(day, (0, 0)); sheet_.paste(night, (day.width + 8, 0))
    sheet_ = sheet_.resize((sheet_.width * 4, sheet_.height * 4), Image.NEAREST)
    d = ImageDraw.Draw(sheet_)
    for (x, y, t) in lab:
        d.text((x * 4, y * 4), t, fill=(240, 238, 224, 255)); d.text(((x + day.width + 8) * 4, y * 4), t, fill=(240, 238, 224, 255))
    sheet_.save(f'{OUT}/folha.png')
    # cinza de dia: os cinco degraus
    lum = lambda h: round(.299 * int(h[0:2], 16) + .587 * int(h[2:4], 16) + .114 * int(h[4:6], 16))
    def avg(t):
        v = [lum(t.g[y][x]) for y in range(t.h) for x in range(t.w) if t.g[y][x]]; return sum(v) / len(v)
    print('luma media: vazio %.0f dobra %.0f tabua %.0f topo %.0f ladrilho %.0f tapete %.0f' % (
        avg(void), avg(fold), avg(pl), lum(P['lot_wall_top']), avg(tl), lum(P['rug'])))
sheet()

# ---------------------------------------------------------------- cores proibidas
bad = {'000000', '5fd3c6', 'ff7a45'}
found = []
for folder in (LOT, MAP, ICO):
    for f in os.listdir(folder):
        if f.endswith('.png') and (folder != MAP or f.startswith('veil_door')) and (folder != ICO or f.startswith('lot_')):
            im = Image.open(f'{folder}/{f}').convert('RGBA')
            for px in im.getdata():
                if px[3] and '%02x%02x%02x' % px[:3] in bad: found.append(f)
print('cores proibidas:', sorted(set(found)) or 'nenhuma')
print('sprites:', len(A))
