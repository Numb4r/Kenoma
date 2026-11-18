-- Frondling (frond.eco), 0.25.1: fronde fractal que anda sobre as raizes. Rodar: aseprite -b --script build.lua
-- corpo: fronde, rosto, raizes. leds: os esporos na ponta de cada pina. glow: a nervura do meio e os esporos soltos.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(28)

local LEG = {
  A = '#1A1424',
  d = '#2F6B45', e = '#4C9A5A', f = '#86D37C',   -- folha
  t = '#3E3026', r = '#5A4636', u = '#8A6A4A',   -- raiz
  x = '#F0EEF8',                                 -- olho
  n = '#5E8A4A', P = '#E6FF9A',                  -- esporo apagado (corpo) e aceso (leds)
  v = '#3A8250', V = '#A8F090', U = '#E8FFC0',   -- nervura apagada (corpo) e acesa (glow)
  S = '#B8F28A', s = '#F0FFC8',                  -- esporo solto
}
local EMIT = { P = { 'n', 'l' }, V = { 'v', 'w' }, U = { 'v', 'w' } }

local BASE = L.frame({
  '............................',
  '............................',
  '............................',
  '............................',
  '.............f..............',
  '............fed.............',
  '...........ffedd............',
  '........f..ffedd..d.........',
  '........fffffeddddd.........',
  '.........ffffedddd..........',
  '......f...fffeddd...d.......',
  '......ffffffeeedddddd.......',
  '.......fffffeeeddddd........',
  '....f...ffffeeedddd...d.....',
  '....ffffffffeeedddddddd.....',
  '.....fffffffeeeddddddd......',
  '......ffffffeeedddddd.......',
  '........fxxxeeexxxed........',
  '.......fexxAeeexxAeed.......',
  '.......fexxAeeexxAeed.......',
  '........eeeeeeeeeedd........',
  '.......urreeeeeeedrur.......',
  '......urr...rrr....rur......',
  '.....urr.....rr.....rrr.....',
  '....ur........r.......rr....',
  '............................',
  '............................',
  '............................',
}, 28, 28, 'frondling')

-- p: 0 em pe, 1 a ponta verga, 2 a fronde inteira verga e as raizes trocam o passo. glow: 1 a 3 (a nervura sobe).
local function pose(o)
  local g = K.copy(BASE)
  local p = o.p or 0
  -- esporos e nervura antes de vergar, para irem junto
  for _, t in ipairs({ { 8, 7 }, { 18, 7 }, { 6, 10 }, { 20, 10 }, { 4, 13 }, { 22, 13 } }) do g[t[2]][t[1]] = 'P' end
  local glow = o.glow or 1
  local top = glow == 1 and 12 or (glow == 2 and 8 or 5)
  for y = top, 16 do g[y][13] = glow == 3 and (y % 2 == 0) and 'U' or 'V' end
  if p >= 1 then for y = 4, 8 do K.shiftRow(g, y, 1) end end
  if p >= 2 then
    for y = 4, 6 do K.shiftRow(g, y, 1) end
    for y = 9, 11 do K.shiftRow(g, y, 1) end
  end
  if p == 1 then K.shiftRow(g, 24, 1) elseif p == 2 then K.shiftRow(g, 24, -1) end
  return g
end

