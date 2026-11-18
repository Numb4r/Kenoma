-- Bitling (bit.eco), glitch que vive em letreiros e telas. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 28 x 28, olhando para a direita: uma pilha de seis faixas de tela fora de sincronia, com dois olhos de
-- pixel e duas pernas. No alerta as faixas se alinham (o glitch para).
-- leds: os olhos. glow: a scanline que desce em cada faixa, a franja magenta das faixas deslocadas e os pixels soltos.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local SL = { { 4, 8, 12, 3 }, { 7, 10, 12, 3 }, { 10, 7, 12, 3 }, { 13, 9, 12, 3 }, { 16, 5, 13, 3 }, { 19, 9, 10, 2 } } -- y, x, largura, altura
local SH = { [0] = { 0, 0, 0, 0, 0, 0 }, [1] = { 0, 0, 1, 0, 2, 0 }, [2] = { -1, 0, -1, 1, 0, 0 }, alert = { 0, -2, 1, -1, 3, 0 } }
local BITS = { [0] = { { 23, 11 }, { 3, 18 } }, [1] = { { 24, 17 }, { 4, 9, 's' } }, [2] = { { 22, 5 }, { 3, 13 }, { 24, 20, 's' } }, alert = {} }

local function pose(p)
  local g = L.grid(28, 28)
  local n = p == 'alert' and 0 or p
  for i, s in ipairs(SL) do
    local x, y = s[2] + SH[p][i], s[1]
    for r = 0, s[4] - 1 do
      local c = r == 0 and 'W' or (r == s[4] - 1 and 'N' or 'M')
      if i % 2 == 1 and r == (n + (i - 1) // 2) % 3 then c = 'J' end
      L.rect(g, x, y + r, x + s[3] - 1, y + r, c)
      if c ~= 'J' and c ~= 'W' then L.set(g, x + s[3] - 1, y + r, 'N') end
      if (i == 3 or i == 5) and p ~= 'alert' and c ~= 'J' then L.set(g, x, y + r, 'P') end
    end
    if i == 2 then
      for r = 1, 2 do
        L.set(g, x + 3, y + r, 'h'); L.set(g, x + 4, y + r, 'H'); L.set(g, x + 8, y + r, 'h'); L.set(g, x + 9, y + r, 'H')
      end
      if p == 'alert' then L.set(g, x + 3, y + 1, 'H'); L.set(g, x + 8, y + 1, 'H') end
    end
  end
  L.put(g, 10, 21, { 'MM...MM', n == 1 and 'MMN....' or 'MMN..MMN' })
  return g, BITS[p]
end

local JIT = { { 0, 0, 0, 0, 0, 0 }, { 0, 0, 3, 0, -2, 0 }, { 2, 0, 0, -1, 4, 0 }, { 0, 0, -3, 0, 0, 1 } }
local PS = { { 12, 26, 40, 10 }, { 22, 32, 40, 12 }, { 34, 22, 40, 10 }, { 44, 28, 40, 10 }, { 54, 16, 43, 10 }, { 64, 28, 33, 8 } }
local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  -- pernas
  for _, lx in ipairs({ 33, 49 }) do
    L.rect(g, lx, 70 + by, lx + 5, 80, 'M'); L.rect(g, lx + 4, 70 + by, lx + 5, 80, 'N')
    L.rect(g, lx, 79, lx + 10, 82, 'M'); L.rect(g, lx, 79, lx + 10, 79, 'W'); L.rect(g, lx, 82, lx + 10, 82, 'N')
  end
  for i, s in ipairs(PS) do
    local x, y, w, h = s[2] + JIT[f][i], s[1] + by, s[3], s[4]
    L.rect(g, x, y, x + w - 1, y + h - 1, 'M')
    L.rect(g, x, y, x + w - 1, y + 1, 'W')
    L.rect(g, x + w - 3, y + 2, x + w - 1, y + h - 1, 'N')
    L.rect(g, x, y + h - 2, x + w - 1, y + h - 1, 'N')
    if i ~= 2 then
      for yy = y + 3, y + h - 4, 3 do L.rect(g, x + 3, yy, x + w - 5, yy, 'j') end
      local sy = y + 3 + 3 * ((f + i) % 2)
      for xx = x + 3, x + w - 5 do L.set(g, xx, sy, F.hash(xx, i, f) % 5 == 0 and 'Y' or 'J') end
    end
    if i == 3 or i == 5 then L.rect(g, x, y, x + 1, y + h - 1, 'P') end
    if i == 2 then -- olhos de pixel, olhando para a direita
      for _, ex in ipairs({ x + 8, x + 25 }) do
        L.rect(g, ex, y + 2, ex + 7, y + 9, 'h')
        local up = f == 4 and 2 or 0
        L.rect(g, ex + 3, y + 3 + up, ex + 6, y + 8, 'H')
      end
    end
  end
  -- pixels soltos: as copias com defeito
  for k, p in ipairs({ { 80, 30 }, { 8, 44 }, { 84, 60 }, { 10, 20 }, { 76, 12 }, { 6, 70 } }) do
    if (k + f) % 3 ~= 0 then
      local x, y = p[1] + ((k + f) % 2) * 2, p[2]
      L.rect(sg, x, y, x + 2, y + 2, (k + f) % 4 == 1 and 's' or 'S')
    end
  end
  return g, sg
end

F.build {
  name = 'bitling', W = 28,
  LEG = {
    A = '#1A1424',
    W = '#4E9A86', M = '#2F6A62', N = '#1F4648',                -- tela
    h = '#122E36', j = '#245E50', p = '#4A2A4E',                -- olho, scanline e franja apagados
    H = '#D9FFF0',                                              -- olho (leds)
    J = '#3DFFB0', Y = '#D9FFF0', P = '#FF5FB0',                -- scanline e franja (glow)
    S = '#3DFFB0', s = '#D9FFF0',                               -- pixel solto (glow)
  },
  BODY_KEYS = { 'W', 'M', 'N' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' }, P = { 'p', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'N',
  pose = pose,
  acc = {
    urban = { { 9, 14, { 'wWWWWWWWWWWw' } }, { 9, 20, { 'wWWWWWWWWw' } } },        -- duas bracadeiras, no meio e na base
    green = { { 11, 4, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto no alto
    water = { { 9, 13, { 'u.u.u.U.u.u.' } }, { 15, 14, { 'U', 'v' } } },            -- colar de contas com gota
    residential = { { 7, 10, { 'OOOOOOOOOOOo' } }, { 7, 11, { 'Oo', 'Oo', 'oo' } } }, -- cachecol sob os olhos
    lit = { { 11, 13, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } },                  -- gravata-borboleta
    sacred = { { 10, 3, { '.GGGGGG.', 'G......G', 'G......G', '.gggggg.' } } },    -- aureola
    crimson = { { 10, 15, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente embaixo
  },
  portrait = portrait,
}
