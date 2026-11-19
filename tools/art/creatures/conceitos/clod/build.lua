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

-- ENTIDADE MAIOR: o entulho do bairro de pé como um disco, à maneira do Tribrachidium: três braços de carapaça em
-- cata-vento, cada um terminando numa cabeça de tatu sem olhos; os olhos estão no entulho. O disco inteiro se equilibra
-- na ponta de uma garra só, e a poeira dele sobe.
local function entidade(k, S, off)
  local g = L.grid(S, S)
  local cx, cy, R, TW = 23.5, 21.5, 14.5, 1.7
  local segs = {}
  for i = 0, 2 do                                              -- vergalhões saindo da borda, no sentido do giro
    local a = -pi / 2 + i * 2 * pi / 3 + 1.25
    local x0, y0 = pol(cx, cy, R - 2, a); local x1, y1 = pol(cx, cy, R + 2.6, a + 0.06); local x2, y2 = pol(cx, cy, R + 4.2, a + 0.3)
    segs[#segs + 1] = { x0, y0, x1, y1, 0.62, 0.62, 'e', 'E', 6 }
    segs[#segs + 1] = { x1, y1, x2, y2, 0.62, 0.62, 'e', 'E', 4 }
  end
  local claws = {}
  for n, a in ipairs({ 0.25, 0.75, 2.45, 2.95, 3.4, 4.5, 4.95, 5.45, 1.05 }) do  -- garras a mais em volta da borda
    local len = 2 + 1.6 * rnd(n, 3, 9)
    local x0, y0 = pol(cx, cy, R - 0.6, a); local x1, y1 = pol(cx, cy, R + len, a + 0.22)
    claws[#claws + 1] = { x0, y0, x1, y1, 0.85, 0.35, 'C', 'D' }
  end
  local leg = { { 23.4, 35, 24.3, 40.6, 1.6, 1.1, 'l', 'M', 7 }, { 24.3, 40.6, 23.9, 45.4, 1.0, 0.3, 'C', 'D' } }
  local eyes = {}
  for i = 0, 2 do
    local ex, ey = pol(cx, cy, 8.6, -pi / 2 + i * 2 * pi / 3 + TW * (8.6 / R) + 1.02)
    eyes[#eyes + 1] = { ex, ey }
  end
  paint(g, k, off, function(u, v, x, y)
    local dx, dy = u - cx, v - cy
    local r, th = sqrt(dx * dx + dy * dy), math.atan(dy, dx)
    local sh = (dx * 0.45 + dy * 0.9) / R
    if r < 1.3 then return 'Y' elseif r < 2.7 then return 'H' elseif r < 3.5 then return '5' end
    if r < R + 4 then
      for i = 0, 2 do
        local d = angdiff(th, -pi / 2 + i * 2 * pi / 3 + TW * (r / R)) * r
        if r < R - 2.5 then
          local w = 1.5 + 1.9 * min(1, r / 7)
          if abs(d) < w then
            local fr = (r / 2.5) % 1 * 2.5
            if fr < 0.95 then return abs(d) < 0.9 and 'Y' or (abs(d) > w - 1 and 'H' or 'J') end
            if abs(d) > w - 0.7 then return '5' end
            local i2 = (d / w < 0.1 and 1 or 2) + (sh > 0.45 and 1 or 0)
            return ('KlM'):sub(i2, i2)
          end
        else
          -- a cabeça na ponta do braço: escudo de placas, focinho de pele, duas orelhas, nenhum olho
          local q = (r - (R - 2.5)) / 6.3
          local w = 3.4 * (1 - q) ^ 0.7 + 0.3
          if q < 1 and abs(d) < w then
            if q > 0.86 then return 'o' elseif q > 0.55 then return d > 0.5 and 'n' or 'N' end
            return stone(x, y, 1.6 * k, 11, sh > 0.25 and { 'lM5', '34M' } or { 'KlM', '23M' }, '5', 0.25 * k, k)
          end
          if q < 0.3 and abs(d) < w + 1.5 and abs(d) > w - 0.2 then return d > 0 and 'n' or 'N' end
        end
      end
    end
    if r <= R then
      for _, e in ipairs(eyes) do
        local d = sqrt((u - e[1]) ^ 2 + (v - e[2]) ^ 2)
        if d < 0.75 then return 'o' elseif d < 2.0 then return d < 1.3 and 'Y' or 'J' elseif d < 2.7 then return '5' end
      end
      if r > R - 1.1 then return stone(x, y, 1.6 * k, 9, { '455', '345', 't55' }, nil, 0, k) end
      return stone(x, y, 3 * k, 21, sh > 0.2 and RUBD or RUB, '5', 0.32 * k, k)
    end
    return caps(u, v, leg) or caps(u, v, claws) or caps(u, v, segs)
  end)
  prune(g)
  L.outline(g, 'A', SOLID)
  local d = {}
  for n = 0, (k > 1 and 21 or 19) do                           -- a poeira sobe, mais rala quanto mais alto
    local a = rnd(n, 5, 4) * 2 * pi
    local rr = R + 3 + rnd(n, 7, 4) * 5
    local px, py = pol(cx, cy - 2 - rnd(n, 9, 4) * 2, rr, a)
    if py < cy + 6 then d[#d + 1] = { px, max(1.2, py), n % 3 == 0 and 's' or 'S' } end
  end
  dust(g, k, off, d)
  return g
end

-- ARQUÉTIPO: a bola que não fecha. Uma espiral de cintas cor de osso cuja ponta de fora passa por baixo do começo; por
-- dentro, um colar de garras em volta de um vão, e no vão a mesma espiral outra vez, menor, sem fundo. Do tatu sobram
-- três feixes de garras e três escudos de cabeça sem rosto. O cascalho cai para dentro dela de todos os lados.
local function arquetipo(k, S, off)
  local g = L.grid(S, S)
  local cx, cy = 31.5, 32
  local T0, TMAX, N = -pi / 2 - 0.5, 2 * pi + 1.1, 9
  local function rc(t, th) return 13.6 + 3.4 * t / (2 * pi) + 1.0 * cos(3 * (th + pi / 2)) end
  local function hwid(t) return 3.7 * max(0, min(1, (t + 0.3) / 0.9, (TMAX - t + 0.1) / 0.8)) end
  local segs = {}
  local function ring(th, turn) local t = (th - T0) % (2 * pi) + turn * 2 * pi; return rc(t, th), hwid(t) end
  for i = 0, 2 do
    -- feixe de três garras de cavar, por fora
    for n = -1, 1 do
      local a = -pi / 2 + 0.25 + i * 2 * pi / 3 + n * 0.17
      local c0, w0 = ring(a, 0)
      if (a - T0) % (2 * pi) + 2 * pi <= TMAX then c0, w0 = ring(a, 1) end
      local len = 5.6 - abs(n) * 1.2 + (n == 1 and 0.8 or 0)
      local x0, y0 = pol(cx, cy, c0 + w0 - 1, a); local x1, y1 = pol(cx, cy, c0 + w0 + len * 0.55, a + 0.07)
      local x2, y2 = pol(cx, cy, c0 + w0 + len, a + 0.26)
      segs[#segs + 1] = { x0, y0, x1, y1, 1.35, 1.0, 'C', 'D' }
      segs[#segs + 1] = { x1, y1, x2, y2, 1.0, 0.3, 'C', 'D' }
    end
    -- vergalhão
    local a = -pi / 2 + 1.3 + i * 2 * pi / 3
    local c0, w0 = ring(a, 0)
    local x0, y0 = pol(cx, cy, c0 + w0 - 1, a); local x1, y1 = pol(cx, cy, c0 + w0 + 3, a - 0.05); local x2, y2 = pol(cx, cy, c0 + w0 + 5, a - 0.3)
    segs[#segs + 1] = { x0, y0, x1, y1, 0.62, 0.62, 'u', 'e', 6 }
    segs[#segs + 1] = { x1, y1, x2, y2, 0.62, 0.62, 'u', 'e', 4 }
  end
  local teeth = {}
  for n = 0, 2 * N - 1 do                                      -- colar de garras para dentro
    local a = T0 + (n + 0.5) * pi / N
    local c0, w0 = ring(a, 0)
    local len = 1.6 + 2.6 * rnd(n, 2, 6)
    local x0, y0 = pol(cx, cy, c0 - w0 + 0.6, a); local x1, y1 = pol(cx, cy, c0 - w0 - len, a + 0.2)
    teeth[#teeth + 1] = { x0, y0, x1, y1, 0.9, 0.3, '6', 'D' }
  end
  local function plate(r, th, t, c0, w0, x, y, sh)
    local tp = t * N / (2 * pi) + 0.22 * (r - c0) / max(w0, 0.5)
    local p = tp % 1
    local idx = floor(tp)
    local pw = 0.09 + 0.05 * rnd(idx, 1, 3)
    if p < pw then return abs(r - c0) < w0 * 0.35 and 'Y' or (sh > 0.25 and 'H' or 'J') end
    if abs(r - c0) > w0 - 0.8 then return sh > 0 and '0' or '9' end
    if p > 0.8 then return sh > 0.1 and '0' or '9' end
    if p < pw + 0.1 then return '6' end
    return stone(x, y, 2.1 * k, 13 + idx, sh > 0.15 and BONED or BONE, sh > 0.15 and '0' or '9', 0.28 * k, k)
  end
  paint(g, k, off, function(u, v, x, y)
    local dx, dy = u - cx, v - cy
    local r, th = sqrt(dx * dx + dy * dy), math.atan(dy, dx)
    local sh = (dx * 0.45 + dy * 0.9) / 22
    local t = (th - T0) % (2 * pi)
    local c0, w0 = rc(t, th), hwid(t)
    if w0 > 0.4 and abs(r - c0) < w0 then return plate(r, th, t, c0, w0, x, y, sh) end
    local c = caps(u, v, teeth)
    if c then return c end
    local c1, w1 = c0, w0
    if t + 2 * pi <= TMAX then
      c1, w1 = rc(t + 2 * pi, th), hwid(t + 2 * pi)
      if w1 > 0.4 and abs(r - c1) < w1 then return plate(r, th, t + 2 * pi, c1, w1, x, y, sh + 0.3) end
    end
    -- escudos de cabeça sem rosto, apontando para fora
    for i = 0, 2 do
      local a = -pi / 2 + 0.25 + pi / 3 + i * 2 * pi / 3
      local d = angdiff(th, a) * r
      local q = (r - (c1 + w1 - 1)) / 6
      if q > 0 and q < 1 then
        local w = 2.9 * (1 - q) ^ 0.8 + 0.2
        if abs(d) < w then
          if q > 0.62 then return d > 0.4 and '8' or '7' end
          return stone(x, y, 1.6 * k, 11, sh > 0.15 and BONED or BONE, '0', 0.25 * k, k)
        end
        if q < 0.3 and abs(d) < w + 1.5 then return d > 0 and '9' or '8' end
      end
    end
    return caps(u, v, segs)
  end)
  prune(g)
  L.outline(g, 'A', SOLID)
  -- o vão: a borda do Véu e a mesma espiral de novo, duas vezes, cada vez menor
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if g[y][x] == '.' then
        local u, v = (x + 0.5 - off) / k, (y + 0.5 - off) / k
        local dx, dy = u - cx, v - cy
        local r, th = sqrt(dx * dx + dy * dy), math.atan(dy, dx)
        local t = (th - T0) % (2 * pi)
        local inner = rc(t, th) - hwid(t)
        if r < inner then
          if r > inner - 1.1 then g[y][x] = 'X'
          else
            for lv = 1, 2 do
              local f = lv == 1 and 0.47 or 0.2
              local t2 = (th - T0 - lv * 1.3) % (2 * pi)
              local c2 = rc(t2, th - lv * 1.3) * f
              if abs(r - c2) < (lv == 1 and 1.3 or 0.7) and hwid(t2) > 1 then
                local p = (t2 * N / (2 * pi)) % 1
                if p > 0.16 then g[y][x] = lv == 1 and (p < 0.4 and 'X' or 'x') or 'x' elseif lv == 1 then g[y][x] = 'S' end
              end
            end
            if r < 0.8 then g[y][x] = 's' end
          end
        end
      end
    end
  end
  local d = {}
  for n = 0, (k > 1 and 29 or 17) do                           -- cascalho caindo para dentro, de todos os lados
    local a = rnd(n, 5, 8) * 2 * pi
    local rr = 25 + rnd(n, 7, 8) * 5.5
    local px, py = pol(cx, cy, rr, a)
    d[#d + 1] = { px, py, n % 3 == 0 and 's' or 'S' }
    if n % 2 == 0 then local qx, qy = pol(cx, cy, rr - 1.6, a + 0.02); d[#d + 1] = { qx, qy, 'S' } end
  end
  dust(g, k, off, d)
  return g
end

local RES = {}
local function out(stage, kind, g)
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
out('arquetipo', 'retrato', arquetipo(2, 128, 0))
print('RESUMO ' .. table.concat(RES, ' | '))
print('ok clod')
