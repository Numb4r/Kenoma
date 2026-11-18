-- Sprigglet (sprig.eco), fada pequena do crepusculo. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 28 x 28, olhando para a direita: cabeca grande de petala com duas antenas, vestido curto, dois pares de asas.
-- leds: a mancha de cada asa de cima. glow: a ponta das antenas e o po de fada que cai das asas.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local BODY = { -- linhas 5..22, asas abertas
  '..........J......J..........',
  '...WWW.....k....k...WWW.....',
  '..WWVVW.....kKKk...WVVWW....',
  '..WVVVVW...KKKKKK..WVVVVW...',
  '..WVHHVVW.KKKKKKKK.WVHHVW...',
  '..UVHHVVVWKKFFFFFKKWVHHVU...',
  '...UVVVVVWKFFgFFgFKWVVVU....',
  '....UVVVVWKFFgFFgFKWVVU.....',
  '.....UUVVWkFFFFFFfkWVU......',
  '.......UUVWkfFFFfkWU........',
  '......WVVW..GGGGG..WVW......',
  '.....WVVVW.FGGGGGF.WVVW.....',
  '.....UVVW..FGGGGgF..UVW.....',
  '......UUW...GGGGg...UU......',
  '...........GGGGGgg..........',
  '..........GGgGGgGgg.........',
  '............F...F...........',
  '............f...Ff..........',
}
local FLAP = { [0] = 1, [1] = 0.7, [2] = 0.45 }
local DUST = {
  [0] = { { 4, 18 }, { 23, 17, 's' } },
  [1] = { { 5, 20 }, { 22, 19 }, { 3, 15, 's' } },
  [2] = { { 6, 22, 's' }, { 21, 21 }, { 4, 17 }, { 24, 14 } },
}

