-- Shadekin (shade.spirit, 0.25.1): vulto alto de bracos longos, sempre de costas. Rodar: aseprite -b --script build.lua
-- Corpo: capuz pequeno, ombros curvados, manto estreito ate o chao e dois bracos que chegam ao chao, com dedos.
-- As cores sao as da Umbrel. Leds: vazio (nao tem rosto: esta de costas). Glow: a costura do Veu na espinha
-- (so tres pixels acesos na nuca parada; desce acesa pela espinha no alerta, na fuga, ao surgir e na sintonia).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#2C2340', B = '#43365E', T = '#5E4E82', H = '#8170AA', -- sombra
  j = '#33284C', J = '#9B7BFF', Y = '#D8CCFF',                -- costura do Veu (glow)
  S = '#9B7BFF', s = '#D8CCFF',                               -- faisca (glow)
}

local ARM = {
  [0] = { { 11, 12 }, { 8, 20 }, { 7, 27 }, { 7, 30 } },
  [1] = { { 11, 12 }, { 8, 20 }, { 8, 27 }, { 9, 30 } },
  [2] = { { 11, 12 }, { 7, 20 }, { 6, 27 }, { 5, 30 } },
  alert = { { 11, 11 }, { 6, 15 }, { 5, 22 }, { 5, 26 } },
  crouch = { { 11, 15 }, { 8, 22 }, { 7, 27 }, { 7, 30 } },
}

local function arm(D, pts, flip)
  local function X(x) return flip and 34 - x or x end
  for k = 1, #pts - 1 do D.line(X(pts[k][1]), pts[k][2], X(pts[k + 1][1]), pts[k + 1][2], 'B', nil, 2) end
  local q = pts[#pts]
  for _, dx in ipairs({ -1, 0.5, 2 }) do
    D.line(X(q[1]) + dx, q[2], X(q[1]) + dx * 1.4, q[2] + 2, 'K', nil, D.s > 1 and 0.6 or 1)
  end
end

local function draw(D, o)
  local p = o.p or 0
  local hy = p == 'crouch' and 3 or (p == 'alert' and -1 or 0)
  local hx = p == 1 and -0.5 or (p == 2 and 0.5 or 0)
  local ph = (p == 1 and 1.6 or (p == 2 and 3.2 or 0))
  -- manto, de costas
  D.poly({ { 14, 9 + hy }, { 21, 9 + hy }, { 25, 12 + hy }, { 23.5, 22 }, { 22.5, 33 }, { 12.5, 33 }, { 11.5, 22 },
    { 10, 12 + hy } }, 'B')
  D.each(function(mx, my) if my > 31.3 + 0.9 * math.sin(mx * 1.5 + ph) then return '.' end end)
  D.ell(17.5 + hx, 6.8 + hy, 3.2, 3.2, 'B')
  arm(D, ARM[p], false); arm(D, ARM[p], true)
  D.rim('B', 'T', 'K')
  if D.s > 1 then
    D.rim('T', 'H', nil, 1)
    D.speck('B', 'K', 13, 1)
  end
  -- dobras do capuz e do manto, e a espinha
  D.line(14.5, 13 + hy, 13.5, 28, 'K', 'B', 0.6); D.line(20.5, 13 + hy, 21.5, 28, 'K', 'B', 0.6)
  D.line(15, 10.5 + hy, 20, 10.5 + hy, 'K', 'BT', 0.6)
  D.line(17.5, 12.5 + hy, 17.5, 25, 'j', nil, D.s > 1 and 0.6 or 1)
  D.line(17.5, 12.5 + hy, 17.5, 14.5 + hy, 'J', nil, D.s > 1 and 0.6 or 1) -- a nuca fica acesa
end

K.run {
  name = 'shadekin', W = 36, LEG = LEG, draw = draw, DARK = 'K',
  BODY_KEYS = { 'K', 'B', 'T', 'H' },
  EMIS = { J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'Y', J = 'Y' } },
  ps = 2.5,
  acc = {
    urban = { 15, 21 }, green = { 12, 9 }, water = { 14, 10 }, residential = { 14, 9 }, lit = { 14, 10 },
    sacred = { 14, 3 }, crimson = { 12, 14 },
  },
}
