-- Rootseer (frond.ritual), arte final: a fronde de ritual da família Frond, ligada a Peab.
-- Na linguagem das peças finais do Frond (_frond.lua): Charnia, verde de calçada, folha seca, raiz, concreto; só a
-- nervura tem cor, e a luz é a do tipo Planta.
-- O QUE ELA TEM DE PRÓPRIO (e o Thicketkin não): uma fronde só, e ela nunca abriu. O báculo continuou enrolando até
-- virar um disco, e o disco é um olho: a nervura acesa é a íris em espiral e o broto, no meio, a pupila (pisca).
-- Fica parada, alta, em cima de seis raízes compridas abertas no chão, que é por onde ela escuta; o talo passa por
-- dentro de uma placa de calçada que ela levantou. No alerta o olho abre (a espiral desenrola, a pupila cresce);
-- encolhida, fecha.
-- Costuras do Véu: duas, de 2 px (atravessando a placa, e nos lobos de fora do disco), só no glow.
-- Camadas: corpo; leds = o broto (a pupila); glow = a nervura em espiral, as costuras e os esporos.
-- Bicho de chão: a placa e o olho sobem e descem (body_dy) e as raízes ficam; na deriva as raízes andam e o olho
-- fica para trás; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rootseer/build.lua')
local Fr = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_frond.lua')
local L, F = Fr.L, Fr.F
local sin, cos, rad, floor = math.sin, math.cos, math.rad, math.floor

local ROOTS = { { 11, 28.6, 6.4, 29.4, 3.8, 33 }, { 13.6, 29.6, 10.6, 31.2, 9.6, 33.4 }, { 17, 30, 16.2, 31.8, 16.6, 33.4 },
  { 21.4, 29.6, 22.4, 31.6, 22.2, 33.4 }, { 24.4, 28.6, 27.4, 30.6, 27.8, 33.2 }, { 25.8, 27.6, 30.4, 28.4, 32.2, 32.8 } }

local function draw(g, sg, k, o)
  local off = k > 1 and 1 or 0
  local P = F.pen(g, k, off, off)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k + (crouch and 1 or 0)            -- a placa e o que nasce dela
  local f = o.jump and (o.dy or 0) / k or 0                  -- as raízes
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0
  local sw = still and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ln = -(o.lean and 1.4 or 0) - sw * 0.4               -- o olho fica para trás
  for n, r in ipairs(ROOTS) do
    local s = (n % 2 == 0) and st or -st
    P:limb({ { r[1], r[2] + b }, { r[3] + s * 0.5, r[4] + (b + f) / 2 }, { math.max(3.4, math.min(32.6, r[5] + s)), r[6] + f } },
      1.5, 0.5, 'h')
  end
  -- a placa de calçada que o talo atravessou
  P:poly({ { 9.6, 25.4 + b }, { 24.6, 23.8 + b }, { 26.6, 26.4 + b }, { 11.6, 28.4 + b } }, 'y')
  P:poly({ { 11.6, 28.4 + b }, { 26.6, 26.4 + b }, { 26.6, 28.2 + b }, { 11.8, 30.2 + b } }, 'J')
  P:poly({ { 9.6, 25.4 + b }, { 11.6, 28.4 + b }, { 11.8, 30.2 + b }, { 9.8, 27.4 + b } }, 'j')
  -- o báculo que virou disco: o talo sobe e enrola, no sentido do relógio, até o meio
  local cx, cy = 19 + ln, 13.6 + b + (crouch and 1.4 or 0)
  local R0 = alert and 7.1 or (crouch and 5.4 or 6.5 + sw * 0.3)
  local turns = alert and 1.3 or (crouch and 1.8 or 1.55 - sw * 0.05)
  local stem = { { 17, 27 + b }, { 16.2 + ln * 0.4, 23.4 + b } }
  local n1 = floor(turns * 12 + 0.5)
  for n = 0, n1 do
    local t = n / n1
    local a = rad(118 + t * turns * 360)
    local r = R0 * (1 - t) ^ 0.85 + 1.0 * t
    stem[#stem + 1] = { cx + cos(a) * r, cy + sin(a) * r }
  end
  local i = -1
  local lobes = Fr.frond(P, stem, { n = 11, t0 = 0.17, t1 = 0.82, ang = 58, r0 = 0.55, r1 = 0.45, fat = 2.7,
    w = function(t)                                          -- os lobos de fora são os cílios; os de dentro enchem o disco
      i = i + 1
      local out = i % 2 == 0
      return (out and 4.1 or 2.4) * (1 - t) ^ 0.7 + 1.1
    end,
    wag = function(n) return alert and (n % 2 == 0 and -10 or 0) or (still and 0 or 4 * sin(ph * 1.571 + n * 0.9)) end,
    mat = function(n) if n % 7 == 2 then return 'y', 'J' elseif n % 7 == 5 then return 'g', 'n' end return 'f', 'a' end })
  Fr.shadeAll(g, k)
  Fr.veins(g, P, k > 1 and lobes or nil, Fr.LEAF .. Fr.DRY, ph, 4)
  -- a pupila: o escuro da junta em volta do broto
  local tip = stem[#stem]
  local pr = alert and 2.1 or 1.5
  if not crouch then
    P:disc(tip[1], tip[2], pr, 'k')
    if k > 1 then P:disc(tip[1], tip[2], 0.6, 'H') end
    P:px(tip[1], tip[2], 'G')
    if k > 1 then L.set(g, P:X(tip[1]) - 1, P:Y(tip[2]) - 1, 'G') end
  end
  -- trinca na placa
  P:limb({ { 20.4, 24.6 + b }, { 21.4, 26.2 + b }, { 20.8, 27.6 + b } }, 0.3, 0.3, 'k', Fr.CONC)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  Fr.seam(P, { { 13.2, 25.2 + b }, { 14.6, 29.8 + b } }, w, '9', Fr.CONC, k > 1 and 2 or nil)
  local a0, a1 = lobes[3], lobes[7]
  Fr.seam(P, { { a0[3], a0[4] }, { a1[3], a1[4] } }, w, 'X', Fr.LEAF, k > 1 and 2 or nil)
  Fr.clean(g, 'rootseer', 'a', 4 * k * k)
  Fr.spores(P, sg, { { 31.6, 16 }, { 5.4, 14.4 }, { 30, 8 }, { 6.4, 21 }, { 32.6, 23 } }, ph, 4)
end

Fr.run {
  name = 'rootseer', stage = 'espirito', W = 36, PW = 96, draw = draw, ownLean = true,
  fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,6 vezes num quadro de 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 16, 26 }, green = { 12, 23 }, water = { 15, 17 }, residential = { 15, 20 }, lit = { 14, 24 },
    sacred = { 15, 2 }, crimson = { 22, 25 },
  },
}
