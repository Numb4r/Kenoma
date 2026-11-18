-- Bouldkin (clod.spirit, 0.25.1): pedra com musgo que anda devagar. Rodar: aseprite -b --script build.lua
-- Corpo: matacao de camadas (cinza e ocre, as pedras do Pebblet), capa de musgo do lado de onde vem a chuva,
-- quatro pes curtos que ficam no chao enquanto a pedra sobe e desce. Leds: os dois olhos.
-- Glow: as costuras do Veu entre as camadas (apagadas parada; acendem no alerta, na fuga e na sintonia).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#6E5136', B = '#9A7448', T = '#C79A5B',  -- camada ocre
  g = '#58524E', G = '#857C72', M = '#B4AA9C',  -- pedra cinza
  F = '#4A3A30',                                -- pes e rachadura
  m = '#2F5A32', N = '#4C8444', n = '#7CB45C',  -- musgo
  e = '#3A2C30', E = '#FFE9B8',                 -- olho apagado e aceso (leds)
  j = '#463654', J = '#9B7BFF', Y = '#D8CCFF',  -- costura do Veu (glow)
  S = '#F0C878', s = '#FFF2D0',                 -- faisca (glow)
}

local function draw(D, o)
  local p = o.p or 0
  local leg = ({ [0] = 3, 4, 4, alert = 4, crouch = 1 })[p]
  local step = p == 2 and 1 or 0
  local by = 27.4 -- base da pedra
  D.rect(7, 27, 10, by + leg, 'F'); D.rect(13, 27, 15, by + leg - 1, 'F')
  D.rect(20 + step, 27, 22 + step, by + leg - 1, 'F'); D.rect(25 + step, 27, 28 + step, by + leg, 'F')
  -- matacao
  D.ell(17.5, 18, 13, 11.5, 'G'); D.ell(24, 11.5, 5.5, 5, 'G'); D.ell(8.5, 22, 5, 5.5, 'G')
  D.each(function(mx, my, c)
    if c ~= 'G' then return end
    if my > by then return 'F' end
    local v = my + (mx - 18) * 0.12
    for _, q in ipairs({ 13.5, 19.5, 24.5 }) do
      if v >= q and v < q + (D.s > 1 and 0.5 or 1) then return 'j' end
    end
    if v > 19.5 and v < 24.5 then return 'B' end
  end)
  D.rim('G', 'M', 'g'); D.rim('B', 'T', 'K')
  D.speck('G', 'g', 13, 1); D.speck('B', 'K', 13, 2); D.speck('M', 'G', 7, 3)
  D.line(18, 21.5, 20, 23.5, 'F', 'BTK', 0.5); D.line(11, 15, 13, 17.5, 'F', 'GMg', 0.5)
  -- musgo: capa no alto a esquerda, com a barra escorrida, e tufos
  local up = p == 'alert' and 1 or 0
  D.each(function(mx, my, c)
    if c == 'F' or c == 'A' then return end
    if my < 14.5 - (mx - 5) * 0.3 + 1.3 * math.sin(mx * 1.25) then return 'N' end
  end)
  D.ell(9.5, 9.5 - up, 2.6, 2.4 + up, 'N'); D.ell(14.5, 7 - up, 2.4, 2 + up, 'N'); D.ell(19, 6.8 - up * 0.5, 1.8, 1.6, 'N')
  D.rim('N', 'n', 'm')
  D.speck('N', 'm', 9, 4)
  -- olhos
  local big = p == 'alert' and 1 or 0
  if p == 'crouch' then
    D.rect(21, 17, 22, 17, 'E'); D.rect(26, 17, 27, 17, 'E')
  else
    D.rect(21 - big, 16 - big, 22, 17, 'E'); D.rect(26 - big, 16 - big, 27, 17, 'E')
  end
end

K.run {
  name = 'bouldkin', W = 36, LEG = LEG, draw = draw, DARK = 'F',
  BODY_KEYS = { 'K', 'B', 'T', 'g', 'G', 'M', 'F', 'm', 'N', 'n' },
  EMIS = { E = { 'e', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'J' } },
  fps = { idle = 5, drift = 5 }, -- anda devagar
  lean = function(y) return y < 12 and 1 or 0 end, -- pedra nao entorta: so o alto vai a frente
  ps = 2.5,
  acc = {
    urban = { 7, 21 }, green = { 16, 20 }, water = { 20, 20 }, residential = { 21, 9 }, lit = { 20, 21 },
    sacred = { 20, 4 }, crimson = { 12, 15 },
  },
}
