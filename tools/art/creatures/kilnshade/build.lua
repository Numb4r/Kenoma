-- Kilnshade (soot.ritual), 0.25.1: a sombra de um forno, com o fogo na boca. Rodar: aseprite -b --script build.lua
-- corpo: a cupula de fuligem, a chamine, a fumaca, a boca apagada. leds: os dois olhos de brasa.
-- glow: o fogo na boca do forno e as faiscas.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  d = '#2A2E3C', a = '#3D4254', b = '#5A6072', c = '#8A8FA3', -- fuligem
  q = '#5C2A26', o = '#7A3828', p = '#8E4A34',                -- fogo apagado (corpo)
  Q = '#C9502A', O = '#FF7A45', P = '#FFB37A', Y = '#FFE9B8', -- fogo (glow)
  e = '#6E4638', E = '#FFB37A', F = '#FFE9B8',                -- olho apagado (corpo) e aceso (leds)
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
  '..................c.................',
  '.................cc.................',
  '................ccb.................',
  '...............cbbba................',
  '...............cbbba................',
  '...............cbbba................',
  '............ccbbbbbbbbaa............',
  '..........ccbbbbbbbbbbbbaa..........',
  '.........cbbbbbbbbbbbbbbbaa.........',
  '........cbbbbabbbbbbabbbbbaa........',
  '.......cbbbbbbbbbbbbbbbbbbbaa.......',
  '.......cbbEEEbbbbbbbbEEEbbbaa.......',
  '......cbbbeEEbbbbbbbbeEEbbbaaa......',
  '......cbbabbbbbbbabbbbbbbabaaa......',
  '......cbbbbbbddddddddbbbbbbaaa......',
  '......cbbbbddQQQQQQQQddbbbbaaa......',
  '......cbbbdQQQOOOOOOQQQdbbbaaa......',
  '......cbbbdQQOOOPPOOOQQdbbbaaa......',
  '......cbbbdQOOOPPPPOOOQdbbaaaa......',
  '......cbbbdQOOPPYYPPOOQdbbaaaa......',
  '......cbbbdQOOPYYYYPOOQdbaaaaa......',
  '......cbbbdQOOPPYYPPOOQdbaaaaa......',
  '......cbbbdQOOOPPPPOOOQdbaaaaa......',
  '......cbbbdQQOOOOOOOOQQdaaaaaa......',
  '......abbbddddddddddddddaaaaaa......',
  '......aabbbbbbbbbbbaaaaaaaaaaa......',
  '.......aaaaaaaaaaaaaaaaaaaaaa.......',
  '....................................',
  '....................................',
  '....................................',
  '....................................',
  '....................................',
}, 36, 36, 'kilnshade')

