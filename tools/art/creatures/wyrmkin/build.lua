-- Wyrmkin (wyrm.spirit), filhote de dragao ainda sem forma inteira. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 36 x 36, olhando para a direita: a cabeca (chifres, focinho, dentes) e a ponta da cauda estao prontas; o
-- meio e uma massa de carvao onde as escamas mudam de lugar a cada quadro.
-- leds: o olho. glow: a costura de brasa que desce pelo corpo (respira, cresce no alerta) e as fagulhas.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local BODY = { -- linhas 5..30
  '....................B....B..........',
  '....................BB...BB.........',
  '.....................BB...BB........',
  '....................TTTTTTTTC.......',
  '...................TTCCCCCCCCCT.....',
  '..................TCCCCChHCCCCCT....',
  '..................TCCCCChHCCCCDC....',
  '..................CCCCCCCCCCDDDD....',
  '.................CCCCCCCDDBDBD......',
  '...............TCCCCCCDDDD..........',
  '............TTTCCJCCCCDDD...........',
  '..........TTCCCCJJCCCCCDDD..........',
  '.........TCCCCCCCJCCCCCDDD..........',
  '........TCCCCCCCCJJCCCCDDDD.........',
  '........TCCCCCCCJJCCCCCCDDD.........',
  '.......TCCCCCCJJCCCCCCCCCDDD........',
  '.......CCCCCCJJCCCCCCCCDDDD.........',
  '.......CCCCCCJCCCCCCCCDDDDD.........',
  '......CCCCCCJJCCCCCCDDDDDD..........',
  '.....CDCCCCCJCCCCCDDDDDDD...........',
  '....CDD.CCCCJJCCDDDDDDD.............',
  '...CDD...DDDDJDDDDDDD...............',
  '...CD.....DDD....DDD................',
  '...TCD....DDBB...DDBB...............',
  '...TTCD.............................',
  '....TC..............................',
}
local SCALE = { 'TT.', '.EE' }
local SPOTS = { -- onde as escamas estao em cada quadro
  [0] = { { 10, 17 }, { 20, 17 }, { 9, 21 }, { 19, 20 }, { 15, 23 } },
  [1] = { { 12, 18 }, { 21, 19 }, { 10, 22 }, { 18, 22 }, { 19, 16 } },
  [2] = { { 11, 19 }, { 19, 18 }, { 8, 20 }, { 17, 21 }, { 15, 24 } },
}
local SPARKS = { [0] = {}, [1] = { { 13, 12 } }, [2] = { { 11, 11, 's' }, { 14, 12 }, { 6, 17 } } }

