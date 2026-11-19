-- Kilnshade (soot.ritual), arte final: o saruê de ritual da família Soot, ligado a Ialprg (chamas ardentes).
-- Na linguagem das peças finais do Soot (_soot.lua): fuligem, cara branca suja, pele nua, ferro fundido; só a brasa
-- tem cor, e a luz é a do tipo Fogo.
-- O QUE ELE TEM DE PRÓPRIO (e o Cinderkin não): está sentado, em pé sobre as ancas, parado como um ídolo, de olho
-- fechado. O tronco é uma boca de fornalha: um arco de ferro fundido, e por dentro ele é só o fogo, com as brasas
-- no chão do forno. O rabo sobe reto atrás dele como chaminé, com a bituca acesa no alto e a fumaça. As duas mãos
-- (as que parecem de gente) ficam juntas na frente do fogo.
-- Costuras do Véu: duas, de 2 px (no lombo, atrás do forno, e na nuca), só no glow.
-- Camadas: corpo; leds = as brasas no chão do forno e a bituca (piscam); glow = o fogo, a garganta no alerta, as
-- costuras e as faíscas.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; na deriva ele verga para a frente e arrasta os
-- pés; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/kilnshade/build.lua')
local S = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_soot.lua')
local L, F = S.L, S.F
local floor, abs, sin, sqrt = math.floor, math.abs, math.sin, math.sqrt

