-- Thicketkin (frond.spirit), arte final: o Espírito da família Frond, a partir do conceito aprovado. A fronde tomada
-- pela calçada: o disco de fixação virou um pedaço de laje levantado por sete raízes, com a rachadura acesa; dela
-- sai uma fronde grande, com alguns lobos já de concreto ou secos, e um báculo que não abriu.
-- O ELEMENTO ERRADO (o que o Frondling não tem): uma raiz no lugar de fronde. Onde a fronde de trás devia estar, uma
-- raiz grossa sai da laje para cima, para o ar, e abre em cinco radículas como uma mão, segurando uma lasca de
-- calçada; a mão abre e fecha devagar, e escancara no alerta. A planta não sabe mais qual lado é o de cima.
-- Costuras do Véu: duas, de 2 px (atravessando a laje, e nos lobos de baixo da fronde grande), só no glow.
-- Camadas: corpo; leds = os brotos dos dois báculos (piscam); glow = as nervuras, a rachadura da laje, as costuras e
-- os esporos.
-- Bicho de chão: a laje sobe e desce (body_dy) e as raízes ficam; na deriva as raízes andam; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/thicketkin/build.lua')
local Fr = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_frond.lua')
local L, F = Fr.L, Fr.F
local sin, floor = math.sin, math.floor

local ROOTS = { { 9, 28, 4.6, 27.6, 2.8, 33 }, { 11, 29, 8, 30.4, 7.4, 33.2 }, { 15, 29, 14, 31.4, 14.6, 33.4 },
  { 20, 28, 20.6, 31, 19.8, 33.4 }, { 24, 27, 26.6, 29.8, 26, 33.2 }, { 27, 26, 31.6, 26.6, 33, 32.6 }, { 17, 29, 17.4, 31, 17, 32.4 } }
local S1 = { { 17, 25.4 }, { 17.6, 20.4 }, { 19.4, 15.4 }, { 22.4, 10.8 }, { 26, 7.8 }, { 29.2, 7.6 }, { 30.4, 9.4 }, { 29.4, 11 }, { 28, 10.4 } }
local S2 = { { 23.6, 23.4 }, { 25.6, 19.6 }, { 28.4, 17.6 }, { 30.4, 18.6 }, { 30, 20.6 }, { 28.6, 20.4 } }

