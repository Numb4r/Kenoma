-- Gratekin (rust.spirit, 0.25.1): grade retorcida com olhos de parafuso. Rodar: aseprite -b --script build.lua
-- Corpo: um pano de grade (quatro barras com ponta de lanca, tres travessas, o ferro e a ferrugem do Rustling)
-- que entorta de um lado para o outro e anda sobre as barras de fora. Leds: os dois parafusos (apagados sao
-- cabeca de parafuso de aco; a fenda gira a cada quadro e para no alerta). Glow: as brasas nas soldas
-- enferrujadas (apagadas parada; acendem no alerta e na fuga).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  n = '#3C4552', N = '#66768A', M = '#9FB3C8',  -- ferro
  K = '#5E2A1C', B = '#8E4424', T = '#B8612E',  -- ferrugem
  e = '#7C8898', E = '#FFE6C0',                 -- parafuso apagado e aceso (leds)
  j = '#70301A', J = '#FF7A45', Y = '#FFC890',  -- brasa (glow)
  S = '#FF7A45', s = '#FFD8B0',                 -- faisca (glow)
}

local function draw(D, o)
  local p = o.p or 0
  local A = ({ [0] = 1.5, 1.5, 1.5, alert = 0, crouch = 2.4 })[p]
  local ph = ({ [0] = 0, 0.9, 1.8, alert = 0, crouch = 0.5 })[p]
  local function b(y) return A * math.sin((y - 9) / 17 * math.pi + ph) end
  local function bi(y) return math.floor(b(y) + 0.5) end
  local function vbar(x, y1)
    local y = 9
    while y < y1 do
      local y2 = math.min(y + 2, y1)
      D.line(x + b(y), y, x + b(y2), y2, 'N', nil, 2)
      y = y2
    end
    local tip = p == 'alert' and 3.5 or (p == 'crouch' and 6 or 4.5)
    D.poly({ { x + b(9) - 0.5, 8.5 }, { x + b(9) + 1.5, 8.5 }, { x + b(9) + 0.5, tip } }, 'N')
  end
  local ll = (p == 1 and 1 or 0) + (p == 'crouch' and 1 or 0)
  local rl = (p == 2 and 1 or 0) + (p == 'crouch' and 1 or 0)
  vbar(7, 31 - ll); vbar(14, 28); vbar(21, 28); vbar(28, 31 - rl)
  D.rect(5 + bi(31), 31 - ll, 9 + bi(31), 32 - ll, 'N'); D.rect(27 + bi(31), 31 - rl, 31 + bi(31), 32 - rl, 'N')
  for _, y in ipairs({ 9, 17, 25 }) do D.rect(6 + bi(y), y, 30 + bi(y), y + 1, 'N') end
  D.rim('N', 'M', 'n')
  -- soldas enferrujadas
  for _, q in ipairs({ { 7.5, 17.5 }, { 14.5, 9.5 }, { 21.5, 25.5 }, { 28.5, 17.5 }, { 14.5, 25.5 }, { 28.5, 9.5 } }) do
    local x = q[1] + bi(q[2] - 0.5)
    D.ell(x, q[2], 2, 1.8, 'Q')
    D.rim('Q', 'T', 'K'); D.swap('Q', 'B')
    D.ell(x, q[2], 0.5, 0.5, 'j')
  end
  -- parafusos
  local sa = math.rad(({ [0] = 0, 45, 90, alert = 0, crouch = 0 })[p])
  for _, x0 in ipairs({ 18, 25 }) do
    local cx, cy = x0 + bi(13), 13.5
    D.ell(cx, cy, 3.2, 3.2, 'n') -- arruela
    D.ell(cx, cy, 2.5, 2.5, 'E')
    D.line(cx - 1.9 * math.cos(sa), cy - 1.9 * math.sin(sa), cx + 1.9 * math.cos(sa), cy + 1.9 * math.sin(sa), 'n',
      nil, D.s > 1 and 0.7 or 1)
  end
end

K.run {
  name = 'gratekin', W = 36, LEG = LEG, draw = draw, DARK = 'n',
  BODY_KEYS = { 'n', 'N', 'M', 'K', 'B', 'T' },
  EMIS = { E = { 'e', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' } },
  heat = { alt = { j = 'J' }, all = { j = 'Y' } },
  ps = 2.5,
  acc = {
    urban = { 9, 20 }, green = { 12, 7 }, water = { 14, 18 }, residential = { 13, 8 }, lit = { 14, 20 },
    sacred = { 14, 5 }, crimson = { 9, 11 },
  },
}
