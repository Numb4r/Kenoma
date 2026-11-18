-- Sootling (soot.eco), 0.25.1: bola de fuligem com a brasa no peito. Rodar: aseprite -b --script build.lua
-- corpo: fuligem, olhos, brasa apagada. leds: ciscos de brasa no pelo. glow: a brasa do peito e as faiscas.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(28)

local LEG = {
  A = '#1A1424',
  a = '#3D4254', b = '#5A6072', c = '#8A8FA3',                -- fuligem
  x = '#F0EEF8',                                              -- olho
  q = '#5C2A26', o = '#7A3828', p = '#8E4A34',                -- brasa apagada (corpo)
  Q = '#C9502A', O = '#FF7A45', P = '#FFB37A', Y = '#FFE9B8', -- brasa (glow)
  e = '#6E4638', E = '#FFB37A', F = '#FFE9B8',                -- cisco apagado (corpo) e aceso (leds)
  S = '#FF7A45', s = '#FFD08A',                               -- faisca
}
local EMIT = {
  Q = { 'q', 'w' }, O = { 'o', 'w' }, P = { 'p', 'w' }, Y = { 'p', 'w' },
  E = { 'e', 'l' }, F = { 'e', 'l' },
}

local BASE = L.frame({
  '............................',
  '............................',
  '............................',
  '............................',
  '.............c..............',
  '......c.....ccb......b......',
  '......cc...cccbb....bb......',
  '.......cccccccbbbbbbba......',
  '......cccccccbbbbbbbbba.....',
  '.....ccccccbbbbbbbbbbbba....',
  '....ccccbbbbbbbbbbbbbbbaa...',
  '....cccbbbbbbbbbbbbbbbbaa...',
  '....ccbbxxxxbbbbbxxxxbbaa...',
  '....ccbxxxxxxbbbxxxxxxbaa...',
  '....ccbxxxxAAbbbxxxxAAbaa...',
  '....ccbxxxxAAbbbxxxxAAbaa...',
  '....ccbbxxxxbbbbbxxxxbbaa...',
  '....cbbbbbbbbQQQbbbbbbaaa...',
  '....cbbbbbbbQOOOQbbbbaaaa...',
  '.....bbbbbbQOOPOOQbbaaaa....',
  '.....bbbbbbQOPPOOQbaaaaa....',
  '......bbbbbbQOOOQaaaaaa.....',
  '.......bbbbbbQQQaaaaaa......',
  '.......cbb.........bba......',
  '......ccbb.........bbaa.....',
  '............................',
  '............................',
  '............................',
}, 28, 28, 'sootling')

local function shiftRow(g, y, dx)
  local row = {}
  for x = 0, g.w - 1 do row[x] = L.get(g, x - dx, y) end
  for x = 0, g.w - 1 do g[y][x] = row[x] end
end

-- p: 0 tufos em pe, 1 pontas para a frente, 2 tufos inteiros para a frente. glow: 1 a 3. dim: brasa menor.
local function pose(o)
  local g = K.copy(BASE)
  local p = o.p or 0
  if p >= 1 then shiftRow(g, 4, 1); shiftRow(g, 5, 1) end
  if p >= 2 then shiftRow(g, 6, 1) end
  if o.wide then L.put(g, 8, 11, { 'xxxx.....xxxx' }) end
  g[9][9] = 'E'; g[17][22] = 'E'; g[20][7] = 'E'
  local glow = o.glow or 1
  if o.dim then K.swap(g, { P = 'O' }); g[20][13] = 'P' end
  if glow == 2 then L.put(g, 12, 18, { '.PPP.', 'PPYPP', 'PYYPP', '.PPP.' }) end
  if glow == 3 then
    K.swap(g, { Q = 'O' })
    L.put(g, 12, 18, { '.PPP.', 'PYYYP', 'PYYYP', '.PPP.' })
    g[9][9] = 'F'; g[17][22] = 'F'; g[20][7] = 'F'
  end
  return g
end

