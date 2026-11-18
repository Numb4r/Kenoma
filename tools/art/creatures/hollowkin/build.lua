-- Hollowkin (wisp.spirit), manto vazio com uma vela dentro. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa 36 x 36, olhando para a direita: manto de pe com capuz pontudo, sem ninguem dentro; a frente aberta
-- mostra a vela acesa no lugar do peito. A barra em farrapos balanca.
-- leds: o miolo da chama (a vela tremula). glow: a chama por fora e a luz quente no forro do manto, que cresce no alerta.
local F = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/wisplet/_fase1.lua')
local L = F.L

local CLOAK = { -- linhas 4..29
  '...............WWM..................',
  '..............WWMMMN................',
  '............WWMMMMMNN...............',
  '...........WWMMMMMMMMNN.............',
  '..........WMMMMMMMMMMMNN............',
  '..........WMMMMooooooooNN...........',
  '.........WMMMMooooooooooN...........',
  '.........WMMMMooooooooooNN..........',
  '.........WMMMMooooooooooNN..........',
  '.........WMMMMMoooooooooNN..........',
  '.........WMMMMMMoooooooNNN..........',
  '.........WMMMMMMMMNNNNNNND..........',
  '........WMMMMMMDoooooDNNNNN.........',
  '........WMMMMMDoooJoooDNNNN.........',
  '.......WMMMMMMDoOJYJOoDNNNNN........',
  '.......WMMMMMMDOOJYJOODNNNNN........',
  '.......WMMMMMMDoOOJOOoDNNNNN........',
  '.......WMMMMMMDooXXxooDNNNNN........',
  '.......WMMMMMMDooXXxooDNNNNN........',
  '.......WMMMMMMDooXXxooDNNNNN........',
  '......WMMMMMMMDooXXxooDNNNNNN.......',
  '......WMMMMMMMMDoXXxoDNNNNNNN.......',
  '......WMMMMMMMMMDDDDDNNNNNNND.......',
  '......WMMMMMMMMMMMNNNNNNNNNDD.......',
  '.....WMMMMMMMMMMMNNNNNNNNNNDDD......',
  '.....MMMNMMMMMDMMNNNNDNNNNNDDD......',
}
local HEM = { 'MMN.MMMDD.MNNND.NNNDD.DDD', 'MN...MDD...NND...NDD...DD', 'N.....D.....N.....D.....D' } -- linhas 30..32
local SWAY = { [0] = 0, [1] = 1, [2] = -1 }

