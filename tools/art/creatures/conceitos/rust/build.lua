-- Conceitos da família Rust (Etapa 1): besouro-rinoceronte + grade e portão de ferro + Metal como a luz fria que
-- passa pelas barras. Traço-assinatura: casco de grade (barras de ferro com vão, e luz por trás do vão).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rust/build.lua')
-- Cada etapa é uma função de (k, S, off): formas em unidades do mapa, textura por pixel (o retrato tem ferrugem,
-- aresta e rebite próprios, não o mapa ampliado).
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, sqrt, abs, sin, cos, pi, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.pi, math.max, math.min

local LEG = {
  A = '#1A1424',
  ['1'] = '#2E2B33', ['2'] = '#44404A', ['3'] = '#5E5A66', ['4'] = '#858290', ['5'] = '#AEB0BC', -- ferro e aço
  r = '#5A3324', R = '#874A2E', q = '#B06A3C', Q = '#D09458',  -- ferrugem
  g = '#3F5248', G = '#5F7868',                                -- resto de tinta verde de portão
  z = '#2D2A3C',                                              -- o escuro de dentro da grade
  b = '#8A7440', B = '#B89A58',                                -- latão do cadeado
  o = '#201A26', W = '#E6E6EE',                                -- olho e o brilho dele
  e = '#B06A3C', E = '#874A2E', m = '#C2C5CB', n = '#4C4E58',  -- perna fina, sem contorno (ferrugem; cinza no Arquétipo)
  ['6'] = '#C2C5CB', ['7'] = '#9A9DA6', ['8'] = '#70737D', ['9'] = '#4C4E58', ['0'] = '#33343D', -- cinza de aço (Arquétipo)
  h = '#232838', i = '#2C3448', k = '#20242F',                 -- vãos apagados (corpo)
  H = '#9FB3C8', I = '#EAF2FA', K = '#5E7088',                 -- luz fria nos vãos
  S = '#D4E2F0', s = '#FFFFFF', X = '#9B7BFF', x = '#6A52B8',  -- limalha solta e o Véu no vão (só no emissivo)
}
local LIT = { H = 'h', I = 'i', K = 'k' }
local LOOSE = 'SsXx'
local SOLID = ''
for ch in pairs(LEG) do
  if not ('AeEmnSsXx'):find(ch, 1, true) then SOLID = SOLID .. ch end
end

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
local function rnd(x, y, k) return (hash(x, y, k) % 1000) / 1000 end
local function angdiff(a, b) return (a - b + pi) % (2 * pi) - pi end
local function vor(x, y, s, seed)
  local gx, gy = floor(x / s), floor(y / s)
  local b1, b2, id = 1e9, 1e9, 0
  for j = -1, 1 do
    for i = -1, 1 do
      local h = hash(gx + i, gy + j, seed)
      local px = (gx + i + 0.2 + 0.6 * ((h & 255) / 255)) * s
      local py = (gy + j + 0.2 + 0.6 * (((h >> 8) & 255) / 255)) * s
      local d = (x - px) ^ 2 + (y - py) ^ 2
      if d < b1 then b2 = b1; b1 = d; id = h elseif d < b2 then b2 = d end
    end
  end
  return id, sqrt(b2) - sqrt(b1)