local function draw(g, sg, k, o)
  local off = k > 1 and 1 or 0
  local P = F.pen(g, k, off, off)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local b = (o.dy or 0) / k + (crouch and 0.6 or 0)          -- o tronco
  local f = o.jump and (o.dy or 0) / k or 0                  -- os pés
  local m = (b + f) / 2
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0     -- o passo
  local lx = o.lean and 1 or 0                               -- na deriva o tronco verga para a frente
  local sw = (alert or crouch) and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ty = alert and -1 or (crouch and 1.5 or 0)
  local hb = b + (alert and -0.8 or (crouch and 1 or 0))     -- a cabeça
  local grow = alert and 1 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  -- o rabo: a chaminé
  local tip = { 5.6 + sw * 0.7 + lx * 0.5, 7.2 + b + ty }
  P:limb({ { 9, 30 + m }, { 5.8, 29 + m }, { 4.2, 24.5 + b }, { 3.9 + sw * 0.2, 18 + b + ty * 0.3 },
    { 4.4 + sw * 0.5 + lx * 0.3, 12 + b + ty * 0.7 }, tip }, 1.6, 0.9, 't')
  S.leg(P, 12.5, 30 + m, 15.5, 31.8 + m, 17, 32.6 + f, 1.3, 0.9, 'g', -st)   -- o pé de trás
  P:ell(14.5, 24 + b, 6.6, 6.2, 'f')
  P:ell(17 + lx * 0.5, 17.4 + b, 5.6, 6.4, 'f')
  P:ell(19.6 + lx, 13.4 + hb, 3.6, 3.4, 'f')
  P:limb({ { 20.5 + lx, 16 + b }, { 23.8 + lx, 19.4 + b }, { 23.4 + lx, 21.6 + b } }, 1.1, 0.7, 'g')   -- o braço de trás
  -- a boca da fornalha no tronco: o arco de ferro e, por dentro, só o fogo
  local cx, hw, spring, base = 14.8 + lx * 0.3, 4.5, 19.4 + b, 27.2 + b
  local fr = 1.05
  for y = floor(P:Y(spring - hw - 1)), floor(P:Y(base)) do for x = floor(P:X(cx - hw - 1)), floor(P:X(cx + hw + 1)) do
    if L.get(g, x, y) == 'f' then
      local u, v = (x - P.ox) / k, (y - P.oy) / k
      local d = v < spring and sqrt((u - cx) ^ 2 + (v - spring) ^ 2) or abs(u - cx)
      if d <= hw and v <= base then
        if d > hw - fr or v > base - fr then g[y][x] = 'y'
        else
          local h = (base - fr - v) / (base - fr - (spring - hw + fr))   -- 0 no chão do forno, 1 no alto do arco
          local col = floor(x / math.max(1, floor(k)))
          local heat = 1 - h * 1.35 + F.rnd(col, ph, 9) * 0.35 + grow * 0.14 - abs(u - cx) / hw * 0.25
          g[y][x] = heat > 0.85 and 'Y' or heat > 0.45 and 'E' or heat > 0.1 and 'R' or (heat > -0.25 and 'r' or 'k')
        end
      end
    end
  end end
  -- a coxa, o pé e o braço da frente
  P:ell(11.6, 29.6 + m, 5.6, 3.4, 'f')
  S.leg(P, 15, 30.6 + m, 18.6, 32 + m, 20.6, 32.6 + f, 1.5, 1.0, 'f', st)
  P:limb({ { 19.4 + lx, 16.6 + b }, { 22.4 + lx, 20.4 + b }, { 21.6 + lx, 22.8 + b } }, 1.3, 0.8, 'f')
  local T = S.head(P, k, 22.6 + lx, 10.4 + hb, 12, 1.08, { open = alert and 1.5 or nil, ear = 2 })
  P:ell(19.6 + lx, 9.4 + hb, 2.6, 2.6, 'f')
  S.paw(P, k, 17 - st, 33 + f, 'q', 0.55); S.paw(P, k, 20.6 + st, 33 + f, 'p', 0.55)
  S.furShade(g, k, 'f', S.FUR, { zones = 3, within = 'fygYERrk' })
  S.furShade(g, k, 'g', 'ba', { zones = 1 })
  S.ironShade(g, k, 'y', { within = 'yYERrk', p = 2, ax = 1, ay = 1, bias = -0.2 })
  S.faceShade(g, k)
  S.skinShade(g, k)
  -- ferrugem e a pedra de fecho do arco
  P:px(cx, spring - hw + 0.3, 'I', S.IRON)
  P:px(cx - hw + 0.4, spring + 2, 'N', S.IRON); P:px(cx + hw - 0.4, spring + 5, 'n', S.IRON)
  -- as brasas no chão do forno (piscam)
  for n = -1, 1 do
    P:px(cx + n * 2.2, base - fr - 0.6, (ph + n) % 4 == 1 and 'G' or 'B', 'YERrk')
    if k > 1 then P:disc(cx + n * 2.2, base - fr - 0.6, 0.45, (ph + n) % 4 == 1 and 'G' or 'B', 'YERrk') end
  end
  -- as mãos juntas na frente do fogo
  P:limb({ { 21.6 + lx, 22.8 + b }, { 22.8 + lx, 23.8 + b } }, 0.6, 0.45, 'P')
  P:px(23.6 + lx, 22.2 + b, 'p')
  if k > 1 then
    for n = 0, 2 do L.line(g, P:X(22.8 + lx), P:Y(23.8 + b), P:X(23.6 + lx + n * 0.4), P:Y(25 + b - n * 0.5), 'P') end
  end
  -- o olho fechado
  S.headFinish(P, k, T, 1.08, {})
  local e0, e1 = T(1.0, -0.8), T(2.8, -0.3)
  P:limb({ e0, e1 }, 0.3, 0.3, 'k', S.FACE)
  if k > 1 then local e2 = T(1.9, 0.2); P:limb({ e0, e2, e1 }, 0.3, 0.3, 'K', S.FACE) end
  S.buttTip(P, k, tip[1], tip[2], -0.2, 0.95, ph == 2)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  S.seam(P, { { 8.8, 20.4 + b }, { 9.4, 26.4 + b } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  S.seam(P, { { 17.8 + lx, 10.6 + hb }, { 18.6 + lx, 14.8 + hb } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  -- fumaça da chaminé, sem contorno
  if not o.jump and not crouch then
    local n1 = k > 1 and 12 or 4
    local ax, ay = tip[1] + 0.4, tip[2] - (k > 1 and 1.3 or 2.2)   -- encostada no alto do rabo
    local px, py
    for n = 0, n1 do
      local t = n / n1
      local x, y = P:X(ax + sin(t * 4 + ph * 1.5) * 1.0 * math.min(1, t * 3) + t * 1.6), P:Y(ay) - t * 3 * k
      L.line(g, px or x, py or y, x, y, n % 2 == 0 and 'M' or 'm', '.')
      if k > 1 then L.set(g, x + 1, y, 'm', '.') end
      px, py = x, y
    end
  end
  for n, q in ipairs({ { 25.6, 26, 'S' }, { 27.4, 21, 's' }, { 30, 24, 'T' }, { 9.6, 11, 's' }, { 11.6, 14, 'S' } }) do
    local r = (ph + n) % 4
    if r < 3 then S.spark(P, sg, q[1], q[2] + b - r * 0.9, q[3]) end
  end
end

S.run {
  name = 'kilnshade', stage = 'espirito', W = 36, PW = 96, draw = draw, ownDy = true, ownLean = true,
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,6 vezes num quadro de 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 8, 28 }, green = { 11, 13 }, water = { 15, 12 }, residential = { 13, 14 }, lit = { 14, 15 },
    sacred = { 19, 3 }, crimson = { 6, 21 },
  },
}
