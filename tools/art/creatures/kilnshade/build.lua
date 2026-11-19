-- Kilnshade (soot.ritual), arte final: o saruê de ritual da família Soot, ligado a Ialprg (chamas ardentes).
-- Na linguagem das peças finais do Soot (_soot.lua): fuligem, cara branca suja, pele nua, ferro fundido; só a brasa
-- tem cor, e a luz é a do tipo Fogo.
-- O QUE ELE TEM DE PRÓPRIO (e o Cinderkin não): está sentado, em pé sobre as ancas, parado como um ídolo, de olho
-- fechado. O tronco é uma boca de fornalha: um arco de ferro fundido, e por dentro ele é só o fogo, com as brasas
-- no chão do forno. O rabo sobe reto atrás dele como chaminé, com a bituca acesa no alto e a fumaça. As duas mãos
-- (as que parecem de gente) ficam juntas na frente do fogo.
-- A CARA (o que se lê a 36 px): a cabeça é grande (HS 1,55), a cara branca passa de 8×7 px, as duas orelhas ficam
-- separadas e a fresta do olho fechado tem 4 px sobre a pálpebra clara.
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
  -- o rabo de saruê: sai grosso e peludo da anca, deita no chão, sobe em S afinando e a ponta, fina, enrola para
  -- fora segurando a bituca (a chaminé é só a ponta)
  local tx = sw * 0.6 + lx * 0.4
  local tip = { 3.4 + tx, 7.6 + b + ty }
  local tail = { { 10, 30.4 + m }, { 6.6, 31 + m }, { 4.4, 28.6 + m }, { 4, 24.4 + b }, { 5.6 + tx * 0.3, 20 + b + ty * 0.3 },
    { 7.2 + tx * 0.6, 16 + b + ty * 0.6 }, { 7 + tx * 0.9, 12.4 + b + ty * 0.8 }, { 5.4 + tx, 9.4 + b + ty }, tip }
  P:limb(tail, 2.0, 0.55, 't')
  P:limb({ tail[1], tail[2], { 5.4, 30 + m } }, 2.0, 1.75, 'g')   -- a base ainda tem pelo
  S.leg(P, 12.5, 30 + m, 15.5, 31.8 + m, 17, 32.6 + f, 1.3, 0.9, 'g', -st)   -- o pé de trás
  P:ell(14.5, 24 + b, 6.6, 6.2, 'f')
  P:ell(17 + lx * 0.5, 17.4 + b, 5.6, 6.4, 'f')
  P:ell(19.6 + lx, 13.4 + hb, 3.6, 3.4, 'f')
  P:limb({ { 20.5 + lx, 16 + b }, { 23.8 + lx, 19.4 + b }, { 23.4 + lx, 21.6 + b } }, 1.1, 0.7, 'g')   -- o braço de trás
  -- a boca da fornalha no tronco: o arco de ferro e, por dentro, só o fogo
  local cx, hw, spring, base = 14.8 + lx * 0.3, 4.5, 19.4 + b, 27.2 + b
  local fr, bed = 1.05, 2
  for y = floor(P:Y(spring - hw - 1)), floor(P:Y(base)) do for x = floor(P:X(cx - hw - 1)), floor(P:X(cx + hw + 1)) do
    if L.get(g, x, y) == 'f' then
      local u, v = (x - P.ox) / k, (y - P.oy) / k
      local d = v < spring and sqrt((u - cx) ^ 2 + (v - spring) ^ 2) or abs(u - cx)
      if d <= hw and v <= base then
        if d > hw - fr or v > base - fr then g[y][x] = 'y'
        elseif v > base - fr - bed then g[y][x] = 'k'        -- o leito de carvão: escuro, para as brasas aparecerem
        else
          local h = (base - fr - bed - v) / (base - fr - bed - (spring - hw + fr))   -- 0 no leito, 1 no alto do arco
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
  local HS = 1.55                                            -- cabeça grande: a cara branca passa de 8×7 px no mapa
  -- as duas orelhas, separadas (as do kit crescem com a cabeça e viravam um gorro)
  do
    local hx, hy, ca, sa = 20.8 + lx, 12 + hb, math.cos(math.rad(12)), math.sin(math.rad(12))
    for _, e in ipairs({ { -2.2, -3.2 }, { 1.0, -3.3 } }) do
      local u, v = e[1] * HS, e[2] * HS
      local ex, ey = hx + u * ca - v * sa, hy + u * sa + v * ca
      P:ell(ex, ey, 1.8, 2.3, 'q'); P:ell(ex + 0.2, ey + 0.4, 0.9, 1.3, 'p')
    end
  end
  local T = S.head(P, k, 20.8 + lx, 12 + hb, 12, HS, { open = alert and 1.3 or nil, ear = 0 })
  P:ell(16.6 + lx, 11 + hb, 2.4, 3.6, 'f')
  S.paw(P, k, 17 - st, 33 + f, 'q', 0.55); S.paw(P, k, 20.6 + st, 33 + f, 'p', 0.55)
  S.furShade(g, k, 'f', S.FUR, { zones = 3, within = 'fygYERrk' })
  S.furShade(g, k, 'g', 'ba', { zones = 1 })
  S.ironShade(g, k, 'y', { within = 'yYERrk', p = 2, ax = 1, ay = 1, bias = -0.2 })
  S.faceShade(g, k)
  S.skinShade(g, k)
  -- ferrugem e a pedra de fecho do arco
  P:px(cx, spring - hw + 0.3, 'I', S.IRON)
  P:px(cx - hw + 0.4, spring + 2, 'N', S.IRON); P:px(cx + hw - 0.4, spring + 5, 'n', S.IRON)
  -- as brasas no leito de carvão (piscam): três pontos claros no escuro, com uma linha escura entre elas e o fogo
  for n = -1, 1 do
    local ex, ey = cx + n * 2.4, base - fr - 0.6
    P:px(ex, ey, (ph + n) % 4 == 1 and 'B' or 'G', 'k')
    if k > 1 then
      P:disc(ex, ey, 0.5, 'B', 'k'); P:disc(ex, ey, 0.25, (ph + n) % 4 == 1 and 'B' or 'G', 'kB')
    end
  end
  -- as mãos juntas na frente do fogo
  P:limb({ { 21.6 + lx, 22.8 + b }, { 22.8 + lx, 23.8 + b } }, 0.6, 0.45, 'P')
  P:px(23.6 + lx, 22.2 + b, 'p')
  if k > 1 then
    for n = 0, 2 do L.line(g, P:X(22.8 + lx), P:Y(23.8 + b), P:X(23.6 + lx + n * 0.4), P:Y(25 + b - n * 0.5), 'P') end
  end
  -- o olho fechado
  S.headFinish(P, k, T, HS, {})
  -- a pálpebra clara limpa a hachura da cara e a fresta escura, em arco para baixo, fica por cima
  local ec = T(1.5, -0.5)
  P:ell(ec[1], ec[2], 2.9, 2.2, 'V', S.FACE)
  P:limb({ T(0.1, -1.0), T(0.9, -0.1), T(2.1, -0.1), T(2.9, -1.0) }, 0.3, 0.3, 'k', S.FACE)
  S.buttTip(P, k, tip[1], tip[2], -0.5, -0.85, ph == 2)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  S.seam(P, { { 8.8, 20.4 + b }, { 9.4, 26.4 + b } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  S.seam(P, { { 16 + lx, 9 + hb }, { 16.8 + lx, 13.4 + hb } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  -- fumaça da chaminé, sem contorno
  if not o.jump and not crouch then
    local n1 = k > 1 and 12 or 4
    local ax, ay = tip[1] + 0.2, tip[2] - (k > 1 and 0.8 or 1.9)   -- encostada na ponta do rabo
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
    -- espalhados: braçadeiras no meio do rabo, guirlanda na anca, colar no pescoço, pano vermelho amarrado no alto
    -- do rabo, óculos na testa, auréola, marca na base do rabo
    urban = { 3, 20 }, green = { 8, 28 }, water = { 15, 14 }, residential = { 3, 12 }, lit = { 19, 7 },
    sacred = { 18, 1 }, crimson = { 5, 27 },
  },
}