local function pose(p)
  local n = p == 'alert' and 0 or p
  local src = L.grid(28, 28)
  F.rows(src, 5, BODY, 'corpo')
  if n == 0 then return src, DUST[0] end
  -- bater de asa: as asas (colunas 0..9 e 19..27) encolhem para o corpo
  local g, s = L.grid(28, 28), FLAP[n]
  for y = 0, 27 do
    for x = 0, 27 do
      if x >= 10 and x <= 18 then g[y][x] = src[y][x]
      else
        local sx = x < 10 and math.floor(10 - (10 - x) / s + 0.5) or math.floor(18 + (x - 18) / s + 0.5)
        local c = L.get(src, sx, y)
        if (sx < 10 or sx > 18) and c ~= '.' then g[y][x] = c end
      end
    end
  end
  return g, DUST[n]
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -2, -1 })[f]
  local fs = ({ 1, 0.86, 0.72, 0.86 })[f]
  local up = ({ 0, -2, -4, -2 })[f]
  local function wing(rx, ry, pts)
    local o = {}
    for i, p in ipairs(pts) do
      local k = (i - 1) / (#pts - 1)
      o[i] = { rx + (p[1] - rx) * fs, ry + by + (p[2] - ry) + up * k, p[3] }
    end
    F.stroke(g, o, 'V')
    return o
  end
  local wl = wing(42, 54, { { 42, 54, 3 }, { 29, 38, 11 }, { 19, 24, 8 }, { 14, 15, 2 } })
  local wr = wing(58, 54, { { 58, 54, 3 }, { 70, 40, 9 }, { 78, 26, 7 }, { 82, 18, 2 } })
  wing(42, 60, { { 42, 60, 3 }, { 28, 68, 7 }, { 21, 78, 2 } })
  wing(58, 60, { { 58, 60, 3 }, { 70, 68, 6 }, { 76, 77, 2 } })
  F.bevel(g, 'V', 'W', 'U', 3)
  -- nervuras e a mancha de cada asa de cima
  for _, w in ipairs({ wl, wr }) do
    L.line(g, w[1][1], w[1][2], w[4][1], w[4][2], 'U', 'V')
    L.line(g, w[2][1], w[2][2], w[3][1] + (w == wl and -6 or 6), w[3][2] + 6, 'U', 'V')
    local sx, sy = (w[2][1] + w[3][1]) / 2, (w[2][2] + w[3][2]) / 2
    F.ell(g, sx, sy, 4, 4, 'h'); F.ell(g, sx, sy, 2, 2, 'H', 'h')
  end
  -- pernas, vestido, bracos
  F.stroke(g, { { 47, 76 + by, 1.3 }, { 46, 87 + by, 1 } }, 'F'); L.rect(g, 45, 88 + by, 48, 89 + by, 'f')
  F.stroke(g, { { 56, 76 + by, 1.3 }, { 58, 86 + by, 1 } }, 'F'); L.rect(g, 57, 87 + by, 61, 88 + by, 'f')
  F.stroke(g, { { 44, 61 + by, 1.6 }, { 38, 71 + by, 1.2 } }, 'F')
  F.stroke(g, { { 58, 61 + by, 1.6 }, { 65, 69 + by, 1.2 } }, 'F')
  F.poly(g, { { 44, 57 + by }, { 58, 57 + by }, { 67, 78 + by }, { 37, 78 + by } }, 'G')
  for x = 39, 65, 6 do F.ell(g, x, 78 + by, 3, 2.5, 'G') end
  F.bevel(g, 'G', nil, 'g', 3)
  for x = 42, 62, 6 do L.line(g, x, 66 + by, x - 1 + (x - 51) // 6, 77 + by, 'g', 'G') end
  -- antenas
  F.stroke(g, { { 45, 30 + by, 1 }, { 40, 20 + by, 0.8 }, { 36, 14 + by, 0.8 } }, 'k')
  F.stroke(g, { { 57, 30 + by, 1 }, { 62, 20 + by, 0.8 }, { 66, 14 + by, 0.8 } }, 'k')
  F.ell(g, 35, 12 + by, 2.5, 2.5, 'J'); F.ell(g, 67, 12 + by, 2.5, 2.5, 'J')
  if f == 3 then L.set(g, 35, 12 + by, 'Y'); L.set(g, 67, 12 + by, 'Y') end
  -- cabelo de petala e rosto
  F.ell(g, 50, 42 + by, 17, 16, 'K')
  F.poly(g, { { 44, 28 + by }, { 51, 20 + by }, { 57, 28 + by } }, 'K')
  F.bevel(g, 'K', nil, 'k', 3)
  F.ell(g, 52, 47 + by, 12, 10.5, 'F')
  F.bevel(g, 'F', nil, 'f', 2)
  F.ell(g, 48, 46 + by, 1.8, 3.2, 'g'); F.ell(g, 58, 46 + by, 1.8, 3.2, 'g')
  L.rect(g, 43, 51 + by, 45, 52 + by, 'f'); L.rect(g, 60, 51 + by, 62, 52 + by, 'f')
  L.line(g, 52, 53 + by, 55, 53 + by, 'k')
  -- po de fada caindo das asas
  for k, p in ipairs({ { 16, 40 }, { 24, 56 }, { 80, 44 }, { 74, 58 }, { 12, 62 }, { 84, 66 }, { 30, 84 }, { 70, 86 } }) do
    if (k + f) % 4 ~= 0 then
      local c = (k + f) % 4 == 2 and 's' or 'S'
      local x, y = p[1], p[2] + f * 2
      L.set(sg, x, y, c)
      if k % 3 == 0 then L.set(sg, x - 1, y, c); L.set(sg, x + 1, y, c); L.set(sg, x, y - 1, c); L.set(sg, x, y + 1, c) end
    end
  end
  return g, sg
end

F.build {
  name = 'sprigglet', W = 28,
  LEG = {
    A = '#1A1424',
    W = '#F6D2EE', V = '#D694CC', U = '#9A5E9E',                -- asa
    K = '#FF8FD8', k = '#C458A6',                               -- cabelo de petala
    F = '#FFE6DA', f = '#E2AEB4',                               -- pele
    G = '#7A4A8C', g = '#4A2C62',                               -- vestido (e os olhos)
    h = '#8A5E84', j = '#8A6A40',                               -- mancha e antena apagadas
    H = '#FFF3A8',                                              -- mancha da asa (leds)
    J = '#FFD84A', Y = '#FFF8D8', S = '#FFE08A', s = '#FFF8D8', -- antena e po de fada (glow)
  },
  BODY_KEYS = { 'W', 'V', 'U', 'K', 'k', 'F', 'f', 'G', 'g' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'g',
  pose = pose,
  acc = {
    urban = { { 12, 17, { 'WWWWw' } }, { 11, 19, { 'WWWWWWw' } } },                -- duas bracadeiras no vestido
    green = { { 12, 6, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto entre as antenas
    water = { { 11, 15, { 'u.U.U.u' } }, { 14, 16, { 'U', 'v' } } },                -- colar de contas com gota
    residential = { { 11, 15, { 'OOOOOOo' } }, { 17, 16, { 'O', 'o', 'o' } } },     -- cachecol
    lit = { { 11, 15, { 'NN...NN', 'NNNMNNN', 'NN...NN' } } },                     -- gravata-borboleta
    sacred = { { 10, 6, { '.GGGGGGG.', 'G.......G', '.ggggggg.' } } },             -- aureola
    crimson = { { 13, 16, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no vestido
  },
  portrait = portrait,
}
