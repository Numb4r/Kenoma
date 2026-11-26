-- Fairkin (sprig.spirit), arte final: o Espírito da família Sprig, a partir do conceito aprovado (a forma está no
-- _sprig.lua, com pose). A maritaca tomada pela árvore: quatro asas de folha (uma já só nervura), dois olhos do
-- mesmo lado, folha de topete, casca subindo pela barriga, raízes agarradas a um caco de pedra portuguesa.
-- Costuras do Véu: duas, mais largas que as do Eco, na pena do corpo, só no glow.
-- Camadas: corpo; leds = o brilho dos olhos e a ponta das nervuras (piscam); glow = as nervuras, os olhos, as
-- costuras e o pólen solto.
-- Animação (laço de 8 quadros): pousada na pedra, não sobe nem desce (body_dy 0). As quatro asas abanam cada uma no
-- seu passo (a de cá e a de lá em sentidos opostos, a escura atrasada, a de nervura mais curta), a cabeça vira o bico
-- para baixo e volta, a folha de topete e o rabo de graveto balançam, o peito respira. Na deriva o corpo inclina
-- sobre as raízes e a pedra fica reta. No alerta as asas abrem em leque e a cabeça ergue; na antecipação o corpo
-- senta na pedra com as asas fechadas; na fuga ela salta com a pedra, inclinada.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/fairkin/build.lua')
local Sp = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_sprig.lua')
local L = Sp.L
local sin, cos, pi = math.sin, math.cos, math.pi

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 8
  local ph = (o.ph or 0) % NL
  local t = ph / NL * 2 * pi
  local a
  if o.pose == 'alert' then a = { w = { 12, 8, 9, 11 }, hd = -14, hy = -0.4, top = -14, tw = -0.6 }
  elseif o.pose == 'crouch' then a = { w = { 16, -8, -14, -26 }, l = { 0.7, 0.85, 0.75, 0.8 }, hd = 12, hy = 0.6, sq = 1, br = 1, top = 20, tw = 0.8 }
  elseif o.pose == 'half' then a = { w = { 8, -4, -6, -14 }, l = { 0.85, 0.9, 0.85, 0.9 }, hd = 6, sq = 0.5 }
  else
    local m = o.portrait and 0.5 or 1
    a = { w = { -9 * m * sin(t), 8 * m * sin(t), 8 * m * (1 - cos(t)), 13 * m * sin(t) },
      hd = m * 10 * (1 - cos(t)), hy = m * 0.25 * (1 - cos(t)), top = 14 * sin(t + 1) - 14 * sin(1), tw = 0.8 * sin(t),
      br = (1 - cos(t)) / 2, tilt = o.dash and 10 or (o.lean and 6 or 0) }
    if o.dash then a.w[4] = -12 + 6 * sin(t) end                 -- no salto a asa de cá vai varrida para trás
  end
  local src = Sp.C.espirito(k, g.w, a)
  Sp.place(g, sg, src, { k = k, ph = ph % 4, NL = 4, piv = 28, dark = o.dark,
    hot = (not o.pose and ph % 4 == 2) and 1 or 0 })
end

Sp.run {
  name = 'fairkin', stage = 'espirito', W = 36, PW = 96, draw = draw,
  nloop = 8, dy = { 0, 0, 0, 0, 0, 0, 0, 0 }, fleeDy = { 0, 0, -1, -1, -1, -1 },
  over = {
    flee = function(_, os) for i = 2, #os do os[i].dash = true end return os end,
    spawn = function(_, os) os[5].pose = 'half'; return os end,
  },
  -- o retrato é o mesmo desenho feito em 96, com a textura no pixel
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 96 / 36, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 17, 19 }, green = { 14, 21 }, water = { 16, 18 }, residential = { 16, 19 }, lit = { 16, 20 },
    sacred = { 20, 4 }, crimson = { 19, 18 },
  },
}
