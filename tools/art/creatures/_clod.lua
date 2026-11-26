-- Kit da arte final da família Clod (Terra): Pebblet (Eco), Bouldkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run). As formas são as dos conceitos aprovados (tools/art/creatures/conceitos/clod/build.lua),
-- agora com pose. O Eco e o Espírito são funções do ponto (u, v) em unidades do mapa (o retrato é desenhado no próprio
-- tamanho); a Entidade e o Arquétipo usam as formas do _r2.lua, com textura no pixel (pp = 1 abaixo de escala 2,5).
-- LUZ: só a do tipo (tools/art/ui/types/palette.lua, Terra: H = d, J = m, Y = l), no lugar do âmbar dos conceitos.
-- leds = os olhos e o buraco de luz (I, T: piscam); glow = as juntas, as trincas, a costura, o vão e a poeira solta.
-- Bicho de chão: o tronco sobe e desce (o.dy) e as garras ficam; só no salto da fuga (o.jump) sai tudo do chão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local L = K.L
local R = dofile(ART .. 'creatures/conceitos/_r2.lua')(K.C)
local C = { L = L, K = K, R = R, hash = K.hash }
local floor, sqrt, abs, sin, cos, pi, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.pi, math.max, math.min
local hash = K.hash

local ET
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'earth' then ET = c end end
local VEU = '#9B7BFF'

C.LEG = {
  A = '#1A1424',
  ['1'] = '#B9B1A0', ['2'] = '#918A7B', ['3'] = '#6C675D', ['4'] = '#4B4843', ['5'] = '#32302F', -- concreto e brita
  a = '#B39062', b = '#8B6C45', c = '#5F4931',                 -- seixo ocre
  p = '#9C614B', q = '#74412F', t = '#4D2B23',                 -- caco de tijolo, terra roxa
  K = '#8C7A69', M = '#473C35', l = '#66574B',                 -- cinta de queratina (l é o meio)
  f = '#2C2523',                                               -- pelo da barriga
  C = '#CDBFA2', D = '#9A8C74',                                -- garra
  N = '#9A8474', n = '#74615A', r = '#B5978A', R = '#86675E',  -- pele do focinho e da orelha
  g = '#7E8C54', G = '#58683C', m = '#3B4731',                 -- musgo
  e = '#A2623C', E = '#6F3F29', u = '#5A5C62',                 -- vergalhão: ferrugem e aço (sem contorno)
  o = '#1F1A22', W = '#D8D2C4',                                -- olho e o brilho dele
  ['6'] = '#CBC6BA', ['7'] = '#A09B91', ['8'] = '#77736D', ['9'] = '#54514F', ['0'] = '#39373B', -- osso e cinza (Arquétipo)
  j = '#4F3F2B', y = '#5F4D33', h = '#3F2E22',                 -- juntas apagadas (corpo)
  J = ET.m, Y = ET.l, H = ET.d,                                -- juntas acesas (glow)
  T = ET.m, I = ET.l,                                          -- olho e buraco de luz (leds: piscam)
  S = ET.m, s = ET.l,                                          -- poeira solta (só no glow)
  v = '#565064', Z = VEU,                                      -- costura do Véu apagada e acesa (glow)
  O = '#120D1C',                                               -- o vão apagado (mais escuro que o contorno)
  X = VEU, x = '#5A45A8', U = ET.m, V = ET.l,                  -- o vão do Arquétipo (glow)
}
C.LIT = {
  J = { 'j', 'w' }, Y = { 'y', 'w' }, H = { 'h', 'w' }, T = { 'j', 'l' }, I = { 'y', 'l' }, Z = { 'v', 'w' },
  X = { 'O', 'w' }, x = { 'O', 'w' }, U = { 'O', 'w' }, V = { 'O', 'w' },
}
C.NOPULL = 'AeEuSs'
C.SOLID = ''
for ch in pairs(C.LEG) do if not C.NOPULL:find(ch, 1, true) then C.SOLID = C.SOLID .. ch end end
C.BODY_KEYS = { '1', '2', '3', '4', '5', 'a', 'b', 'c', 'p', 'q', 't', 'K', 'M', 'l', 'f', 'C', 'D', 'N', 'n', 'r', 'R',
  'g', 'G', 'm', 'e', 'E', 'u', '6', '7', '8', '9', '0' }

function C.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'H' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'J'
    elseif c == 'J' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'Y' end
  end end
end

function C.rnd(x, y, k) return (hash(x, y, k) % 1000) / 1000 end
function C.vn(t, seed)
  local i = floor(t)
  local a, b = C.rnd(i, seed, 1), C.rnd(i + 1, seed, 1)
  return a + (b - a) * (t - i)
end
-- Voronoi: id da célula, distância até a borda, deslocamento do centro.
function C.vor(x, y, s, seed)
  local gx, gy = floor(x / s), floor(y / s)
  local b1, b2, id, ox, oy = 1e9, 1e9, 0, 0, 0
  for j = -1, 1 do
    for i = -1, 1 do
      local h = hash(gx + i, gy + j, seed)
      local px = (gx + i + 0.2 + 0.6 * ((h & 255) / 255)) * s
      local py = (gy + j + 0.2 + 0.6 * (((h >> 8) & 255) / 255)) * s
      local d = (x - px) ^ 2 + (y - py) ^ 2
      if d < b1 then b2 = b1; b1 = d; id = h; ox = x - px; oy = y - py elseif d < b2 then b2 = d end
    end
  end
  return id, sqrt(b2) - sqrt(b1), ox, oy
