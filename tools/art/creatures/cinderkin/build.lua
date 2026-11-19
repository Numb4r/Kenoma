-- Cinderkin (soot.spirit), arte final: o Espírito da família Soot, a partir do conceito aprovado. O saruê tomado pelo
-- bueiro: dois rabos (um arrasta), dois olhos de brasa do mesmo lado, três orelhas, a boca aberta e os filhotes de
-- fuligem agarrados no lombo.
-- O ELEMENTO ERRADO (o que o Sootling não tem): o flanco é a grelha do bueiro, e por dentro ele é oco. Onde devia
-- haver costela e tripa só tem a brasa atrás das barras, e de lá de dentro uma mão de saruê (a que parece de gente)
-- passa três dedos pelos vãos e segura a grade: tem alguém do lado de dentro.
-- Costuras do Véu: duas, de 2 px (na anca e no pescoço), só no glow.
-- Camadas: corpo; leds = as duas bitucas e os olhos de brasa (dele e dos filhotes); glow = a brasa da grelha e do
-- peito, a garganta, as costuras e as faíscas.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/cinderkin/build.lua')
local S = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_soot.lua')
local L, F = S.L, S.F
local floor, abs, sin = math.floor, math.abs, math.sin

local function draw(g, sg, k, o)
  local off = k > 1 and 1 or 0
  local P = F.pen(g, k, off, off)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local b = (o.dy or 0) / k                                  -- o tronco
  local f = o.jump and b or 0                                -- os pés
  local m = (b + f) / 2
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0
  local sw = (alert or crouch) and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ty = alert and -1 or (crouch and 2 or 0)
  local hb = b + (crouch and 1 or 0)
  local grow = ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  -- o rabo de cima, com a bituca, e o que arrasta
  local tip = { 10.6 + sw, 11.6 + b + ty }
  P:limb({ { 7, 21 + b }, { 4, 18 + b + ty * 0.3 }, { 3.2 + sw * 0.3, 13.5 + b + ty * 0.6 }, { 4.4 + sw * 0.6, 9 + b + ty },
    { 7.4 + sw, 6.2 + b + ty }, { 10.6 + sw, 6.8 + b + ty }, { 11.8 + sw, 9.4 + b + ty }, tip }, 1.5, 0.9, 't')
  local drag = { 8 - st, 32.8 + f }
  P:limb({ { 7, 24 + b }, { 3.6, 26 + m }, { 2.6, 29.5 + f }, { 4.6 - st * 0.5, 32.4 + f }, drag }, 1.4, 0.8, 't')
  S.leg(P, 22, 26 + b, 21.4, 29.5 + m, 22.2, 32.6 + f, 1.3, 0.9, 'g', st)
  S.leg(P, 13.6, 26 + b, 15, 29.5 + m, 14.2, 32.6 + f, 1.5, 0.9, 'g', -st)
  P:ell(16, 21.5 + b, 9.2, 6, 'f')
  P:ell(10.6, 21 + b, 5.4, 6.2, 'f')
  P:ell(22.5, 20 + b, 4.4, 5.2, 'f')
  -- filhotes no lombo: um de cada vez levanta a cabeça
  local pups = { { 10.4, 14.4 }, { 14.4, 13.8 }, { 18.4, 14.4 } }
  for n, q in ipairs(pups) do
    q[2] = q[2] + b
    local up = (not alert and not crouch and (ph + n) % 4 == 1) and -0.7 or 0
    P:ell(q[1], q[2], 1.9, 1.5, 'g'); P:ell(q[1] + 1.6, q[2] + 0.4 + up, 1.0, 0.8, 'g')
    q[3] = up
  end
  local T = S.head(P, k, 26, 17.6 + hb, 14, 1.12, { open = alert and 1.7 or (crouch and 0.5 or 1), ear = 3 })
  P:ell(23.4, 15.8 + hb, 3.2, 2.8, 'f')
  P:ell(10.6, 25.4 + b, 3.4, 3.6, 'f')
  S.leg(P, 9.8, 27.5 + b, 8.6, 30.4 + m, 9.6, 32.6 + f, 1.7, 1.0, 'f', st)
  S.leg(P, 24.6, 24.5 + b, 25.2, 29 + m, 24.8, 32.6 + f, 1.5, 1.0, 'f', -st)
  S.paw(P, k, 22.2 + st, 33 + f, 'q', 0.55); S.paw(P, k, 14.2 - st, 33 + f, 'q', 0.55)
  S.paw(P, k, 9.6 + st, 33 + f, 'p', 0.55); S.paw(P, k, 24.8 - st, 33 + f, 'p', 0.55)
  -- a grelha no flanco: barras de ferro, a brasa nos vãos (pulsa com o laço)
  local gx0, gx1, gy0, gy1 = 12, 21.6, 17.4 + b, 26.2 + b
  local bw = k > 1 and floor(k) or 1
  local X0 = floor(P:X(gx0))
  for y = floor(P:Y(gy0)), floor(P:Y(gy1)) do for x = X0, floor(P:X(gx1)) do
    if L.get(g, x, y) == 'f' then
      local u, v = (x - P:X(gx0)) / (P:X(gx1) - P:X(gx0)), (y - P:Y(gy0)) / (P:Y(gy1) - P:Y(gy0))
      local col = floor((x - X0) / bw)
      if v < 0.1 or v > 0.9 or u < 0.04 or u > 0.96 then g[y][x] = 'y'
      elseif col % 2 == 0 then g[y][x] = 'y'
      else
        local heat = 1 - abs(v - 0.55) * 2.2 - abs(u - 0.5) * 0.9 + (F.rnd(x, y, 9) - 0.5) * 0.25 + grow * 0.14
        g[y][x] = heat > 0.62 and 'Y' or heat > 0.3 and 'E' or heat > -0.25 and 'R' or 'r'
      end
    end
  end end
  S.furShade(g, k, 'f', S.FUR, { zones = 3, within = 'fygYERr' })
  S.furShade(g, k, 'g', 'ba', { zones = 1 })
  S.ironShade(g, k, 'y', { within = 'yYERr', p = 2, ax = 0, ay = 1 })
  S.faceShade(g, k)
  S.skinShade(g, k)
  -- a mão de dentro: três dedos saem pelos vãos e dobram por cima da barra de baixo
  local function gx(col) return (X0 + bw * col + (bw - 1) / 2 - P.ox) / k end
  for n = (alert and 0 or 1), 3 do                            -- no alerta aparece o quarto dedo
    local v = 18.6 + n * 1.9 + b
    local x1 = gx(5) + (k > 1 and ((ph + n) % 4 == 0 and 0.3 or 0.7) or 0)
    P:limb({ { gx(3), v }, { x1, v } }, 0.4, 0.4, 'P')
    P:px(gx(4), v, 'p')                                       -- o nó do dedo, em cima da barra
    if k > 1 then P:px(x1 + 0.3, v, 'V') end                  -- a unha
  end
  S.headFinish(P, k, T, 1.12, { eyes = { { 2.0, -0.5, 'B' }, { 0.2, -1.5, 'B' } } })
  for _, q in ipairs(pups) do P:px(q[1] + 1.8, q[2] + 0.2 + q[3], 'B') end
  S.buttTip(P, k, tip[1], tip[2], -0.5, 0.86, ph == 2)
  S.buttTip(P, k, drag[1], drag[2], 1, 0.1, ph == 0)
  S.ember(g, P:X(25), P:Y(23.6 + b), 3 * k, 21, S.FUR, k > 1 and 11 or 7, grow)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  S.seam(P, { { 6.4, 17.6 + b }, { 8, 25.4 + b } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  S.seam(P, { { 22, 14 + b }, { 22.8, 19.4 + b } }, w, 'X', S.FUR, k > 1 and 2 or nil)
  -- fumaça da bituca de cima, sem contorno
  if not o.jump and not crouch then
    local n1 = k > 1 and 16 or 5
    local ax, ay = tip[1] + 1.2, tip[2] - 2.2 - 1.45          -- encostada no alto do rabo
    local px, py
    for n = 0, n1 do
      local t = n / n1
      local x, y = P:X(ax + sin(t * 5 + ph * 1.5) * 1.2 * math.min(1, t * 3) + t * 2), P:Y(ay) - t * 5.5 * k
      L.line(g, px or x, py or y, x, y, n % 2 == 0 and 'M' or 'm', '.')
      if k > 1 then L.set(g, x + 1, y, 'm', '.') end
      px, py = x, y
    end
  end
  for n, q in ipairs({ { 30, 26, 'S' }, { 28.4, 29, 's' }, { 32.4, 24, 'T' }, { 11, 33.6, 's' }, { 13, 31, 'S' } }) do
    local r = (ph + n) % 4
    if r < 3 then S.spark(P, sg, q[1], q[2] + b - r * 0.9, q[3]) end
  end
end

S.run {
  name = 'cinderkin', stage = 'espirito', W = 36, PW = 96, draw = draw, ownDy = true, ownLean = true,
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,6 vezes num quadro de 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 5, 19 }, green = { 6, 16 }, water = { 21, 16 }, residential = { 20, 16 }, lit = { 21, 17 },
    sacred = { 24, 9 }, crimson = { 22, 20 },
  },
}