-- Retrato: a bola felpuda, os tres tufos balancando, a brasa pulsando e ciscos subindo.
local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local ty = ({ 0, -1, -2, -1 })[f]
  local tx = ({ 0, 1, 2, 1 })[f]
  local cx, cy = 47, 51 + by
  K.ell(g, 33, 84, 10, 5, 'b'); K.ell(g, 63, 84, 10, 5, 'b')
  K.stroke(g, { { 27, 30 + by }, { 21 + tx, 19 + ty }, { 18 + tx, 11 + ty } }, 5, 1, 'b')
  K.stroke(g, { { 47, 24 + by }, { 47 + tx, 13 + ty }, { 50 + tx, 6 + ty } }, 6, 1, 'b')
  K.stroke(g, { { 67, 30 + by }, { 74 + tx, 20 + ty }, { 78 + tx, 13 + ty } }, 5, 1, 'b')
  L.disc(g, cx, cy, 30, 'b')
  for k = 0, 23 do
    local a = math.rad(k * 15 + 7)
    L.disc(g, cx + 30 * math.cos(a), cy + 30 * math.sin(a), 3 + K.hash(k, 1, 2) % 2, 'b')
  end
  K.relight(g, { 'abc' }, 7, 12)
  -- pelo: riscos curtos na luz e na sombra
  for j = 0, 9 do for i = 0, 9 do
    local x, y = 8 + i * 9 + K.hash(i, j, 21) % 4, 14 + j * 8 + K.hash(i, j, 22) % 3
    local c = (x + y < 92) and 'c' or 'a'
    K.put(g, x, y, { c .. '.' .. c, '.' .. c .. '.' }, 'b')
  end end
  -- olhos, voltados para a direita
  for _, ex in ipairs({ 37, 61 }) do
    K.ell(g, ex, 45 + by, 9.5, 10.5, 'a')
    K.ell(g, ex, 45 + by, 8, 9, 'x')
    L.disc(g, ex + 3, 46 + by, 4, 'A')
    L.rect(g, ex + 1, 43 + by, ex + 2, 44 + by, 'x')
  end
  -- brasa
  local ey = 68 + by
  local r = ({ 0, 0.6, 1.2, 0.6 })[f]
  K.ell(g, 49, ey, 10, 9, 'Q')
  K.ell(g, 49, ey, 7.5 + r * 0.5, 6.5 + r * 0.5, 'O')
  K.ell(g, 49, ey + 1, 4.5 + r, 3.5 + r, 'P')
  K.ell(g, 49, ey + 1, 2 + r, 1.5 + r, 'Y')
  -- rachaduras escuras da brasa
  L.line(g, 41, ey - 4, 45, ey - 1, 'Q'); L.line(g, 57, ey - 3, 54, ey + 1, 'Q'); L.line(g, 46, ey + 7, 48, ey + 4, 'Q')
  -- ciscos no pelo: um mais quente por quadro
  local specks = { { 28, 34 }, { 70, 40 }, { 22, 60 }, { 74, 66 }, { 40, 26 }, { 62, 78 } }
  for k, pt in ipairs(specks) do
    local c = (k % 4 == f % 4) and 'F' or 'E'
    L.rect(g, pt[1], pt[2] + by, pt[1] + 1, pt[2] + 1 + by, c)
  end
  -- faiscas soltas subindo
  local loose = { { 12, 46 }, { 84, 38 }, { 60, 12 }, { 8, 70 }, { 88, 62 }, { 34, 12 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then
      L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S')
    end
  end
  return g, sg
end

K.build {
  name = 'sootling', size = 28, leg = LEG, emit = EMIT, keys = { 'a', 'b', 'c' }, dark = 'a',
  pose = pose, portrait = portrait,
  idle = { { p = 0 }, { p = 1, stretch = 20, dim = true }, { p = 2, stretch = 20 }, { p = 1, dim = true } },
  alert = { p = 0, stretch = 20, wide = true },
  alert2 = { { 3, 8 }, { 24, 9 }, { 10, 3, 's' } },
  alert3 = S.cat(S.plus(3, 6), S.plus(24, 7), { { 9, 2 }, { 18, 2, 's' }, { 2, 13 }, { 25, 14 } }),
  sq = 21,
  variants = {
    { key = 'urban', -- asfalto, mais escuro que a base; faixa rebitada de tampa de bueiro na testa
      grad = { '#24262E', '#3A3E4A', '#6A6E7C' },
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 7, 10, { 'WwWWwWWwWWwWWw' } } } },
    { key = 'green', -- musgo; broto de duas folhas no alto da cabeca
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 16, 3, { '.LL', 'lL.', 'd..', 'd..' } } } },
    { key = 'water', -- petroleo escuro; gotas de orvalho claras no ombro esquerdo
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 5, 9, { '.U.', 'Uu.', 'uu.' } }, { 9, 8, { 'U', 'u' } } } },
    { key = 'residential', -- cimentado claro; cachecol telha com a ponta solta
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 4, 17, { 'OOOOOOOo', '.Oo.....', '.Oo.....', '.oo.....' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; gravata-borboleta escura
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 18, 17, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas de pedra; aureola dourada em volta do tufo do meio
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 9, 4, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } } },
    { key = 'crimson', -- vinho quase preto; crescente da Lua Carmim entre os olhos
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 13, 12, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
