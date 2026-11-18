-- Rustling (rust.eco, 0.25.1): ferrugem viva em grades e portoes. Rodar: aseprite -b --script build.lua
-- Corpo: um pedaco de grade (duas barras com ponta de lanca e a travessa) que anda sobre as proprias barras,
-- com a mancha de ferrugem agarrada no meio. Leds: os dois olhos. Glow: as brasas de ferrugem na mancha
-- (apagadas parada; acendem no alerta e na fuga).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  n = '#3C4552', N = '#66768A', M = '#9FB3C8',                -- ferro da grade
  K = '#5E2A1C', B = '#8E4424', T = '#B8612E', H = '#E08A44', -- ferrugem
  e = '#3A2420', E = '#FFE6C0',                               -- olho apagado e aceso (leds)
  j = '#70301A', J = '#FF7A45', Y = '#FFC890',                -- brasa apagada e acesa (glow)
  S = '#FF7A45', s = '#FFD8B0',                               -- faisca (glow)
}

local function bar(D, x, top, bottom)
  D.rect(x, top, x + 1, bottom, 'N')
  D.rect(x, top, x, bottom - 3, 'M')
  D.rect(x, bottom - 1, x + 1, bottom, 'n')
  D.poly({ { x - 0.5, top - 0.5 }, { x + 1.5, top - 0.5 }, { x + 0.5, top - 3 } }, 'M')
end

local function draw(D, o)
  local p = o.p or 0
  local la = (p == 1 and 1 or 0) + (p == 'alert' and 1 or 0) + (p == 'crouch' and -1 or 0)
  local lb = (p == 2 and 1 or 0) + (p == 'alert' and 1 or 0) + (p == 'crouch' and -1 or 0)
  local sq = p == 'crouch' and 1 or ((p == 1 or p == 2) and -0.4 or 0)
  -- grade
  bar(D, 8, 8 - la, p == 'crouch' and 24 or 25 - la); bar(D, 19, 8 - lb, p == 'crouch' and 24 or 25 - lb)
  local cy = 9 - math.max(la, lb, 0)
  D.rect(5, cy, 23, cy + 1, 'N'); D.rect(5, cy, 23, cy, 'M')
  -- mancha
  D.ell(14, 16.5 + sq * 0.5, 8.5 + sq, 6 - sq * 0.5, 'B')
  D.ell(8.5, 14, 3.5, 3.2, 'B'); D.ell(19.5, 13.5, 3.4, 3, 'B')
  D.ell(10.5, 20.5, 3.2, 2.8, 'B'); D.ell(18.5, 20.8, 3.4, 2.8, 'B')
  D.rect(12, 22, 12, 24 - (p == 2 and 1 or 0), 'B'); D.rect(16, 22, 16, 23 + (p == 1 and 1 or 0), 'B')
  D.rim('B', 'T', 'K')
  if D.s > 1 then
    D.rim('T', 'H', nil, 1)
    D.speck('B', 'K', 9, 1); D.speck('B', 'T', 13, 2)
  end
  -- brasas
  for _, q in ipairs({ { 10, 17 }, { 12.5, 20 }, { 17, 19 }, { 21, 16 }, { 12, 13.5 }, { 16.5, 12.5 }, { 7.5, 14 } }) do
    D.ell(q[1], q[2] + sq * 0.5, 0.5, 0.5, 'j', 'BTKH')
  end
  -- olhos
  local big = p == 'alert' and 1 or 0
  local ey = 15 + (p == 'crouch' and 1 or 0)
  D.rect(15 - big, ey, 15, ey + (p == 'crouch' and 0 or 1), 'E')
  D.rect(19 - big, ey, 19, ey + (p == 'crouch' and 0 or 1), 'E')
end

K.run {
  name = 'rustling', W = 28, LEG = LEG, draw = draw, DARK = 'K',
  BODY_KEYS = { 'n', 'N', 'M', 'K', 'B', 'T', 'H' },
  EMIS = { E = { 'e', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'Y' } },
  ps = 3,
  acc = {
    urban = { 11, 19 }, green = { 8, 11 }, water = { 10, 11 }, residential = { 10, 11 }, lit = { 10, 18 },
    sacred = { 10, 3 }, crimson = { 9, 15 },
  },
}
