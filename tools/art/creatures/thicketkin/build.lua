-- Thicketkin (frond.spirit), 0.25.1: moita com um oco na frente, de onde dois olhos espiam. Rodar: aseprite -b --script build.lua
-- corpo: tufos de folha, o oco, raizes. leds: os dois olhos no oco. glow: as bagas e os esporos soltos.
-- Os tufos sao discos iluminados um a um e empilhados de cima para baixo; o farfalhar muda o raio de cada um.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  d = '#2F6B45', e = '#4C9A5A', f = '#86D37C',   -- folha
  t = '#3E3026', r = '#5A4636', u = '#8A6A4A',   -- raiz
  k = '#16242A',                                 -- o oco (igual em toda variante)
  n = '#4E6E4A', P = '#E6FF9A',                  -- olho apagado (corpo) e aceso (leds)
  m = '#7A3248', B = '#FF8FA8', Z = '#FFD8E0',   -- baga apagada (corpo) e acesa (glow)
  S = '#B8F28A', s = '#F0FFC8',
}
local EMIT = { P = { 'n', 'l' }, B = { 'm', 'w' }, Z = { 'm', 'w' } }
local BERRIES = { { 9, 15 }, { 27, 13 }, { 14, 8 }, { 25, 25 }, { 10, 24 } }

-- Em unidades de 36 px vezes [s]. bob em unidades. Devolve nada; o oco e os olhos vem depois.
local function bush(g, s, ph, bob, nh, nl)
  for _, r in ipairs({ { 12, 28, 8.5, 31.5 }, { 18, 29, 18, 32 }, { 24, 28, 27.5, 31.5 } }) do
    K.stroke(g, { { r[1] * s, r[2] * s }, { r[3] * s, r[4] * s } }, 1.6 * s, 0.7 * s, 'r')
  end
  K.relight(g, { 'tru' }, nh, nh)
  K.ell(g, 18 * s, (18.5 + bob) * s, 9.5 * s, 9.5 * s, 'd')
  local n = 0
  for j = 0, 4 do
    local y = 9 + j * 4.3
    local w = 10.2 * math.sqrt(math.max(0, 1 - ((y - 18.5) / 11.5) ^ 2))
    local m = math.max(1, math.ceil(2 * w / 4.6))
    for i = 0, m do
      n = n + 1
      local c = L.grid(g.w, g.h)
      L.disc(c, (18 + w * (2 * i / m - 1)) * s, (y + bob) * s, (3.3 + 0.45 * math.sin(ph + n * 1.7)) * s, 'e')
      K.relight(c, { 'def' }, nh, nl)
      K.stamp(g, c)
    end
  end
end

-- p: 0 a 3, a fase do farfalhar. bob: a copa sobe. wide: o oco abre. glow: 1 a 3.
local function pose(o)
  local g = L.grid(36, 36)
  local p, bob, glow = o.p or 0, o.bob or 0, o.glow or 1
  bush(g, 1, p * math.pi / 2, bob, 1, 2)
  K.ell(g, 19.5, 21 + bob, o.wide and 7 or 5.6, o.wide and 4.2 or 3, 'k')
  L.put(g, 17, 20 + bob, { 'PP..PP', 'PP..PP' })
  for k, b in ipairs(BERRIES) do
    local c = 'm'
    if glow == 3 then c = 'Z' elseif glow == 2 or k <= 2 then c = 'B' end
    g[b[2] + bob][b[1]] = c
  end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local s = 96 / 36
  local bob = ({ 0, -0.4, -0.8, -0.4 })[f]
  bush(g, s, (f - 1) * math.pi / 2, bob, 3, 5)
  local hy = (21 + bob) * s
  K.ell(g, 19.5 * s, hy, 6 * s, 3.4 * s, 'k')
  -- olhos: piscam em rodizio, a fenda da pupila em pe
  for k, ex in ipairs({ 44, 60 }) do
    if (k + f) % 4 == 0 then L.rect(g, ex - 3, hy, ex + 3, hy + 1, 'n')
    else
      K.ell(g, ex, hy, 3.6, 4.2, 'P')
      L.rect(g, ex + 1, hy - 3, ex + 1, hy + 3, 'A')
    end
  end
  for k, b in ipairs(BERRIES) do
    local x, y = b[1] * s, (b[2] + bob) * s
    L.disc(g, x, y, 2.4, (k % 4 == f % 4) and 'Z' or 'B')
    L.set(g, x - 1, y - 1, 'Z')
  end
  local loose = { { 6, 30 }, { 90, 26 }, { 8, 66 }, { 90, 60 }, { 76, 14 }, { 20, 14 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S') end
  end
  return g, sg
end

K.build {
  name = 'thicketkin', size = 36, leg = LEG, emit = EMIT, keys = { 'd', 'e', 'f', 't', 'r', 'u' }, dark = 'd',
  pose = pose, portrait = portrait,
  idle = { { p = 0, bob = 0 }, { p = 1, bob = -1 }, { p = 2, bob = -1 }, { p = 3, bob = 0 } },
  alert = { p = 0, bob = -1, wide = true },
  alert2 = { { 3, 12 }, { 33, 11, 's' }, { 24, 3 } },
  alert3 = S.cat(S.plus(3, 10), S.plus(33, 9), { { 24, 2, 's' }, { 10, 3 }, { 2, 22 }, { 33, 23 } }),
  sq = 26,
  variants = {
    { key = 'urban', -- moita de terreno baldio, cinza; faixa rebitada no alto
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 11, 12, { 'WwWWwWWwWWwWWwW' } } } },
    { key = 'green', -- musgo; florzinha clara a esquerda
      legend = { L = '#F4F8D0', l = '#F2C84A' },
      put = { { 6, 17, { '.L.', 'LlL', '.L.' } } } },
    { key = 'water', -- petroleo escuro; gotas de orvalho no alto, a direita
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 25, 8, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- cerca-viva seca, clara; cachecol telha debaixo do oco
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 11, 26, { 'OOOOOOOOOOOOOo', '..........Oo..', '..........oo..' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; laco escuro no alto
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 16, 7, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas; aureola dourada sobre a copa
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 12, 3, { '.GGGGGGGGGG.', 'G..........G', '.gggggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim a esquerda do oco
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 9, 19, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
