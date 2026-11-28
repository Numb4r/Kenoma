"""Casa do mapa (0.28.0): 24 x 22 px. Gera app/assets/art/map/home.png e o texto do carimbo (uma letra por pixel)."""
import sys
from PIL import Image
W, H = 24, 22
COL = {'O': '1a1424', 'l': 'cc7655', 't': 'b05a40', 'd': '8a4431', 'k': '86828a', 's': '6e6a70', 'n': '56525a',
       'U': 'c9b8ff', 'V': '9b7bff', 'T': '5a4a9e', 'w': '5a4c3c', 'x': '403630', 'p': '9a6a3e', 'q': '6a4628',
       'm': 'c9b8ff', 'g': '1f2334'}
g = [['.'] * W for _ in range(H)]
def put(x, y, c): g[y][x] = c
# telhado: degraus 2-2-2, beiral em y 10
L = {1: 11, 2: 11, 3: 9, 4: 9, 5: 7, 6: 7, 7: 5, 8: 5, 9: 3}
for y, l in L.items():
    for x in range(l, 23 - l + 1):
        tile = x < 12
        course = y in (3, 6, 9)
        put(x, y, ('t' if course else 'l') if tile else ('d' if course else 't'))
for x in range(24): put(x, 10, 't' if x < 12 else 'd')
for y in range(2, 7):
    for x, c in zip((17, 18, 19), 'ksn'): put(x, y, c)
for y in range(11, 21):
    for x in range(2, 22): put(x, y, 'x' if x >= 18 else 'w')
for y in range(15, 21):
    for x in range(10, 14): put(x, y, 'p' if x < 12 else 'q')
put(12, 18, 'm')
for y in range(13, 16):
    for x in (4, 5, 6, 17, 18, 19): put(x, y, 'g')
for (x, y), c in {(11,5):'U',(12,5):'U',(10,6):'U',(11,6):'V',(12,6):'V',(13,6):'V',(10,7):'V',(11,7):'V',(12,7):'V',(13,7):'T',(11,8):'T',(12,8):'T'}.items(): put(x, y, c)
# contorno de 1 px fora da silhueta (4 vizinhos); a soleira em y 21
fill = [[c != '.' for c in r] for r in g]
for y in range(H):
    for x in range(W):
        if not fill[y][x] and any(0 <= x+dx < W and 0 <= y+dy < H and fill[y+dy][x+dx] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
            g[y][x] = 'O'
for x in range(1, 23): g[21][x] = 'O'
rows = [''.join(r) for r in g]
open(sys.argv[1], 'w').write('\n'.join(rows) + '\n')
im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
for y, r in enumerate(rows):
    for x, c in enumerate(r):
        if c != '.': im.putpixel((x, y), tuple(int(COL[c][i:i+2], 16) for i in (0, 2, 4)) + (255,))
im.save('app/assets/art/map/home.png')
print('\n'.join(rows))
