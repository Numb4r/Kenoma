-- Rillet (rill.eco), 0.25.1: gota que reflete o ceu. Rodar: aseprite -b --script build.lua
-- corpo: agua, olhos, o ceu refletido. leds: os reflexos que cintilam (brilho da pele e a estrela no ceu refletido).
-- glow: a caustica no fundo da gota e os pingos soltos.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(28)

local LEG = {
  A = '#1A1424',
  h = '#2D5AA0', i = '#4A86D6', j = '#9FD0F5',   -- agua
  k = '#1F2A5C', z = '#D98A6C', y = '#F2C48D',   -- ceu refletido
  x = '#F0EEF8',                                 -- olho
  g = '#7FB4E0', W = '#FFFFFF',                  -- reflexo apagado (corpo) e aceso (leds)
  c = '#2F6E9A', C = '#7FE0F0', D = '#D8FFFF',   -- caustica apagada (corpo) e acesa (glow)
  S = '#9FD0F5', s = '#E8F8FF',                  -- pingo
}
local EMIT = { W = { 'g', 'l' }, C = { 'c', 'w' }, D = { 'c', 'w' } }

local BASE = L.frame({
  '............................',
  '............................',
  '............................',
  '............................',
  '.............j..............',
  '.............j..............',
  '............jj..............',
  '............jji.............',
  '...........jjii.............',
  '...........jjiih............',
  '..........jjiiiih...........',
  '.........jjjiiiiih..........',
  '........jjjiiiiiiihh........',
  '.......jjjiiiiiiiiiihh......',
  '......jjxxxxiiiiixxxxhhh....',
  '......jxxxxxxiiixxxxxxhh....',
  '.....jjxxxxAAiiixxxxAAihh...',
  '.....jjxxxxAAiiixxxxAAihh...',
  '.....jjixxxxiiiiixxxxiihh...',
  '.....jiiiiiiiiiiiiiikkihh...',
  '.....jiiiiiiiiiiiikkkzzhh...',
  '.....jjiiiiiiiiiikkkzzyhh...',
  '......jiiiiiiiiiikkzzyyh....',
  '.......hiiiiiiiiiizyyhh.....',
  '........hhhhhhhhhhhhhh......',
  '............................',
  '............................',
  '............................',
}, 28, 28, 'rillet')

