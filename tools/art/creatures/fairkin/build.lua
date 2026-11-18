-- Fairkin (sprig.spirit), fada de asas de folha seca. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 36 x 36, olhando para a direita: fada esguia, do tamanho de um gato, com quatro folhas secas no lugar das asas.
-- leds: os olhos. glow: a nervura central de cada folha (cresce no alerta) e o po que cai das asas.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L
local DY = 3

local WING = { -- metade esquerda (colunas 0..17), linhas 4..25; a direita e espelho
  '....TT............',
  '...TTJBB..........',
  '...TTTJBBB........',
  '....TTTJBBB.......',
  '....RTTJBBBB......',
  '.....TTTJBBBB.....',
  '.....RTTTJBBB.....',
  '......RTTTJBBB....',
  '.......RTTTJBB....',
  '........RRTJBB....',
  '.........RRTJBR...',
  '...........RRJR...',
  '..................',
  '...........TTT....',
  '.........TTTJB....',
  '........TTTJBB....',
  '.......TTTJBB.....',
  '.......RTTJB......',
  '......RTTJB.......',
  '......RTJB........',
  '......RJB.........',
  '......RR..........',
}
local BODY = { -- colunas 13..22, linhas 5..28
  '....KK....',
  '..KKKKKK..',
  '.KKKKKKKK.',
  '.KFFFFFFK.',
  '.KFhHFhHK.',
  '.KFhHFhHK.',
  '.kFFFFFFk.',
  '..kfFFFfk.',
  '...ffff...',
  '..GGGGGG..',
  '.FGGGGGGF.',
  '.FGGGGGgF.',
  '.FGGGGGgF.',
  '.FGGGGggF.',
  '.fGGGGggf.',
  '..GGGGGgg.',
  '.GGGGGGggg',
  '.GgGGgGggg',
  '...FF.FF..',
  '...FF.FF..',
  '...Ff.Ff..',
  '....F.F...',
  '....F.Ff..',
  '....f.....',
}
local FLAP = { [0] = 1, [1] = 0.7, [2] = 0.45 }
local DUST = {
  [0] = { { 5, 24 }, { 30, 22, 's' } },
  [1] = { { 6, 27 }, { 29, 25 }, { 3, 19, 's' } },
  [2] = { { 7, 30, 's' }, { 28, 28 }, { 5, 22 }, { 31, 18 } },
}

