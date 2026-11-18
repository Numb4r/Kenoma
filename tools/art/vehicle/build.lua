-- Veículos do Véu (0.25.0): 2 quadros de 48x36, o Conjurador de 24x24 em (12, 3), pés na linha 26.
-- Camadas: back (atrás do Conjurador), conjurador_teste (só referência, não exporta), front (na frente).
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local DIR = L.ROOT .. 'vehicle/'
local LEG = {
  K = '#1A1424', V = '#9B7BFF', v = '#6F55C4', L = '#CBBCFF', d = '#4A3F7A', D = '#3A2E4C', M = '#7A688E', m = '#5A4A6E',
  F = '#2B2540', B = '#56507A', C = '#3A3450', E = '#5FD3C6',
}

-- Boneco de referência no lugar do Conjurador: sino encapuzado, pés na linha 26.
local function ref()
  local g = L.grid(48, 36)
  for y = 1, 22 do
    local hw = y < 9 and 3 + y // 4 or 4 + (y - 8) // 3
    for x = 12 - hw, 11 + hw do g[3 + y][12 + x] = x < 12 and 'C' or 'F' end
  end
  L.rect(g, 25, 9, 27, 11, 'E')
  L.outline(g, 'K')
  return g
end

local function spokes(g, cx, cy, r, phase, c)
  if phase == 0 then
    L.line(g, cx - r + 1, cy, cx + r - 1, cy, c); L.line(g, cx, cy - r + 1, cx, cy + r - 1, c)
  else
    local k = math.floor((r - 1) * 0.72 + 0.5)
    L.line(g, cx - k, cy - k, cx + k, cy + k, c); L.line(g, cx - k, cy + k, cx + k, cy - k, c)
  end
end

local function bike(phase)
  local b, f = L.grid(48, 36), L.grid(48, 36)
  for _, cx in ipairs({ 9, 38 }) do
    spokes(b, cx, 29, 5, phase, 'v')
    L.ring(b, cx, 29, 5.3, 'V')
    L.set(b, cx, 29, 'L')
  end
  L.line(b, 9, 29, 17, 21, 'v')   -- escora do selim
  L.line(b, 17, 20, 22, 29, 'v')  -- tubo do selim
  L.line(b, 17, 21, 33, 19, 'v')  -- tubo de cima
  L.line(b, 33, 21, 38, 29, 'v')  -- garfo
  L.line(b, 33, 21, 32, 13, 'v')  -- coluna do guidão
  L.rect(b, 13, 18, 19, 18, 'F'); L.rect(b, 15, 19, 18, 19, 'F')  -- selim
  L.outline(b, 'K')

  L.line(f, 9, 29, 22, 29, 'V')   -- escora da corrente
  L.line(f, 22, 29, 33, 21, 'V')  -- tubo de baixo
  L.disc(f, 22, 29, 1.5, 'v'); L.set(f, 22, 29, 'L')
  if phase == 0 then
    L.line(f, 23, 30, 25, 32, 'L'); L.rect(f, 24, 33, 27, 33, 'F')
  else
    L.line(f, 21, 28, 19, 26, 'L'); L.rect(f, 17, 25, 20, 25, 'F')
  end
  L.rect(f, 28, 12, 31, 12, 'F'); L.set(f, 32, 13, 'V')  -- manopla
  L.rect(f, 34, 16, 35, 17, 'L')  -- farol
  L.outline(f, 'K')
  return b, f
end

local function skate(phase)
  local b, f = L.grid(48, 36), L.grid(48, 36)
  for _, cx in ipairs({ 14, 33 }) do
    L.rect(b, cx - 1, 29, cx + 1, 29, 'M')  -- truck
    L.disc(b, cx, 32, 2.3, 'V'); L.set(b, cx, 32, 'F')
    if phase == 0 then L.set(b, cx - 1, 31, 'L') else L.set(b, cx + 1, 33, 'L') end
  end
  L.outline(b, 'K')
  L.rect(f, 7, 27, 40, 27, 'V'); L.rect(f, 11, 27, 17, 27, 'L')
  L.rect(f, 7, 28, 40, 28, 'v')
  L.put(f, 4, 25, { 'V', 'VV', '.Vv' }); L.put(f, 41, 25, { '..V', '.VV', 'Vv.' })  -- as pontas erguidas
  L.outline(f, 'K')
  return b, f
end

local function cart(phase)
  local b, f = L.grid(48, 36), L.grid(48, 36)
  L.ring(b, 26, 27, 6.3, 'd'); L.set(b, 26, 27, 'd')  -- roda de lá
  L.rect(b, 7, 16, 37, 17, 'D')                      -- borda de trás
  L.outline(b, 'K')
  L.line(b, 36, 5, 36, 15, 'K'); L.line(b, 36, 4, 41 + phase, 4, 'K')  -- poste da lanterna
  local lx = 39 + phase
  L.line(b, lx + 2, 5, lx + 2, 6, 'K')
  local lamp = L.grid(48, 36)
  L.put(lamp, lx, 8, { '.vVv.', 'VVLVV', 'VLLLV', 'VVLVV', '.vVv.' })
  L.outline(lamp, 'K')
  for y = 0, 35 do for x = 0, 47 do if lamp[y][x] ~= '.' then b[y][x] = lamp[y][x] end end end

  L.rect(f, 6, 19, 38, 19, 'V')
  L.rect(f, 6, 20, 38, 20, 'M')
  L.rect(f, 6, 21, 38, 26, 'm')
  for _, x in ipairs({ 12, 18, 26, 32 }) do L.line(f, x, 21, x, 26, 'D') end
  L.rect(f, 6, 21, 7, 26, 'M'); L.rect(f, 37, 21, 38, 26, 'D')
  L.rect(f, 6, 27, 38, 27, 'D')
  L.line(f, 39, 23, 47, 19, 'M')  -- varal de cá
  L.outline(f, 'K')
  L.disc(f, 22, 28, 7.3, 'K')     -- roda de cá, com o contorno
  L.disc(f, 22, 28, 6.3, 'F')
  spokes(f, 22, 28, 6, phase, 'L')
  L.ring(f, 22, 28, 6.3, 'V')
  L.disc(f, 22, 28, 1, 'V'); L.set(f, 22, 28, 'L')
  return b, f
end

for name, fn in pairs({ veh_bike = bike, veh_skate = skate, veh_cart = cart }) do
  local b0, f0 = fn(0)
  local b1, f1 = fn(1)
  L.save(DIR .. name, LEG, {
    { name = 'back', grid = L.sheet { b0, b1 }, png = DIR .. name .. '_back.png' },
    { name = 'conjurador_teste', grid = L.sheet { ref(), ref() } },
    { name = 'front', grid = L.sheet { f0, f1 }, png = DIR .. name .. '_front.png' },
  })
end
