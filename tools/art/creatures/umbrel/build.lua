-- Umbrel (shade.eco, 0.25.1): a sombra que fica quando a pessoa vai embora. Rodar: aseprite -b --script build.lua
-- Corpo: vulto de cabeca e ombros, barra rasgada que ondula e uma ponta que escorre para tras, como sombra no chao.
-- Leds: os dois olhos claros. Glow: a costura do Veu no peito (apagada parada; acende no alerta e na fuga).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#2C2340', B = '#43365E', T = '#5E4E82', H = '#8170AA', -- sombra
  e = '#57506C', E = '#F0EEF8',                               -- olho apagado e aceso (leds)
  j = '#33284C', J = '#9B7BFF', Y = '#D8CCFF',                -- costura do Veu (glow)
  S = '#9B7BFF', s = '#D8CCFF',                               -- faisca (glow)
}

local function draw(D, o)
  local p = o.p or 0
  local tall = p == 'alert' and 1 or (p == 'crouch' and -2 or 0)
  local hy = -tall + (p == 2 and -0.5 or 0)
  local sw = p == 'alert' and 1.5 or (p == 'crouch' and 1 or 0)
  local ph = (p == 1 and 1.6 or (p == 2 and 3.2 or 0))
  -- manto: ombros, lados abrindo ate a barra, ponta escorrendo para a esquerda
  D.poly({ { 12, 11 + hy }, { 18, 11 + hy }, { 21.5 + sw, 14.5 + hy }, { 23, 20 }, { 23.5, 26 }, { 4, 26 },
    { 6, 20 }, { 8.5 - sw, 14.5 + hy } }, 'B')
  D.poly({ { 6.5, 18 }, { 2.6, 24.4 }, { 9, 24.4 } }, 'B')
  D.each(function(mx, my)
    if my > 23.4 + 1.2 * math.sin(mx * 1.15 + ph) - (mx < 6 and -1.5 or 0.6) then return '.' end
  end)
  D.ell(15, 8.5 + hy, 4, 4, 'B')
  D.rim('B', 'T', 'K')
  if D.s > 1 then
    D.rim('T', 'H', nil, 1)
    D.speck('B', 'K', 13, 1)
  end
  -- bracos colados ao corpo e a costura
  D.line(10.5 - sw, 16 + hy, 9.5 - sw, 21, 'K', 'B', 0.6)
  D.line(20 + sw, 16 + hy, 21, 21, 'K', 'B', 0.6)
  D.line(15, 15 + hy, 15, 19, 'j', nil, D.s > 1 and 0.6 or 1)
  -- olhos
  local big = p == 'alert' and 1 or 0
  local ey = 8 + hy
  if p == 'crouch' then
    D.rect(15, ey + 1, 15, ey + 1, 'E'); D.rect(18, ey + 1, 18, ey + 1, 'E')
  else
    D.rect(15 - big, ey, 15, ey + 1, 'E'); D.rect(18 - big, ey, 18, ey + 1, 'E')
  end
end

K.run {
  name = 'umbrel', W = 28, LEG = LEG, draw = draw, DARK = 'K',
  BODY_KEYS = { 'K', 'B', 'T', 'H' },
  EMIS = { E = { 'e', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'Y' } },
  ps = 3,
  acc = {
    urban = { 11, 20 }, green = { 9, 11 }, water = { 11, 12 }, residential = { 11, 11 }, lit = { 11, 12 },
    sacred = { 11, 3 }, crimson = { 9, 15 },
  },
}
