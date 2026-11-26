-- Glimlet (glare.eco), arte final: o Eco da família Glare, a partir do conceito aprovado. O beija-flor-tesoura
-- pairando, em proporção natural. As asas são dois cacos de vidro de corte reto, o bico é uma agulha de vidro e o papo
-- é uma lente de farol acesa. O errado é pouco: o reflexo na asa não é de nada em volta (corre pelo vidro sozinho).
-- Costuras do Véu: três, de 1 px (asa, dorso, alto da cabeça), só no glow; apagadas ficam quase na cor do material.
-- Camadas: corpo; leds = a estrela de quatro pontas na asa (pisca); glow = o papo, as duas faixas do reflexo, as
-- costuras e o brilho solto.
-- Animação: as asas batem (quatro posições), a cauda em tesoura balança, o reflexo anda pela asa. No alerta as asas
-- sobem e o papo acende; na antecipação as asas fecham para baixo.
-- As asas de vidro e o bico não têm contorno (o vidro traz a própria borda escura).
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/glimlet/build.lua')
local G = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_glare.lua')
local L = G.L

local WN = { [0] = 0, -22, -46, -20 }
local WF = { [0] = -6, -30, -50, -24 }
local DUST = { { 3, 3.6, 's' }, { 22.6, 15.4 }, { 11.4, 1.8 }, { 24.6, 5.4, 's' }, { 20.4, 18.6 }, { 2.4, 15 }, { 12.6, 25.4 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local p = { seams = true, wn = WN[ph], wf = WF[ph], tail = ({ [0] = 0, 0.5, 0, -0.5 })[ph], rc = ({ [0] = 0, 1, 2, 3 })[ph] * 0.9 }
  if alert then p.wn, p.wf, p.tail, p.rc = 8, 4, 0, 0
  elseif crouch then p.wn, p.wf, p.tail, p.rc = -75, -78, 0.8, 0 end
  G.paint(g, k, ox, oy, G.bird(k, p))
  G.prune(g)
  G.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[2], DUST[5] }, ph, 4)
end

G.run {
  name = 'glimlet', stage = 'eco', W = 28, PW = 96, draw = draw, NOPULL = G.NOPULL .. '12345gGIKXx',
  -- o retrato é o mesmo desenho feito em 96 (escala 3,3), com os pontos das costuras e o brilho do olho
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o, 1.8, 3.8)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 10, 15 }, green = { 7, 17 }, water = { 9, 13 }, residential = { 9, 14 }, lit = { 9, 15 },
    sacred = { 14, 5 }, crimson = { 12, 14 },
  },
}