local function pose(p)
  local n = p == 'alert' and 0 or p
  local g = L.grid(36, 36)
  F.rows(g, 5, BODY, 'corpo')
  for _, s in ipairs(SPOTS[n]) do
    for j, row in ipairs(SCALE) do
      for i = 1, #row do
        local c = row:sub(i, i)
        if c ~= '.' then L.set(g, s[1] + i - 1, s[2] + j - 1, c, 'C') end
      end
    end
  end
  for y = 0, 35 do for x = 0, 35 do
    if g[y][x] == 'J' and ((n == 2 and (x + y) % 2 == 0) or (n == 1 and (x + y) % 3 == 0)) then g[y][x] = 'Y' end
  end end
  return g, SPARKS[n]
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local hy = ({ 0, -1, -2, -1 })[f] -- a cabeca sobe mais que o corpo
  -- cauda com a ponta em pa, patas, massa do corpo, pescoco, cabeca
  F.stroke(g, { { 32, 66 + by, 9 }, { 18, 72 + by, 5 }, { 11, 81, 3 }, { 13, 88, 1.5 } }, 'C')
  F.poly(g, { { 6, 84 }, { 13, 80 }, { 21, 88 }, { 12, 92 } }, 'C')
  F.ell(g, 38, 84, 7, 4, 'C'); F.ell(g, 60, 84, 7, 4, 'C')
  F.ell(g, 44, 62 + by, 24, 19, 'C')
  F.ell(g, 30, 58 + by, 10, 9, 'C'); F.ell(g, 60, 68 + by, 12, 10, 'C')
  F.stroke(g, { { 48, 54 + by, 13 }, { 58, 38 + hy, 9 } }, 'C')
  F.ell(g, 64, 30 + hy, 14, 10, 'C')
  F.ell(g, 77, 34 + hy, 9, 6.5, 'C')
  F.bevel(g, 'C', 'T', 'D', 5)
  -- o meio ainda sem forma: manchas fundas e escamas que mudam de lugar
  for y = 44, 80 do for x = 18, 70 do
    if g[y][x] == 'C' then
      local h = F.hash(x // 3, y // 3, 31) % 9
      if h == 0 then g[y][x] = 'E' end
    end
  end end
  for k = 0, 13 do
    local x = 24 + F.hash(k, f, 32) % 40
    local y = 50 + by + F.hash(k, f, 33) % 24
    L.line(g, x, y, x + 3, y, 'T', 'CE'); L.set(g, x - 1, y + 1, 'T', 'CE'); L.set(g, x + 4, y + 1, 'T', 'CE')
    L.line(g, x, y + 2, x + 3, y + 2, 'D', 'CE')
  end
  -- a cabeca ja esta pronta: escamas em fileira, chifres, sobrancelha, narina, boca e dentes
  for r = 0, 2 do
    for x = 54 + r * 2, 72, 5 do
      local y = 24 + r * 4 + hy
      L.line(g, x, y, x + 2, y, 'T', 'C'); L.line(g, x, y + 1, x + 2, y + 1, 'D', 'C')
    end
  end
  F.poly(g, { { 55, 23 + hy }, { 49, 8 + hy }, { 60, 20 + hy } }, 'B')
  F.poly(g, { { 65, 20 + hy }, { 63, 6 + hy }, { 71, 20 + hy } }, 'B')
  L.line(g, 70, 39 + hy, 85, 38 + hy, 'D'); L.line(g, 70, 40 + hy, 80, 40 + hy, 'E', 'CD')
  for x = 73, 82, 4 do L.rect(g, x, 39 + hy, x + 1, 41 + hy, 'B') end
  L.rect(g, 82, 31 + hy, 83, 32 + hy, 'E')
  L.line(g, 63, 24 + hy, 73, 26 + hy, 'D')
  F.ell(g, 68, 30 + hy, 3.5, 3.5, 'h')
  F.ell(g, 69, 30 + hy, 1, f == 4 and 1.5 or 3, 'H', 'h')
  for _, cx in ipairs({ 34, 56 }) do for i = 0, 2 do L.rect(g, cx + i * 4, 86, cx + i * 4 + 1, 88, 'B') end end
  -- costura de brasa
  local CR = {
    { { 54, 42 + hy }, { 47, 53 + by }, { 51, 62 + by }, { 41, 70 + by }, { 37, 79 + by } },
    { { 47, 53 + by }, { 36, 52 + by } },
    { { 51, 62 + by }, { 61, 69 + by } },
    { { 41, 70 + by }, { 30, 68 + by } },
  }
  for _, cr in ipairs(CR) do
    local o = {}
    for i, q in ipairs(cr) do o[i] = { q[1], q[2], 1.5 } end
    F.stroke(g, o, 'j', 'CTDE')
  end
  for _, cr in ipairs(CR) do
    local o = {}
    for i, q in ipairs(cr) do o[i] = { q[1], q[2], 0.7 } end
    F.stroke(g, o, 'J', 'j')
  end
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'J' and F.hash(x // 2, y // 2, 34) % 6 < f then g[y][x] = 'Y' end
  end end
  for k, p in ipairs({ { 30, 30 }, { 40, 16 }, { 86, 14 }, { 12, 50 }, { 88, 56 }, { 22, 38 } }) do
    if (k + f) % 3 ~= 0 then
      local c = (k + f) % 4 == 1 and 's' or 'S'
      L.set(sg, p[1] + (f % 2), p[2] + 6 - f * 2, c)
      if k % 2 == 0 then L.set(sg, p[1] + (f % 2) + 1, p[2] + 6 - f * 2, c) end
    end
  end
  return g, sg
end

F.build {
  name = 'wyrmkin', W = 36,
  LEG = {
    A = '#1A1424',
    T = '#C8544C', C = '#8A3440', D = '#56263A', E = '#341C2C', -- escama e carvao
    B = '#E0C8A8',                                              -- chifre, dente e garra
    h = '#2A1418', j = '#6A2E24',                               -- olho e costura apagados
    H = '#FFE9A8',                                              -- olho (leds)
    J = '#FF7A45', Y = '#FFD27A', S = '#FF7A45', s = '#FFD27A', -- brasa e fagulha (glow)
  },
  BODY_KEYS = { 'T', 'C', 'D', 'E', 'B' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'E',
  pose = pose,
  acc = {
    urban = { { 7, 22, { 'wWWWWWWWWWWWWWWWWWWw' } } },                             -- bracadeira no meio do corpo
    green = { { 22, 6, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto entre os chifres
    water = { { 15, 14, { 'u.U.u.U.u.u' } }, { 19, 15, { 'U', 'v' } } },            -- coleira de contas com gota
    residential = { { 15, 14, { 'OOOOOOOOOOo' } }, { 16, 15, { 'Oo', 'Oo', 'oo' } } }, -- cachecol no pescoco
    lit = { { 12, 16, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } },                  -- gravata-borboleta no peito
    sacred = { { 20, 5, { '.GGGGGGG.', 'G.......G', '.ggggggg.' } } },             -- aureola sobre os chifres
    crimson = { { 20, 18, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no flanco
  },
  portrait = portrait,
}
