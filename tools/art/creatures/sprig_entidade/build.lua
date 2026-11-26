-- Entidade Maior da família Sprig (nome e pasta provisórios: sprig_entidade), arte final a partir do conceito
-- aprovado da rodada 3, com o ajuste do dono. O desenho está no _sprig.lua (entidade).
-- O bando fundido num corpo só de pena verde-oliva.
-- AJUSTE DO DONO: não é mais uma moita. Quatro cabeças de maritaca, cada uma no seu pescoço e virada para um lado
-- (para cima, para a frente, para baixo e para trás), com o anel do olho, a mancha azul da garganta e o bico cor de
-- chifre; a da frente grita, com a garganta acesa. A folha seca fica só nas duas asas.
-- REGRA QUEBRADA: as asas estão cada uma num ponto diferente da batida e o corpo não cai.
-- Costura do Véu: uma, larga, no peito, só no glow.
-- Camadas: corpo; leds = o brilho dos olhos e a ponta das nervuras (piscam); glow = as nervuras, os olhos, a
-- garganta que grita, a costura e o pólen solto.
-- Animação (6 quadros, lenta): as duas asas batem em sentidos opostos, cada cabeça sobe e desce no seu passo, o
-- corpo paira. No alerta as asas abrem; na antecipação fecham e as cabeças baixam.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/sprig_entidade/build.lua')
local Sp = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_sprig.lua')
local L = Sp.L

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local src = Sp.C.entidade(k, g.w, { t = (alert or crouch) and 0 or ph / NL * 2 * math.pi, flap = alert and 1.4 or (crouch and -1.4 or nil), crouch = crouch })
  Sp.place(g, sg, src, { k = k, ph = ph, NL = NL, dark = o.dark, sway = o.lean and math.max(1, k * 0.6) or nil, piv = 44 })
end

Sp.run {
  name = 'sprig_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 19, 28 }, green = { 16, 30 }, water = { 18, 27 }, residential = { 18, 28 }, lit = { 18, 29 },
    sacred = { 32, 4 }, crimson = { 21, 28 },
  },
}