local function pose(p)
  local n = p == 'alert' and 0 or p
  local g = L.grid(36, 36)
  F.rows(g, 4, CLOAK, 'manto')
  L.put(g, 5 + SWAY[n], 30, HEM)
  if n == 1 then L.set(g, 18, 17, 'o'); L.set(g, 19, 17, 'J') end
  if n == 2 then L.set(g, 18, 17, 'o'); L.set(g, 17, 17, 'J') end
  if p == 'alert' then L.set(g, 18, 16, 'J'); L.set(g, 18, 17, 'Y'); L.set(g, 16, 17, 'O'); L.set(g, 20, 17, 'O') end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local sw = ({ 0, 2, 0, -2 })[f]
  local fl = ({ 0, 1.5, 0, -1.5 })[f]
  local function Y(pts)
    local o = {}
    for i, p in ipairs(pts) do o[i] = { p[1], p[2] + by } end
    return o
  end
  F.poly(g, Y { { 46, 8 }, { 58, 13 }, { 66, 25 }, { 69, 40 }, { 73, 50 }, { 77, 66 }, { 80, 84 }, { 16, 84 }, { 19, 66 },
    { 23, 50 }, { 27, 40 }, { 30, 25 }, { 36, 13 } }, 'M')
  for i = 0, 4 do F.poly(g, { { 16 + 13 * i, 84 + by }, { 22 + 13 * i + sw, 92 }, { 29 + 13 * i, 84 + by } }, 'M') end
  -- luz da esquerda: lado direito na sombra, borda esquerda clara, dobras
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'M' then
      if x > 70 + (y - 40) * 0.12 then g[y][x] = 'D'
      elseif x > 57 + (y - 8) * 0.1 then g[y][x] = 'N'
      elseif L.get(g, x - 1, y) == '.' or L.get(g, x - 2, y) == '.' or L.get(g, x - 3, y) == '.' then g[y][x] = 'W' end
    end
  end end
  L.line(g, 33, 50 + by, 28, 88, 'N', 'M'); L.line(g, 39, 60 + by, 37, 90, 'N', 'M')
  L.line(g, 69, 52 + by, 73, 88, 'D', 'N'); L.line(g, 40, 14 + by, 34, 30 + by, 'W', 'M')
  -- capuz: aba e o vazio
  F.ell(g, 53, 31 + by, 15, 16, 'N', 'MNW')
  L.ring(g, 53, 31 + by, 15.4, 'W', 'N')
  F.ell(g, 54, 32 + by, 12, 13, 'o')
  -- frente aberta, com a luz da vela no forro
  F.poly(g, Y { { 47, 50 }, { 60, 50 }, { 64, 82 }, { 44, 82 } }, 'o')
  L.line(g, 46, 50 + by, 43, 82 + by, 'D'); L.line(g, 61, 50 + by, 65, 82 + by, 'D')
  F.ell(g, 53, 58 + by, 7.5, 12, 'O', 'o')
  if f == 2 or f == 3 then F.ell(g, 53, 58 + by, 5, 8, 'Q', 'O') end
  -- vela
  L.rect(g, 49, 64 + by, 56, 81 + by, 'X'); L.rect(g, 55, 64 + by, 56, 81 + by, 'x')
  L.rect(g, 50, 64 + by, 50, 69 + by, 'x'); L.rect(g, 53, 64 + by, 53, 66 + by, 'x')
  L.rect(g, 52, 61 + by, 53, 63 + by, 'D')
  F.ell(g, 52.5, 56 + by, 3.2, 5, 'J')
  F.poly(g, { { 49, 55 + by }, { 52.5 + fl, 44 + by }, { 56, 55 + by } }, 'J')
  if f == 3 then F.ell(g, 52.5, 55 + by, 2.4, 4.5, 'B', 'J') end
  F.ell(g, 52.5, 57 + by, 1.4, 3, 'Y')
  for k, p in ipairs({ { 12, 30 }, { 84, 20 }, { 88, 56 }, { 8, 66 }, { 74, 6 }, { 22, 12 } }) do
    if (k + f) % 4 ~= 0 then
      local c = (k + f) % 4 == 2 and 's' or 'S'
      L.set(sg, p[1], p[2] - f, c)
      if k % 2 == 1 then L.set(sg, p[1] + 1, p[2] - f, c) end
    end
  end
  return g, sg
end

F.build {
  name = 'hollowkin', W = 36,
  LEG = {
    A = '#1A1424',
    W = '#A9B2CC', M = '#727C9E', N = '#4E5678', D = '#333A58', -- manto
    X = '#E4DCCB', x = '#B0A696',                               -- cera da vela
    o = '#221A33', y = '#6A4A30', j = '#5A3A28',                -- o vazio (forro sem luz), miolo e chama apagados
    Y = '#FFF6D0',                                              -- miolo da chama (leds)
    J = '#FFB040', B = '#FFE9A8', O = '#8A4E30', Q = '#C87A3C', -- chama e luz no forro (glow)
    S = '#FFB040', s = '#FFE9A8',
  },
  BODY_KEYS = { 'W', 'M', 'N', 'D', 'X', 'x' },
  EMIT = { Y = { 'y', 'leds' }, J = { 'j', 'glow' }, B = { 'j', 'glow' }, O = { 'o', 'glow' }, Q = { 'o', 'glow' } },
  BRIGHT = { J = 'B', O = 'Q' },
  DARK = 'D',
  pose = pose,
  acc = {
    urban = { { 6, 27, { 'wWWWWWWWWWWWWWWWWWWWWWw' } } },                           -- bracadeira na barra
    green = { { 14, 4, { 'L..L', 'lLLl', '.dd.' } } },                             -- broto na ponta do capuz
    water = { { 9, 15, { 'u.u.u.u.U.u.u.u.u' } }, { 12, 16, { 'U', 'v' } } },       -- colar de contas na gola, com gota
    residential = { { 9, 15, { 'OOOOOOOOOOOOOOOOo' } }, { 10, 16, { 'Oo', 'Oo', 'Oo', 'oo' } } }, -- cachecol
    lit = { { 8, 19, { 'NN..NN', 'NNMMNN', 'NN..NN' } } },                         -- laco no ombro
    sacred = { { 12, 5, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } },          -- aureola no capuz
    crimson = { { 23, 20, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } },               -- crescente no lado
  },
  portrait = portrait,
}