-- Fronde recursiva: o eixo, e em cada no um par de frondes menores. Devolve a ponta.
local function frond(g, x, y, ang, len, depth, bend, tips)
  local N = depth == 2 and 6 or 7
  local nodes, a, px, py = {}, ang, x, y
  for i = 1, N do
    a = a + bend / N
    px, py = px + math.cos(a) * len / N, py + math.sin(a) * len / N
    nodes[i] = { px, py, a }
  end
  if depth == 0 then
    K.stroke(g, { { x, y }, nodes[3], nodes[N] }, 1.2, 0.5, 'e')
    return nodes[N]
  end
  local pts = { { x, y } }
  for i = 1, N do pts[i + 1] = nodes[i] end
  K.stroke(g, pts, depth == 2 and 2 or 1, 0.5, 'e')
  local k = depth == 2 and 0.66 or 0.2
  for i = 1, N - 1 do
    for _, sgn in ipairs({ -1, 1 }) do
      local tip = frond(g, nodes[i][1], nodes[i][2], nodes[i][3] + sgn * math.rad(depth == 2 and 60 or 52),
        len * k * (1 - i / (N + 0.8)) + 1, depth - 1, -sgn * 0.5 + bend, tips)
      if tips and depth == 2 then tips[#tips + 1] = tip end
    end
  end
  return nodes[N], nodes
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local bend = ({ 0, 0.12, 0.26, 0.12 })[f]
  local tips = {}
  local _, axis = frond(g, 47, 63 + by, -math.pi / 2, 54, 2, bend, tips)
  -- raizes: tres pernas com radiculas
  local st = ({ 0, 1, 0, -1 })[f]
  K.stroke(g, { { 38, 74 + by }, { 28, 82 }, { 19 + st, 88 } }, 3.4, 0.8, 'r')
  K.stroke(g, { { 30, 81 }, { 24, 80 }, { 18, 82 } }, 1.2, 0.5, 'r')
  K.stroke(g, { { 47, 78 + by }, { 49, 85 }, { 53 - st, 90 } }, 3, 0.8, 'r')
  K.stroke(g, { { 58, 74 + by }, { 68, 82 }, { 77 + st, 88 } }, 3.4, 0.8, 'r')
  K.stroke(g, { { 66, 81 }, { 73, 79 }, { 79, 81 } }, 1.2, 0.5, 'r')
  K.ell(g, 47, 70 + by, 16, 10, 'e')
  K.relight(g, { 'def', 'tru' }, 1, 2)
  K.fillHoles(g, 'd')
  for _, ex in ipairs({ 40, 56 }) do
    K.ell(g, ex, 69 + by, 6, 6.5, 'd')
    K.ell(g, ex, 69 + by, 5, 5.5, 'x')
    L.disc(g, ex + 2, 70 + by, 2.4, 'A')
    L.set(g, ex + 1, 68 + by, 'x')
  end
  -- nervura do meio: um trecho mais claro sobe a cada quadro
  for i = 1, 5 do
    local c = (i % 4 == f % 4) and 'U' or 'V'
    L.line(g, axis[i][1], axis[i][2], axis[i + 1][1], axis[i + 1][2], c)
  end
  -- esporos nas pontas das pinas: apagam em rodizio
  for k, t in ipairs(tips) do
    local c = ((k + f) % 4 == 0) and 'n' or 'P'
    L.rect(g, t[1] - 0.5, t[2] - 0.5, t[1] + 0.5, t[2] + 0.5, c)
  end
  -- esporos soltos subindo
  local loose = { { 10, 30 }, { 86, 26 }, { 14, 62 }, { 84, 58 }, { 70, 8 }, { 26, 10 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S') end
  end
  return g, sg
end

K.build {
  name = 'frondling', size = 28, leg = LEG, emit = EMIT, keys = { 'd', 'e', 'f', 't', 'r', 'u' }, dark = 'd',
  pose = pose, portrait = portrait,
  idle = { { p = 0 }, { p = 1, stretch = 20 }, { p = 2, stretch = 20 }, { p = 1 } },
  alert = { p = 0, stretch = 20 },
  alert2 = { { 3, 9 }, { 24, 9, 's' }, { 17, 3 } },
  alert3 = S.cat(S.plus(2, 8), S.plus(25, 8), { { 17, 2, 's' }, { 9, 3 }, { 2, 17 }, { 25, 18 } }),
  sq = 20,
  variants = {
    { key = 'urban', -- samambaia de muro, cinza; faixa rebitada no pe da fronde
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 7, 16, { 'WwWWwWWwWWwWW' } } } },
    { key = 'green', -- musgo; florzinha clara na pina de baixo, a esquerda
      legend = { L = '#F4F8D0', l = '#F2C84A' },
      put = { { 5, 13, { '.L.', 'LlL', '.L.' } } } },
    { key = 'water', -- petroleo escuro; gotas de orvalho na pina de baixo, a direita
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 17, 14, { 'U.U', 'u.u' } } } },
    { key = 'residential', -- folha seca, clara; cachecol telha debaixo do rosto
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 8, 20, { 'OOOOOOOOOOOo', '.........Oo.' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; gravata-borboleta escura no meio da fronde
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 11, 12, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas; aureola dourada em volta da ponta
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 9, 4, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim entre os olhos
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 12, 17, { '.RR', 'Rr.', '.RR' } } } },
  },
}