local function draw(g, sg, k, o)
  local off = k > 1 and 1 or 0
  local P = F.pen(g, k, off, off)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k + (crouch and 1 or 0)            -- a laje e o que nasce dela
  local f = o.jump and (o.dy or 0) / k or 0                  -- as raízes
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0
  local sw = still and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ln = -sw - (o.lean and 1.2 or 0) - (alert and 0.6 or 0)   -- as frondes vergam para trás
  local sy = alert and 1.04 or (crouch and 0.86 or 1)
  local function bend(pts, by, amt)
    local out = {}
    for n, q in ipairs(pts) do
      local h = (by - q[2]) * sy
      out[n] = { q[1] + ln * amt * (h / 18) ^ 1.4, by - h + b }
    end
    return out
  end
  for n, r in ipairs(ROOTS) do
    local s = (n % 2 == 0) and st or -st
    P:limb({ { r[1], r[2] + b }, { r[3] + s * 0.5, r[4] + (b + f) / 2 }, { math.min(33, r[5] + s), r[6] + f } }, 1.15, 0.5, 'h')
  end
  local grow = alert and 1.08 or (crouch and 0.88 or 1)
  -- a raiz que cresce para cima, no lugar da fronde de trás: o pulso sai da laje, a palma segura uma lasca de
  -- calçada e cinco radículas abrem e fecham
  local op = alert and 1.5 or (crouch and 0.1 or 0.6 + 0.4 * sin(ph * 1.571))
  local arm = bend({ { 11, 26 }, { 9.6, 21 }, { 8.4, 15.4 } }, 26, -0.5)
  local px, py = arm[3][1], arm[3][2]
  P:limb(arm, 1.6, 1.3, 'h')
  for n, a in ipairs({ -160, -125, -92, -60, -25 }) do
    local sp = (n - 3) * 6 * (op - 0.6)                       -- abre em leque
    local an = math.rad(a + sp)
    local len = ({ 5.6, 8.6, 9.8, 8.6, 5.6 })[n] * (0.84 + 0.16 * math.min(op, 1)) * sy
    local mx, my = px + math.cos(an) * len * 0.55, py + math.sin(an) * len * 0.55
    local cu = math.rad(a + sp + (n < 3 and 1 or -1) * (1.2 - op) * 45)   -- a ponta dobra para dentro quando fecha
    P:limb({ { px, py }, { mx, my }, { mx + math.cos(cu) * len * 0.45, my + math.sin(cu) * len * 0.45 } }, 0.95, 0.45, 'h')
  end
  P:poly({ { px - 1.3, py - 2.6 }, { px + 0.9, py - 3 }, { px + 1.3, py - 1 }, { px - 0.7, py - 0.6 } }, 'y')   -- a lasca
  -- a laje
  P:poly({ { 5.6, 24.4 + b }, { 27.4, 21.4 + b }, { 30.6, 25.6 + b }, { 9, 29.4 + b } }, 'y')
  P:poly({ { 9, 29.4 + b }, { 30.6, 25.6 + b }, { 30.6, 27.6 + b }, { 9.4, 31.2 + b } }, 'J')
  P:poly({ { 5.6, 24.4 + b }, { 9, 29.4 + b }, { 9.4, 31.2 + b }, { 5.8, 26.4 + b } }, 'j')
  -- a fronde grande
  local s1 = bend(S1, 25.4, 1)
  local l1 = Fr.frond(P, s1, { n = 8, t0 = 0.05, t1 = 0.72, ang = 52, r0 = 0.9, r1 = 0.45,
    w = function(t) return (2.4 + 5.6 * sin(3.14 * (0.14 + 0.82 * t / 0.72)) ^ 0.8) * grow end,
    wag = function(i) return alert and 7 or (still and 0 or 4 * sin(ph * 1.571 + i * 0.9)) end,
    mat = function(i) if i % 5 == 2 then return 'y', 'J' elseif i % 5 == 4 then return 'g', 'n' end return 'f', 'a' end })
  -- o báculo que não abriu
  local s2 = bend(S2, 23.4, 0.5)
  P:limb(s2, 0.8, 0.45, 'm')
  Fr.shadeAll(g, k)
  Fr.veins(g, P, k > 1 and l1 or nil, Fr.LEAF .. Fr.DRY, ph, 4)
  -- a rachadura acesa na laje
  local cr = { { 7.6, 26.4 }, { 11, 26.6 }, { 13.6, 25 }, { 17, 25.6 }, { 20.4, 23.8 }, { 23.6, 24 }, { 27.4, 22.6 } }
  for n = 1, #cr - 1 do
    for th = 0, (k > 1 and 1 or 0) do
      L.line(g, P:X(cr[n][1]), P:Y(cr[n][2] + b) + th, P:X(cr[n + 1][1]), P:Y(cr[n + 1][2] + b) + th,
        th == 0 and ((n + ph) % 2 == 0 and 'E' or 'D') or 'B', Fr.CONC)
    end
  end
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  Fr.seam(P, { { 12.4, 24 + b }, { 14.2, 30.2 + b } }, w, '9', Fr.CONC, k > 1 and 2 or nil)
  local a0, a1 = l1[2], l1[5]
  Fr.seam(P, { { a0[3], a0[4] }, { a1[3], a1[4] } }, w, 'X', Fr.LEAF, k > 1 and 2 or nil)
  -- os brotos dos báculos
  for _, tip in ipairs({ s1[#s1], s2[#s2] }) do
    if k > 1 then P:disc(tip[1], tip[2], 0.45, 'H', 'DEBm') end
    P:px(tip[1], tip[2], 'G')
  end
  Fr.clean(g, 'thicketkin', 'a', 4 * k * k)
  Fr.spores(P, sg, { { 33, 13 }, { 2.6, 13.4 }, { 13.4, 6 }, { 33.4, 22 }, { 14, 12.4 } }, ph, 4)
end

Fr.run {
  name = 'thicketkin', stage = 'espirito', W = 36, PW = 96, draw = draw, ownLean = true,
  fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,6 vezes num quadro de 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 15, 24 }, green = { 12, 21 }, water = { 13, 15 }, residential = { 14, 18 }, lit = { 13, 20 },
    sacred = { 14, 3 }, crimson = { 20, 23 },
  },
}
