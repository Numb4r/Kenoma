-- Brookkin (rill.spirit), 0.25.1: um fio de corrego em pe, ondulando sobre a propria poca, com um anel achado
-- dentro. Rodar: aseprite -b --script build.lua
-- corpo: agua, olhos, o anel. leds: os reflexos (na cabeca e no anel). glow: a correnteza no meio do fio e os pingos.
-- O fio e desenhado por curva (a onda anda de quadro em quadro); olhos, anel e reflexos sao postos a mao.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/sootling/_kit.lua')
local L = K.L
local S = K.S(36)

local LEG = {
  A = '#1A1424',
  h = '#2D5AA0', i = '#4A86D6', j = '#9FD0F5',   -- agua
  x = '#F0EEF8',                                 -- olho
  G = '#E8C860', n = '#A88838',                  -- o anel que ele carrega
  g = '#7FB4E0', W = '#FFFFFF',                  -- reflexo apagado (corpo) e aceso (leds)
  c = '#2F6E9A', C = '#7FE0F0', D = '#D8FFFF',   -- correnteza apagada (corpo) e acesa (glow)
  S = '#9FD0F5', s = '#E8F8FF',
}
local EMIT = { W = { 'g', 'l' }, C = { 'c', 'w' }, D = { 'c', 'w' } }

-- O fio: da cabeca (em cima) a poca (embaixo), em unidades de 36 px vezes [s]. Devolve os pontos do eixo.
local function ribbon(g, s, ph, bob, amp)
  local pts = {}
  for k = 0, 14 do
    local t = k / 14
    local env = math.sin(t * math.pi) ^ 0.8
    pts[k + 1] = { (18 + math.sin(t * math.pi * 2.3 + ph) * amp * env) * s, (11 + t * 19) * s + bob * (1 - t) }
  end
  K.ell(g, 18 * s, 30.3 * s, 9.5 * s, 2.2 * s, 'i')
  K.stroke(g, pts, 4.2 * s, 2 * s, 'i')
  local hx, hy = 18 * s, 11 * s + bob
  L.disc(g, hx, hy, 5.6 * s, 'i')
  K.stroke(g, { { hx - 1.5 * s, hy - 4 * s }, { hx - 3.5 * s, hy - 6 * s }, { hx - 4.5 * s, hy - 7.2 * s } }, 1.8 * s, 0.4 * s, 'i')
  return pts, hx, hy
end

-- p: 0 a 3, a fase da onda. bob: quanto a cabeca sobe. glow: 1 a 3.
local function pose(o)
  local g = L.grid(36, 36)
  local p, bob = o.p or 0, o.bob or 0
  local pts = ribbon(g, 1, p * math.pi / 2, bob, o.wide and 7.5 or 6)
  K.relight(g, { 'hij' }, 1, 2)
  L.put(g, 15, 9 + bob, { 'xxx.xxx', 'xxA.xxA', 'xxx.xxx' })
  local glow = o.glow or 1
  for k = 3, 13 do
    local on = glow == 3 or (glow == 2 and (k + p) % 3 ~= 1) or (k + p) % 3 == 0
    if on then L.set(g, pts[k][1], pts[k][2], glow == 3 and k % 2 == 0 and 'D' or 'C') end
  end
  local r = pts[8]
  L.put(g, math.floor(r[1] + 0.5) - 1, math.floor(r[2] + 0.5) - 1, { 'WGG', 'G_G', 'nGn' })
  g[7 + bob][15] = 'W'; g[8 + bob][14] = 'W'
  return g
end

