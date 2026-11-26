-- Rillet (rill.eco), arte final: o Eco da família Rill, a partir do conceito aprovado. O sapo-cururu sentado, de
-- perfil, em proporção natural: pele de verruga cor de barro, glândula atrás do olho, íris ocre com a pupila deitada,
-- barriga creme. O errado é pouco: o dorso é um espelho d'água que reflete um céu com nuvem, e do queixo pinga.
-- Costuras do Véu: três, curtas e de 1 px (coxa, flanco, alto da cabeça), só no glow, longe do espelho.
-- Camadas: corpo; leds = as nuvens do espelho (piscam); glow = o céu do espelho, as costuras e as gotas soltas.
-- Animação: o papo enche e esvazia (respira), o céu corre no espelho, a gota do queixo cai. O tronco sobe e os
-- dedos ficam; na fuga ele salta. No alerta o papo enche e o espelho acende; na antecipação agacha.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rillet/build.lua')
local Rl = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rill.lua')
local L, F = Rl.L, Rl.F
local SKIN, BELLY = Rl.SKIN, Rl.BELLY

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local all = o.jump and (o.dy or 0) or 0
  local P = F.pen(g, k, ox, oy + all)
  local b = math.min(1, ((o.dy or 0) - all) / k + (crouch and 0.8 or 0))   -- o tronco
  local puff = alert and 1 or (crouch and -0.3 or ({ [0] = 0, 0.4, 0.7, 0.3 })[ph])
  P:limb({ { 21.6, 19 + b }, { 23.4, 22.4 }, { 23, 24.6 } }, 1.1, 0.8, 'h')        -- braço de trás
  P:ell(11.4, 18.4 + b, 8.3, 5.3, 'f', nil, -20)
  P:ell(8.6, 20.2 + b, 5.2, 4.2, 'f')
  P:ell(19.2, 13.4 + b, 5.2, 3.7, 'f', nil, -10)
  P:ell(22.8, 14.2 + b, 2.9, 2.4, 'f')
  P:ell(20.2, 10.6 + b, 2.0, 1.7, 'f')                                            -- calombo do olho
  P:ell(19.4 + puff * 0.3, 17.2 + b, 3.4 + puff * 0.7, 2.2 + puff * 0.5, 'x')     -- o papo
  P:ell(15.2, 21.6 + b * 0.5, 4.6, 2.4, 'x')
  P:limb({ { 17.6, 19.4 + b }, { 19.8, 22.6 }, { 19.4, 24.6 } }, 1.75, 1.3, 'a')
  P:limb({ { 18.2, 19.6 + b }, { 20.2, 22.6 }, { 19.6, 24.6 } }, 1.4, 0.95, 'h')
  P:ell(7.4, 20.6 + b * 0.5, 5.2, 3.8, 'a', nil, 24)
  P:ell(7.4, 21 + b * 0.5, 4.7, 3.3, 'h', nil, 24)
  P:limb({ { 4.2, 23 }, { 9.6, 24.5 } }, 1.3, 1.0, 'h')
  P:limb({ { 8.6, 25 }, { 14.2, 25 } }, 0.55, 0.5, 'h')
  Rl.toes(P, 19.4, 24.6, 3, 2.6, 'h')
  if k > 1 then Rl.toes(P, 22.8, 24.6, 3, 2.2, 'h'); Rl.toes(P, 12.6, 24.6, 3, 3.6, 'h') end
  Rl.skin(g, k, 'f', SKIN, { within = 'fxh' })
  Rl.skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', BELLY, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 3, within = 'x', jit = k > 1 and 2 or 0 })
  -- glândula atrás do olho
  P:ell(15.4, 11.9 + b, 2.7, 1.3, 'e', SKIN, -14)
  P:ell(15.4, 12.3 + b, 2.5, 0.8, 'd', 'e', -14)
  -- costuras, antes do espelho (ele passa por cima)
  for _, q in ipairs({ { 5.6, 20.6, 7.4, 22.4 }, { 14.6, 19.2, 16.4, 20.4 }, { 21.4, 12.4, 22.8, 13.4 } }) do
    Rl.seam(P, { { q[1], q[2] + b * 0.5 }, { q[3], q[4] + b * 0.5 } }, 1, 'X', SKIN .. 'h', k > 1 and 1.4 or nil)
  end
  -- espelho no dorso: o céu corre
  Rl.mirror(g, P, 9.4, 15.6 + b, 4.9, 2.1, SKIN .. 'X', { rot = -20, clouds = 4, sh = ph * 0.8 })
  -- boca, narina, olho
  P:limb({ { 17.6, 15.6 + b }, { 22, 15.5 + b }, { 25.2, 14.6 + b } }, 0.3, 0.3, 'a', SKIN .. BELLY)
  P:px(24.8, 12.8 + b, 'a')
  Rl.eye(g, P, 20.4, 10.8 + b, 1)
  F.prune(g, '', 'rillet')
  Rl.drops(P, sg, k > 1 and { { 24.4, 19.4 }, { 23.6, 21 }, { 24.8, 17.4 } } or { { 24.4, 19.4 } }, ph, 4, false)
  if k > 1 then Rl.drops(P, sg, { { 5, 13 }, { 3.6, 11 } }, ph, 4, true) else Rl.drops(P, sg, { { 3.6, 12 } }, ph, 4, true) end
end

Rl.run {
  name = 'rillet', stage = 'eco', W = 28, PW = 96, draw = draw, ownLean = true,
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o mesmo desenho feito em 96 (escala 3,3)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o, 2, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 11, 19 }, green = { 8, 21 }, water = { 12, 18 }, residential = { 11, 20 }, lit = { 10, 21 },
    sacred = { 15, 6 }, crimson = { 13, 19 },
  },
}
