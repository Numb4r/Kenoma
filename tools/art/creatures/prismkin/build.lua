-- Prismkin (glare.spirit, 0.25.1): prisma que separa a luz em cores. Rodar: aseprite -b --script build.lua
-- Corpo: prisma alto de vidro dourado (o vidro do Glimlet), com a face clara, a face escura e a aresta, de pe
-- sobre sete lascas, uma de cada cor. Leds: o brilho em cruz na face clara (o mesmo do Glimlet).
-- Glow: as sete cores que saem pela base, sempre acesas ("a luz que entra branca sai em sete"), e o feixe branco
-- por dentro do vidro (apagado parada; acende no alerta e na fuga).
local K = dofile('/home/yuri/Documentos/kenoma/tools/art/creatures/pebblet/kit.lua')

local LEG = {
  A = '#1A1424',
  K = '#A8873C', B = '#D6B658', T = '#F4DE88', H = '#FFF8D6', -- vidro dourado
  D = '#5A4630',                                              -- olho
  i = '#FBEFB8', I = '#FFFFFF',                               -- brilho em cruz (leds)
  c = '#EDDA94', C = '#FFFFFF',                               -- feixe branco (glow)
  p = '#7A3A44', q = '#7A5434', r = '#7A7038', u = '#3E6E48', v = '#346A66', w = '#38508A', x = '#54448A', -- lascas apagadas
  ['1'] = '#FF5A6A', ['2'] = '#FF9A45', ['3'] = '#FFE04A', ['4'] = '#6FE07A', ['5'] = '#5FD3C6', ['6'] = '#5A8CFF',
  ['7'] = '#9B7BFF',                                          -- as sete cores (glow)
  S = '#FFF3B0', s = '#FFFFFF',                               -- faisca (glow)
}

local function draw(D, o)
  local p = o.p or 0
  local top = p == 'crouch' and 7 or 4
  local by = 26
  -- as sete lascas, em leque
  for k = 0, 6 do
    local len = ({ [0] = 4, k % 2 == 0 and 4 or 3, k % 2 == 0 and 3 or 4, alert = 5, crouch = 2 })[p]
    local x = 8.5 + k * 3
    local fan = (k - 3) * (p == 'alert' and 0.6 or 0.35)
    D.line(x, by, x + fan * len / 4, by + 1 + len, tostring(k + 1), nil, 2)
  end
  -- prisma
  D.poly({ { 17.5, top }, { 29, by + 1 }, { 6, by + 1 } }, 'T')
  D.poly({ { 17.5, top }, { 29, by + 1 }, { 21, by + 1 } }, 'B')
  D.rim('T', 'H', nil); D.rim('B', nil, 'K')
  D.line(17.5, top + 1, 21, by, 'H', 'TB', D.s > 1 and 0.5 or 1)
  D.rect(6, by, 29, by + 1, 'K', 'TBH')
  if D.s > 1 then D.speck('T', 'H', 17, 1); D.speck('B', 'T', 19, 2) end
  -- feixe branco por dentro
  D.line(11.5, 17, 16.5, by - 1, 'c', 'TH', D.s > 1 and 0.7 or 1)
  -- brilho em cruz
  D.rect(13, 13, 15, 13, 'I'); D.rect(14, 12, 14, 14, 'I')
  -- olhos
  if p == 'crouch' then
    D.rect(17, 19, 18, 19, 'D'); D.rect(22, 19, 23, 19, 'D')
  else
    local big = p == 'alert' and 1 or 0
    D.rect(17, 18 - big, 18, 19, 'D'); D.rect(22, 18 - big, 23, 19, 'D')
  end
end

K.run {
  name = 'prismkin', W = 36, LEG = LEG, draw = draw, DARK = 'K',
  BODY_KEYS = { 'K', 'B', 'T', 'H', 'D' },
  EMIS = { I = { 'i', 'l' }, C = { 'c', 'w' }, ['1'] = { 'p', 'w' }, ['2'] = { 'q', 'w' }, ['3'] = { 'r', 'w' },
    ['4'] = { 'u', 'w' }, ['5'] = { 'v', 'w' }, ['6'] = { 'w', 'w' }, ['7'] = { 'x', 'w' } },
  heat = { alt = { c = 'C' }, all = { c = 'C' } },
  lean = function(y) return y < 13 and 1 or 0 end, -- vidro nao entorta: so a ponta vai a frente
  ps = 2.5,
  acc = {
    urban = { 12, 21 }, green = { 12, 23 }, water = { 14, 20 }, residential = { 14, 12 }, lit = { 14, 21 },
    sacred = { 14, 5 }, crimson = { 12, 18 },
  },
}