end
-- Placa de cascalho: seixos de tamanho s (px), cada um com luz em cima à esquerda e sombra embaixo à direita.
-- pals: lista de trincas 'claro meio escuro'; grout: rejunte (nil = sem); gw: largura do rejunte em px.
function C.stone(x, y, s, seed, pals, grout, gw, k)
  local id, e, ox, oy = C.vor(x, y, s, seed)
  if grout and e < gw then return grout end
  local p = pals[(id >> 16) % #pals + 1]
  local t = (ox + oy) / s
  local i = 2
  if t < -0.2 then i = 1 elseif t > 0.2 then i = 3 end
  if k > 1 and i == 2 then
    local h = hash(x, y, seed + 5) % 11
    if h == 0 then i = 1 elseif h == 1 then i = 3 end
  end
  return p:sub(i, i)
end
function C.paint(g, k, ox, oy, f)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = f((x + 0.5 - ox) / k, (y + 0.5 - oy) / k, x, y)
      if c then g[y][x] = c end
    end
  end
end
-- Cápsulas: { x0, y0, x1, y1, r0, r1, claro, escuro, anéis }.
function C.caps(u, v, list)
  for _, s in ipairs(list) do
    local dx, dy = s[3] - s[1], s[4] - s[2]
    local t = max(0, min(1, ((u - s[1]) * dx + (v - s[2]) * dy) / (dx * dx + dy * dy)))
    local px, py = s[1] + dx * t, s[2] + dy * t
    if sqrt((u - px) ^ 2 + (v - py) ^ 2) <= s[5] + (s[6] - s[5]) * t then
      if s[9] and floor(t * s[9]) % 2 == 1 then return s[8] end
      return ((u - px) + (v - py) < 0) and s[7] or s[8]
    end
  end
end
function C.dseg(u, v, x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  local t = max(0, min(1, ((u - x0) * dx + (v - y0) * dy) / (dx * dx + dy * dy)))
  return sqrt((u - x0 - dx * t) ^ 2 + (v - y0 - dy * t) ^ 2)
end
function C.inpoly(u, v, p)
  local c, j = false, #p
  for i = 1, #p do
    local a, b = p[i], p[j]
    if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end
    j = i
  end
  return c
end
-- Só a maior peça fica (ponta de garra que a grade partiu).
function C.prune(g)
  local id, sizes, n = {}, {}, 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local k0 = y * g.w + x
    if g[y][x] ~= '.' and not id[k0] then
      n = n + 1
      local stack, size = { k0 }, 0
      id[k0] = n
      while #stack > 0 do
        local q = table.remove(stack)
        size = size + 1
        local qx, qy = q % g.w, q // g.w
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = qx + dx, qy + dy
          if nx >= 0 and ny >= 0 and nx < g.w and ny < g.h and g[ny][nx] ~= '.' and not id[ny * g.w + nx] then
            id[ny * g.w + nx] = n; stack[#stack + 1] = ny * g.w + nx
          end
        end end
      end
      sizes[n] = size
    end
  end end
  local best = 1
  for i = 2, n do if sizes[i] > sizes[best] then best = i end end
  for k0, i in pairs(id) do if i ~= best then g[k0 // g.w][k0 % g.w] = '.' end end
end
-- Costura do Véu num ponto (u, v): verdade a menos de w da linha a-b; step: pontos atravessados (retrato).
function C.seam(u, v, a, b, w, step)
  if C.dseg(u, v, a[1], a[2], b[1], b[2]) < w then return true end
  if step then
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local len = sqrt(dx * dx + dy * dy)
    local t = ((u - a[1]) * dx + (v - a[2]) * dy) / len
    local dn = abs((u - a[1]) * -dy + (v - a[2]) * dx) / len
    if t > 0 and t < len and dn < w + 0.8 and abs((t % step) - step / 2) < 0.2 then return true end
  end
end
-- Poeira solta em sg (só no glow), onde o corpo está vazio. list = { { u, v, ch } }; dir = { du, dv } por quadro.
function C.dust(g, sg, k, ox, oy, list, ph, NL, dir)
  local n = max(1, floor(k * 0.6 + 0.5))
  dir = dir or { 0, -0.8 }
  for i, d in ipairs(list) do
    local r = (ph + i) % NL
    if r < NL - 1 then
      local x, y = floor((d[1] + dir[1] * r) * k + ox), floor((d[2] + dir[2] * r) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = d[3] or (i % 2 == 0 and 's' or 'S')
        end
      end end
    end
  end
end

C.GRAV = { '123', '234', '123', 'abc', '234', 'pqt' }
C.GRAVD = { '234', '345', '234', 'bc4', '345', 'qt5' }
C.RUB = { '234', '345', 'bc4', 'qt5', '345', '234' }
C.RUBD = { '345', '455', 'c45', 't55', '455', '345' }
C.BONE = { '678', '789', '678', '123', '890', '234' }
C.BONED = { '789', '890', '789', '234', '890', '345' }

function C.run(spec)
  spec.LEG = spec.LEG or C.LEG
  spec.LIT, spec.heat = C.LIT, C.heat
  spec.NOPULL = spec.NOPULL or C.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or C.BODY_KEYS
  spec.DARK = spec.DARK or '5'
  spec.ownDy, spec.ownLean = true, true
  if not spec.over then
    spec.over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end }
  end
  return K.run(spec)
end

return C
