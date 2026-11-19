-- Conceitos da família Clod (Etapa 1): tatu-bola + cascalho e entulho + Terra como a luz âmbar das juntas.
-- Traço-assinatura: placas de cascalho (seixos com rejunte) e a junta acesa entre elas.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/clod/build.lua')
-- Cada etapa é uma função de (k, S, off): as formas são em unidades do mapa e a textura é por pixel,
-- então o retrato tem seixo, rejunte e trinca próprios, não o mapa ampliado.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, sqrt, abs, sin, cos, pi, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.pi, math.max, math.min

local LEG = {
  A = '#1A1424',
  ['1'] = '#B9B1A0', ['2'] = '#918A7B', ['3'] = '#6C675D', ['4'] = '#4B4843', ['5'] = '#32302F', -- concreto e brita
  a = '#B39062', b = '#8B6C45', c = '#5F4931',                 -- seixo ocre
  p = '#9C614B', q = '#74412F', t = '#4D2B23',                 -- caco de tijolo, terra roxa
  K = '#8C7A69', M = '#473C35', l = '#66574B',                 -- cinta de queratina (l é o meio)
  f = '#2C2523',                                               -- pelo da barriga
  C = '#CDBFA2', D = '#9A8C74',                                -- garra
  N = '#9A8474', n = '#74615A',                                -- pele do focinho e da orelha
  g = '#7E8C54', G = '#58683C', m = '#3B4731',                 -- musgo
  e = '#A2623C', E = '#6F3F29', u = '#5A5C62',                 -- vergalhão: ferrugem e aço
  o = '#1F1A22', W = '#D8D2C4',                                -- olho e o brilho dele
  ['6'] = '#CBC6BA', ['7'] = '#A09B91', ['8'] = '#77736D', ['9'] = '#54514F', ['0'] = '#39373B', -- osso e cinza (Arquétipo)
  j = '#4F3F2B', y = '#5F4D33', h = '#3F2E22',                 -- juntas apagadas (corpo)
  J = '#E8B860', Y = '#FFF0D0', H = '#C7823B',                 -- juntas acesas
  S = '#E8C890', s = '#FFF0D0', X = '#9B7BFF', x = '#6A52B8',  -- poeira solta e o Véu no vão (só no emissivo)
}
local LIT = { J = 'j', Y = 'y', H = 'h' }
local LOOSE = 'SsXx'
local SOLID = ''
for ch in pairs(LEG) do
  if not ('AeEuSsXx'):find(ch, 1, true) then SOLID = SOLID .. ch end
end

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
local function rnd(x, y, k) return (hash(x, y, k) % 1000) / 1000 end
local function vn(t, seed)
  local i = floor(t)
  local a, b = rnd(i, seed, 1), rnd(i + 1, seed, 1)
  return a + (b - a) * (t - i)
end
local function angdiff(a, b) return (a - b + pi) % (2 * pi) - pi end

-- Voronoi: id da célula, distância até a borda, deslocamento do centro.
local function vor(x, y, s, seed)
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
-- Placa de cascalho: seixos de tamanho s, cada um com luz em cima à esquerda e sombra embaixo à direita.
-- pals: lista de trincas 'claro meio escuro'; grout: rejunte (nil = sem); gw: largura do rejunte em px.
local function stone(x, y, s, seed, pals, grout, gw, k)
  local id, e, ox, oy = vor(x, y, s, seed)
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

local function paint(g, k, off, f)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = f((x + 0.5 - off) / k, (y + 0.5 - off) / k, x, y)
      if c then g[y][x] = c end
    end
  end
