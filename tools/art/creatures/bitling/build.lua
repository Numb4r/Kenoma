-- Bitling (bit.eco), arte final: o Eco da família Bit, a partir do conceito aprovado. O pombo de perfil, em proporção
-- de pombo. O errado é pouco: uma faixa do corpo está dois pixels fora do lugar (a ponta de trás magenta de pena, a
-- da frente acesa), as barras da asa acendem onde a faixa passa e o brilho do pescoço é feito de subpixels.
-- Costuras do Véu: três, curtas e de 1 px (dorso, barriga, alto da cabeça), só no glow, longe do pescoço aceso.
-- Camadas: corpo; leds = os subpixels do pescoço (piscam); glow = a franja do glitch, as barras acesas, as costuras
-- e o pixel solto.
-- Animação: a cabeça balança (o passo do pombo), a faixa fora do lugar muda de linha e de lado a cada quadro, o
-- tronco sobe e desce e os pés ficam. Na deriva ele anda; na fuga, salta. No alerta o glitch dobra.
-- O mapa é desenhado pixel a pixel (sem o contorno); o retrato é o mesmo pombo desenhado em 96 (escala 3).
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/bitling/build.lua')
local B = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_bit.lua')
local L = B.L
local floor = math.floor

local ROWS = {
  '............................', '............................', '............................',
  '............................',
  '.................cddc.......',
  '................bcdedc......',
  '................bcdcrdh.....',
  '................abcdccqq....',
  '................aGbNc.......',
  '...............aNbGbc.......',
  '..............abGbNQcd......',
  '............abcbGbNccde.....',
  '.........abccdcdccbccdee....',
  '.......abcdcdcfdcfccdede....',
  '......abcdcdcffdcffcdcde....',
  '.....abcbcdcdffcdffcdcd.....',
  '....fabcbcdcdcffdcffdcc.....',
  '...ffabcbcbcdcdffcfcbb......',
  '...fafabcbcbcbcdcdcba.......',
  '...faf.ababcbcbcbcba........',
  '...f........b...b...........',
  '............j...j...........',
  '............i...i...........',
  '...........jijjjijj.........',
  '............................', '............................', '............................', '............................',
}
local TEAR = { [0] = { 15, 16, 2 }, { 15, 16, 2 }, { 12, 13, -1 }, { 16, 17, 1 } }
local SEAMS = { { 7, 17 }, { 8, 18 }, { 18, 18 }, { 19, 17 }, { 17, 5 }, { 18, 4 } }
local DUST = { { 1, 14 }, { 26, 18 }, { 2, 22 }, { 5, 24 }, { 24, 10 }, { 3, 12 }, { 25, 22 } }

-- as linhas 0..y1 sobem ou descem dy; a perna (a linha y1 + 1) estica para cobrir
local function vshift(g, y1, dy)
  if dy == 0 then return g end
  local o = L.grid(g.w, g.h)
  for y = y1 + 1, g.h - 1 do for x = 0, g.w - 1 do o[y][x] = g[y][x] end end
  if dy < 0 then for y = y1 + dy + 1, y1 do for x = 0, g.w - 1 do o[y][x] = L.get(g, x, y1 + 1) end end end
  for y = 0, y1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' then L.set(o, x, y + dy, g[y][x]) end
  end end
  return o
end

local function drawMap(g, sg, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local t = L.frame(ROWS, 28, 28, 'bitling')
  local bob = (alert or crouch) and 0 or ({ [0] = 0, 1, 1, 0 })[ph]
  B.tear(t, 4, 9, bob, false)                                   -- o balanço da cabeça
  if o.lean and ph % 2 == 1 then B.tear(t, 21, 23, 1, false) end   -- o passo
  for _, q in ipairs(SEAMS) do
    if ('abcde'):find(t[q[2]][q[1]], 1, true) then t[q[2]][q[1]] = 'Z' end
  end
  local te = alert and { 15, 16, 2 } or (crouch and { 15, 16, 1 } or TEAR[ph])
  B.tear(t, te[1], te[2], te[3])
  if alert then B.tear(t, 12, 13, -2) end
  for y = te[1], te[2] do for x = 0, 27 do if t[y][x] == 'f' then t[y][x] = 'Q' end end end
  local dy = o.dy or 0
  if crouch then t = vshift(t, 20, 1) end
  t = o.jump and vshift(t, 27, dy) or vshift(t, 20, dy)
  B.blit(g, t)
  B.dust(g, sg, 1, 0, 0, { DUST[1], DUST[2], DUST[4], DUST[5] }, ph, 4)
end

local function draw(g, sg, k, o)
  if k == 1 then return drawMap(g, sg, o) end
  local ph = (o.ph or 0) % 4
  local ox, oy = 6, 8
  local dy = o.dy or 0
  local bob = ({ [0] = 0, 0.5, 0.5, 0 })[ph]
  local function X(v) return v * k + (k - 1) / 2 + ox end
  local function Y(v) return v * k + (k - 1) / 2 + oy + dy end
  B.layer(g, function(t)
    B.pigeon(t, k, ox, oy, { by = dy, roll = ph, heads = { { 18.6, 12, 18.8, 6.4, nil, bob } } })
    for _, q in ipairs({ { 6.6, 16.4, 9, 18.4 }, { 17.6, 18.6, 20, 16.6 }, { 16.6, 5.2, 18.6, 4.2 } }) do
      B.seam(t, { { X(q[1]), Y(q[2]) }, { X(q[3]), Y(q[4]) } }, 1, 4)
    end
  end)
  local te = TEAR[ph]
  B.tear(g, Y(te[1]), Y(te[2] + 0.4), te[3] * 3)
  B.tear(g, Y(9.4), Y(9.9), ph % 2 == 0 and -3 or 2)
  for y = floor(Y(te[1])), floor(Y(te[2] + 0.4)) do for x = 0, g.w - 1 do
    if g[y][x] == 'f' and (x + y) % 3 ~= 0 then g[y][x] = 'Q' end
  end end
  B.dust(g, sg, k, ox, oy, DUST, ph, 4)
end

B.run {
  name = 'bitling', stage = 'eco', W = 28, PW = 96, draw = draw,
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 9, 13 }, green = { 6, 15 }, water = { 8, 12 }, residential = { 8, 13 }, lit = { 8, 14 },
    sacred = { 15, 1 }, crimson = { 12, 13 },
  },
}
