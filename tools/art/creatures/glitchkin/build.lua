-- Glitchkin (bit.spirit), criatura feita de quadros repetidos. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 36 x 36, olhando para a direita: a mesma figura (cabeca de tela, tronco, bracos, pernas) tres vezes, cada
-- copia um pouco fora do lugar; so a da frente esta acesa. As copias pulam de lugar a cada quadro e se juntam no alerta.
-- leds: os olhos da copia da frente. glow: as scanlines que descem, a franja magenta da copia de tras e os pixels soltos.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local FIG = { -- 16 x 23
  '..WWWWWWWWWWWW..',
  '.WMMMMMMMMMMMMN.',
  '.WMMMMMMMMMMMMN.',
  '.WMMMMhHMMMhHMN.',
  '.WMMMMhHMMMhHMN.',
  '.WMMMMMMMMMMMMN.',
  '.WMMMMMMMMMMMMN.',
  '..NNNNNNNNNNNN..',
  '.....MMMMMN.....',
  '.WWWWWWWWWWWWWW.',
  'WMMMMMMMMMMMMMMN',
  'WMMMMMMMMMMMMMMN',
  'MM.MMMMMMMMMN.MN',
  'MM.MMMMMMMMMN.MN',
  'MN.MMMMMMMMMN.MN',
  'MN.MMMMMMMMMN.MN',
  'NN.NNNNNNNNNN.NN',
  '...WMMN..WMMN...',
  '...MMMN..MMMN...',
  '...MMMN..MMMN...',
  '...MMMN..MMMN...',
  '...MMNN..MMNN...',
  '...MMMNN.MMMMNN.',
}
local OFF = { -- copia de tras e do meio, em relacao a da frente
  [0] = { { -6, -2 }, { -3, -1 } }, [1] = { { -4, -3 }, { -2, 1 } }, [2] = { { -7, 0 }, { -4, -2 } },
  alert = { { -2, 0 }, { -1, 0 } },
}
local BITS = { [0] = { { 31, 12 }, { 4, 22 } }, [1] = { { 32, 20 }, { 5, 9, 's' } }, [2] = { { 30, 6 }, { 3, 15 }, { 32, 26, 's' } }, alert = {} }
local X0, Y0 = 13, 7

local function pose(p)
  local n = p == 'alert' and 0 or p
  local g = L.grid(36, 36)
  for k = 1, 3 do
    local o = OFF[p][k] or { 0, 0 }
    for r, row in ipairs(FIG) do
      for c = 1, 16 do
        local ch = row:sub(c, c)
        if ch ~= '.' then
          local x, y = X0 + o[1] + c - 1, Y0 + o[2] + r - 1
          if k == 1 then ch = (L.get(g, x - 1, y) == '.' and row:sub(c - 1, c - 1) ~= 'M' and (c == 1 or row:sub(c - 1, c - 1) == '.')) and 'P' or 'D'
          elseif k == 2 then ch = (ch == 'H' or ch == 'h') and 'h' or 'N'
          elseif ch == 'M' and (r - 1 + 2 * n) % 6 == 5 then ch = 'J' end
          g[y][x] = ch
        end
      end
    end
  end
  return g, BITS[p]
end

local POFF = { { { -16, -6 }, { -8, -3 } }, { { -12, -9 }, { -6, 2 } }, { { -19, -2 }, { -10, -5 } }, { { -14, -6 }, { -7, -1 } } }
local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local function stamp(ox, oy, fill)
    for r, row in ipairs(FIG) do
      for c = 1, 16 do
        local ch = row:sub(c, c)
        if ch ~= '.' then
          local x, y = ox + (c - 1) * 3, oy + (r - 1) * 3
          L.rect(g, x, y, x + 2, y + 2, (ch == 'h' or ch == 'H') and 'h' or fill)
        end
      end
    end
  end
  local fx, fy = 31, 15 + by
  -- copia de tras: escura, com a franja magenta na borda esquerda
  local b = POFF[f][1]
  stamp(fx + b[1], fy + b[2], 'D')
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'D' and L.get(g, x - 1, y) == '.' then g[y][x] = 'P'; if L.get(g, x + 1, y) == 'D' then g[y][x + 1] = 'P' end end
  end end
  -- copia do meio: sem luz, so as linhas da tela
  local m = POFF[f][2]
  stamp(fx + m[1], fy + m[2], 'N')
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'N' and (y - fy - m[2]) % 4 == 2 then g[y][x] = 'D' end
  end end
  -- copia da frente: acesa
  stamp(fx, fy, 'M')
  F.bevel(g, 'M', 'W', 'N', 2)
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'M' and (y - fy) % 4 == 2 then
      local lit = ((y - fy) // 4 + f) % 5 == 0
      g[y][x] = lit and (F.hash(x, y, f) % 6 == 0 and 'Y' or 'J') or 'j'
    end
  end end
  -- olhos: o pixel aceso do lado para onde olha
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'h' and y >= fy + 9 and y <= fy + 14 and x >= fx then
      local c = (x - fx) // 3
      if (c == 7 or c == 12) and not (f == 4 and y < fy + 11) then g[y][x] = 'H' end
    end
  end end
  for k, p in ipairs({ { 86, 30 }, { 6, 50 }, { 88, 64 }, { 8, 26 }, { 84, 10 }, { 10, 80 } }) do
    if (k + f) % 3 ~= 0 then
      local x, y = p[1] + ((k + f) % 2) * 2, p[2]
      L.rect(sg, x, y, x + 2, y + 2, (k + f) % 4 == 1 and 's' or 'S')
    end
  end
  return g, sg
end

F.build {
  name = 'glitchkin', W = 36,
  LEG = {
    A = '#1A1424',
    W = '#5AA894', M = '#347268', N = '#22504E', D = '#183638', -- tela
    h = '#102A32', j = '#28665A', p = '#4A2A4E',                -- olho, scanline e franja apagados
    H = '#D9FFF0',                                              -- olho (leds)
    J = '#3DFFB0', Y = '#D9FFF0', P = '#FF5FB0',                -- scanline e franja (glow)
    S = '#3DFFB0', s = '#D9FFF0',                               -- pixel solto (glow)
  },
  BODY_KEYS = { 'W', 'M', 'N', 'D' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' }, P = { 'p', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'D',
  pose = pose,
  -- a tela da base tem o mesmo valor do cinza de concreto: aqui o urban desce para grafite
  ramps = { urban = { '#16181E', '#34374A', '#9EA2AE' } },
  acc = {
    urban = { { 16, 20, { 'wWWWWWWWWw' } }, { 16, 23, { 'wWWWWWWWWw' } } },        -- duas bracadeiras no tronco
    green = { { 19, 6, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto no alto da tela
    water = { { 15, 16, { 'u.u.u.U.u.u.' } }, { 21, 17, { 'U', 'v' } } },           -- colar de contas com gota
    residential = { { 16, 15, { 'OOOOOOOOOo' } }, { 17, 16, { 'Oo', 'Oo', 'oo' } } }, -- cachecol
    lit = { { 17, 15, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } },                  -- gravata-borboleta
    sacred = { { 16, 5, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } },          -- aureola
    crimson = { { 19, 19, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no tronco
  },
  portrait = portrait,
}
