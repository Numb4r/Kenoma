-- Wyrmlet (wyrm.eco), brasa que respira. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 28 x 28, olhando para a direita: um ovo de carvao rachado, com uma ponta de crista em cima e um toco de
-- cauda atras. Quase nao parece dragao (GDD). O movimento proprio e inchar e desinchar.
-- leds: os dois olhos de brasa. glow: as rachaduras (mais fortes quando incha, crescem no alerta) e as fagulhas.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local EGG = { -- linhas 5..21, desinchado
  '..............T.............',
  '.............TC.............',
  '............TCCD............',
  '..........TTTCCCDD..........',
  '.........TTCCCCCCCD.........',
  '........TTCCJCCCCCCD........',
  '........TCCCJChHChHD........',
  '.......TCCCJJChHChHDD.......',
  '.......TCCJCCCCCCCCCDD......',
  '.......CCCJJCCCCJCDDDD......',
  '.......CCCCJJJCJJCDDDD......',
  '.......CCDCCCJJJCCDDDD......',
  '....C..CDDCCCCJCCDDDDD......',
  '.....CDDDDCCCCJJCDDDDD......',
  '........DDDCCCCJDDDD........',
  '.........DDDDDDDDDD.........',
  '...........DDDDDD...........',
}
local SPARKS = { [0] = {}, [1] = { { 12, 3 } }, [2] = { { 16, 2, 's' }, { 10, 4 }, { 22, 7 } } }

local function pose(p)
  local n = p == 'alert' and 2 or p
  local src = L.grid(28, 28)
  F.rows(src, 5, EGG, 'ovo')
  local g = src
  if n == 2 then -- inchado: as colunas 9 e 19 dobram e o ovo ganha 1 px de cada lado
    g = L.grid(28, 28)
    for y = 0, 27 do for x = 0, 27 do
      local sx = (x <= 8 and x + 1) or (x >= 20 and x - 1) or x
      g[y][x] = L.get(src, sx, y)
    end end
  end
  for y = 0, 27 do for x = 0, 27 do
    if g[y][x] == 'J' and ((n == 2 and (x + y) % 2 == 0) or (n == 1 and (x + y) % 3 == 0)) then g[y][x] = 'Y' end
  end end
  return g, SPARKS[n]
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local sc = ({ 1, 1.03, 1.06, 1.03 })[f]
  local function P(x, y, r) return { 48 + (x - 48) * sc, 56 + (y - 56) * sc, r } end
  local function path(pts, c, mask, r)
    local o = {}
    for i, p in ipairs(pts) do o[i] = P(p[1], p[2], r) end
    F.stroke(g, o, c, mask)
  end
  -- toco de cauda, ovo e crista
  F.stroke(g, { P(24, 68, 6), P(14, 60, 3), P(10, 53, 1) }, 'C')
  F.ell(g, 48, 56, 27 * sc, 28 * sc, 'C')
  F.ell(g, 48, 56 - 14 * sc, 22 * sc, 24 * sc, 'C')
  local a, b, c = P(40, 24), P(49, 10), P(57, 24)
  F.poly(g, { a, b, c }, 'C')
  F.bevel(g, 'C', 'T', 'D', 6)
  -- cinza e crosta
  for y = 14, 88 do for x = 8, 86 do
    if g[y][x] == 'C' then
      local h = F.hash(x // 2, y // 2, 21) % 17
      if h == 0 then g[y][x] = 'D' elseif h == 1 and y < 50 then g[y][x] = 'T' end
    end
  end end
  -- rachaduras: a brasa por baixo da crosta
  local CR = {
    { { 30, 36 }, { 38, 46 }, { 34, 56 }, { 44, 64 }, { 54, 60 }, { 62, 70 }, { 58, 80 } },
    { { 38, 46 }, { 48, 44 }, { 52, 34 } },
    { { 54, 60 }, { 64, 56 }, { 70, 62 } },
    { { 44, 64 }, { 42, 75 } },
    { { 62, 70 }, { 70, 74 } },
  }
  for _, cr in ipairs(CR) do path(cr, 'j', 'CTD', 1.6) end
  for _, cr in ipairs(CR) do path(cr, 'J', 'j', 0.7) end
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'J' and F.hash(x // 2, y // 2, 22) % 6 < f then g[y][x] = 'Y' end
  end end
  -- olhos de brasa, olhando para a direita
  for _, e in ipairs({ { 57, 45, 4 }, { 69, 46, 3 } }) do
    local q = P(e[1], e[2])
    F.ell(g, q[1], q[2], e[3], e[3] + 1.5, 'h')
    F.ell(g, q[1] + 1, q[2], 1.2, e[3], 'H', 'h')
  end
  -- fagulhas subindo
  for k, p in ipairs({ { 30, 12 }, { 62, 8 }, { 78, 26 }, { 16, 34 }, { 86, 48 }, { 44, 6 } }) do
    if (k + f) % 3 ~= 0 then
      local c2 = (k + f) % 4 == 1 and 's' or 'S'
      L.set(sg, p[1] + (f % 2), p[2] + 6 - f * 2, c2)
      if k % 2 == 0 then L.set(sg, p[1] + (f % 2) + 1, p[2] + 6 - f * 2, c2) end
    end
  end
  return g, sg
end

F.build {
  name = 'wyrmlet', W = 28,
  LEG = {
    A = '#1A1424',
    T = '#8E5A50', C = '#54303A', D = '#34202E',                -- crosta de carvao
    h = '#2A1418', j = '#6A2E24',                               -- olho e rachadura apagados
    H = '#FFE9A8',                                              -- olho (leds)
    J = '#FF7A45', Y = '#FFD27A', S = '#FF7A45', s = '#FFD27A', -- brasa e fagulha (glow)
  },
  BODY_KEYS = { 'T', 'C', 'D' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'D',
  pose = pose,
  -- a base ja e carvao escuro: o crimson desce ate quase preto para se separar dela em cinza
  ramps = { crimson = { '#140810', '#32101C', '#C04858' } },
  acc = {
    urban = { { 8, 19, { 'wWWWWWWWWWWw' } } },                                     -- bracadeira na base
    green = { { 12, 5, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto na crista
    water = { { 9, 9, { 'u.u.U.u.u.', '.u.u.u.u.u' } }, { 13, 10, { 'U', 'U', 'v' } } }, -- colar de duas voltas com gota
    residential = { { 7, 13, { 'OOOOOOOOOOOOOo' } }, { 8, 14, { 'Oo', 'Oo', 'oo' } } }, -- cachecol sob os olhos
    lit = { { 9, 15, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } },                   -- gravata-borboleta
    sacred = { { 10, 6, { '.GGGGGG.', 'G......G', '.gggggg.' } } },                -- aureola na crista
    crimson = { { 16, 16, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no flanco
  },
  portrait = portrait,
}