end
-- Cápsulas: { x0, y0, x1, y1, r0, r1, claro, escuro, anéis }.
local function caps(u, v, list)
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
local function dseg(u, v, x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  local t = max(0, min(1, ((u - x0) * dx + (v - y0) * dy) / (dx * dx + dy * dy)))
  return sqrt((u - x0 - dx * t) ^ 2 + (v - y0 - dy * t) ^ 2)
end
local function inpoly(u, v, p)
  local c, j = false, #p
  for i = 1, #p do
    local a, b = p[i], p[j]
    if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end
    j = i
  end
  return c
end
-- Poeira solta (só emissivo): { u, v, caractere } em unidades do mapa, só no vazio.
local function dust(g, k, off, list)
  local n = max(1, floor(k * 0.6 + 0.5))
  for _, d in ipairs(list) do
    local x, y = floor(d[1] * k + off), floor(d[2] * k + off)
    L.rect(g, x, y, x + n - 1, y + n - 1, d[3] or 'S', '.')
  end
end
-- Tira o que ficou solto do corpo (ponta de garra que a grade partiu): só a maior peça fica.
local function prune(g)
  local id, sizes, n = {}, {}, 0
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local k0 = y * g.w + x
      if g[y][x] ~= '.' and not id[k0] then
        n = n + 1
        local stack, size = { k0 }, 0
        id[k0] = n
        while #stack > 0 do
          local q = table.remove(stack)
          size = size + 1
          local qx, qy = q % g.w, q // g.w
          for dy = -1, 1 do
            for dx = -1, 1 do
              local nx, ny = qx + dx, qy + dy
              if nx >= 0 and ny >= 0 and nx < g.w and ny < g.h and g[ny][nx] ~= '.' and not id[ny * g.w + nx] then
                id[ny * g.w + nx] = n; stack[#stack + 1] = ny * g.w + nx
              end
            end
          end
        end
        sizes[n] = size
      end
    end
  end
  local best = 1
  for i = 2, n do if sizes[i] > sizes[best] then best = i end end
  for k0, i in pairs(id) do if i ~= best then g[k0 // g.w][k0 % g.w] = '.' end end
end
local function pol(cx, cy, r, a) return cx + cos(a) * r, cy + sin(a) * r end

local GRAV = { '123', '234', '123', 'abc', '234', 'pqt' }
local GRAVD = { '234', '345', '234', 'bc4', '345', 'qt5' }
local RUB = { '234', '345', 'bc4', 'qt5', '345', '234' }
local RUBD = { '345', '455', 'c45', 't55', '455', '345' }
local BONE = { '678', '789', '678', '123', '890', '234' }
local BONED = { '789', '890', '789', '234', '890', '345' }

-- FAGULHA (Grit Mote): uma placa de cascalho que se soltou da carapaça, com a junta ainda acesa na borda quebrada.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '....AAAA....',
    '...A1123A...',
    '..A1a23p4A..',
    '..AJ2134qA.S',
    '..AJY2b345A.',
    '..AHJY34t5A.',
    '...AHJJ45A..',
    '....AAAAA.s.',
    '..S...S.....',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local P = { { 30, 16 }, { 58, 12 }, { 78, 28 }, { 80, 52 }, { 60, 70 }, { 34, 72 }, { 16, 50 }, { 18, 28 } }
  paint(g, 1, 0, function(u, v, x, y)
    if inpoly(u, v, P) then
      -- a borda quebrada (embaixo à esquerda) acesa, e duas trincas
      local d = min(dseg(u, v, 16, 50, 34, 72), dseg(u, v, 18, 28, 16, 50), dseg(u, v, 34, 72, 60, 70))
      if d < 1.5 then return 'Y' elseif d < 3.5 then return 'J' elseif d < 5 then return 'H' end
      local cr = min(dseg(u, v, 22, 46, 40, 40), dseg(u, v, 40, 40, 47, 28), dseg(u, v, 40, 40, 52, 52))
      if cr < 0.8 then return 'J' elseif cr < 1.6 then return '5' end
      return stone(x, y, 9, 3, (u - 48) * 0.4 + (v - 42) * 0.9 > 12 and GRAVD or GRAV, '5', 1.3, 2)
    end
    -- a espessura da placa, do lado da sombra
    for i = 1, 6 do
      if inpoly(u - i * 0.6, v - i * 1.3, P) then
        return (i > 5 or floor((u + v) / 3) % 3 == 0) and '5' or (stone(x, y, 5, 9, { '345', '455', 'c45' }, nil, 0, 2))
      end
    end
  end)
  L.outline(g, 'A')
  dust(g, 3, 0, { { 3, 27 }, { 5.3, 28.6, 's' }, { 8, 27.6 }, { 12, 29 }, { 14.6, 27.4, 's' }, { 2, 21.5 }, { 28.4, 22 },
    { 29.6, 8, 's' }, { 27.6, 4.6 }, { 4, 6 }, { 22.6, 28.4 }, { 18.4, 30, 's' } })
  return g
end

-- ECO (Pebblet): tatu-bola de perfil, em proporção natural. Os escudos são placas de cascalho, as três cintas são de
-- queratina, e as juntas entre elas acendem. O detalhe errado: falta uma placa no escudo de trás, e o buraco é luz.
local function eco(k, S, off)
  local g = L.grid(S, S)
  local cx, cy, rx, ry = 11.8, 14.5, 8.8, 9.5
  local ca, sa = cos(math.rad(26)), sin(math.rad(26))
  local limbs = {
    { 17.4, 19.2, 18.4, 22.2, 1.05, 0.8, 'l', 'M' }, { 18.4, 22.2, 19.2, 23.9, 0.65, 0.4, 'C', 'D' },
    { 6.9, 19.2, 6.4, 22.4, 1.15, 0.85, 'l', 'M' }, { 6.4, 22.4, 7.7, 23.8, 0.65, 0.4, 'C', 'D' },
    { 19.9, 19.2, 20.9, 22.3, 0.8, 0.6, 'M', 'M' }, { 20.9, 22.3, 21.5, 23.5, 0.55, 0.4, 'D', 'D' },
    { 9.7, 19.2, 9.4, 22.5, 0.8, 0.6, 'M', 'M' }, { 9.4, 22.5, 10.4, 23.5, 0.55, 0.4, 'D', 'D' },
    { 3.9, 17.2, 2.9, 20.8, 1.1, 0.5, 'K', 'l', 5 },
  }
  paint(g, k, off, function(u, v, x, y)
    local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
    if e <= 1 and v <= 19.6 then
      local hw = rx * sqrt(max(0.02, 1 - ((v - cy) / ry) ^ 2))
      local lon = (u - cx) / hw
      local sh = (u - cx) / rx * 0.45 + (v - cy) / ry * 0.9
      if v > 18.6 then return floor(u * (k > 1 and 0.6 or 1)) % 2 == 0 and 'l' or 'M' end
      for n, sx in ipairs({ -0.17, 0.17, -0.5, 0.5 }) do
        local d = abs(lon - sx) * hw
        if d < (k > 1 and 0.32 or 0.5) then
          if n > 2 then return 'M' end
          if sh > 0.3 then return 'H' end
          return (sh < -0.45 and (k == 1 or d < 0.16)) and 'Y' or 'J'
        end
      end
      if (u - 5.6) ^ 2 + (v - 10.8) ^ 2 < 1.25 then return ((u - 5.6) ^ 2 + (v - 10.8) ^ 2 < 0.4) and 'Y' or 'J' end
      if abs(lon) < 0.5 then
        local p = ((lon + 0.5) / 0.333) % 1
        if k > 1 and (v * 0.62) % 1 < 0.18 then return 'M' end
        local i = (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
        return ('KlM'):sub(i, i)
      end
      return stone(x, y, 2.3 * k, 7, sh > 0.4 and GRAVD or GRAV, '5', 0.3 * k, k)
    end
    local hu = (u - 21.6) * ca + (v - 17.2) * sa
    local hv = -(u - 21.6) * sa + (v - 17.2) * ca
    local hh = -1
    if hu < 0 then
      if hu > -3.4 then hh = 2.2 * sqrt(1 - (hu / 3.4) ^ 2) end
    elseif hu < 4.4 then hh = 1.85 * (1 - hu / 4.4) ^ 0.8 + 0.35 end
    if abs(hv) <= hh then
      if hu > 3.7 then return 'o' end
      if k > 1 and (hu - 1.1) ^ 2 + (hv - 0.3) ^ 2 < 0.07 then return 'W' end
      if (hu - 1.3) ^ 2 + (hv - 0.5) ^ 2 < 0.42 then return 'o' end
      if hv < 0.1 and hu < 2.8 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M', 'KlM' }, 'M', 0.25 * k, k) end
      return hv > 1.0 and 'n' or 'N'
    end
    if ((u - 21.6) / 1.0) ^ 2 + ((v - 14.5) / 1.4) ^ 2 <= 1 then return (u > 21.5 and v > 13.6) and 'n' or 'N' end
    local c = caps(u, v, limbs)
    if c then return c end
    if v > 19.2 and v < 20.4 and u > 5.2 and u < 19.6 then return 'f' end
  end)
  L.outline(g, 'A')
  dust(g, k, off, k > 1 and { { 1.2, 24.4 }, { 3.4, 25.2, 's' }, { 12.6, 25 }, { 14.5, 24.2, 's' }, { 23.6, 24.6 }, { 5.2, 8.4, 's' }, { 4.2, 6.6 } }
    or { { 4, 8 }, { 13, 25, 's' } })
  return g
end

-- ESPÍRITO (Bouldkin): o tatu tomado pelo entulho. A metade da frente da carapaça virou um bloco de guia quebrada com
-- vergalhão e musgo; as cintas abriram e a luz vaza. Partes em número errado: cinco patas, dois rabos, três olhos em fila.
local function espirito(k, S, off)
  local g = L.grid(S, S)
  local cx, cy, rx, ry = 13.5, 20, 10, 10
  local BL = { { 15.5, 8 }, { 27.5, 10.5 }, { 31, 18 }, { 29.2, 26.2 }, { 16.5, 26.2 }, { 14.5, 16.5 } }
  local TOP = { { 15.5, 8 }, { 27.5, 10.5 }, { 25.6, 13.2 }, { 14.9, 11.2 } }
  local ca, sa = cos(math.rad(30)), sin(math.rad(30))
  local limbs = {
    { 8.5, 25.8, 9.2, 28.6, 1.15, 0.9, 'l', 'M' }, { 9.2, 28.6, 10.6, 31, 0.7, 0.4, 'C', 'D' },
    { 12.6, 25.8, 13.2, 30.4, 1.0, 0.8, 'M', 'M' }, { 13.2, 30.4, 14.6, 32.6, 0.6, 0.4, 'D', 'D' },
    { 17.6, 25.8, 18.2, 29.4, 1.15, 0.9, 'l', 'M' }, { 18.2, 29.4, 19.8, 31.6, 0.7, 0.4, 'C', 'D' },
    { 22, 25.8, 22.5, 30.8, 1.0, 0.8, 'M', 'M' }, { 22.5, 30.8, 24, 33.2, 0.6, 0.4, 'D', 'D' },
    { 26.4, 25.8, 26.8, 29.6, 1.15, 0.9, 'l', 'M' }, { 26.8, 29.6, 28.4, 32, 0.7, 0.4, 'C', 'D' },
    { 4.6, 22.4, 2.6, 27, 1.2, 0.5, 'K', 'l', 6 }, { 5.6, 24.6, 4.6, 30, 1.0, 0.5, 'l', 'M', 6 },
  }
  local bars = {
    { 25, 11, 27.2, 6.2, 0.62, 0.62, 'e', 'E', 7 }, { 27.2, 6.2, 31, 4.6, 0.62, 0.62, 'e', 'E', 5 },
    { 19.6, 9.4, 20, 5.2, 0.62, 0.62, 'e', 'E', 6 }, { 20, 5.2, 17.6, 3.8, 0.62, 0.62, 'e', 'E', 4 },
  }
  paint(g, k, off, function(u, v, x, y)
    if inpoly(u, v, BL) then
      local top = 8 + (u - 15.5) * 0.208
      local md = 0.6 + 3.2 * vn(u * 0.8, 31)
      if v < top + md then
        local q = (v - top) / md
        return q < 0.35 and 'g' or ((q < 0.75 or hash(x, y, 2) % 3 == 0) and 'G' or 'm')
      end
      local cr = min(dseg(u, v, 22, 13, 20.5, 19), dseg(u, v, 20.5, 19, 23.5, 26), dseg(u, v, 20.5, 19, 16.5, 21.5))
      if cr < 0.45 then return cr < 0.2 and k > 1 and 'J' or (k > 1 and '5' or 'J') end
      if inpoly(u, v, TOP) then return stone(x, y, 1.8 * k, 5, { '112', '122', '1a2' }, nil, 0, k) end
      if u > 27.4 + (v - 10.5) * 0.25 then return stone(x, y, 1.8 * k, 5, { '455', '345', 'c45' }, nil, 0, k) end
      if v > 25.4 then return stone(x, y, 1.6 * k, 5, { '345', '455' }, nil, 0, k) end
      return stone(x, y, 2.6 * k, 5, { '233', '223', '233', '2b3' }, nil, 0, k)
    end
    local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
    if e <= 1 and v <= 25.8 then
      local hw = rx * sqrt(max(0.02, 1 - ((v - cy) / ry) ^ 2))
      local lon = (u - cx) / hw
      local sh = (u - cx) / rx * 0.45 + (v - cy) / ry * 0.9
      if v > 24.8 then return floor(u * (k > 1 and 0.6 or 1)) % 2 == 0 and 'l' or 'M' end
      for n, sx in ipairs({ -0.02, 0.22, -0.27 }) do
        local d = abs(lon - sx) * hw
        if d < (n == 3 and 0.5 or 0.85) * (k > 1 and 0.7 or 1) then
          if sh > 0.35 then return 'H' end
          return (d < 0.25 and sh < 0) and 'Y' or 'J'
        end
      end
      if lon > -0.27 then
        local p = ((lon + 0.27) / 0.245) % 1
        if k > 1 and (v * 0.62) % 1 < 0.18 then return 'M' end
        local i = (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
        return ('KlM'):sub(i, i)
      end
      local top = cy - ry * sqrt(max(0, 1 - ((u - cx) / rx) ^ 2))
      local md = 0.4 + 3 * vn(u * 0.9, 77)
      if v < top + md and u > 5.5 then
        return (v - top) / md < 0.4 and 'g' or (hash(x, y, 2) % 3 == 0 and 'm' or 'G')
      end
      return stone(x, y, 2.4 * k, 7, sh > 0.4 and GRAVD or GRAV, '5', 0.3 * k, k)
    end
    local c = caps(u, v, bars)
    if c then return c end
    local hu = (u - 29.6) * ca + (v - 26) * sa
    local hv = -(u - 29.6) * sa + (v - 26) * ca
    local hh = -1
    if hu < 0 then
      if hu > -3.4 then hh = 2.3 * sqrt(1 - (hu / 3.4) ^ 2) end
    elseif hu < 4.5 then hh = 1.9 * (1 - hu / 4.5) ^ 0.8 + 0.4 end
    if abs(hv) <= hh then
      if hu > 3.8 then return 'o' end
      for _, ex in ipairs({ -1.0, 0.6, 2.2 }) do
        local d = (hu - ex) ^ 2 + (hv - 0.35) ^ 2
        if d < 0.36 then return 'Y' elseif d < 0.8 and k > 1 then return 'o' end
      end
      if hv < 0.1 and hu < 2.9 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M', '34M' }, 'M', 0.25 * k, k) end
      return hv > 1.0 and 'n' or 'N'
    end
    c = caps(u, v, limbs)
    if c then return c end
    if v > 25.6 and v < 26.9 and u > 6 and u < 28.6 then return 'f' end
  end)
  prune(g)
  L.outline(g, 'A', SOLID)
  dust(g, k, off, k > 1 and { { 31.8, 3 }, { 16.4, 2.4, 's' }, { 33, 6.4 }, { 1.4, 30.6 }, { 6.6, 33, 's' }, { 16, 33.6 }, { 30.6, 33.4 }, { 20.8, 34, 's' }, { 11.4, 7.6, 's' }, { 9.6, 5.6 } }
    or { { 32, 3 }, { 16, 2, 's' }, { 6, 33 }, { 30, 33, 's' }, { 11, 7 } })
  return g
end

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.Z, LEG.v = '#9B7BFF', '#565064'                          -- costura do Véu e o par apagado
LIT.Z = 'v'; SOLID = SOLID .. 'Zv'
local function keratin(d, y0, y1) return R.mat('MlK', R.hor(d:pp()), function(u, v) return 0.9 - (v - y0) / (y1 - y0) end) end

-- ENTIDADE MAIOR: o monte de entulho da obra, de ponta-cabeça em cima do tatu. O bicho ficou pequeno embaixo, com seis
-- patas; a carapaça sobe e vira o monte, que alarga para cima (cascalho, entulho, guia de concreto, um pedaço de
-- parede) e passa dos dois lados dele. Um segundo rosto, virado, saiu no alto do monte. O cascalho rola morro acima.
-- RODADA 3. ENTIDADE MAIOR: o tatu fechado em bola, e a bola é de entulho (escudo de cascalho, um pedaço de parede,
-- vergalhão), com as três cintas no meio e a junta acesa. A bola não abre, mas três cabeças e cinco patas saem dela
-- por onde não há abertura: uma cabeça para cima, uma para baixo, patas no alto e nas costas. Cada uma sai de uma
-- trinca acesa. A costura fecha a bola onde ela devia abrir.
local function entidade(k, S, off)
  local d = R.ctx(S, k)
  local p = d:pp()
  local CX, CY, RR = 23, 28, 15.5
  local ca, sa = cos(math.rad(-24)), sin(math.rad(-24))
  local function head(t, x0, y0, x1, y1, eye)
    local dx, dy = x1 - x0, y1 - y0
    local len = sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy, ux
    if ny > 0 then nx, ny = -nx, -ny end
    for e = 0, 1 do                                                                 -- duas orelhas em pé
      local bx, by = x0 + ux * (0.2 + e * 2.2) + nx * 2.6, y0 + uy * (0.2 + e * 2.2) + ny * 2.6
      local sp = e == 0 and -1.6 or 0.8
      t:cap(bx, by, bx + nx * 4.6 + ux * sp, by + ny * 4.6 + uy * sp, 1.15, 0.5, e == 0 and 'R' or 'r')
    end
    t:cap(x0, y0, x1, y1, 3.4, 1.2, function(x, y, u, v)
      local a = ((u - x0) * ux + (v - y0) * uy) / len
      local b = (u - x0) * nx + (v - y0) * ny
      if a > 0.9 then return 'o' end
      if b > 0.3 and a < 0.7 then return stone(x, y, 1.5 * k, 11, { '12K', '1Kl' }, 'l', 0.25 * k, k) end
      return b < -1.2 and 'R' or (a > 0.55 and b > -0.2 and 'C' or 'r')
    end)
    local ex, ey = x0 + dx * 0.45 - nx * 0.6, y0 + dy * 0.45 - ny * 0.6
    t:ell(ex, ey, 1, 1, eye or 'o')
    if k > 1 and not eye then t:ell(ex - 0.2, ey - 0.2, 0.25, 0.25, 'W') end
  end
  local function leg(t, x0, y0, x1, y1)
    local a = math.atan(y1 - y0, x1 - x0)
    t:cap(x0, y0, x1, y1, 1.9, 1.4, R.mat('fMl', R.hor(p), 0.5))
    for c = -1, 1 do
      t:cap(x1, y1, x1 + cos(a + c * 0.6) * 2.6, y1 + sin(a + c * 0.6) * 2.6, 0.7, 0.3, R.mat('DC', R.ver(p), c == 1 and 0 or 1))
    end
  end
  -- de onde sai cada coisa (na bola) e para onde aponta
  local HEADS = { { 35.5, 32.6, 45, 34.6 }, { 11.6, 19.4, 2.4, 18.6, 'Y' }, { 29.6, 13.4, 29.8, 3.4 } }
  local LEGS = { { 18, 14, 15.6, 7.6 }, { 9.6, 33.4, 4.6, 36 }, { 37, 22.6, 43.4, 20 } }
  -- no mapa a cabeça é desenhada pixel a pixel (focinho para a direita); no retrato ela é a função head()
  local HEAD = {
    '..R...R.....',
    '..RR..RR....',
    '..rR1.rR1...',
    '.11KK11K11..',
    '.1K1o11KrrC.',
    '.KK1KKrrrrCo',
    '..RRrrrrrroo',
    '...RRRRRR...',
  }
  local function stamp(t, x0, y0, mode, lit)
    for j, row in ipairs(HEAD) do
      for i = 1, #row do
        local c = row:sub(i, i)
        if c ~= '.' then
          if lit and (c == 'o' and i < 8 or c == 'W') then c = 'Y' end
          local x, y = i - 1, j - 1
          if mode == 'left' then x = #row - 1 - x elseif mode == 'up' then x, y = #HEAD - 1 - (j - 1), #row - 1 - (i - 1) end
          t.g[y0 + y][x0 + x] = c
        end
      end
    end
  end
  LEG.r, LEG.R = '#B5978A', '#86675E'                           -- pele da orelha e do focinho das cabeças
  SOLID = SOLID .. 'rR'
  d:layer(function(t)                                                              -- a bola
    t:ell(CX, CY, RR, RR, function(x, y, u, v)
      local a = (u - CX) * ca + (v - CY) * sa
      local b = -(u - CX) * sa + (v - CY) * ca
      local hw = RR * sqrt(max(0.02, 1 - (b / RR) ^ 2))
      local lon = a / hw
      local sh = (u - CX) / RR * 0.45 + (v - CY) / RR * 0.9
      for _, q in ipairs(HEADS) do                                                  -- a trinca em volta de cada saída
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 3.7 then return r > 3 and 'H' or 'J' end
      end
      for _, q in ipairs(LEGS) do
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 2.5 then return r > 1.9 and 'H' or 'J' end
      end
      for n, sx in ipairs({ -0.12, 0.12, -0.36, 0.36 }) do
        local dd = abs(lon - sx) * hw
        if dd < (k > 1 and 0.5 or 0.62) then
          if sh > 0.35 then return 'H' end
          return (sh < -0.35 and dd < 0.3) and 'Y' or 'J'
        end
      end
      if abs(lon) < 0.36 then
        local pp = ((lon + 0.36) / 0.24) % 1
        if k > 1 and (b * 0.62) % 1 < 0.18 then return 'M' end
        local i = (pp < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
        return ('KlM'):sub(i, i)
      end
      if lon > 0 then                                                               -- o escudo da frente: parede e entulho
        if b < -1 then
          local row = floor(v / 1.7)
          local bx = (u + (row % 2) * 1.7) % 3.4
          if bx < 0.5 or v % 1.7 < 0.45 then return '4' end
          return R.pick('tqp', 0.6 - sh * 0.5, R.noise(p, 8)(x, y))
        end
        return stone(x, y, 3 * k, 21, sh > 0.3 and RUBD or RUB, '5', 0.32 * k, k)
      end
      return stone(x, y, 2.3 * k, 7, sh > 0.4 and GRAVD or GRAV, '5', 0.3 * k, k)
    end)
    t:suture({ { 14.6, 37 }, { 19, 41.4 }, { 26, 42.4 } }, 'Z', 1.3, nil)
  end, SOLID)
  for _, b in ipairs({ { 36, 26, 42.6, 25.6, 44.6, 27.4 } }) do                     -- vergalhão
    d:wire({ { b[1], b[2] }, { b[3], b[4] }, { b[5], b[6] } }, 'e', 'E', 0.6, '.')
  end
  d:layer(function(t)
    for _, q in ipairs(LEGS) do leg(t, q[1], q[2], q[3], q[4]) end
    if k == 1 then
      stamp(t, 34, 29, nil); stamp(t, 1, 15, 'left', true); stamp(t, 26, 2, 'up')
    else
      for _, q in ipairs(HEADS) do head(t, q[1], q[2], q[3], q[4], q[5]) end
    end
  end, SOLID)
  dust(d.g, k, 0, { { 3, 12 }, { 6, 40, 's' }, { 40, 41 }, { 44.6, 8, 's' }, { 13, 4 }, { 2.4, 33 }, { 37, 44.6, 's' }, { 45, 38 }, { 26, 2.6 } })
  -- a luz é a do tipo Terra na paleta (m, l, d), no lugar do âmbar das etapas de baixo
  LEG.T, LEG.U, LEG.V, LEG.F, LEG.B = '#C0915A', '#E6C594', '#7E5A32', '#C0915A', '#E6C594'
  LIT.T = 'j'; LIT.U = 'y'; LIT.V = 'h'
  if not LOOSE:find('F', 1, true) then LOOSE = LOOSE .. 'FB' end
  local M = { J = 'T', Y = 'U', H = 'V', S = 'F', s = 'B' }
  for y = 0, S - 1 do for x = 0, S - 1 do if M[d.g[y][x]] then d.g[y][x] = M[d.g[y][x]] end end end
  return d.g
end
local function entidadeR2(k, S, off)
  local d = R.ctx(S, k)
  local p = d:pp()
  local MOUND ={ { 13.5, 31.5 }, { 34.5, 31.5 }, { 41, 21 }, { 44, 11 }, { 38, 6 }, { 24, 4.2 }, { 11, 6.4 }, { 4, 13 }, { 7, 23 } }
  d:layer(function(t)                                                              -- as patas de trás
    for _, x in ipairs({ 14.5, 23, 31.5 }) do
      t:cap(x, 37, x + 0.6, 42.4, 1.2, 0.9, 'M'); t:cap(x + 0.6, 42.4, x + 1.6, 44.4, 0.7, 0.4, 'D')
    end
  end, SOLID)
  d:layer(function(t)
    t:cap(11.5, 35, 5.6, 40.6, 1.3, 0.5, keratin(t, 34, 41))                        -- rabo
    t:ell(24, 34.6, 13.6, 5.8, function(x, y, u, v)                                 -- a carapaça: só cintas, com a junta acesa
      local f = ((u - 10.4) / 3.4) % 1
      if f < 0.24 then return v < 32.6 and 'Y' or (v > 36.6 and 'H' or 'J') end
      return R.pick('MlK', 0.85 - (v - 30) / 8 - f * 0.3, R.hor(p)(x, y))
    end)
    t:rect(11.5, 39.4, 36.5, 40, 'f')
    t:ell(37.4, 32.8, 1, 1.7, function(x, y, u, v) return u > 37.5 and 'n' or 'N' end)
    t:cap(36, 36.6, 41.6, 39, 2.5, 1.1, function(x, y, u, v)
      if u > 41.6 then return 'o' end
      if v < 36.6 and u < 39.6 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M' }, 'M', 0.25 * k, k) end
      return v > 38 and 'n' or 'N'
    end)
    t:ell(37.6, 37, 0.7, 0.7, 'o'); if k > 1 then t:ell(37.4, 36.8, 0.25, 0.25, 'W') end
    for _, x in ipairs({ 17.5, 26, 34.5 }) do                                       -- as patas de cá
      t:cap(x, 38, x + 0.5, 42.6, 1.25, 0.95, R.mat('MlK', R.hor(p), 0.4)); t:cap(x + 0.5, 42.6, x + 1.8, 44.8, 0.7, 0.4, R.mat('DC', R.ver(p), 0))
    end
  end, SOLID)
  d:layer(function(t)                                                              -- o monte
    t:poly(MOUND, function(x, y, u, v)
      local dark = (u - 24) / 40 + (v - 17) / 30 > 0.2
      if v > 25.5 then return stone(x, y, 2.2 * k, 7, dark and GRAVD or GRAV, '5', 0.3 * k, k) end
      if v > 13.5 + (u - 24) * 0.1 then return stone(x, y, 3 * k, 21, dark and RUBD or RUB, '5', 0.32 * k, k) end
      if u > 25 then                                                                -- o pedaço de parede
        local row = floor(v / 1.7)
        local bx = (u + (row % 2) * 1.7) % 3.4
        if bx < 0.5 or v % 1.7 < 0.45 then return '4' end
        return R.pick('tqp', 0.5 - (u - 34) / 20, R.noise(p, 8)(x, y))
      end
      return R.pick('4321', 0.75 - (v - 5) / 14, R.noise(p, 3)(x, y))                -- a guia de concreto
    end)
    -- trincas com a junta acesa, e a borda de baixo do monte, que a luz das cintas pega
    t:wire({ { 20, 5 }, { 21.6, 11 }, { 18.6, 16 }, { 21, 22.6 }, { 19.6, 28 } }, 'J', 'Y', 0.5)
    t:wire({ { 21.6, 11 }, { 27, 13.4 }, { 33, 12.6 }, { 37.6, 16.4 } }, 'J', 'Y', 0.5)
    t:wire({ { 33, 12.6 }, { 31.6, 20 }, { 34, 26 } }, 'H', 'J', 0.5)
    t:wire({ { 18.6, 16 }, { 12, 17.6 }, { 9.6, 22 } }, 'H', 'J', 0.5); t:wire({ { 21, 22.6 }, { 27, 24 }, { 28.6, 29 } }, 'J', 'Y', 0.5)
    t:wire({ { 12, 17.6 }, { 10.6, 12.6 } }, 'J', 'Y', 0.5); t:wire({ { 37.6, 16.4 }, { 41.6, 14 } }, 'H', 'J', 0.5)
    t:wire({ { 8, 22.6 }, { 13.6, 30.6 } }, 'H', 'J', 0.6); t:wire({ { 40.6, 21 }, { 34.6, 30.6 } }, 'H', 'J', 0.6)
    t:suture({ { 14.6, 30.4 }, { 33.4, 30.4 } }, 'Z', 1.4, nil)                      -- a costura: onde o tatu acaba e o monte começa
    -- o rosto de cima, virado: escudo, focinho para o alto, um olho de junta
    t:cap(9, 11, 5.4, 5.4, 2.6, 1, function(x, y, u, v)
      if v < 5.6 then return 'o' end
      if v > 8.6 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M' }, 'M', 0.25 * k, k) end
      return u < 6.8 and 'N' or 'n'
    end)
    t:ell(10.6, 13.6, 1, 1.7, function(x, y, u, v) return u > 10.7 and 'n' or 'N' end)
    t:ell(8.4, 10.4, 1.2, 1.2, 'J'); t:ell(8.4, 10.4, 0.5, 0.5, 'o')
    -- musgo no alto
    local g = t.g
    for y = 1, S - 1 do for x = 0, S - 1 do
      local u = (x - (k - 1) / 2) / k
      if g[y][x] ~= '.' and g[y - 1][x] == '.' and u > 14 and u < 37 then
        for i = 0, floor((0.6 + 2.2 * vn(u * 0.9, 31)) * k) do
          if ('1234tqp'):find(L.get(g, x, y + i), 1, true) then g[y + i][x] = i < k and 'g' or ((x + y + i) % 3 == 0 and 'm' or 'G') end
        end
      end
    end end
  end, SOLID)
  for _, b in ipairs({ { 30, 6, 31.6, 2.8, 34.4, 2.4 }, { 15, 6.4, 14, 3.2, 11.6, 3 } }) do  -- vergalhão
    d:wire({ { b[1], b[2] }, { b[3], b[4] }, { b[5], b[6] } }, 'e', 'E', 0.6)
  end
  local dl = {}
  for n = 0, 15 do                                                                  -- o cascalho rola morro acima
    local s = n < 8 and -1 or 1
    local t = (n % 8) / 8
    dl[#dl + 1] = { 24 + s * (10.5 + t * 12 + 2.2), 32 - t * 24 + rnd(n, 3, 2) * 2, n % 3 == 0 and 's' or 'S' }
  end
  dust(d.g, k, 0, dl)
  return d.g
end

-- ARQUÉTIPO: o tatu de perfil, partido no meio. Os dois escudos são osso e andam juntos, mas as três cintas que os
-- uniam não estão: no lugar delas, o vão, e dentro dele as cintas se repetem, cada vez menores, sem chegar ao fundo.
-- As patas (demais) e as placas encolhem na direção do vão; a cabeça é um escudo pequeno demais, sem rosto, e as
-- garras são grandes demais. O cascalho em volta cai de lado, para dentro do vão.
local function arquetipo(k, S, ox, oy)
  local d = R.ctx(S, k, ox, oy)
  local p = d:pp()
  local GX = 30.5
  local function plates(cx)
    return function(x, y, u, v)
      local near = 1 - min(1, abs(u - GX) / 16)                                      -- perto do vão: placa menor, junta acesa
      local sh = (v - 30) / 16
      local s = (3.6 - 2 * near) * k
      local id, e = vor(x, y, s, 13)
      if v > 41.4 then return R.pick('098', 0.3, R.ver(p)(x, y)) end                  -- a barra de escudos da borda
      if e < 0.3 * k then return near > 0.3 and (near > 0.62 and 'Y' or 'J') or (sh > 0.3 and '0' or '9') end
      return stone(x, y, s, 13, sh > 0.45 and BONED or BONE, nil, 0, k)
    end
  end
  local LEGS = { 11.5, 21, 40, 50 }
  d:layer(function(t)                                                              -- patas do lado de lá
    for _, x in ipairs(LEGS) do t:cap(x + 3, 43, x + 3.4, 48.6, 1.5, 1.1, R.mat('098', R.hor(p), 0.3)) end
  end, SOLID)
  d:layer(function(t)
    t:cap(7.6, 40.6, 1.6, 48, 1.7, 0.5, R.mat('098', R.hor(p), 0.5))                -- rabo
    t:ell(30, 44, 25, 23.5, plates(30))                                             -- a carapaça inteira; o vão a parte depois
    for y = 0, S - 1 do for x = 0, S - 1 do                                         -- corta a barriga reta
      if (y - t.oy - (k - 1) / 2) / k > 43.6 then t.g[y][x] = '.' end
    end end
    t:rect(7, 43.6, 53, 44.4, R.mat('f5', R.ver(p), 0))
    -- a cabeça: um escudo pequeno demais, sem rosto, duas orelhas
    t:ell(56.4, 33.8, 1, 2.4, '8'); t:ell(54.2, 33.6, 1, 2.4, '7')
    t:cap(54.6, 38.6, 60.8, 44.6, 2.9, 0.9, function(x, y, u, v)
      if u > 60.2 then return '0' end
      if v > 40.2 + (u - 54.6) * 0.75 then return R.pick('987', 0.4, R.noise(p, 4)(x, y)) end
      return stone(x, y, 1.5 * k, 11, BONE, '0', 0.25 * k, k)
    end)
    for _, x in ipairs(LEGS) do                                                     -- patas de cá, com garras de cavar grandes demais
      t:cap(x, 44, x + 0.5, 49, 2, 1.5, R.mat('987', R.hor(p), 0.5))
      for c = -1, 1 do
        t:cap(x + 0.5 + c * 1.3, 49.4, x + 2.6 + c * 2.2, 55.4, 0.9, 0.3, R.mat('DC', R.ver(p), 0))
      end
    end
  end, SOLID)
  -- o vão entre os escudos, em ampulheta
  local function gap(u, v)
    if v < 19.6 or v > 43.6 then return nil end
    local w = 3.6 + 4.4 * abs((v - 33) / 13) ^ 1.6
    local t = abs(u - GX) / w
    return t <= 1 and t or nil
  end
  d:vao(gap, 'X', 'x', 0.66)
  -- as cintas que faltam: repetidas para dentro, cada vez menores; e três fios de osso, o que sobrou delas
  for lv, f in ipairs({ 0.62, 0.36, 0.18 }) do
    for n = -1, 1 do
      local y = 33 + n * 8 * f
      d:wire({ { GX - 3.4 * f, y - 1.2 * f }, { GX, y + 1.4 * f }, { GX + 3.4 * f, y - 1.2 * f } }, lv == 1 and 'X' or (lv == 2 and 'S' or 's'), nil, 0.5, '.x')
    end
  end
  for _, y in ipairs({ 21.6, 32, 42.6 }) do
    local w = 3.9 + 4.4 * abs((y - 33) / 13) ^ 1.6
    d:wire({ { GX - w - 1, y }, { GX - w * 0.4, y + 1.6 }, { GX + w * 0.4, y + 1.6 }, { GX + w + 1, y } }, '7', '6', 0.5)
  end
  local dl = {}
  for n = 0, (k > 1 and 33 or 21) do                                                -- o cascalho cai de lado, para dentro do vão
    local s = n % 2 == 0 and -1 or 1
    local r = 7 + rnd(n, 5, 8) * 24
    local y = 3 + rnd(n, 7, 8) * 14 + (r > 20 and 0 or 2)
    dl[#dl + 1] = { GX + s * r, y + r * 0.12, n % 3 == 0 and 's' or 'S' }
    if n % 2 == 0 then dl[#dl + 1] = { GX + s * (r + 1.6), y + r * 0.12, 'S' } end
  end
  dust(d.g, k, 0, dl)
  return d.g
end

local RES = {}
local function out(stage, kind, g)
  if R.skip(stage) then return end
  local m = C.save('clod', stage, kind, g, LEG, LIT, LOOSE)
  RES[#RES + 1] = string.format('%s %s: op %d cores %d det %.2f cont %.2f emis %.2f', stage, kind, m.opacos, m.cores, m.detalhe, m.contorno, m.emissivo)
end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', eco(1, 28, 0))
out('eco', 'retrato', eco(3.3, 96, 1.8))
out('espirito', 'mapa', espirito(1, 36, 0))
out('espirito', 'retrato', espirito(2.55, 96, 2.1))
out('entidade', 'mapa', entidade(1, 48, 0))
out('entidade', 'retrato', entidade(2, 96, 0))
out('arquetipo', 'mapa', arquetipo(1, 64, 0))
out('arquetipo', 'retrato', arquetipo(3, 128, -60, -33))                           -- busto: o vão, o escudo da frente e a cabeça
print('RESUMO ' .. table.concat(RES, ' | '))
print('ok clod')
