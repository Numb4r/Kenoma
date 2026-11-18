-- Cinderkin (soot.spirit), 0.25.1: a fuligem de pe em volta de cinco brasas. Rodar: aseprite -b --script build.lua
-- corpo: fuligem e as brasas apagadas. leds: os olhos de brasa e dois ciscos. glow: as cinco brasas (peito, punhos
-- e pes) e as faiscas.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  a = '#3D4254', b = '#5A6072', c = '#8A8FA3',                -- fuligem
  q = '#5C2A26', o = '#7A3828', p = '#8E4A34',                -- brasa apagada (corpo)
  Q = '#C9502A', O = '#FF7A45', P = '#FFB37A', Y = '#FFE9B8', -- brasa (glow)
  e = '#6E4638', E = '#FFB37A', F = '#FFE9B8',                -- olho e cisco apagados (corpo) e acesos (leds)
  S = '#FF7A45', s = '#FFD08A',
}
local EMIT = {
  Q = { 'q', 'w' }, O = { 'o', 'w' }, P = { 'p', 'w' }, Y = { 'p', 'w' },
  E = { 'e', 'l' }, F = { 'e', 'l' },
}

local BASE = L.frame({
  '....................................',
  '....................................',
  '....................................',
  '....................................',
  '.................c..................',
  '..........c.....ccb......b..........',
  '..........cc...cccbb....bb..........',
  '...........cccccccbbbbbbba..........',
  '..........ccccccbbbbbbbbbba.........',
  '.........cccccbbbbbbbbbbbbaa........',
  '.........cccbbbbbbbbbbbbbbaa........',
  '.........ccbEEEEbbbbbEEEEbaa........',
  '.........ccbeEEEbbbbbeEEEbaa........',
  '.........cbbbbbbbbbbbbbbbbaa........',
  '..........bbbbbbbbbbbbbbbaa.........',
  '...........bbbbbbbbbbbbaaa..........',
  '......ccbbbcbbbbbbbbbbbaabbbba......',
  '.....ccbb..cbbbbQQQQbbbaa..bbaa.....',
  '.....cbba..cbbbQOOOOQbbaa..bbaa.....',
  '.....cbba..cbbbQOPPOQbbaa..bbaa.....',
  '.....cbba..cbbbQOPPOQbaaa..bbaa.....',
  '.....cbba..cbbbQOOOOQbaaa..bbaa.....',
  '.....cbba...bbbbQQQQbaaa...bbaa.....',
  '....QQQQQ...bbbbbbbbaaaa..QQQQQ.....',
  '....QOPOQ...bbbbbbbaaaaa..QOPOQ.....',
  '....QQQQQ...bbbb....aaaa..QQQQQ.....',
  '............cbbb....baaa............',
  '............cbbb....baaa............',
  '............cbbb....baaa............',
  '...........QQQQQ...QQQQQ............',
  '...........QOPOQ...QOPOQ............',
  '...........QQQQQ...QQQQQ............',
  '....................................',
  '....................................',
  '....................................',
  '....................................',
}, 36, 36, 'cinderkin')

-- p: 0 a 2, os tufos vergam. dim: so a brasa do peito fica quente. glow: 1 a 3.
local function pose(o)
  local g = K.copy(BASE)
  local p = o.p or 0
  if p >= 1 then K.shiftRow(g, 4, 1); K.shiftRow(g, 5, 1) end
  if p >= 2 then K.shiftRow(g, 6, 1) end
  g[8][12] = 'E'; g[14][24] = 'E'
  local glow = o.glow or 1
  if o.dim then K.swap(g, { P = 'O' }); L.put(g, 17, 19, { 'PP', 'PP' }) end
  if glow == 2 then L.put(g, 16, 18, { 'PPPP', 'PYYP', 'PYYP', 'PPPP' }) end
  if glow == 3 then
    K.swap(g, { Q = 'O', O = 'P', P = 'Y', E = 'F' })
    L.put(g, 12, 12, { 'E........E' })
  end
  return g
end

local function ember(g, x, y, r, hot)
  L.disc(g, x, y, r, 'Q')
  L.disc(g, x, y, r * 0.72, 'O')
  L.disc(g, x, y + 0.5, r * 0.42 + hot, 'P')
  if hot > 0 then L.disc(g, x, y + 0.5, r * 0.2 + hot * 0.5, 'Y') end
end

