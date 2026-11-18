-- Glimlet (glare.eco, 0.25.1): reflexo vivo em vitrines e farois. Rodar: aseprite -b --script build.lua
-- Corpo: lente redonda de vidro com oito raios que alternam de comprimento (o cintilar). Leds: o brilho em cruz
-- no alto da lente. Glow: o aro de luz embaixo da lente e o fio de luz de cada raio (apagados parada, como diz o Bestiario:
-- "de noite quase nao se ve"; acendem no alerta e na fuga, quando ele ofusca).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#A8873C', B = '#D6B658', T = '#F4DE88', H = '#FFF8D6', -- vidro dourado
  D = '#5A4630',                                              -- olho
  i = '#FBEFB8', I = '#FFFFFF',                               -- brilho em cruz apagado e aceso (leds)
  j = '#EAD890', J = '#FFF3B0', c = '#EDDA94', C = '#FFFFFF', -- fio do raio e miolo (glow)
  S = '#FFF3B0', s = '#FFFFFF',                               -- faisca (glow)
}
local CX, CY = 13.5, 14

local function ray(D, deg, len, hw)
  local a = math.rad(deg)
  local dx, dy = math.cos(a), math.sin(a)
  D.poly({ { CX - dy * hw, CY + dx * hw }, { CX + dx * len, CY + dy * len }, { CX + dy * hw, CY - dx * hw } }, 'B')
  D.line(CX, CY, CX + dx * (len - 2.2), CY + dy * (len - 2.2), 'j', nil, D.s > 1 and 0.5 or 1)
end

local function draw(D, o)
  local p = o.p or 0
  local v = ({ [0] = 10, 8.5, 7, alert = 10, crouch = 7 })[p]
  local h = ({ [0] = 7.5, 8.5, 10, alert = 10, crouch = 7 })[p]
  local d = ({ [0] = 7.6, 7, 7.6, alert = 8.2, crouch = 6.2 })[p]
  ray(D, 45, d, 1.6); ray(D, 135, d, 1.6); ray(D, 225, d, 1.6); ray(D, 315, d, 1.6)
  ray(D, 90, v, 2.6); ray(D, 270, v, 2.6); ray(D, 0, h, 2.6); ray(D, 180, h, 2.6)
  D.rim('B', 'T', 'K')
  -- lente
  local ry = p == 'crouch' and 4.5 or 5.5
  D.ell(CX, CY, 5.5, ry, 'Q')
  D.rim('Q', 'H', 'B')
  D.swap('Q', 'T')
  if D.s > 1 then D.ell(CX + 0.6, CY + 0.6, 4.2, ry - 1.3, 'B', 'T'); D.ell(CX, CY, 3.8, ry - 1.7, 'T', 'B') end
  -- aro de luz por dentro da borda de baixo da lente
  D.each(function(mx, my, c)
    local r = math.sqrt((mx - CX) ^ 2 + ((my - CY) * 5.5 / ry) ^ 2)
    if (c == 'T' or c == 'B') and r > 3.6 and r <= 4.6 and my > CY + 0.5 then return 'c' end
  end)
  -- brilho em cruz, no alto a esquerda da lente
  D.rect(10, 10, 12, 10, 'I'); D.rect(11, 9, 11, 11, 'I')
  -- olhos
  local ey = p == 'crouch' and 14 or 13
  D.rect(14, ey, 14, ey + (p == 'crouch' and 0 or 1), 'D'); D.rect(17, ey, 17, ey + (p == 'crouch' and 0 or 1), 'D')
  if p == 'alert' then D.rect(13, ey, 14, ey + 1, 'D'); D.rect(16, ey, 17, ey + 1, 'D') end
end

K.run {
  name = 'glimlet', W = 28, LEG = LEG, draw = draw, DARK = 'K',
  BODY_KEYS = { 'K', 'B', 'T', 'H', 'D' },
  EMIS = { I = { 'i', 'l' }, J = { 'j', 'w' }, C = { 'c', 'w' } },
  heat = { alt = { j = 'J', c = 'C' }, all = { j = 'J', c = 'C' } },
  ps = 3.4,
  acc = {
    urban = { 11, 16 }, green = { 8, 17 }, water = { 10, 15 }, residential = { 10, 16 }, lit = { 10, 16 },
    sacred = { 10, 5 }, crimson = { 9, 12 },
  },
}