-- p: 0 a 2, a fumaca verga. dim: o fogo baixa. glow: 1 a 3.
local function pose(o)
  local g = K.copy(BASE)
  local p = o.p or 0
  if p >= 1 then K.shiftRow(g, 4, 1); K.shiftRow(g, 5, 1) end
  if p >= 2 then K.shiftRow(g, 4, 1); K.shiftRow(g, 6, 1) end
  local glow = o.glow or 1
  if o.dim then K.swap(g, { Y = 'P' }); L.put(g, 15, 21, { 'OOOOOO' }) end
  if glow == 2 then L.put(g, 15, 22, { 'PYYYYP', 'YYYYYY', 'YYYYYY', 'PYYYYP' }) end
  if glow == 3 then K.swap(g, { Q = 'O', O = 'P', P = 'Y', E = 'F' }) end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local tx = ({ 0, 2, 4, 2 })[f]
  -- fumaca, chamine, cupula
  K.stroke(g, { { 48, 18 + by }, { 50 + tx / 2, 12 + by }, { 46 + tx, 7 + by }, { 50 + tx, 4 + by } }, 3.2, 1, 'c')
  L.rect(g, 41, 16 + by, 55, 32 + by, 'b')
  K.ell(g, 48, 58 + by, 31, 31, 'b')
  L.rect(g, 17, 60 + by, 79, 87, 'b')
  for y = 84, 95 do for x = 0, 95 do if y > 87 then g[y][x] = '.' end end end
  K.relight(g, { 'abc' }, 5, 10)
  -- fiadas de tijolo na cupula
  for y = 34, 86, 9 do
    for x = 14, 82 do K.put(g, x, y + by, { 'a' }, 'b') end
  end
  for j, y in ipairs({ 34, 43, 52, 61, 70, 79 }) do
    for x = 18 + (j % 2) * 6, 82, 12 do for k = 1, 8 do K.put(g, x, y + k + by, { 'a' }, 'b') end end
  end
  -- boca em arco, e o fogo
  K.ell(g, 48, 70 + by, 20, 19, 'd')
  L.rect(g, 28, 70 + by, 68, 84, 'd')
  for y = 88, 95 do for x = 0, 95 do g[y][x] = '.' end end
  local fl = ({ 0, 2, 1, 3 })[f]
  K.ell(g, 48, 74 + by, 16, 13, 'Q'); L.rect(g, 32, 74 + by, 64, 82, 'Q')
  for k, t in ipairs({ { 38, 12 }, { 48, 17 }, { 58, 13 }, { 43, 9 }, { 53, 10 } }) do
    local h = t[2] + ((k + fl) % 3) * 2
    K.stroke(g, { { t[1], 80 }, { t[1] + (k % 2 == 0 and 1 or -1), 80 - h * 0.6 + by }, { t[1] + ((k + f) % 3 - 1), 80 - h + by } }, 4.5, 0.8, 'O')
  end
  for k, t in ipairs({ { 41, 7 }, { 48, 11 }, { 55, 8 } }) do
    local h = t[2] + ((k + fl) % 3) * 2
    K.stroke(g, { { t[1], 81 }, { t[1], 81 - h + by } }, 3, 0.7, 'P')
  end
  K.ell(g, 48, 79, 5 + fl * 0.5, 2.5, 'Y')
  for y = 83, 87 do for x = 28, 68 do if ('QOPY'):find(g[y][x], 1, true) and y > 82 then g[y][x] = 'd' end end end
  -- olhos de brasa, mais quentes do lado para onde olha
  for _, ex in ipairs({ 37, 60 }) do
    K.ell(g, ex, 42 + by, 6.5, 4.5, 'd')
    K.ell(g, ex, 42 + by, 5.5, 3.5, 'E')
    K.ell(g, ex + 2, 42 + by, 2.5, 2, (f % 2 == 0) and 'F' or 'E')
    L.rect(g, ex - 5, 41 + by, ex - 4, 43 + by, 'e')
  end
  local loose = { { 10, 40 }, { 86, 44 }, { 76, 14 }, { 16, 18 }, { 88, 76 }, { 8, 78 }, { 30, 12 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S') end
  end
  return g, sg
end

K.build {
  name = 'kilnshade', size = 36, leg = LEG, emit = EMIT, keys = { 'd', 'a', 'b', 'c' }, dark = 'd',
  pose = pose, portrait = portrait,
  idle = { { p = 0 }, { p = 1, stretch = 17, dim = true }, { p = 2, stretch = 17 }, { p = 1, dim = true } },
  alert = { p = 0, stretch = 17 },
  alert2 = { { 4, 13 }, { 32, 12 }, { 25, 5, 's' } },
  alert3 = S.cat(S.plus(4, 11), S.plus(32, 10), { { 25, 4, 's' }, { 10, 5 }, { 3, 22 }, { 33, 23 } }),
  sq = 17,
  variants = {
    { key = 'urban', -- asfalto, mais escuro que a base; faixa rebitada na base
      grad = { '#1E2028', '#343842', '#6A6E7C' },
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 7, 29, { 'WwWWwWWwWWwWWwWWwWWwWW' } } } },
    { key = 'green', -- musgo; broto ao lado da chamine
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 21, 6, { 'LL.', '.Ll', '..d', '..d' } } } },
    { key = 'water', -- petroleo escuro; gotas de orvalho no alto, a esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 11, 11, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- barro claro; cachecol telha debaixo dos olhos
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 7, 17, { 'OOOOOOOOOOOOOOOOOOOOo' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; laco escuro na testa
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 16, 11, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas de pedra; aureola dourada em volta da chamine
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 12, 6, { '.GGGGGGGGGG.', 'G..........G', '.gggggggggg.' } } } },
    { key = 'crimson', -- vinho quase preto; crescente da Lua Carmim entre os olhos
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 16, 14, { '.RR', 'Rr.', 'Rr.', '.RR' } } } },
  },
}
