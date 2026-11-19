-- Frondling (frond.eco), arte final: o Eco da família Frond, a partir do conceito aprovado. Uma fronde de Charnia em
-- pé, a ponta ainda enrolada em báculo virada para a direita, andando sobre as cinco raízes do disco de fixação.
-- O errado é pouco: os lobos não se espelham (um lado, depois o outro), um já secou, a raiz segura uma lasca de
-- calçada e a nervura do talo é um fio de luz.
-- Costuras do Véu: quatro, de 1 px, atravessadas nos lobos, só no glow; apagadas ficam quase na cor da folha.
-- Camadas: corpo; leds = o broto na ponta do báculo (pisca); glow = a nervura, as costuras e os esporos.
-- Bicho de chão: o tronco sobe e desce (body_dy) e as raízes ficam; a fronde balança para trás e volta; na deriva
-- as raízes andam e a fronde fica para trás; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/frondling/build.lua')
local Fr = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_frond.lua')
local L, F = Fr.L, Fr.F
local sin = math.sin

local STEM = { { 12.4, 21 }, { 12.4, 17 }, { 13.4, 13 }, { 15.6, 9.4 }, { 18.8, 6.8 }, { 22, 6 }, { 24.2, 7.4 }, { 24.2, 10 }, { 22.4, 11 }, { 21, 9.8 } }
local ROOTS = { { 11.4, 21.4, 7.4, 19.8, 4, 24.4 }, { 11.8, 22, 9.8, 23, 8.6, 24.6 }, { 12.6, 22.4, 12.8, 23.6, 12.2, 24.8 },
  { 13.2, 22, 15.2, 23, 16.2, 24.6 }, { 13.6, 21.4, 17.8, 19.8, 21, 24.4 } }

local function draw(g, sg, k, o)
  local P = F.pen(g, k, k > 1 and 2 or 0, 0)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k                                  -- o tronco
  local f = o.jump and b or 0                                -- as raízes (só saem do chão no salto da fuga)
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0     -- o passo
  local sw = still and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local ln = -sw * 0.9 - (o.lean and 1.3 or 0) - (alert and 0.5 or 0)   -- a fronde verga para trás
  local sy = alert and 1.05 or (crouch and 0.84 or 1)
  local function T(q)                                        -- a base do talo fica; o resto verga com a altura
    local h = (21 - q[2]) * sy
    return { q[1] + ln * (h / 15) ^ 1.4, 21 - h + b }
  end
  local stem = {}
  for n, q in ipairs(STEM) do stem[n] = T(q) end
  for n, r in ipairs(ROOTS) do
    local s = (n % 2 == 0) and st or -st
    P:limb({ { r[1], r[2] + b }, { r[3] + s * 0.5, r[4] + (b + f) / 2 }, { r[5] + s, r[6] + f } }, 1.25, 0.7, 'h')
  end
  -- o báculo: a ponta ainda enrolada
  P:limb({ stem[5], stem[6], stem[7], stem[8], stem[9] }, 1.2, 0.8, 'f')
  local grow = alert and 1.1 or (crouch and 0.86 or 1)
  local lobes = Fr.frond(P, stem, { n = 7, t0 = 0.04, t1 = 0.6, ang = 48, fat = 2.6,
    w = function(t) return (2.2 + 4.6 * sin(3.14 * (0.14 + 0.82 * t / 0.6)) ^ 0.8) * grow end,
    wag = function(i) return alert and 8 or (still and 0 or 5 * sin(ph * 1.571 + i * 0.9)) end,
    mat = function(i) if i == 3 then return 'g', 'n' end return 'f', 'a' end })
  P:ell(12.5, 21.8 + b, 2.2, 1.4, 'h')
  P:poly({ { 14.4, 21 + b }, { 16.2, 20.6 + b }, { 16.6, 22 + b }, { 14.8, 22.4 + b } }, 'y')   -- a lasca de calçada presa na raiz
  Fr.shadeAll(g, k)
  Fr.veins(g, P, k > 1 and lobes or nil, Fr.LEAF .. Fr.DRY, ph, 4)
  -- costuras do Véu: quatro, finas, cada uma atravessada num lobo
  for _, n in ipairs({ 1, 6, 9, 12 }) do Fr.lobeSeam(P, lobes[n], 1, 0.55, k > 1 and 1.3 or nil) end
  -- o broto na ponta do báculo
  local tip = stem[#stem]
  if k > 1 then P:disc(tip[1], tip[2], 0.45, 'H', 'DEBm'); end
  P:px(tip[1], tip[2], 'G')
  Fr.clean(g, 'frondling', 'a', 4 * k * k)
  Fr.spores(P, sg, { { 25.2, 13.4 }, { 5.4, 9 }, { 24.4, 17.6 } }, ph, 4)
end

Fr.run {
  name = 'frondling', stage = 'eco', W = 28, PW = 96, draw = draw, ownLean = true,
  fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho do mapa ampliado 3,3 vezes, com detalhe (os lobinhos, o fio de cada lobo, pontos nas costuras)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 10, 17 }, green = { 7, 20 }, water = { 9, 11 }, residential = { 9, 14 }, lit = { 9, 16 },
    sacred = { 8, 6 }, crimson = { 11, 14 },
  },
}