local function portrait(f)
  local g, sg = L.grid(96, 96), L.grid(96, 96)
  local s = 96 / 36
  local bob = ({ 0, -1, -2, -1 })[f]
  local pts, hx, hy = ribbon(g, s, (f - 1) * math.pi / 2, bob, 6)
  K.relight(g, { 'hij' }, 4, 6)
  for _, ex in ipairs({ hx - 4, hx + 9 }) do
    K.ell(g, ex, hy, 6.2, 7.2, 'h')
    K.ell(g, ex, hy, 5.2, 6.2, 'x')
    L.disc(g, ex + 2, hy + 1, 2.8, 'A')
    L.rect(g, ex, hy - 2, ex + 1, hy - 1, 'x')
  end
  -- correnteza: riscos no meio do fio que descem a cada quadro
  for k = 2, 14 do
    for u = 0, 5 do
      local t = u / 6
      local x, y = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * t, pts[k][2] + (pts[k + 1][2] - pts[k][2]) * t
      local m = (k * 6 + u - f * 3) % 12
      if m < 6 then L.set(g, x, y, m < 2 and 'D' or 'C'); if m < 4 then L.set(g, x + 1, y, 'C') end end
    end
  end
  -- o anel, no meio do fio
  local r = pts[8]
  local rx, ry = math.floor(r[1] + 0.5), math.floor(r[2] + 0.5)
  L.ring(g, rx, ry, 5.4, 'G'); L.ring(g, rx, ry, 4.4, 'G')
  for y = ry + 1, ry + 6 do for x = rx - 6, rx + 6 do
    if L.get(g, x, y) == 'G' and (x - rx) + (y - ry) > 3 then g[y][x] = 'n' end
  end end
  if f % 2 == 1 then L.put(g, rx - 5, ry - 5, { '.W.', 'WWW', '.W.' }) else L.set(g, rx - 4, ry - 4, 'W') end
  -- reflexos na cabeca e na crista
  local on = function(k) return (k + f) % 4 ~= 0 end
  K.stroke(g, { { hx - 11, hy - 3 }, { hx - 8, hy - 9 } }, on(1) and 1.5 or 0.8, 0.5, 'W')
  if on(2) then L.rect(g, hx - 10, hy - 17, hx - 9, hy - 15, 'W') end
  if on(3) then L.rect(g, 30, 80, 33, 80, 'W') end
  -- pingos soltos: sobem, porque ele corre para cima se quiser
  local loose = { { 12, 50 }, { 84, 40 }, { 76, 14 }, { 16, 22 }, { 86, 70 }, { 10, 76 } }
  for k, pt in ipairs(loose) do
    local y = pt[2] - ((f + k) % 4) * 4
    if (f + k) % 4 ~= 3 then L.put(sg, pt[1], y, { 'SS', 'SS', 's.' }) end
  end
  return g, sg
end

K.build {
  name = 'brookkin', size = 36, leg = LEG, emit = EMIT, keys = { 'h', 'i', 'j' }, dark = 'h',
  pose = pose, portrait = portrait,
  idle = { { p = 0, bob = 0 }, { p = 1, bob = -1 }, { p = 2, bob = -1 }, { p = 3, bob = 0 } },
  alert = { p = 0, bob = -1, wide = true },
  alert2 = { { 5, 14 }, { 31, 12, 's' }, { 26, 4 } },
  alert3 = S.cat(S.plus(5, 12), S.plus(31, 10), { { 26, 3, 's' }, { 8, 5 }, { 4, 22 }, { 32, 24 } }),
  sq = 24,
  variants = {
    { key = 'urban', -- agua de sarjeta, cinza; faixa rebitada na testa
      legend = { W = '#B6BAC4', w = '#8E92A0' },
      put = { { 15, 7, { 'WwWWwWW' } } } },
    { key = 'green', -- agua de lago, verde fundo (mais escura que a base, para nao se confundir com ela em cinza)
      grad = { '#22402A', '#467448', '#B4DCA0' },
      legend = { L = '#B4E08A', l = '#5FB26A', d = '#2F7446' }, outline = true,
      put = { { 19, 3, { '.LL', 'lL.', 'd..' } } } },
    { key = 'water', -- fundo de rio, a mais escura das azuis; contas claras na bochecha esquerda
      legend = { U = '#E8F8FF', u = '#9FD4F0' },
      put = { { 13, 11, { 'U.', 'Uu', '.u' } } } },
    { key = 'residential', -- agua de barro, clara; cachecol telha no pescoco
      legend = { O = '#A03C2C', o = '#6E261E' },
      put = { { 14, 16, { 'OOOOOOOOo', 'Oo.......', 'oo.......' } } } },
    { key = 'lit', -- leitosa, a mais clara; gravata-borboleta escura no peito
      legend = { N = '#2B2F3D', M = '#40465A' },
      put = { { 16, 18, { 'NN.NN', 'NNMNN', 'NN.NN' } } } },
    { key = 'sacred', -- lilas; aureola dourada em volta da crista
      legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
      put = { { 9, 4, { '.GGGGGGGG.', 'G........G', '.gggggggg.' } } } },
    { key = 'crimson', -- vinho; crescente da Lua Carmim debaixo do olho direito
      legend = { R = '#FF5A6A', r = '#C03048' },
      put = { { 20, 12, { '.RR', 'Rr.', '.RR' } } } },
  },
}
