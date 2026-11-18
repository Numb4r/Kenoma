-- Rootseer (frond.ritual), 0.25.1: um no de raizes com um olho so, coroado de brotos, de pe em quatro raizes.
-- Rodar: aseprite -b --script build.lua
-- corpo: o no de raiz, as pernas, os brotos, o branco do olho. leds: a iris. glow: a seiva nas raizes e os esporos.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  t = '#3E3026', r = '#5A4636', u = '#8A6A4A',   -- raiz
  d = '#2F6B45', e = '#4C9A5A', f = '#86D37C',   -- broto
  x = '#F0EEF8',                                 -- olho
  n = '#3E6A58', P = '#9AF0C0', Q = '#E0FFF0',   -- iris apagada (corpo) e acesa (leds)
  v = '#4A5A3A', V = '#A8F090', U = '#E8FFC0',   -- seiva apagada (corpo) e acesa (glow)
  S = '#B8F28A', s = '#F0FFC8',
}
local EMIT = { P = { 'n', 'l' }, Q = { 'n', 'l' }, V = { 'v', 'w' }, U = { 'v', 'w' } }
local LEGS = { { 9, 18, 5.5, 22, 3.8, 24 }, { 12, 20, 11, 23, 9.8, 24.4 }, { 16, 20, 17.5, 23, 18.6, 24.4 }, { 19, 18, 22.5, 22, 24.2, 24 } }

-- Em unidades de 28 px vezes [s]. p: 0 a 3, as raizes trocam o passo e os brotos balancam. bob: o no sobe.
local function seer(g, s, p, bob, glow, nh, nl)
  local sw = ({ 0, 0.5, 0, -0.5 })[p + 1]
  local mids = {}
  for k, r in ipairs(LEGS) do
    local sx = (k % 2 == 0) and sw or -sw
    local pts = { { r[1] * s, (r[2] + bob) * s }, { r[3] * s, r[4] * s }, { (r[5] + sx) * s, r[6] * s } }
    K.stroke(g, pts, 1.9 * s, 0.6 * s, 'r')
    mids[k] = pts
  end
  K.ell(g, 14 * s, (14 + bob) * s, 7 * s, 7 * s, 'r')
  for _, b in ipairs({ { 8.5, 10 }, { 20, 11.5 }, { 8, 17 }, { 19.5, 18 } }) do L.disc(g, b[1] * s, (b[2] + bob) * s, 1.5 * s, 'r') end
  for _, c in ipairs({ { 11, 8, 8, 5.2 }, { 14, 7.5, 14.5, 4.6 }, { 17, 8, 20.5, 5.6 } }) do
    K.stroke(g, { { c[1] * s, (c[2] + bob) * s }, { (c[3] + sw) * s, (c[4] + bob) * s } }, 1.3 * s, 0.5 * s, 'e')
  end
  K.relight(g, { 'tru', 'def' }, nh, nl)
  -- seiva: sobe pelas pernas conforme o brilho cresce
  for k, pts in ipairs(mids) do
    if glow >= 2 or k % 2 == 0 then
      local c = glow == 3 and 'U' or 'V'
      L.line(g, pts[3][1], pts[3][2] - s * 0.3, pts[2][1], pts[2][2], c)
      if glow >= 2 then L.line(g, pts[2][1], pts[2][2], (pts[1][1] + pts[2][1]) / 2, (pts[1][2] + pts[2][2]) / 2, 'V') end
    end
  end
  return mids
end