local function pose(p)
  local n = p == 'alert' and 0 or p
  local src = L.grid(36, 36)
  for j, row in ipairs(WING) do
    if #row ~= 18 then error('asa linha ' .. j .. ': ' .. #row) end
    for i = 1, 18 do
      local c = row:sub(i, i)
      if c ~= '.' then src[3 + j + DY][i - 1] = c; src[3 + j + DY][36 - i] = c end
    end
  end
  local g, s = L.grid(36, 36), FLAP[n]
  for y = 0, 35 do
    for x = 0, 35 do
      if x >= 14 and x <= 21 then g[y][x] = src[y][x]
      else
        local sx = x < 14 and math.floor(14 - (14 - x) / s + 0.5) or math.floor(21 + (x - 21) / s + 0.5)
        local c = L.get(src, sx, y)
        if (sx < 14 or sx > 21) and c ~= '.' then g[y][x] = c end
      end
    end
  end
  for j, row in ipairs(BODY) do if #row ~= 10 then error('corpo linha ' .. j .. ': ' .. #row) end end
  L.put(g, 13, 5 + DY, BODY)
  return g, DUST[n]
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -2, -1 })[f]
  local fs = ({ 1, 0.88, 0.76, 0.88 })[f]
  local up = ({ 0, -2, -4, -2 })[f]
  -- folha serrilhada da base ate a ponta, com a metade de cima mais clara e a nervura acesa
  local function leaf(bx, by0, tx, ty, w)
    tx = bx + (tx - bx) * fs; ty = ty + up
    by0 = by0 + by; ty = ty + by
    local dx, dy = tx - bx, ty - by0
    local len = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / len, dx / len
    if ny > 0 then nx, ny = -nx, -ny end
    local a, b, axis = {}, {}, {}
    local N = 10
    for i = 0, N do
      local t = i / N
      local hw = w * math.sin(math.pi * t ^ 0.75) * (i % 2 == 1 and 0.8 or 1)
      local ax, ay = bx + dx * t, by0 + dy * t
      axis[#axis + 1] = { ax, ay }
      a[#a + 1] = { ax + nx * hw, ay + ny * hw }; b[#b + 1] = { ax - nx * hw, ay - ny * hw }
    end
    local whole, half = {}, {}
    for i = 1, #a do whole[#whole + 1] = a[i]; half[#half + 1] = a[i] end
    for i = #b, 1, -1 do whole[#whole + 1] = b[i] end
    for i = #axis, 1, -1 do half[#half + 1] = axis[i] end
    F.poly(g, whole, 'B'); F.poly(g, half, 'T', 'B')
    for i = 3, N - 1, 2 do
      L.line(g, axis[i - 1][1], axis[i - 1][2], a[i][1], a[i][2], 'R', 'T')
      L.line(g, axis[i - 1][1], axis[i - 1][2], b[i][1], b[i][2], 'R', 'B')
    end
    F.stroke(g, { { bx, by0, 1 }, { tx, ty, 0.5 } }, 'J', 'TBR')
    if f >= 2 then
      for k = 2, N - 1, 3 do L.set(g, axis[k + (f % 2)][1], axis[k + (f % 2)][2], 'Y', 'J') end
    end
  end
  leaf(43, 53, 10, 14, 13); leaf(58, 53, 87, 16, 11)
  leaf(43, 59, 18, 84, 8); leaf(58, 59, 80, 82, 7)
  F.bevel(g, 'TB', nil, 'R', 2)
  -- pernas, vestido, bracos
  F.stroke(g, { { 47, 75 + by, 1.4 }, { 45, 88 + by, 1 } }, 'F'); L.rect(g, 44, 89 + by, 47, 90 + by, 'f')
  F.stroke(g, { { 55, 75 + by, 1.4 }, { 57, 86 + by, 1 } }, 'F'); L.rect(g, 56, 87 + by, 60, 88 + by, 'f')
  F.stroke(g, { { 45, 53 + by, 1.6 }, { 39, 64 + by, 1.2 }, { 41, 70 + by, 1 } }, 'F')
  F.stroke(g, { { 57, 53 + by, 1.6 }, { 64, 62 + by, 1.2 }, { 67, 58 + by, 1 } }, 'F')
  F.poly(g, { { 45, 49 + by }, { 57, 49 + by }, { 63, 76 + by }, { 39, 76 + by } }, 'G')
  for x = 41, 61, 5 do F.ell(g, x, 76 + by, 2.5, 2.5, 'G') end
  F.bevel(g, 'G', nil, 'g', 3)
  for x = 44, 60, 5 do L.line(g, x, 60 + by, x - 1 + (x - 51) // 5, 76 + by, 'g', 'G') end
  -- cabelo comprido para tras, com uma folha presa
  F.stroke(g, { { 41, 34 + by, 5 }, { 36, 48 + by, 3.5 }, { 34, 60 + by, 1 } }, 'K')
  F.ell(g, 50, 34 + by, 14, 13, 'K')
  F.bevel(g, 'K', nil, 'k', 3)
  F.poly(g, { { 42, 24 + by }, { 50, 16 + by }, { 54, 25 + by } }, 'T')
  L.line(g, 44, 24 + by, 50, 18 + by, 'R', 'T')
  F.ell(g, 52, 39 + by, 10, 8.5, 'F')
  F.bevel(g, 'F', nil, 'f', 2)
  -- olhos acesos, olhando para a direita
  for _, ex in ipairs({ 48, 57 }) do
    F.ell(g, ex, 38 + by, 2, 3.2, 'h')
    F.ell(g, ex + 0.6, 38 + by - (f == 2 and 1 or 0), 0.8, 1.8, 'H', 'h')
  end
  L.rect(g, 43, 43 + by, 45, 44 + by, 'f'); L.rect(g, 59, 43 + by, 61, 44 + by, 'f')
  L.line(g, 52, 45 + by, 55, 44 + by, 'k')
  -- po das folhas
  for k, p in ipairs({ { 14, 40 }, { 26, 60 }, { 82, 44 }, { 72, 62 }, { 10, 66 }, { 86, 70 }, { 32, 88 }, { 68, 88 } }) do
    if (k + f) % 4 ~= 0 then
      local c = (k + f) % 4 == 2 and 's' or 'S'
      local x, y = p[1], p[2] + f * 2 - 4
      L.set(sg, x, y, c)
      if k % 3 == 0 then L.set(sg, x - 1, y, c); L.set(sg, x + 1, y, c); L.set(sg, x, y - 1, c); L.set(sg, x, y + 1, c) end
    end
  end
  return g, sg
end

F.build {
  name = 'fairkin', W = 36,
  LEG = {
    A = '#1A1424',
    T = '#D8A858', B = '#AE7638', R = '#774828',                -- folha seca
    K = '#FF8FD8', k = '#B8508E',                               -- cabelo
    F = '#F4D8C8', f = '#C89898',                               -- pele
    G = '#8A4A6E', g = '#4E2A4A',                               -- vestido
    h = '#3A2038', j = '#6A4A28',                               -- olho e nervura apagados
    H = '#FFF3A8',                                              -- olho (leds)
    J = '#FFD84A', Y = '#FFF8D8', S = '#FFE08A', s = '#FFF8D8', -- nervura e po (glow)
  },
  BODY_KEYS = { 'T', 'B', 'R', 'K', 'k', 'F', 'f', 'G', 'g' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'g',
  pose = pose,
  acc = {
    urban = { { 15, 21, { 'WWWWWw' } }, { 15, 24, { 'WWWWWWw' } } },               -- duas bracadeiras no vestido
    green = { { 16, 6, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto no alto da cabeca
    water = { { 14, 17, { 'u.U.U.u.' } }, { 17, 18, { 'U', 'v' } } },               -- colar de contas com gota
    residential = { { 14, 17, { 'OOOOOOOo' } }, { 20, 18, { 'O', 'O', 'o' } } },    -- cachecol
    lit = { { 14, 17, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } },                  -- gravata-borboleta
    sacred = { { 13, 7, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } },          -- aureola
    crimson = { { 16, 20, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no vestido
  },
  portrait = portrait,
}