end
local RUSTP = { 'QqRr', 'qRr1', '4321', 'QqRr', 'Gg21', 'qRr1' }
local IRONP = { '5432', '4321', 'qRr1', '4321', '5432', 'Gg21' }
local ASH = { '6789', '7890', '6789', '5432', '7890', '4321', 'qRr1' }
-- Barra de ferro: d = distância assinada ao eixo, w = meia largura, sh = sombra do lugar (-1 luz, +1 sombra).
-- No retrato a barra tem aresta clara, miolo e aresta escura; a ferrugem vem em manchas.
local function iron(d, w, x, y, sh, k, pal)
  local p = pal or RUSTP
  local id = vor(x, y, k > 1 and 4.5 or 6, 17)
  local s = p[(id >> 16) % #p + 1]
  local i = 2
  if w * k >= 1.2 then
    if d < -w * 0.3 then i = 1 elseif d > w * 0.3 then i = 3 end
  end
  if sh < -0.35 then i = i - 1 elseif sh > 0.35 then i = i + 1 end
  if k > 1 and hash(x, y, 31) % 13 == 0 then i = i + 1 end
  i = max(1, min(4, i))
  return s:sub(i, i)
end

local function paint(g, k, off, f)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = f((x + 0.5 - off) / k, (y + 0.5 - off) / k, x, y)
      if c then g[y][x] = c end
    end
  end
end
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
-- Perna em três segmentos a partir de pontos; r = raio; a, b = cores; ribs = anéis por segmento.
local function leg(list, pts, r, a, b, ribs)
  for n = 1, #pts - 1 do
    list[#list + 1] = { pts[n][1], pts[n][2], pts[n + 1][1], pts[n + 1][2], r, n == #pts - 1 and r * 0.7 or r, a, b, ribs }
  end
end
-- Ponta de lança de portão: haste, colar e losango, a partir de (px, py) na direção (dx, dy).
local function spear(u, v, px, py, dx, dy, len, w, c1, c2, c3)
  local a = (u - px) * dx + (v - py) * dy
  local b = -(u - px) * dy + (v - py) * dx
  if a >= 0 and a <= len and abs(b) < w then return b < 0 and c1 or c2 end
  if a > len - 0.7 and a < len and abs(b) < w + 0.6 then return c3 end
  local tl = w * 3.4 + 1
  if abs(a - len - tl / 2) / (tl / 2) + abs(b) / (w + 0.9) <= 1 then return b < 0 and c1 or c2 end
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
local function dust(g, k, off, list)
  local n = max(1, floor(k * 0.6 + 0.5))
  for _, d in ipairs(list) do
    local x, y = floor(d[1] * k + off), floor(d[2] * k + off)
    L.rect(g, x, y, x + n - 1, y + n - 1, d[3] or 'S', '.')
  end
end
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
-- Patas finas sem contorno: entram depois do contorno, só no vazio (se cruzassem antes, fechariam bolsos que o
-- contorno não alcança), e o que ficar solto sai.
local function behind(g, k, off, list)
  paint(g, k, off, function(u, v, x, y)
    if g[y][x] == '.' then return caps(u, v, list) end
  end)
  prune(g)
end

-- Chapa de ferro (pronoto, cubo): tons pelo lugar, manchas de ferrugem.
local function plate(x, y, sh, k)
  local id = vor(x, y, 2.6 * k, 23)
  if (id >> 16) % 3 == 0 then return sh < -0.3 and 'q' or (sh < 0.35 and 'R' or 'r') end
  return sh < -0.5 and '4' or (sh < -0.05 and '3' or (sh < 0.45 and '2' or '1'))
end
-- Olho de parafuso: cabeça de aço com a fenda.
local function screw(u, v, ex, ey, r, k, ang)
  local d = sqrt((u - ex) ^ 2 + (v - ey) ^ 2)
  if d > r then return end
  local b = -(u - ex) * sin(ang) + (v - ey) * cos(ang)
  if k > 1 and abs(b) < r * 0.24 then return '1' end
  if k == 1 and u > ex and v > ey then return '3' end
  return (u - ex) + (v - ey) < 0 and '5' or '4'
end

-- FAGULHA (Filing Mote): um caco de grade que a limalha remontou, com a luz fria ainda nos vãos.
local function fagulhaMapa()
  local g = L.frame({
    '............',
    '.......s....',
    '.S..........',
    '..QqqRq43...',
    '..qHRIrH2.S.',
    '..qRr4321...',
    '..RIrH2K1...',
    '..rr32211...',
    '...r..2..s..',
    '...R........',
    '.S......S...',
    '............',
  }, 12, 12, 'fagulha')
  L.outline(g, 'A', SOLID .. 'HIK')
  return g
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local vx = { { 28, 22, 80 }, { 46, 30, 74 }, { 64, 24, 68 } }      -- x, de v, até v
  local hz = { { 34, 14, 76 }, { 50, 20, 82 }, { 66, 18, 70 } }      -- y, de u, até u
  paint(g, 1, 0, function(u, v, x, y)
    local sh = (u - 48) / 60 + (v - 50) / 50
    local c = spear(u, v, 46, 30, 0, -1, 9, 2.5, '4', '2', 'q')
    if c then return c end
    for _, b in ipairs(hz) do
      local d = v - b[1]
      if abs(d) < 2.5 and u > b[2] and u < b[3] then return iron(d, 2.5, x, y, sh, 2) end
    end
    for _, b in ipairs(vx) do
      local d = u - b[1] - 0.8 * sin(v * 0.12 + b[1])
      if abs(d) < 2.5 and v > b[2] and v < b[3] then return iron(d, 2.5, x, y, sh, 2) end
    end
    if u > 28 and u < 64 and v > 34 and v < 66 then
      local gl = sqrt(((u - 46) / 20) ^ 2 + ((v - 50) / 18) ^ 2)
      return gl < 0.38 and 'I' or (gl < 0.8 and 'H' or 'K')
    end
  end)
  prune(g)
  L.outline(g, 'A', SOLID .. 'HIK')
  -- limalha: fiapos que se alinham para as pontas quebradas
  local d = {}
  for n = 0, 30 do
    local a = rnd(n, 1, 2) * 2 * pi
    local rr = 34 + rnd(n, 3, 2) * 10
    local px, py = pol(47, 49, rr, a)
    d[#d + 1] = { px, py, n % 3 == 0 and 's' or 'S' }
    if n % 2 == 0 then local qx, qy = pol(47, 49, rr - 2.4, a); d[#d + 1] = { qx, qy, 'S' } end
  end
  dust(g, 1, 0, d)
  for _, p in ipairs(d) do L.set(g, p[1] + 1, p[2], p[3], '.') end
  return g
end

-- Casco de grade num élitro em elipse: barras longitudinais (as estrias do besouro), duas travessas e a moldura.
-- Devolve a cor do pixel: barra, vão aceso (perto do miolo de luz) ou o escuro de dentro.
local function elytra(u, v, x, y, k, cx, cy, rx, ry, glow)
  local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
  if e > 1 then return end
  local bw = 0.5
  local hh = ry * sqrt(max(0.02, 1 - ((u - cx) / rx) ^ 2))
  local lat = (v - cy) / hh
  local sh = lat * 0.8 + (u - cx) / rx * 0.25
  local rim = (1 - sqrt(e)) * min(rx, ry)
  if rim < 2 * bw then return iron(rim - bw, bw, x, y, sh, k) end
  -- barras de portão: uma a cada 3 px do mapa, e uma travessa no meio
  local dd = ((u - cx + 91.5 - lat * 0.5) % 3) - 1.5
  if abs(dd) < bw then return iron(dd, bw, x, y, sh, k) end
  dd = (lat + 0.08) * hh
  if abs(dd) < bw then return iron(dd, bw, x, y, sh, k) end
  local gl = ((u - cx - 0.6) / (rx * 0.64 * glow)) ^ 2 + ((lat - 0.05) / (0.8 * glow)) ^ 2
  if gl < 0.07 then return 'I' elseif gl < 0.3 then return 'H' elseif gl < 0.62 then return 'K' end
  return 'z'
end

-- ECO (Rustling): besouro-rinoceronte em proporção natural. Os élitros são uma grade de ferro enferrujado com resto de
-- tinta, o chifre é uma ponta de lança de portão, e dentro do casco há luz. O detalhe errado: uma barra arrombada.
local function eco(k, S, off)
  local g = L.grid(S, S)
  local cx, cy, rx, ry = 10.6, 15.4, 8.6, 6.6
  local parts = {
    { 22.4, 14.6, 23.1, 10.4, 0.66, 0.6, '4', '2' },
    { 23.1, 17.6, 24.7, 18.9, 0.42, 0.4, '3', '2' }, { 24.7, 18.9, 25.0, 19.2, 0.7, 0.7, 'q', 'R' },
    { 7.8, 10.6, 6.6, 8.3, 0.56, 0.56, 'q', 'R' }, { 6.6, 8.3, 7.5, 6.9, 0.56, 0.5, 'Q', 'q' },
  }
  leg(parts, { { 18.4, 19.4 }, { 20.4, 21.6 }, { 21, 24 } }, 0.62, '4', '2')
  leg(parts, { { 12.4, 20.8 }, { 11.4, 22.8 }, { 12.3, 24.4 } }, 0.62, '4', '2')
  leg(parts, { { 6.2, 19.8 }, { 4.3, 22 }, { 4.7, 24.2 } }, 0.62, '4', '2')
  paint(g, k, off, function(u, v, x, y)
    local pe = ((u - 19) / 3.6) ^ 2 + ((v - 15.2) / 5.1) ^ 2
    if pe <= 1 then
      local sh = (v - 15.2) / 5.1 * 0.85 + (u - 19) / 3.6 * 0.3
      if k > 1 and pe > 0.52 and pe < 0.8 and (math.atan(v - 15.2, u - 19) * 2.2) % 1 < 0.22 then return sh < 0 and '5' or '3' end
      return plate(x, y, sh, k)
    end
    local c = elytra(u, v, x, y, k, cx, cy, rx, ry, 1)
    if c then return c end
    local he = ((u - 22.4) / 1.9) ^ 2 + ((v - 16.2) / 2.3) ^ 2
    if he <= 1 then
      if k > 1 and (u - 22.8) ^ 2 + (v - 15.3) ^ 2 < 0.07 then return 'W' end
      if (u - 23.0) ^ 2 + (v - 15.6) ^ 2 < 0.42 then return 'o' end
      if u > 23.6 and v > 17 then return 'r' end
      return v < 15.4 and '3' or (v < 17 and '2' or '1')
    end
    c = spear(u, v, 23.1, 10.4, 0.16, -0.987, 0.9, 0.62, '5', '3', 'q')
    if c then return c end
    return caps(u, v, parts)
  end)
  prune(g)
  L.outline(g, 'A')
  dust(g, k, off, k > 1 and { { 6.2, 5 }, { 8.6, 4.2, 's' }, { 4.6, 6.6 }, { 9.6, 6.4 }, { 1.4, 25.4 }, { 14, 26, 's' }, { 25.4, 25 } }
    or { { 9, 5 }, { 5, 6, 's' } })
  return g
end

-- ESPÍRITO (Gratekin): o besouro tomado pelo portão. Um élitro se ergueu como uma folha de portão de barras torcidas,
-- com lanças em cima e a luz vazando pela dobradiça. Sete patas, dois chifres, cinco olhos de parafuso, e um cadeado
-- fechado pendurado atrás.
local function espirito(k, S, off)
  local g = L.grid(S, S)
  local cx, cy, rx, ry = 13.5, 22, 10, 6.2
  local OX, OY, AX, AY, BX, BY = 8.5, 18, 12, -1, 1.5, -10
  local det = AX * BY - AY * BX
  local parts = {
    { 27, 20.6, 28.4, 17, 0.66, 0.6, '3', '2' },
    { 26.2, 20.4, 26, 17.4, 0.6, 0.56, 'q', 'R' }, { 26, 17.4, 24.5, 16, 0.56, 0.5, 'q', 'R' },
    { 28.4, 24, 30.2, 25.6, 0.45, 0.42, '3', '2' }, { 30.2, 25.6, 30.6, 26, 0.75, 0.75, 'q', 'R' },
    { 5, 23.4, 4.2, 26.4, 0.56, 0.56, '4', '2', 5 },
  }
  leg(parts, { { 22.6, 26 }, { 24.8, 28.4 }, { 25.6, 32.4 } }, 0.64, '3', '2')
  leg(parts, { { 17.4, 27.6 }, { 16.6, 30.2 }, { 18, 33.6 } }, 0.64, '3', '2')
  leg(parts, { { 12.4, 28 }, { 10.6, 30.6 }, { 11.4, 33 } }, 0.64, '3', '2')
  leg(parts, { { 8, 26.6 }, { 6.4, 29.4 }, { 7.4, 31.6 }, { 6.6, 33.8 } }, 0.64, 'q', 'R')
  local thin = {}
  leg(thin, { { 24.6, 25.6 }, { 27.6, 27.6 }, { 28.4, 31.4 } }, 0.58, 'e', 'E', 3)
  leg(thin, { { 20, 27.6 }, { 20.8, 30.6 }, { 22, 32.6 } }, 0.58, 'e', 'E', 3)
  leg(thin, { { 14.6, 28.2 }, { 14.4, 31 }, { 15.4, 32.2 } }, 0.58, 'e', 'E', 3)
  local bw = 0.5
  paint(g, k, off, function(u, v, x, y)
    -- a folha de portão
    local s = ((u - OX) * BY - (v - OY) * BX) / det
    local t = (AX * (v - OY) - AY * (u - OX)) / det
    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
      local sh = (s - 0.5) * 0.8 - (t - 0.5) * 0.8
      local ds, dt = min(s, 1 - s) * 12, min(t, 1 - t) * 10.1
      if ds < 2 * bw or dt < 2 * bw then return iron(min(ds, dt) - bw, bw, x, y, sh, k) end
      for n = 1, 4 do
        local d = (s - n / 5 - 0.03 * sin(t * 8 + n * 2.1)) * 12
        if abs(d) < bw and not (n == 3 and t > 0.62 and t < 0.8) then return iron(d, bw, x, y, sh, k) end
      end
      local d = (t - 0.52 - 0.04 * sin(s * 7)) * 10.1
      if abs(d) < bw then return iron(d, bw, x, y, sh, k) end
      return
    end
    for n = 0, 2 do
      local px, py = OX + AX * (0.17 + n * 0.33) + BX, OY + AY * (0.17 + n * 0.33) + BY
      local c = spear(u, v, px, py, 0.148, -0.989, 1.5, 0.5, '4', '2', 'q')
      if c then return c end
    end
    local pe = ((u - 23.2) / 3.8) ^ 2 + ((v - 21.4) / 5) ^ 2
    if pe <= 1 then
      for n = -2, 2 do
        local a = n * 0.5
        local c = screw(u, v, 23.2 + 2.7 * cos(a), 21.4 + 3.9 * sin(a), k > 1 and 0.85 or 0.75, k, n * 0.9)
        if c then return c end
      end
      return plate(x, y, (v - 21.4) / 5 * 0.85 + (u - 23.2) / 3.8 * 0.3, k)
    end
    -- a luz que vaza por baixo da folha erguida
    if t < 0 and t > -0.16 and s > 0.04 and s < 0.96 and ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2 < 0.9 then
      return t > -0.07 and 'I' or 'H'
    end
    local c = elytra(u, v, x, y, k, cx, cy, rx, ry, 1.25)
    if c then return c end
    local he = ((u - 27.4) / 2.1) ^ 2 + ((v - 22.6) / 2.5) ^ 2
    if he <= 1 then
      if u > 28.6 and v > 23.6 then return 'r' end
      return v < 21.6 and '3' or (v < 23.6 and '2' or '1')
    end
    c = spear(u, v, 28.4, 17, 0.3, -0.954, 1.8, 0.55, '4', '2', 'q')
    if c then return c end
    -- cadeado
    if u > 2.4 and u < 5.8 and v > 27.4 and v < 31 then
      if (u - 4.1) ^ 2 + (v - 28.8) ^ 2 < 0.36 or (abs(u - 4.1) < 0.3 and v > 28.8 and v < 30) then return 'I' end
      return (u > 5 or v > 30.2) and 'b' or 'B'
    end
    local dd = sqrt((u - 4.1) ^ 2 + (v - 27.4) ^ 2)
    if v <= 27.4 and dd < 1.7 and dd > 0.8 then return u < 4.1 and '5' or '3' end
    return caps(u, v, parts)
  end)
  prune(g)
  L.outline(g, 'A', SOLID)
  behind(g, k, off, thin)
  dust(g, k, off, k > 1 and { { 24.6, 6 }, { 26.4, 8.4, 's' }, { 5.6, 9 }, { 4, 12, 's' }, { 6.4, 14.4 }, { 31.4, 12 }, { 1.6, 33.6 }, { 30.6, 33 }, { 20, 34.2, 's' } }
    or { { 25, 6 }, { 5, 10, 's' }, { 6, 14 }, { 31, 12 } })
  return g
end

-- RODADA 2. A luz das peças refeitas é a do tipo Metal em tools/art/ui/types/palette.lua (l, m, d), no lugar do azul-aço.
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.L, LEG.M, LEG.D = '#CCD6E2', '#93A1B3', '#566274'        -- Metal: claro, principal, escuro
LEG.l, LEG.j, LEG.d = '#2C2D36', '#272830', '#22232B'        -- os pares apagados
LEG.Z, LEG.v = '#9B7BFF', '#4A4658'                          -- costura do Véu e o par apagado
LIT.L = 'l'; LIT.M = 'j'; LIT.D = 'd'; LIT.Z = 'v'; SOLID = SOLID .. 'LMDljdZv'
local function diamond(t, x, y, w, h, fn) t:poly({ { x - w, y }, { x, y - h * 0.62 }, { x + w, y }, { x, y + h * 0.38 } }, fn) end

-- ENTIDADE MAIOR: o portão inteiro. As duas folhas de grade são os élitros, abertos de frente; no meio, onde elas se
-- encontram, a chapa da fechadura é o que sobrou do besouro: o buraco da fechadura aceso é o rosto, com três parafusos
-- de olho, e o chifre é a lança do meio. Seis patas de ferrugem saem dos montantes. A corrente do cadeado fica de pé:
-- o cadeado cai para cima.
local function entidade(k, S, off)
  local d = R.ctx(S, k)
  local p = d:pp()
  local cx = 23.5
  d:layer(function(t)
    t:poly({ { 5.5, 15 }, { 21, 11.5 }, { 21, 35 }, { 5.5, 33 } }, function(x, y, u, v)
      local top, bot = 15 - (u - 5.5) * 0.226, 33 + (u - 5.5) * 0.129
      local sh = (v - 23) / 13
      if v < top + 1.3 or v > bot - 1.3 or u < 6.9 or u > 19.9 then return iron(0, 1, x, y, sh, k) end
      if abs(v - 24 + (u - 5.5) * 0.05) < 0.7 then return iron(0, 1, x, y, sh + 0.4, k) end
      local f = (u - 6.9) % 3.2
      if f > 1.9 then return iron(f - 2.55, 0.65, x, y, sh, k) end
      local near = (u - 5.5) / 15.5 - abs(v - 23) / 40                              -- a luz por trás do vão, mais forte perto da chapa
      return near > 0.62 and 'L' or (near > 0.36 and 'M' or (near > 0.12 and 'D' or 'z'))
    end)
    for i = 0, 3 do                                                                 -- pontas de lança
      local bx = 9.45 + i * 3.2
      local top = 15 - (bx - 5.5) * 0.226
      t:wire({ { bx, top }, { bx, top - 2 } }, '3', '4', 0.5)
      diamond(t, bx, top - 3, 1.1, 3.4, R.mat('234', R.ver(p), 0.5))
    end
    t:mirror(cx)
  end, SOLID)
  d:layer(function(t)                                                              -- a chapa da fechadura: o besouro
    t:wire({ { cx, 15 }, { cx, 9 } }, '3', '4', 1.3)
    diamond(t, cx, 8.4, 2.2, 7, function(x, y, u, v) return iron(u - cx, 2, x, y, (v - 6) / 6, k, IRONP) end)
    for _, s in ipairs({ -1, 1 }) do t:cap(cx + s * 2.6, 16, cx + s * 4.4, 12.6, 0.8, 0.3, R.mat('qRr', R.hor(p), 0.5)) end
    t:ell(cx, 23, 4.3, 7.6, function(x, y, u, v) return plate(x, y, (u - cx) / 9 + (v - 23) / 10, k) end)
    t:ell(cx, 22.4, 1.25, 1.25, 'L'); t:rect(cx - 0.5, 22.4, cx + 0.5, 26, 'L')
    if k > 1 then t:ell(cx, 22.4, 0.55, 0.55, 'M'); t:rect(cx, 23, cx, 25.4, 'M') end
    for _, e in ipairs({ { -2.3, 18.6, 0.6 }, { 2.3, 18.6, 2.2 }, { 0, 28.2, 1.2 } }) do
      t:ell(cx + e[1], e[2], 0.95, 0.95, function(x, y, u, v) return screw(u, v, cx + e[1], e[2], 1.1, k, e[3]) or '4' end)
    end
    t:suture({ { cx, 30.8 }, { cx, 35 } }, 'Z', 1.4, nil)
  end, SOLID)
  -- a corrente de pé e o cadeado no alto
  d:layer(function(t)
    t:wire({ { 42, 14.6 }, { 42, 8.4 } }, '4', '2', 0.6)
    t:wire({ { 40.8, 8.4 }, { 40.8, 7 }, { 43.2, 7 }, { 43.2, 8.4 } }, '5', '3', 0.5)
    t:rect(40, 3.4, 44, 6.6, R.mat('bB', R.chk(p), 0.3))
    t:rect(41.8, 4.4, 42.2, 5.4, 'o')
  end, SOLID)
  local legs = {}
  for _, s in ipairs({ -1, 1 }) do
    leg(legs, { { cx + s * 17.4, 29 }, { cx + s * 21.4, 33 }, { cx + s * 19.4, 41 }, { cx + s * 21, 45 } }, 0.55, 'e', 'E', 4)
    leg(legs, { { cx + s * 11.6, 35 }, { cx + s * 13.4, 39 }, { cx + s * 11.4, 43.6 }, { cx + s * 12.8, 45.6 } }, 0.55, 'e', 'E', 4)
    leg(legs, { { cx + s * 4.6, 35.4 }, { cx + s * 5.6, 39.6 }, { cx + s * 3.6, 43.6 }, { cx + s * 4.8, 45.6 } }, 0.55, 'e', 'E', 4)
  end
  behind(d.g, k, 0, legs)
  dust(d.g, k, 0, { { 38.6, 9 }, { 45.4, 11, 's' }, { 39, 2.4 }, { 45, 4.6, 's' }, { 3, 9 }, { 12, 4, 's' }, { 30, 3 }, { 2.6, 24 }, { 45, 22, 's' }, { 16, 40 }, { 31.6, 41, 's' } })
  return d.g
end

-- ARQUÉTIPO: o besouro de frente com os élitros abertos como as duas folhas de um portão, igual demais dos dois lados.
-- Entre as folhas não há corpo: o vão, em arco de portão, e dentro dele outro portão aberto, e outro, cada um menor.
-- Do besouro sobram três chifres de lança e seis patas finas de aço que não chegam ao chão. A luz acende por trás das
-- barras sem haver nada atrás delas.
local function arquetipo(k, S, ox, oy)
  local d = R.ctx(S, k, ox, oy)
  local p = d:pp()
  local cx, HX = 31.5, 25
  d:layer(function(t)
    t:ell(HX, 35, 19, 19.5, function(x, y, u, v)                                     -- a folha: um élitro em D
      if u > HX then return nil end
      local e = ((u - HX) / 19) ^ 2 + ((v - 35) / 19.5) ^ 2
      local sh = (v - 35) / 19
      if e > 0.8 or u > HX - 1.6 then return iron(0, 1, x, y, sh, k, ASH) end
      if abs(v - 27) < 0.75 or abs(v - 43) < 0.75 then return iron(0, 1, x, y, sh + 0.4, k, ASH) end
      local f = (HX - 1.6 - u) % 3.3
      if f > 2 then return iron(f - 2.65, 0.65, x, y, sh, k, ASH) end
      local near = 1 - (HX - u) / 17 - abs(v - 35) / 50
      return near > 0.84 and 'L' or (near > 0.66 and 'M' or (near > 0.5 and 'D' or 'z'))
    end)
    for i = 0, 3 do                                                                 -- lanças na borda de cima da folha
      local bx = HX - 4.25 - i * 3.3
      local top = 35 - 19.5 * sqrt(1 - ((bx - HX) / 19) ^ 2)
      t:wire({ { bx, top + 1 }, { bx, top - 1.6 } }, '8', '7', 0.5)
      diamond(t, bx, top - 2.6, 1.1, 3.2, R.mat('987', R.ver(p), 0.5))
    end
    -- os três chifres
    t:wire({ { cx - 0.4, 17 }, { cx - 0.4, 9 } }, '8', '7', 1.2)
    diamond(t, cx, 7.4, 2.4, 8.4, function(x, y, u, v) return iron(u - cx, 2.2, x, y, (v - 6) / 6, k, ASH) end)
    t:wire({ { cx - 3.4, 17 }, { cx - 6, 11.6 } }, '8', '7', 0.8)
    diamond(t, cx - 6.4, 10.4, 1.3, 4.6, R.mat('987', R.ver(p), 0.5))
    t:rect(HX, 15.6, cx, 17.6, function(x, y, u, v) return iron(v - 16.6, 1, x, y, 0, k, ASH) end)   -- a verga
    t:mirror(cx)
  end, SOLID)
  local function arch(u, v, s, cy)
    local w, top, bot = 6.2 * s, cy - 15 * s, cy + 17 * s
    local a = abs(u - cx)
    if v > bot or a > w then return nil end
    if v >= top + w then return max(a / w, 1 - (bot - v) / (1.6 * s) * 0.3) end
    local r = sqrt(a * a + (v - top - w) ^ 2) / w
    return r <= 1 and r or nil
  end
  d:vao(function(u, v) return arch(u, v, 1, 34) end, 'X', 'x', 0.82)
  for lv, s in ipairs({ 0.66, 0.4, 0.2 }) do                                         -- portão dentro de portão
    local cy = 34 - lv * 1.2
    local w, top, bot = 6.2 * s, cy - 15 * s, cy + 17 * s
    local ch = lv == 1 and 'X' or (lv == 2 and 'S' or 's')
    local pts = { { cx - w, bot } }
    for a = 180, 360, 30 do pts[#pts + 1] = { cx + cos(math.rad(a)) * w, top + w + sin(math.rad(a)) * w } end
    pts[#pts + 1] = { cx + w, bot }
    d:wire(pts, ch, nil, 0.5, '.x')
    for _, sg in ipairs({ -1, 1 }) do                                               -- as folhas dele, abertas
      d:wire({ { cx + sg * w, top + w }, { cx + sg * w * 0.45, top + w + 2 * s }, { cx + sg * w * 0.45, bot - 2 * s }, { cx + sg * w, bot } }, ch, nil, 0.5, '.x')
    end
  end
  local legs = {}
  for _, s in ipairs({ -1, 1 }) do
    leg(legs, { { cx + s * 9, 50 }, { cx + s * 13, 53.6 }, { cx + s * 11.6, 58.4 }, { cx + s * 13, 61 } }, 0.55, 'm', 'n', 4)
    leg(legs, { { cx + s * 16, 50 }, { cx + s * 21, 52.6 }, { cx + s * 20, 57.6 }, { cx + s * 22, 60 } }, 0.55, 'm', 'n', 4)
    leg(legs, { { cx + s * 22, 44 }, { cx + s * 27.4, 46 }, { cx + s * 27, 52 }, { cx + s * 29, 55 } }, 0.55, 'm', 'n', 4)
  end
  behind(d.g, k, d.ox, legs)
  local dl = {}
  for n = 0, 19 do
    local a = n * 2.4
    dl[#dl + 1] = { cx + cos(a) * (23 + (n * 7) % 8), 33 + sin(a) * (24 + (n * 5) % 7), n % 3 == 0 and 's' or 'S' }
  end
  dust(d.g, k, d.ox, dl)
  return d.g
end

local RES = {}
local function out(stage, kind, g)
  if R.skip(stage) then return end
  local edge = ''
  for i = 0, g.w - 1 do
    for _, p in ipairs({ { i, 0 }, { i, 1 }, { i, g.h - 1 }, { 0, i }, { g.w - 1, i } }) do
      local c = g[p[2]][p[1]]
      if c ~= '.' and not LOOSE:find(c, 1, true) then edge = ' BORDA!' end
    end
  end
  local m = C.save('rust', stage, kind, g, LEG, LIT, LOOSE)
  RES[#RES + 1] = string.format('%s %s: op %d cores %d det %.2f cont %.2f emis %.2f%s', stage, kind, m.opacos, m.cores, m.detalhe, m.contorno, m.emissivo, edge)
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
out('arquetipo', 'retrato', arquetipo(3, 128, -31, -31))                           -- busto: os chifres, o arco do vão e o alto das folhas
print('RESUMO ' .. table.concat(RES, ' | '))
print('ok rust')
