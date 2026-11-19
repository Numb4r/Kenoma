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

-- seis raízes compridas, em arco: a placa fica alta em cima delas
local ROOTS = { { 10.6, 26.6, 5.4, 27.2, 3.6, 32.8 }, { 13, 27.6, 9.4, 29.6, 9, 32.8 }, { 16.6, 28, 15.6, 30.4, 16.2, 32.8 },
  { 21, 27.6, 22.6, 30.2, 22.2, 32.8 }, { 24, 26.6, 27.8, 28.8, 28, 32.8 }, { 25.6, 25.6, 30.6, 26.2, 32.4, 32.6 } }

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
    P:limb({ { r[1], r[2] + b }, { r[3] + s * 0.5, r[4] + (b + f) / 2 }, { math.max(3.6, math.min(32.4, r[5] + s)), r[6] + f } },
      1.6, 0.75, 'h')
  end
  -- a placa de calçada que o talo atravessou
  P:poly({ { 9.6, 24 + b }, { 24.6, 22.4 + b }, { 26.6, 25 + b }, { 11.6, 27 + b } }, 'y')
  P:poly({ { 11.6, 27 + b }, { 26.6, 25 + b }, { 26.6, 26.8 + b }, { 11.8, 28.8 + b } }, 'J')
  P:poly({ { 9.6, 24 + b }, { 11.6, 27 + b }, { 11.8, 28.8 + b }, { 9.8, 26 + b } }, 'j')
  -- a fronde: o talo sobe vergado, com os lobos alternados da família (compridos do lado de fora, curtos do lado do
  -- báculo), e a ponta enrola no sentido do relógio. O báculo pende para a frente, fora do eixo do talo (um "?", não
  -- uma flor no cabo), e os lobos de fora dele vão sumindo ao longo da volta: sem coroa de pétalas.
  local R0 = alert and 6.1 or (crouch and 4.6 or 5.6 + sw * 0.2)
  local turns = alert and 1.25 or (crouch and 1.8 or 1.5 - sw * 0.05)
  local cx, cy = 14.8 + R0 + ln, 11.6 + b + (crouch and 1.6 or 0)
  local coil = {}
  local n1 = floor(turns * 12 + 0.5)
  for n = 0, n1 do
    local t = n / n1
    local a = rad(180 + t * turns * 360)
    local r = R0 * (1 - t) ^ 0.85 + 1.0 * t
    coil[#coil + 1] = { cx + cos(a) * r, cy + sin(a) * r }
  end
  local stalk = { { 16.4, 25.4 + b }, { 14.6 + ln * 0.2, 21.2 + b }, { 13.6 + ln * 0.5, 17.6 + b },
    { 13.8 + ln * 0.8, 14.6 + b + (crouch and 0.8 or 0) }, coil[1] }
  local function wag(n) return alert and (n % 2 == 0 and -10 or 0) or (still and 0 or 4 * sin(ph * 1.571 + n * 0.9)) end
  local i = -1
  local lobes = Fr.frond(P, stalk, { n = 3, t0 = 0.14, t1 = 0.98, ang = 50, r0 = 0.7, r1 = 0.55, fat = 1.35, wag = wag,
    w = function(t)                                          -- pinas separadas, com vão entre elas
      i = i + 1
      return i % 2 == 0 and (6.6 - 1.6 * t) or (3.8 - 1.0 * t)
    end,
    mat = function(n) if n == 3 then return 'g', 'n' end return 'f', 'a' end })
  local j = -1
  local inner = Fr.frond(P, coil, { n = 8, t0 = 0.03, t1 = 0.84, ang = 58, r0 = 0.55, r1 = 0.45, fat = 2.6, wag = wag,
    w = function(t)                                          -- os de fora somem ao longo da volta; os de dentro enchem o rolo
      j = j + 1
      return j % 2 == 0 and (3.2 * (1 - t) ^ 2.6 + 0.7) or (2.5 * (1 - t) ^ 0.7 + 1.0)
    end,
    mat = function(n) if n % 7 == 3 then return 'y', 'J' elseif n % 7 == 6 then return 'g', 'n' end return 'f', 'a' end })
  for _, q in ipairs(inner) do lobes[#lobes + 1] = q end
  Fr.shadeAll(g, k)
  Fr.veins(g, P, k > 1 and lobes or nil, Fr.LEAF .. Fr.DRY, ph, 4)
  -- a pupila: o escuro da junta em volta do broto
  local tip = coil[#coil]
  local pr = alert and 2.1 or 1.5
  if not crouch then
    P:disc(tip[1], tip[2], pr, 'k')
    if k > 1 then P:disc(tip[1], tip[2], 0.6, 'H') end
    P:px(tip[1], tip[2], 'G')
    if k > 1 then L.set(g, P:X(tip[1]) - 1, P:Y(tip[2]) - 1, 'G') end
  end
  -- trinca na placa
  P:limb({ { 20.4, 23.2 + b }, { 21.4, 24.8 + b }, { 20.8, 26.2 + b } }, 0.3, 0.3, 'k', Fr.CONC)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  Fr.seam(P, { { 12.6, 23.8 + b }, { 14, 28.4 + b } }, w, '9', Fr.CONC, k > 1 and 2 or nil)
  local a0, a1 = lobes[1], lobes[3]
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
    -- espalhados: braçadeiras no talo, guirlanda nas raízes, colar pendurado no báculo, pano na placa, óculos no
    -- olho do báculo, auréola, marca na placa
    urban = { 11, 18 }, green = { 12, 29 }, water = { 17, 14 }, residential = { 10, 24 }, lit = { 17, 10 },
    sacred = { 16, 1 }, crimson = { 22, 23 },
  },
}