-- p: 0 ponta em pe, 1 e 2 a ponta cai para a frente. glow: 1 a 3 (a caustica cresce).
local function pose(o)
  local g = K.copy(BASE)
  local p = o.p or 0
  if p >= 1 then K.shiftRow(g, 4, 1); K.shiftRow(g, 5, 1) end
  if p >= 2 then K.shiftRow(g, 6, 1) end
  if o.wide then L.put(g, 8, 13, { 'xxxx.....xxxx' }) end
  g[12][9] = 'W'; g[13][8] = 'W'; g[20][19] = 'W'
  local glow = o.glow or 1
  L.put(g, 8, 23, { glow == 1 and 'CCCC' or 'CCCCCCC' })
  if glow >= 2 then L.put(g, 6, 21, { 'C', '.C' }) end
  if glow == 3 then K.swap(g, { C = 'D' }); L.put(g, 8, 22, { 'CCCCC' }) end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local by = ({ 0, -1, -1, 0 })[f]
  local sq = ({ 0, 1, 0, -1 })[f]      -- a gota estica e achata
  local tx = ({ 0, 1, 3, 1 })[f]
  local cx, cy, rx, ry = 47, 60 + by, 28 - sq, 26 + sq
  K.stroke(g, { { 45, 42 + by }, { 43, 28 + by - sq }, { 44 + tx, 15 + by - sq * 2 }, { 48 + tx, 7 + by - sq * 2 } }, 11, 1, 'i')
  K.ell(g, cx, cy, rx, ry, 'i')
  K.relight(g, { 'hij' }, 7, 10)
  -- o ceu de agora, refletido embaixo e a direita: noite, entardecer, claro
  for y = 0, 95 do for x = 0, 95 do
    local d = ((x - 61) / 14) ^ 2 + ((y - (71 + by)) / 11) ^ 2
    if d <= 1 and (g[y][x] == 'i' or g[y][x] == 'h') then
      local t = (y - (71 + by)) + (x - 61) * 0.7
      g[y][x] = t < -3 and 'k' or (t < 4 and 'z' or 'y')
    end
  end end
  for _, ex in ipairs({ 36, 60 }) do
    K.ell(g, ex, 52 + by, 9.5, 10.5, 'h')
    K.ell(g, ex, 52 + by, 8, 9, 'x')
    L.disc(g, ex + 3, 53 + by, 4, 'A')
    L.rect(g, ex + 1, 50 + by, ex + 2, 51 + by, 'x')
  end
  -- reflexos que cintilam: o brilho da pele, o da ponta e a estrela no ceu refletido
  local on = function(k) return (k + f) % 4 ~= 0 end
  if on(1) then K.stroke(g, { { 27, 50 + by }, { 30, 42 + by } }, 1.6, 0.6, 'W') else K.stroke(g, { { 27, 50 + by }, { 30, 42 + by } }, 1, 0.5, 'W') end
  L.rect(g, 25, 56 + by, 26, 57 + by, 'W')
  if on(2) then L.rect(g, 41 + tx // 2, 24 + by, 42 + tx // 2, 27 + by, 'W') end
  local sx, sy = 58, 66 + by
  L.set(g, sx, sy, 'W')
  if on(3) then L.put(g, sx - 1, sy - 1, { '.W.', 'WWW', '.W.' }) end
  if on(0) then L.set(g, 66, 69 + by, 'W') end
  -- caustica: o arco de luz no fundo da gota
  for a = 100, 165, 1 do
    local r = math.rad(a)
    local c = ((a + f * 12) % 48 < 10) and 'D' or 'C'
    local x, y = cx + (rx - 5) * math.cos(r), cy + (ry - 4) * math.sin(r)
    L.set(g, x, y, c); L.set(g, x, y - 1, c)
  end
  -- pingos soltos caindo
  local loose = { { 12, 30 }, { 84, 24 }, { 10, 62 }, { 86, 56 }, { 70, 10 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] + ((f + k) % 4) * 4
    if (f + k) % 4 ~= 3 then L.put(sg, pt[1], y, { 's.', 'SS', 'SS' }) else L.put(sg, pt[1] - 1, y, { 'S..S' }) end
  end
  return g, sg
end

K.build {
  name = 'rillet', size = 28, leg = LEG, emit = EMIT, keys = { 'h', 'i', 'j', 'k', 'z', 'y' }, dark = 'h',
  pose = pose, portrait = portrait,
  idle = { { p = 0 }, { p = 1, stretch = 19 }, { p = 2, stretch = 19 }, { p = 1 } },
  alert = { p = 0, stretch = 19, wide = true },
  alert2 = { { 3, 10 }, { 24, 11, 's' }, { 20, 5 } },
  alert3 = S.cat(S.plus(3, 8), S.plus(24, 9), { { 20, 3, 's' }, { 6, 4 }, { 2, 16 }, { 25, 17 } }),
  sq = 21,
  variants = {
    { key = 'urban', -- agua de sarjeta, cinza; faixa rebitada na testa
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 9, 12, { 'WwWWwWWwWW' } } } },
    { key = 'green', -- agua de lago, verde; broto no ombro direito
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 16, 7, { '.LL', 'lL.', 'd..', 'd..' } } } },
    { key = 'water', -- fundo de rio, a mais escura das azuis; contas claras na bochecha esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 6, 19, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- agua de barro, clara; cachecol telha
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 9, 19, { 'OOOOOOOOo', '......Oo.', '......oo.' } } } },
    { key = 'lit', -- leitosa, a mais clara; gravata-borboleta escura embaixo
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 8, 21, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas; aureola dourada em volta da ponta
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 8, 6, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim entre os olhos
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 13, 14, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