-- Retrato: a cada quadro uma das cinco brasas e a mais quente.
local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local ty = ({ 0, -1, -2, -1 })[f]
  local tx = ({ 0, 1, 2, 1 })[f]
  local hy = 30 + by + (f == 3 and -1 or 0)
  K.stroke(g, { { 40, 76 }, { 39, 86 } }, 5.5, 5, 'b'); K.stroke(g, { { 56, 76 }, { 57, 86 } }, 5.5, 5, 'b')
  K.stroke(g, { { 33, 49 + by }, { 23, 58 + by }, { 20, 70 + by } }, 5.5, 4.5, 'b')
  K.stroke(g, { { 63, 49 + by }, { 73, 58 + by }, { 76, 70 + by } }, 5.5, 4.5, 'b')
  K.ell(g, 48, 61 + by, 16, 17, 'b')
  K.stroke(g, { { 36, 20 + by }, { 31 + tx, 12 + ty }, { 29 + tx, 7 + ty } }, 4, 1, 'b')
  K.stroke(g, { { 48, 16 + by }, { 48 + tx, 10 + ty }, { 50 + tx, 7 + ty } }, 4.5, 1, 'b')
  K.stroke(g, { { 60, 20 + by }, { 65 + tx, 13 + ty }, { 68 + tx, 8 + ty } }, 4, 1, 'b')
  L.disc(g, 48, hy, 17, 'b')
  for k = 0, 17 do
    local a = math.rad(k * 20 + 5)
    L.disc(g, 48 + 17 * math.cos(a), hy + 17 * math.sin(a), 2 + K.hash(k, 3, 2) % 2, 'b')
  end
  for k = 0, 9 do
    local a = math.rad(k * 20 + 190)
    L.disc(g, 48 + 16 * math.cos(a), 61 + by - 17 * math.sin(a), 2.5, 'b')
  end
  K.relight(g, { 'abc' }, 5, 9)
  for j = 0, 9 do for i = 0, 9 do
    local x, y = 8 + i * 9 + K.hash(i, j, 21) % 4, 12 + j * 8 + K.hash(i, j, 22) % 3
    local c = (x + y < 88) and 'c' or 'a'
    K.put(g, x, y, { c .. '.' .. c, '.' .. c .. '.' }, 'b')
  end end
  -- olhos de brasa: fendas, mais quentes do lado para onde olha
  for _, ex in ipairs({ 40, 57 }) do
    K.ell(g, ex, hy + 1, 6.5, 4.5, 'a')
    K.ell(g, ex, hy + 1, 5.5, 3.5, 'E')
    K.ell(g, ex + 2, hy + 1, 2.5, 2, (f % 2 == 0) and 'F' or 'E')
    L.rect(g, ex - 5, hy, ex - 4, hy + 2, 'e')
  end
  local hot = function(k) return (k == f or (k == 5 and f == 1)) and 1.5 or 0 end
  ember(g, 48, 62 + by, 9, f % 2 == 1 and 1 or 0.3)
  ember(g, 20, 74 + by, 6.5, hot(1)); ember(g, 76, 74 + by, 6.5, hot(3))
  ember(g, 38, 87, 6, hot(2)); ember(g, 58, 87, 6, hot(4))
  for k, pt in ipairs({ { 30, 26 }, { 62, 44 }, { 36, 52 }, { 66, 22 } }) do
    L.rect(g, pt[1], pt[2] + by, pt[1] + 1, pt[2] + 1 + by, (k % 4 == f % 4) and 'F' or 'E')
  end
  local loose = { { 10, 40 }, { 86, 44 }, { 78, 12 }, { 14, 16 }, { 88, 84 }, { 8, 86 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S') end
  end
  return g, sg
end

K.build {
  name = 'cinderkin', size = 36, leg = LEG, emit = EMIT, keys = { 'a', 'b', 'c' }, dark = 'a',
  pose = pose, portrait = portrait,
  idle = { { p = 0 }, { p = 1, stretch = 21, dim = true }, { p = 2, stretch = 21 }, { p = 1, dim = true } },
  alert = { p = 0, stretch = 21 },
  alert2 = { { 3, 20 }, { 32, 20 }, { 14, 3, 's' }, { 28, 6 } },
  alert3 = S.cat(S.plus(3, 18), S.plus(32, 18), { { 13, 2, 's' }, { 22, 2 }, { 6, 10 }, { 30, 9, 's' }, { 8, 30 }, { 27, 30 } }),
  sq = 27,
  variants = {
    { key = 'urban', -- asfalto, mais escuro que a base; faixa rebitada na testa
      grad = { '#24262E', '#3A3E4A', '#6A6E7C' },
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 10, 9, { 'WwWWwWWwWWwWWwWW' } } } },
    { key = 'green', -- musgo; broto no alto da cabeca
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 20, 3, { '.LL', 'lL.', 'd..', 'd..' } } } },
    { key = 'water', -- petroleo escuro; gotas de orvalho na bochecha esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 9, 12, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- cimentado claro; cachecol telha no pescoco
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 11, 15, { 'OOOOOOOOOOOOOOo', '...........Oo..', '...........Oo..', '...........oo..' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; cinto escuro com fivela
      legend = { N = '#2B2F3D', M = '#8E92A0' },
      put = { { 12, 23, { 'NNNNNMMNNNNN' } } } },
    { key = 'sacred', -- lilas de pedra; aureola dourada em volta do tufo do meio
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 12, 4, { '.GGGGGGGGGG.', 'G..........G', '.gggggggggg.' } } } },
    { key = 'crimson', -- vinho quase preto; crescente da Lua Carmim entre os olhos
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 17, 9, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
