-- Brookkin (rill.spirit), arte final: o Espírito da família Rill, a partir do conceito aprovado. O cururu tomado pela
-- sarjeta: a boca virou boca de lobo (verga e soleira de concreto, a quina com a tinta amarela gasta, uma trinca na
-- verga) e despeja água sem parar. O errado: três olhos em fila, três braços, e o espelho do dorso partiu em três poças.
-- Costuras do Véu: duas, mais largas que as do Eco (na coxa e no flanco), só no glow, longe das poças e da boca.
-- Camadas: corpo; leds = as nuvens da poça maior (piscam); glow = o céu das poças, a água que sai da boca, as
-- costuras e as gotas soltas.
-- Animação: a água corre (o fio desce um passo por quadro), os três olhos piscam em onda, um de cada vez, o céu anda
-- nas poças. O tronco sobe e os dedos ficam. No alerta a água engrossa; na antecipação agacha e fecha os olhos.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/brookkin/build.lua')
local Rl = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rill.lua')
local L, F = Rl.L, Rl.F
local SKIN, BELLY, CONC = Rl.SKIN, Rl.BELLY, Rl.CONC
local floor = math.floor

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or -1, oy or 0                                  -- no mapa, 1 px para a esquerda (a boca passa do corpo)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local all = o.jump and (o.dy or 0) or 0
  local P = F.pen(g, k, ox, oy + all)
  local b = math.min(1, ((o.dy or 0) - all) / k + (crouch and 0.8 or 0))
  P:limb({ { 29.6, 26 + b }, { 31.8, 29.6 }, { 31.4, 32.6 } }, 1.3, 0.9, 'h')
  P:ell(14.6, 21.6 + b, 10.4, 7.6, 'f', nil, -12)
  P:ell(11, 24 + b, 6.6, 5.6, 'f')
  P:ell(23.6, 17.4 + b, 7, 5.4, 'f', nil, -5)
  local EYES = { { 19.6, 12.2 }, { 24.4, 11.4 }, { 28.6, 12.8 } }
  for _, q in ipairs(EYES) do P:ell(q[1], q[2] + b, 2.1, 1.8, 'f') end
  P:ell(20, 26.6 + b * 0.5, 5.6, 3, 'x')
  -- a boca de lobo
  P:poly({ { 20.4, 17.6 + b }, { 33.4, 16.6 + b }, { 34, 19.6 + b }, { 20.4, 20.8 + b } }, 'y')
  P:poly({ { 21.4, 20.8 + b }, { 33.8, 19.6 + b }, { 33.6, 22.4 + b }, { 21.4, 23.2 + b } }, 'k')
  P:poly({ { 20.4, 23.2 + b }, { 34, 22.4 + b }, { 33.4, 25.8 + b }, { 21, 26.6 + b } }, 'y')
  P:limb({ { 21.6, 26 + b }, { 24.4, 30 }, { 23.8, 32.6 } }, 1.6, 1.1, 'h')
  P:limb({ { 25.6, 26 + b }, { 28.2, 29.8 }, { 27.6, 32.6 } }, 1.5, 1.0, 'h')
  P:ell(8.6, 26.8 + b * 0.5, 6.2, 4.2, 'h', nil, 24)
  P:limb({ { 4.4, 29.6 }, { 11.4, 32.2 } }, 1.6, 1.2, 'h')
  P:limb({ { 10, 33 }, { 17.6, 33 } }, 0.6, 0.55, 'h')
  Rl.toes(P, 23.6, 32.6, 3, 2.8, 'h'); Rl.toes(P, 27.6, 32.6, 3, 2.6, 'h')
  if k > 1 then Rl.toes(P, 31.2, 32.6, 3, 2.2, 'h'); Rl.toes(P, 15.6, 32.6, 3, 3.6, 'h') end
  Rl.skin(g, k, 'f', SKIN, { within = 'fxhyk' })
  Rl.skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', BELLY, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 3, within = 'x' })
  F.shade(g, 'y', CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0.2, zones = 2, within = 'y', jit = k > 1 and 2 or 1, jw = 3 })
  -- tinta amarela gasta na quina da soleira, trinca na verga
  for x = 21, 33.6, 1 / k do
    if F.rnd(floor(x * k), 2, 6) > 0.3 then P:px(x, 23.4 + b - (x - 21) * 0.062, floor(x) % 3 == 0 and 'p' or 'P') end
  end
  P:limb({ { 26.4, 16.8 + b }, { 27, 18.6 + b }, { 26.4, 20 + b } }, 0.3, 0.3, 'J', CONC)
  P:ell(14.4, 13.6 + b, 3.3, 1.5, 'e', SKIN, -12); P:ell(14.4, 14.1 + b, 3.1, 0.9, 'd', 'e', -12)
  -- costuras, mais largas que as do Eco
  local w = k > 1 and 2 or 1
  Rl.seam(P, { { 6, 25.6 + b * 0.5 }, { 9.4, 28.4 + b * 0.5 } }, w + (k > 1 and 0 or 1), 'X', SKIN .. 'h', k > 1 and 1.6 or nil)
  Rl.seam(P, { { 15.4, 21.4 + b }, { 18, 24 + b } }, w + (k > 1 and 0 or 1), 'X', SKIN, k > 1 and 1.6 or nil)
  -- poças no dorso
  Rl.mirror(g, P, 8.6, 18.4 + b, 4.6, 2.3, SKIN, { rot = -18, clouds = 4, sh = ph * 0.8 })
  Rl.mirror(g, P, 15.4, 15.9 + b, 3.2, 1.5, SKIN, { rot = -12, sh = ph * 0.8 })
  Rl.mirror(g, P, 5.4, 22.4 + b, 1.9, 1.1, SKIN, { rot = -30 })
  for n, q in ipairs(EYES) do Rl.eye(g, P, q[1] + 0.2, q[2] + 0.2 + b, 1.05, crouch or (not alert and ph == n)) end
  -- a água que sai da boca: dentro dela (corpo) e caindo (solta)
  local fat = alert and 1.4 or 1
  for s = 0, floor(9.6 * k) do
    local t = s / (9.6 * k)
    local x0 = P:X(30.4 + t * 1.6)
    for wd = 0, floor(2.2 * k * fat * (1 - t * 0.5)) do
      local ch = (wd == 0 or (s + ph) % 3 == 0) and 'E' or ((s + wd) % 2 == 0 and 'D' or 'B')
      L.set(g, x0 + wd, P:Y(21.4 + b) + s, ch, 'k')
    end
  end
  F.prune(g, '', 'brookkin')
  for s = 0, floor(10 * k) do
    local t = s / (10 * k)
    for wd = 0, floor(1.8 * k * fat * (1 - t * 0.4)) do
      local x, y = floor(P:X(31.6 + t * 1.2) + wd + 0.5), floor(P:Y(23.4 + b) + s + 0.5)
      if L.get(g, x, y) == '.' and y < g.h - 2 then L.set(sg, x, y, (wd == 0 or (s + ph) % 3 == 0) and 's' or ((s + wd) % 2 == 0 and 'S' or 'T')) end
    end
  end
  Rl.drops(P, sg, { { 3.4, 15.4 }, { 30.4, 34 }, { 34.2, 33.4 } }, ph, 4, true)
end

Rl.run {
  name = 'brookkin', stage = 'espirito', W = 36, PW = 96, draw = draw, ownLean = true, fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o mesmo desenho feito em 96 (escala 2,6)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o, 1, 3)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 11, 22 }, green = { 8, 26 }, water = { 12, 21 }, residential = { 11, 23 }, lit = { 10, 24 },
    sacred = { 20, 4 }, crimson = { 13, 22 },
  },
}
