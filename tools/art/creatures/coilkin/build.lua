-- Coilkin (hum.spirit, 0.25.1): um corpo feito de fios desencapados; a forma Espirito do Humoth, com as mesmas
-- cores (indigo, ciano, amarelo). Rodar: aseprite -b --script build.lua
-- Corpo: cabeca e tronco de bobina, antenas em gancho, bracos e pernas de fio que andam aos trancos.
-- Leds: os dois olhos ciano (os ocelos do Humoth). Glow: o cobre nu, sempre aceso como os veios do Humoth: as
-- pontas dos fios e a volta descascada do tronco; clareia no alerta e na fuga.
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  B = '#8F86C9', T = '#C4BDF0',                               -- antena (as cores do Humoth)
  C = '#2A2140', D = '#4A3D6B', R = '#6A5C94',                -- bobina da cabeca e pernas
  G = '#34305E', F = '#4D4A8A', E = '#7672B8',                -- capa dos fios do tronco e dos bracos
  h = '#17444C', i = '#245A62', j = '#6B5A44',                -- olho e cobre apagados (corpo)
  H = '#5FD3C6', I = '#D9FFF6',                               -- olho aceso (leds)
  J = '#FFD84A', Y = '#FFF3A8', S = '#FFD84A', s = '#FFF3A8', -- cobre nu e faisca (glow)
}

local function wire(D, pts, c, t, tip)
  for k = 1, #pts - 1 do D.line(pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2], c, nil, t) end
  if tip ~= false then
    local q = pts[#pts]
    D.ell(q[1] + (t >= 2 and 0.5 or 0), q[2], 1, 1, 'J')
  end
end
local function mir(pts)
  local o = {}
  for k, q in ipairs(pts) do o[k] = { 34 - q[1], q[2] } end
  return o
end

local ARM = {
  rest = { { 13, 19 }, { 8, 20 }, { 5, 24 }, { 5, 28 } },
  jerk = { { 13, 19 }, { 8, 18 }, { 4, 20 }, { 3, 23 } },
  up = { { 13, 19 }, { 8, 17 }, { 4, 13 }, { 3, 9 } },
  tuck = { { 13, 21 }, { 9, 23 }, { 8, 27 }, { 9, 30 } },
}

local function draw(D, o)
  local p = o.p or 0
  local sq = p == 'crouch' and 2 or 0
  local hx = p == 1 and -1 or (p == 2 and 1 or 0)
  -- tronco: bobina com uma volta descascada
  D.ell(17.5, 21.5 + sq * 0.5, 5.5, 5.5 - sq * 0.5, 'F')
  D.each(function(mx, my, c)
    local k = math.floor((mx * 0.5 + my) / 2)
    if k == 15 then return 'J' end
    if k % 2 == 0 then return 'G' end
  end)
  D.rim('F', 'E', nil)
  -- pernas
  local fl, fr = p == 1 and 1 or 0, p == 2 and 1 or 0
  wire(D, { { 15, 26 }, { 13, 29 - fl }, { 11, 31 - fl } }, 'D', 2)
  wire(D, { { 20, 26 }, { 22, 29 - fr }, { 24, 31 - fr } }, 'D', 2)
  -- pescoco e cabeca
  D.rect(17, 15 + sq, 18, 17 + sq, 'C')
  local hy = 12.5 + sq
  D.ell(17.5 + hx, hy, 5.5, 4, 'D')
  D.rect(12, hy - 1.5, 23, hy - 1.5, 'C', 'D'); D.rect(12, hy + 1.5, 23, hy + 1.5, 'C', 'D')
  D.rim('D', 'R', 'C')
  D.rect(16 + hx, hy - 0.5, 17 + hx, hy + 0.5, 'H'); D.rect(20 + hx, hy - 0.5, 21 + hx, hy + 0.5, 'H')
  D.px(16 + hx, hy - 0.5, 'I'); D.px(20 + hx, hy - 0.5, 'I')
  -- antenas em gancho
  local top = hy - 3.5
  if p == 'alert' then
    wire(D, { { 15 + hx, top }, { 13, top - 3 }, { 12, top - 5 } }, 'B', 1)
    wire(D, { { 20 + hx, top }, { 22, top - 3 }, { 23, top - 5 } }, 'B', 1)
  else
    local tw = p == 2 and 1 or 0
    wire(D, { { 15 + hx, top }, { 14, top - 3 }, { 12, top - 4.5 }, { 10, top - 4 }, { 10, top - 2 + tw } }, 'B', 1)
    wire(D, { { 20 + hx, top }, { 21, top - 3 }, { 23, top - 4.5 }, { 25, top - 4 }, { 25, top - 2 - tw } }, 'B', 1)
  end
  D.rim('B', 'T', nil, 1)
  -- bracos: um de cada vez da o tranco
  local la = ({ [0] = 'rest', 'jerk', 'rest', alert = 'up', crouch = 'tuck' })[p]
  local ra = ({ [0] = 'rest', 'rest', 'jerk', alert = 'up', crouch = 'tuck' })[p]
  wire(D, ARM[la], 'F', 2); wire(D, mir(ARM[ra]), 'F', 2)
  D.rim('F', 'E', 'G')
end

K.run {
  name = 'coilkin', W = 36, LEG = LEG, draw = draw, DARK = 'C',
  BODY_KEYS = { 'G', 'F', 'E', 'C', 'D', 'R', 'B', 'T' },
  EMIS = { H = { 'h', 'l' }, I = { 'i', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { J = 'Y' }, all = { J = 'Y' } },
  ps = 2.5,
  acc = {
    urban = { 15, 20 }, green = { 12, 15 }, water = { 14, 16 }, residential = { 14, 15 }, lit = { 14, 16 },
    sacred = { 14, 6 }, crimson = { 16, 19 },
  },
}
