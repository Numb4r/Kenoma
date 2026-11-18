-- Pebblet (clod.eco, 0.25.1): bicho de cascalho que se fecha em bola. Rodar pelo Aseprite: aseprite -b --script build.lua
-- Corpo: carapaca de faixas de cascalho ocre e cinza, cabeca redonda a direita, tres pes. Leds: os dois olhos.
-- Glow: a costura do Veu entre as pedras (apagada parada; acende no alerta, na fuga, ao surgir e na sintonia).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#6E5136', B = '#9A7448', T = '#C79A5B', H = '#EACB92', -- cascalho ocre
  g = '#58524E', G = '#857C72', M = '#B4AA9C',                -- cascalho cinza
  F = '#4A3A30',                                              -- pes
  e = '#3A2C30', E = '#FFE9B8',                               -- olho apagado e aceso (leds)
  j = '#463654', J = '#9B7BFF', Y = '#D8CCFF',                -- costura do Veu apagada e acesa (glow)
  S = '#F0C878', s = '#FFF2D0',                               -- faisca (glow)
}

local function bands(D, px, py, step)
  D.each(function(mx, my, c)
    if c ~= 'B' then return end
    local d = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2) / step
    if d - math.floor(d) < (D.s > 1 and 0.5 or 1) / step then return 'j' end
    if math.floor(d) % 2 == 1 then return 'G' end
  end)
end

local function draw(D, o)
  local p = o.p or 0
  if p == 'ball' then
    local a = math.rad(200 + (o.rot or 0) * 50)
    D.ell(13.5, 15, 8, 8, 'B')
    bands(D, 13.5 + 8.5 * math.cos(a), 15 + 8.5 * math.sin(a), 4)
    D.rim('B', 'T', 'K'); D.rim('G', 'M', 'g')
    D.speck('B', 'K', 11, 1); D.speck('G', 'g', 11, 2)
    return
  end
  local up = (p == 1 or p == 2) and 0.5 or (p == 'alert' and 1 or (p == 'crouch' and -1 or 0))
  local hy = (p == 2 and -1 or 0) + (p == 'alert' and -2 or 0) + (p == 'crouch' and 1 or 0)
  local hx = p == 'crouch' and -1 or 0
  -- pes (os da ponta levantam no meio do passo)
  local lift = (p == 1 or p == 2) and 1 or 0
  D.rect(5, 21, 6, 23 - lift, 'F'); D.rect(10, 21, 11, 23, 'F'); D.rect(15, 21, 16, 23 - lift, 'F')
  D.rect(21 + hx, 21, 22 + hx, 23, 'F')
  -- carapaca
  D.ell(11.5, 14.5 - up, 9, 8 + up, 'B')
  D.each(function(_, my, c) if c == 'B' and my > 21.4 then return 'F' end end)
  bands(D, 1.5, 23, 4.6)
  D.rim('B', 'T', 'K'); D.rim('G', 'M', 'g')
  D.speck('B', 'K', 11, 1); D.speck('G', 'g', 11, 2); D.speck('T', 'H', 9, 3)
  -- cabeca
  D.ell(19.5 + hx, 17 + hy, 5.5, 5.5, 'j', 'BTKGMg')
  D.ell(19.5 + hx, 17 + hy, 4.5, 4.5, 'Q')
  D.rim('Q', 'H', 'B')
  D.swap('Q', 'T')
  local ey = 15 + hy
  D.rect(19 + hx, ey, 19 + hx, ey + (p == 'crouch' and 0 or 1), 'E')
  D.rect(22 + hx, ey, 22 + hx, ey + (p == 'crouch' and 0 or 1), 'E')
  if D.s > 1 then D.line(20.5 + hx, 19.5 + hy, 22.5 + hx, 19.5 + hy, 'K', nil, 0.4) end
end

K.run {
  name = 'pebblet', W = 28, LEG = LEG, draw = draw, DARK = 'F',
  BODY_KEYS = { 'K', 'B', 'T', 'H', 'g', 'G', 'M', 'F' },
  EMIS = { E = { 'e', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'J' } },
  ps = 3,
  over = {
    flee = function(_, os) -- fecha em bola e rola
      for i = 2, 6 do os[i].p = 'ball'; os[i].rot = i - 2; os[i].lean = false end
      return os
    end,
  },
  acc = {
    urban = { 4, 15 }, green = { 5, 7 }, water = { 13, 13 }, residential = { 16, 11 }, lit = { 16, 18 },
    sacred = { 16, 8 }, crimson = { 9, 10 },
  },
}