-- Mapa em 36 px: o no e as raizes saem da mesma curva; os veios da casca e o olho sao postos a mao.
local function pose(o)
  local g = L.grid(36, 36)
  local bob = o.bob or 0
  seer(g, 36 / 28, o.p or 0, bob / (36 / 28), o.glow or 1, 2, 3)
  for k = 0, 3 do
    for a = k * 90 + 30, k * 90 + 70, 6 do
      local r = math.rad(a)
      K.put(g, math.floor(18 + 7.4 * math.cos(r) + 0.5), math.floor(18 + bob + 7.4 * math.sin(r) + 0.5), { 't' }, 'r')
    end
  end
  K.ell(g, 18.5, 18 + bob, 5.6, 3.4, 't')
  if o.wide then
    L.put(g, 14, 15 + bob, { '..xxxxxx.', '.xxxxxxxx', 'xxxxPPPxx', 'xxxPQAQPx', 'xxxxPPPxx', '.xxxxxxxx', '..xxxxxx.' })
  else
    L.put(g, 14, 16 + bob, { '..xxxxxx.', 'xxxxPPPxx', 'xxxPPAPPx', 'xxxxPPPxx', '..xxxxxx.' })
  end
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local s = 92 / 28
  local bob = ({ 0, -0.3, -0.6, -0.3 })[f]
  local body = L.grid(96, 96)
  seer(body, s, f - 1, bob, f == 3 and 3 or 2, 4, 6)
  -- casca: veios escuros em arco em volta do olho
  for k = 0, 5 do
    local a0 = k * 60 + 20
    for a = a0, a0 + 34 do
      local rr = math.rad(a)
      K.put(body, math.floor(14 * s + 19.5 * math.cos(rr) + 0.5), math.floor((14 + bob) * s + 19.5 * math.sin(rr) + 0.5), { 't' }, 'r')
    end
  end
  -- o olho: palpebra de casca, branco, iris que varre, pupila em fenda
  local ex, ey = 14.6 * s, (14 + bob) * s
  K.ell(body, ex, ey, 14, 10.5, 't')
  K.ell(body, ex, ey, 12.5, 9, 'x')
  local ix = ex + ({ 1, 2, 3, 2 })[f]
  L.disc(body, ix, ey, 6.5, 'P')
  L.disc(body, ix, ey, 4.2, 'Q')
  L.ring(body, ix, ey, 6.5, 'P')
  K.ell(body, ix, ey, 1.6, 5, 'A')
  L.rect(body, ix - 4, ey - 4, ix - 3, ey - 3, 'x')
  K.stamp(g, body, 2, 1)
  local loose = { { 8, 30 }, { 88, 28 }, { 10, 64 }, { 86, 58 }, { 70, 12 }, { 24, 14 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.rect(sg, pt[1], y, pt[1] + 1, y + 1, (f + k) % 2 == 0 and 's' or 'S') end
  end
  return g, sg
end

K.build {
  name = 'rootseer', size = 36, leg = LEG, emit = EMIT, keys = { 't', 'r', 'u', 'd', 'e', 'f' }, dark = 't',
  pose = pose, portrait = portrait,
  idle = { { p = 0, bob = 0 }, { p = 1, bob = -1 }, { p = 2, bob = -1 }, { p = 3, bob = 0 } },
  alert = { p = 0, bob = -1, wide = true },
  alert2 = { { 4, 14 }, { 32, 13, 's' }, { 24, 4 } },
  alert3 = S.cat(S.plus(4, 12), S.plus(32, 11), { { 24, 3, 's' }, { 10, 4 }, { 3, 23 }, { 33, 24 } }),
  sq = 27,
  variants = {
    { key = 'urban', -- raiz de calcada, cinza; faixa rebitada na testa
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 13, 12, { 'WwWWwWWwWWw' } } } },
    { key = 'green', -- raiz coberta de musgo; florzinha clara a esquerda do olho
      legend = { L = '#F4F8D0', l = '#F2C84A' },
      put = { { 10, 17, { '.L.', 'LlL', '.L.' } } } },
    { key = 'water', -- raiz encharcada, escura; gotas de orvalho no alto, a esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 11, 13, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- raiz de quintal, clara; cachecol telha debaixo do olho
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 12, 24, { 'OOOOOOOOOOOOo', '..Oo.........', '..oo.........' } } } },
    { key = 'lit', -- creme de vitrine, a mais clara; gravata-borboleta escura debaixo do olho
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 16, 21, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas; aureola dourada em volta dos brotos
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 12, 6, { '.GGGGGGGGGG.', 'G..........G', '.gggggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim a direita do olho
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 23, 16, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
