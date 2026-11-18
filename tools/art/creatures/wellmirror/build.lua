-- Wellmirror (rill.ritual), 0.25.1: um aro de agua que paira, com a noite de lua cheia espelhada dentro.
-- Rodar: aseprite -b --script build.lua
-- corpo: o aro, o espelho escuro, os olhos, o fio que pinga. leds: as estrelas no espelho.
-- glow: a lua cheia (e o halo dela e a borda do espelho, quando o brilho cresce) e os pingos.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  h = '#2D5AA0', i = '#4A86D6', j = '#9FD0F5',   -- agua do aro
  k = '#141C40',                                 -- o espelho (igual em toda variante)
  x = '#F0EEF8',                                 -- olho
  g = '#4A5488', W = '#FFFFFF',                  -- estrela apagada (corpo) e acesa (leds)
  m = '#565C84', M = '#FFF3C8', R = '#D8C890',   -- lua apagada (corpo), acesa e cratera (glow)
  o = '#232C5C', N = '#8C96D8',                  -- halo apagado (corpo) e aceso (glow)
  c = '#2F6E9A', C = '#7FE0F0',                  -- borda do espelho apagada (corpo) e acesa (glow)
  S = '#9FD0F5', s = '#E8F8FF',
}
local EMIT = { W = { 'g', 'l' }, M = { 'm', 'w' }, R = { 'm', 'w' }, N = { 'o', 'w' }, C = { 'c', 'w' } }

-- Em unidades de 28 px vezes [s]. p: 0 a 3, o fio balanca.
local function mirror(g, s, p, glow, nh, nl)
  local cx, cy = 13.5 * s, 13.5 * s
  local sway = ({ 0, 0.7, 0, -0.7 })[p + 1]
  K.stroke(g, { { cx, 21 * s }, { cx + sway * s * 0.5, 23 * s }, { cx + sway * s, 24.4 * s } }, 2 * s, 0.5 * s, 'i')
  L.disc(g, cx, cy, 9 * s, 'i')
  K.relight(g, { 'hij' }, nh, nl)
  L.disc(g, cx, cy, 6.6 * s, 'k')
  if glow >= 3 then L.ring(g, cx, cy, 6.6 * s, 'C') end
  local mx, my = 15.5 * s, 11 * s
  if glow >= 2 then L.disc(g, mx, my, 3.4 * s, 'N', 'k') end
  L.disc(g, mx, my, 2.3 * s, 'M')
  return cx, cy, mx, my
end

-- Mapa em 36 px: o aro sai da mesma curva, e a lua, os olhos, as estrelas e o rastro da lua sao postos a mao.
local function pose(o)
  local g = L.grid(36, 36)
  local glow = o.glow or 1
  mirror(g, 36 / 28, o.p or 0, glow, 2, 3)
  g[13][19] = 'R'; g[15][21] = 'R'; g[15][20] = 'R'
  L.put(g, 12, 19, { 'xxx....xxx', 'xxA....xxA', 'xxx....xxx' })
  for _, st in ipairs({ { 13, 11 }, { 12, 16 }, { 24, 19 }, { 17, 24 }, { 16, 12 }, { 22, 23 } }) do g[st[2]][st[1]] = 'W' end
  -- o rastro da lua na agua do espelho, que muda com a fase
  local w = (o.p or 0) % 2
  L.put(g, 17 + w, 22, { 'NNNN' }); L.put(g, 18 - w, 24, { 'NN' })
  -- reflexo claro no aro
  g[9][9] = 'j'; g[8][10] = 'j'; g[7][11] = 'j'
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local s = 92 / 28
  local body = L.grid(96, 96)
  local cx, cy, mx, my = mirror(body, s, f - 1, f == 3 and 3 or 2, 4, 6)
  -- crateras e o reflexo da lua na agua do espelho
  L.disc(body, mx - 2, my - 2, 1.6, 'R'); L.disc(body, mx + 3, my + 2, 1.2, 'R'); L.set(body, mx - 3, my + 3, 'R')
  for k = 0, 3 do
    local y = my + 13 + k * 3
    local w = 5 - k + ((k + f) % 2)
    L.rect(body, mx - w, y, mx + w, y, 'N', 'k')
  end
  for _, ex in ipairs({ cx - 9, cx + 6 }) do
    K.ell(body, ex, cy + 9, 4.6, 5.2, 'x')
    L.disc(body, ex + 1.5, cy + 10, 2.2, 'A')
    L.set(body, ex, cy + 8, 'x')
  end
  local stars = { { -15, -8 }, { -8, -15 }, { 16, 3 }, { -17, 4 }, { 3, 18 }, { -4, -3 } }
  for k, st in ipairs(stars) do
    local x, y = math.floor(cx + st[1]), math.floor(cy + st[2])
    if (k + f) % 3 == 0 then L.put(body, x - 1, y - 1, { '.W.', 'WWW', '.W.' }) else L.set(body, x, y, 'W') end
  end
  -- reflexo claro no aro
  K.stroke(body, { { cx - 23, cy - 12 }, { cx - 17, cy - 21 } }, 1.4, 0.6, 'j')
  K.stamp(g, body, 2, ({ 0, -1, -2, -1 })[f])
  local loose = { { 10, 30 }, { 86, 26 }, { 12, 66 }, { 84, 60 }, { 48, 90 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 3
    if (f + k) % 4 ~= 3 then L.put(sg, pt[1], math.max(2, y), { 'SS', 'sS' }) end
  end
  return g, sg
end

K.build {
  name = 'wellmirror', size = 36, leg = LEG, emit = EMIT, keys = { 'h', 'i', 'j' }, dark = 'h',
  pose = pose, portrait = portrait,
  idle = { { p = 0, dy = 0 }, { p = 1, dy = -1 }, { p = 2, dy = -1 }, { p = 3, dy = 0 } },
  alert = { p = 0 },
  alert2 = { { 3, 12 }, { 32, 13, 's' }, { 27, 4 } },
  alert3 = S.cat(S.plus(3, 10), S.plus(32, 11), { { 27, 3, 's' }, { 8, 4 }, { 3, 24 }, { 32, 25 } }),
  sq = 28,
  variants = {
    { key = 'urban', -- agua de sarjeta, cinza; rebites na parte de baixo do aro
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 12, 27, { 'WwWWwWWwWWw' } } } },
    { key = 'green', -- agua de lago, verde fundo; broto no alto, a direita
      grad = { '#22402A', '#467448', '#B4DCA0' },
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 24, 4, { '.LL', 'lL.', 'd..', 'd..' } } } },
    { key = 'water', -- fundo de rio, a mais escura das azuis; contas claras no aro, a esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 7, 14, { 'U', 'u', 'U', 'u', 'U', 'u', 'U' } } } },
    { key = 'residential', -- agua de barro, clara; fita telha amarrada no fio
      legend = { O = '#A03C2C', o = '#6E261E' }, outline = true,
      put = { { 13, 29, { 'OO.OOO.Oo', 'O.......o' } } } },
    { key = 'lit', -- leitosa, a mais clara; laco escuro no aro, a direita
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 26, 16, { 'N.N', 'NMN', 'N.N' } } } },
    { key = 'sacred', -- lilas; aureola dourada sobre o alto do aro
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 12, 4, { '.GGGGGGGGGG.', 'G..........G', '.gggggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim no espelho, a esquerda
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 10, 15, { '.RR', 'Rr.', 'R..', 'Rr.', '.RR' } } } },
  },
}
