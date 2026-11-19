-- Sootling (soot.eco), arte final: o Eco da família Soot, a partir do conceito aprovado. O saruê (gambá-de-orelha-
-- branca) de fuligem em proporção natural, de perfil. O errado é pouco: a ponta do rabo pelado queima como bituca e a
-- brasa aparece pelas falhas do pelo do peito.
-- Costuras do Véu: três, de 1 px (anca, lombo, barriga), só no glow; apagadas ficam quase na cor do pelo.
-- Camadas: corpo; leds = a bituca na ponta do rabo (pisca); glow = a brasa do peito, as costuras e as faíscas.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; na deriva ele anda; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/sootling/build.lua')
local S = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_soot.lua')
local L, F = S.L, S.F
local floor, cos, sin, rad = math.floor, math.cos, math.sin, math.rad

local function draw(g, sg, k, o)
  local P = F.pen(g, k, k > 1 and 2 or 0, 0)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local b = (o.dy or 0) / k                                  -- o tronco
  local f = o.jump and b or 0                                -- os pés (só saem do chão no salto da fuga)
  local m = (b + f) / 2
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0     -- o passo
  local sw = (alert or crouch) and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ty = alert and -0.8 or (crouch and 1.6 or 0)         -- o rabo sobe no alerta e baixa encolhido
  local hb = b + (crouch and 1 or 0)                         -- a cabeça baixa encolhido
  local tip = { 8.8 + sw, 10.2 + b + ty }
  P:limb({ { 6, 17 + b }, { 3.4, 14.5 + b + ty * 0.3 }, { 2.9 + sw * 0.3, 11 + b + ty * 0.6 }, { 3.8 + sw * 0.6, 7.6 + b + ty },
    { 6.2 + sw, 5.6 + b + ty }, { 8.8 + sw, 6.2 + b + ty }, { 9.8 + sw, 8.4 + b + ty }, tip }, 1.3, 0.85, 't')
  S.leg(P, 17, 20 + b, 16.6, 22.5 + m, 17.2, 24.6 + f, 1.1, 0.8, 'g', st)
  S.leg(P, 10.8, 20 + b, 11.8, 22.5 + m, 11.2, 24.6 + f, 1.3, 0.8, 'g', -st)
  if k == 1 then L.rect(g, 18, 21, 18, 23 + floor(f), 'g') end   -- no mapa o vão entre as patas da frente fecha
  P:ell(12.6, 17 + b, 7.4, 4.8, 'f')
  P:ell(8.4, 16.8 + b, 4.4, 4.9, 'f')
  P:ell(17.5, 16 + b, 3.6, 4.2, 'f')
  P:ell(21.3, 10.9 + hb, 1.3, 1.6, 'q')
  P:ell(20.3, 14.4 + hb, 3.2, 3.0, 'x')
  P:poly({ { 21, 12.2 + hb }, { 23.4, 13.6 + hb }, { 24.8, 15.8 + hb }, { 24.6, 16.9 + hb }, { 23, 17.6 + hb }, { 20, 17.4 + hb } }, 'x')
  if alert and k > 1 then P:limb({ { 21.2, 18.3 + hb }, { 24, 18.9 + hb } }, 0.5, 0.35, 'x') end   -- a queixada aberta
  P:ell(18.2, 13 + hb, 2.7, 2.4, 'f')
  P:ell(18.9, 10.6 + hb, 1.8, 2.0, 'q')
  P:ell(19.1, 10.9 + hb, 0.9, 1.1, 'p')
  P:ell(8.4, 19.8 + b, 2.8, 2.9, 'f')
  S.leg(P, 7.8, 21.5 + b, 6.8, 23.2 + m, 7.6, 24.6 + f, 1.4, 0.9, 'f', st)
  S.leg(P, 19.2, 19 + b, 19.7, 22.2 + m, 19.3, 24.6 + f, 1.2, 0.85, 'f', -st)
  S.paw(P, k, 17.2 + st, 25 + f, 'q'); S.paw(P, k, 11.2 - st, 25 + f, 'q')
  S.paw(P, k, 7.6 + st, 25 + f, 'p'); S.paw(P, k, 19.3 - st, 25 + f, 'p')
  S.furShade(g, k, 'f', k > 1 and S.FUR or 'dcba', { zones = k > 1 and 3 or 2, bias = k > 1 and 0 or 0.1 })
  S.furShade(g, k, 'g', 'ba', { zones = 1 })
  S.faceShade(g, k)
  S.skinShade(g, k)
  P:ell(22.4, 14.4 + hb, 1.2, 0.9, 'v', S.FACE)
  P:limb({ { 22.6, 17.2 + hb }, { 24.2, 17 + hb } }, 0.3, 0.3, 'K', S.FACE)
  if k > 1 then
    P:disc(22.5, 14.5 + hb, 0.75, 'k')
    L.set(g, P:X(22.4) - 1, P:Y(14.4 + hb) - 1, 'W')
    P:ell(24.8, 16.2 + hb, 0.8, 0.7, 'P'); L.set(g, P:X(24.7), P:Y(16 + hb), 'V')
    if alert then                                             -- a boca aberta mostra a brasa na garganta
      P:poly({ { 21.4, 17.2 + hb }, { 24.6, 16.9 + hb }, { 24.2, 18.5 + hb }, { 21.4, 18 + hb } }, 'k', S.FACE .. 'K')
      P:disc(22.2, 17.7 + hb, 0.45, 'E', 'k')
      for u = 22.8, 24.4, 0.7 do P:px(u, 17.05 + hb, 'V') end
    end
  else
    local hr = floor(hb + 0.5)
    for _, q in ipairs({ { 21, 13, 'W' }, { 22, 13, 'V' }, { 23, 14, 'V' }, { 21, 14, 'w' }, { 22, 14, 'k' }, { 24, 15, 'V' },
      { 23, 15, 'W' }, { 25, 16, 'P' } }) do
      g[q[2] + hr][q[1]] = q[3]
    end
    if alert then
      for _, q in ipairs({ { 22, 17, 'E' }, { 23, 17, 'k' }, { 24, 17, 'k' }, { 22, 18, 'w' }, { 23, 18, 'W' }, { 24, 18, 'w' } }) do
        g[q[2] + hr][q[1]] = q[3]
      end
    end
  end
  S.buttTip(P, k, tip[1], tip[2], -0.5, 0.86, ph == 2)
  S.ember(g, P:X(20), P:Y(19.4 + b), (k > 1 and 3.3 or 3.2) * k, 11, S.FUR .. (k > 1 and S.FACE or ''), k > 1 and 11 or 6,
    ({ [0] = 0, 0.5, 1, 0.5 })[ph])
  -- costuras do Véu: três, finas
  for _, q in ipairs({ { 5.6, 14.6, 7.4, 18.6 }, { 11.4, 12.8, 13.2, 16.2 }, { 13.6, 18.2, 14.8, 21.2 } }) do
    S.seam(P, { { q[1], q[2] + b }, { q[3], q[4] + b } }, 1, 'X', S.FUR, k > 1 and 1.3 or nil)
  end
  if k > 1 then
    for _, a in ipairs({ -20, 5, 30 }) do                     -- bigodes
      local x0, y0 = P:X(24), P:Y(16.4 + hb)
      L.line(g, x0, y0, x0 + cos(rad(a)) * 9, y0 + sin(rad(a)) * 9, 'l', '.')
    end
  end
  for n, q in ipairs({ { 23.8, 21, 'S' }, { 22.2, 23, 's' }, { 11, 8.6, 'T' }, { 12.4, 5.6, 's' } }) do
    local r = (ph + n) % 4                                    -- as faíscas sobem e somem
    if r < 3 then S.spark(P, sg, q[1] + (n > 2 and sw or 0), q[2] + b - r * 0.9, q[3]) end
  end
end

S.run {
  name = 'sootling', stage = 'eco', W = 28, PW = 96, draw = draw, ownDy = true, ownLean = true,
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho do mapa ampliado 3,3 vezes, com detalhe (bigodes, dedos, pontos nas costuras)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 9, 14 }, green = { 7, 11 }, water = { 9, 15 }, residential = { 12, 12 }, lit = { 12, 16 },
    sacred = { 17, 7 }, crimson = { 5, 15 },
  },
}
