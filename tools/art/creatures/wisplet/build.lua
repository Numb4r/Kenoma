-- Wisplet (wisp.eco), vulto de nevoa. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 28 x 28, olhando para a direita: cabeca redonda de nevoa, a cauda se desfaz para tras em tres fios.
-- leds: os dois olhos. glow: a chama fria no peito (cresce no alerta) e as faiscas frias.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local HEAD = { -- linhas 5..17
  '...........WWWWWW...........',
  '.........WWWWMMMMMM.........',
  '........WWMMMMMMMMMM........',
  '.......WWMMMMMMMMMMMN.......',
  '.......WMMMMMMMMMMMMN.......',
  '......WWMMMMhhMMMhhMNN......',
  '......WMMMMMhHMMMhHMMN......',
  '......WMMMMMhhMMMhhMMN......',
  '......WMMMMMMMMMMMMMMN......',
  '......WMMMMMjJJjMMMMNN......',
  '......WMMMMjJYYJjMMMNN......',
  '.......MMMMMjJJjMMMNN.......',
  '.......MMMMMMjjMMMNNN.......',
}
local TAIL = { -- linhas 18..22
  [0] = {
    '......MMMNMMMMMMNNNN........',
    '.....MMNNNMMMNNNNNN.........',
    '....MMNN.NNNNNNNDD..........',
    '...MNN....NNDDDD............',
    '...NN......DD...............',
  },
  [1] = {
    '......MMMNMMMMMMNNNN........',
    '......MMNNNMMNNNNNN.........',
    '.....MNNN.NNNNNDD...........',
    '....MNN...NNDDD.............',
    '....NN.....DD...............',
  },
  [2] = {
    '.......MMNMMMMMMNNNN........',
    '.......MNNNMMNNNNNN.........',
    '......MNN.NNNNNDD...........',
    '......NN...NNDDD............',
    '.......N....NDD.............',
  },
}

local function pose(p)
  local g = L.grid(28, 28)
  local k = p == 'alert' and 0 or p
  F.rows(g, 5, HEAD, 'cabeca')
  F.rows(g, 18, TAIL[k], 'cauda' .. k)
  if k == 1 then L.set(g, 14, 14, 'Y'); L.set(g, 13, 15, 'J') end
  if k == 2 then L.set(g, 13, 14, 'Y'); L.set(g, 14, 15, 'J') end
  if p == 'alert' then -- olhos arregalados
    L.set(g, 13, 10, 'H'); L.set(g, 18, 10, 'H'); L.set(g, 13, 12, 'H'); L.set(g, 18, 12, 'H')
  end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -2, -1 })[f]
  local sw = ({ 0, 1.5, 0, -1.5 })[f]
  local fl = ({ 0, 2, 0, -2 })[f]
  -- cauda: tres fios de nevoa para tras e para baixo, cada um balancando no seu passo
  F.stroke(g, { { 42, 62 + by, 15 }, { 28 + sw, 75 + by, 9 }, { 17 + sw * 2, 84, 4 }, { 9 + sw * 3, 88, 1 } }, 'M')
  F.stroke(g, { { 52, 66 + by, 12 }, { 45 - sw, 79 + by, 7 }, { 41 - sw * 2, 89, 2 } }, 'M')
  F.stroke(g, { { 62, 62 + by, 10 }, { 63 + sw, 76 + by, 5 }, { 59 + sw * 2, 85, 1 } }, 'M')
  F.ell(g, 50, 46 + by, 27, 26, 'M')
  F.ell(g, 53, 31 + by, 21, 19, 'M')
  F.bevel(g, 'M', 'W', 'N', 5)
  F.bevel(g, 'N', nil, 'D', 2)
  -- fiapos de nevoa
  for _, s in ipairs({ { 38, 24, 12 }, { 30, 36, 8 }, { 62, 22, 6 }, { 28, 50, 7 } }) do
    L.line(g, s[1], s[2] + by, s[1] + s[3], s[2] + by, 'W', 'M')
  end
  for _, s in ipairs({ { 60, 50, 12 }, { 34, 66, 10 }, { 64, 60, 8 }, { 24, 76, 6 } }) do
    L.line(g, s[1] + sw, s[2] + by, s[1] + s[3] + sw, s[2] + by, 'N', 'M')
  end
  -- olhos: orbita escura, a luz olhando para a direita
  for _, ex in ipairs({ 45, 64 }) do
    F.ell(g, ex, 38 + by, 4.5, 6.5, 'h')
    F.ell(g, ex + 1.5, 38 + by + (f == 3 and 1 or 0), 2.5, f == 3 and 3 or 4.5, 'H', 'h')
  end
  -- chama fria no peito
  local cy = 62 + by
  F.ell(g, 54, cy, 7.5, 9, 'j')
  F.poly(g, { { 47, cy - 3 }, { 54 + fl, cy - 17 }, { 61, cy - 3 } }, 'j')
  F.ell(g, 54, cy + 1, 5, 6.5, 'J', 'j')
  F.poly(g, { { 50, cy - 2 }, { 54 + fl, cy - 13 }, { 58, cy - 2 } }, 'J', 'j')
  F.ell(g, 54, cy + 2, 2.5, 4, 'Y', 'J')
  -- frio que se ve
  for k, p in ipairs({ { 12, 30 }, { 84, 26 }, { 88, 58 }, { 78, 82 }, { 20, 60 }, { 70, 8 }, { 30, 10 } }) do
    if (k + f) % 4 ~= 0 then
      local c = (k + f) % 4 == 2 and 's' or 'S'
      L.set(sg, p[1], p[2] - f, c)
      if k % 2 == 0 then L.set(sg, p[1] + 1, p[2] - f, c); L.set(sg, p[1], p[2] - f + 1, c) end
    end
  end
  return g, sg
end

F.build {
  name = 'wisplet', W = 28,
  LEG = {
    A = '#1A1424',
    W = '#B4C0D8', M = '#8490B0', N = '#5C688E', D = '#3E476C', -- nevoa
    h = '#2A3350', j = '#35506E',                               -- olho e chama apagados
    H = '#D8F4FF',                                              -- olho (leds)
    J = '#6FC8F5', Y = '#E4F8FF', S = '#6FC8F5', s = '#E4F8FF', -- chama fria e faisca (glow)
  },
  BODY_KEYS = { 'W', 'M', 'N', 'D' },
  EMIT = { H = { 'h', 'leds' }, J = { 'j', 'glow' }, Y = { 'j', 'glow' } },
  BRIGHT = { J = 'Y' },
  DARK = 'D',
  pose = pose,
  acc = {
    urban = { { 7, 17, { 'wWWWWWWWWWWWWw' } } },                                   -- bracadeira na cintura
    green = { { 12, 4, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto no alto da cabeca
    water = { { 8, 8, { 'u.u.u.uUu.u.u', '.......U.....', '.......v.....' } } },   -- diadema de contas com gota
    residential = { { 6, 13, { 'OOOOOOOOOOOOOOOo' } }, { 7, 14, { 'Oo', 'Oo', 'oo' } } }, -- cachecol
    lit = { { 9, 6, { 'NN..NN', 'NNMMNN', 'NN..NN' } } },                          -- laco na cabeca
    sacred = { { 10, 4, { '.GGGGGG.', 'G......G', 'G......G', '.gggggg.' } } },    -- aureola
    crimson = { { 8, 13, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },                -- crescente no flanco
  },
  portrait = portrait,
}
