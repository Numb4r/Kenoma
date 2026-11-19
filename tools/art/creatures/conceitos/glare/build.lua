-- Conceitos da família Glare (Etapa 1): beija-flor-tesoura + vitrine e farol + Luz como reflexo.
-- Traço-assinatura: o reflexo que pisca (duas faixas claras em diagonal sobre o vidro e a estrela de quatro pontas).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/glare/build.lua')
-- Cada etapa é uma função de (k, S, off): formas em unidades do mapa, textura por pixel.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, sqrt, abs, sin, cos, pi, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.pi, math.max, math.min

local LEG = {
  A = '#1A1424',
  a = '#7A9A8E', b = '#55766E', c = '#3A5755', d = '#273E42',  -- plumagem verde-petróleo
  e = '#46587A', f = '#313F5C', n = '#222B42',                 -- cabeça e cauda azul-escuras
  ['1'] = '#DCE6E8', ['2'] = '#A9BCC2', ['3'] = '#7C939C', ['4'] = '#586E7A', ['5'] = '#3C4E5C', -- vidro
  g = '#6FA08E', G = '#4A7A6C',                                -- o verde da borda do vidro
  M = '#C8CCD0', m = '#8E9298',                                -- cromado do farol
  z = '#C8CCD0', Z = '#8E9298',                                -- bico de agulha de vidro (sem contorno)
  o = '#1E1A26', W = '#F2F2F6',                                -- olho e o brilho dele
  t = '#9CC0D0', u = '#A8786A', v = '#2A3050',                 -- céus refletidos: dia, fim de tarde, noite
  ['6'] = '#D2D4D0', ['7'] = '#A6AAA8', ['8'] = '#7A7F80', ['9'] = '#555A5E', ['0'] = '#383C42', -- vidro cinza (Arquétipo)
  y = '#6A6650', j = '#5A5540', h = '#4A4230',                 -- reflexos apagados (corpo)
  r = '#5A4044', l = '#3E5440', q = '#38465E',                 -- cores do prisma apagadas
  Y = '#FFFBE0', J = '#FFF3B0', H = '#D8BE6A',                 -- reflexo aceso
  R = '#F0A0A0', L = '#A8E0A0', B = '#8AB8F0',                 -- a luz separada pelo prisma
  S = '#FFF3B0', s = '#FFFFFF', X = '#9B7BFF', x = '#6A52B8',  -- brilho solto e o Véu no vão (só no emissivo)
}
local LIT = { Y = 'y', J = 'j', H = 'h', R = 'r', L = 'l', B = 'q' }
local LOOSE = 'SsXx'
local function solid(skip)
  local s = ''
  for ch in pairs(LEG) do
    if not (('ASsXx' .. skip):find(ch, 1, true)) then s = s .. ch end
  end
  return s
end
local SOLID_ECO, SOLID = solid('zZ12345gG'), solid('zZ')

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
local function rnd(x, y, k) return (hash(x, y, k) % 1000) / 1000 end
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
-- Peças finas sem contorno entram depois do contorno, só no vazio.
local function behind(g, k, off, list)
  paint(g, k, off, function(u, v, x, y)
    if g[y][x] == '.' then return caps(u, v, list) end
  end)
  prune(g)
end

-- Vidro: polígono com borda própria, tons em faixas na diagonal e o reflexo (duas faixas claras em "/").
-- o = { pal = 'claro meio escuro', edge = cor da borda, ew = largura da borda, c = onde passa o reflexo (u + v),
--       m, len = centro e meio comprimento do reflexo em (u - v), fn = function(u, v) extra }.
local function glass(u, v, k, pts, o)
  if not inpoly(u, v, pts) then return end
  local de = 1e9
  for i = 1, #pts do
    local a, b = pts[i], pts[i % #pts + 1]
    de = min(de, dseg(u, v, a[1], a[2], b[1], b[2]))
  end
  if de < (o.ew or 0.55) then return o.edge or 'G' end
  if o.fn then
    local c = o.fn(u, v)
    if c then return c end
  end
  if o.c and de > 0.8 and abs(u - v - o.m) < o.len then
    local q = u + v - o.c
    if abs(q) < 0.55 then return 'Y' elseif abs(q - 1.9) < (k > 1 and 0.4 or 0.5) then return 'J' end
  end
  local band = floor((u + v) * (k > 1 and 0.9 or 1.4) + (o.ph or 0)) % 3
  local i = (u + v - (o.c or (u + v))) < 0 and 1 or 2
  if band == 0 then i = i + 1 end
  return o.pal:sub(i, i)
end
-- Estrela de quatro pontas (o reflexo que pisca), só sobre o corpo.
local function star(u, v, sx, sy, len)
  local du, dv = abs(u - sx), abs(v - sy)
  if du < 0.5 and dv < 0.5 then return 'Y' end
  if (du < 0.5 and dv < len) or (dv < 0.5 and du < len) then return 'J' end
end
-- Lente de farol: miolo claro, anéis e o aro cromado.
local function lens(u, v, cx, cy, r, ring, k)
  local d = sqrt((u - cx) ^ 2 + (v - cy) ^ 2)
  if d > r + ring then return end
  if d > r then return ((u - cx) + (v - cy) < 0) and 'M' or 'm' end
  if d < r * 0.3 then return 'Y' end
  if k > 1 and r > 3 and abs((u - cx) % 1.5 - 0.75) < 0.2 then return 'H' end
  return floor(d * (r > 3 and 1 or 1.6)) % 2 == 0 and 'J' or 'H'
end

-- O beija-flor do Eco, como função: devolve a cor do pixel (ou nil). Também é o reflexo dentro do caco da Fagulha.
local AX, AY = 0.766, -0.643
local WN = { { 15.4, 12.8 }, { 13.2, 14.8 }, { 2.6, 6.4 }, { 3.6, 3.4 }, { 9.6, 4.6 } }
local WF = { { 16.6, 11.4 }, { 14.6, 12.6 }, { 9.4, 3.4 }, { 12.4, 2.6 }, { 16.4, 6 } }
local TAIL = { { 9.6, 18.4, 3.6, 23.4, 1.35, 0.4, 'e', 'n' }, { 10.2, 19.2, 6.8, 25, 1.25, 0.4, 'f', 'n' } }
local BILL = { { 20.6, 10.3, 25.6, 9.3, 0.55, 0.45, 'z', 'Z' } }
local function bird(u, v, k)
  local d = sqrt((u - 18.4) ^ 2 + (v - 10.2) ^ 2)
  if d <= 2.7 then
    if k > 1 and (u - 19.2) ^ 2 + (v - 9.8) ^ 2 < 0.06 then return 'W' end
    if (u - 19.5) ^ 2 + (v - 10.1) ^ 2 < 0.4 then return 'o' end
    local sh = (u - 18.4) * 0.5 + (v - 10.2)
    return sh < -1.2 and 'e' or (sh < 1 and 'f' or 'n')
  end
  local c = glass(u, v, k, WN, { pal = '123', edge = '4', c = 16.4, m = 2, len = 3.4 })
  if c then return star(u, v, 6.6, 6.2, 1.6) or c end
  -- papo: lente de farol
  local gd = ((u - 17.5) / 1.8) ^ 2 + ((v - 13.3) / 1.6) ^ 2
  if gd <= 1 then return gd < 0.14 and 'Y' or (gd < 0.55 and 'J' or 'H') end
  local du, dv = u - 13, v - 15.5
  local la, lb = du * AX + dv * AY, -du * AY + dv * AX
  if (la / 5.6) ^ 2 + (lb / 3.3) ^ 2 <= 1 then
    local i = lb < -0.9 and 1 or (lb < 1.3 and 2 or 3)
    if (la * 1.1 + (floor(lb * 1.3) % 2) * 0.5) % 1 < 0.34 then i = i + 1 end
    return ('abcd'):sub(i, i)
  end
  c = caps(u, v, TAIL)
  if c then return c end
  c = glass(u, v, k, WF, { pal = '345', edge = '5', c = 20.5, m = 5, len = 2.6 })
  if c then return c end
  return caps(u, v, BILL)
end

-- FAGULHA (Glint Mote): um caco de vidro com o reflexo que pisca, maior que o caco.
local function fagulhaMapa()
  local g = L.frame({
    '............',
    '.....S......',
    '............',
    '....1J2.....',
    '..112Y23g...',
    'S.2JYYYJ3.S.',
    '..233Y34G...',
    '...34J45....',
    '....455.....',
    '............',
    '.....S......',
    '............',
  }, 12, 12, 'fagulha')
  L.outline(g, 'A', solid(''))
  return g
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local P = { { 34, 14 }, { 66, 20 }, { 78, 46 }, { 62, 80 }, { 30, 74 }, { 18, 40 } }
  paint(g, 1, 0, function(u, v, x, y)
    -- a espessura do vidro, verde, do lado de baixo
    if not inpoly(u, v, P) then
      if inpoly(u - 1.5, v - 3, P) then return (u + v) % 6 < 2 and 'g' or 'G' end
      return
    end
    return glass(u, v, 2, P, { pal = '234', edge = '1', ew = 1.6, c = 106, m = 2, len = 30, fn = function(uu, vv)
      -- o reflexo de um beija-flor que não está na frente do caco
      local c = bird((uu - 22) / 1.9 + 1, (vv - 30) / 1.9 + 3, 1)
      if c then return (c == 'Y' or c == 'J' or c == 'H') and 'J' or ((c == 'z' or c == 'Z' or c == '1' or c == '2') and '3' or (c == 'o' and '2' or '5')) end
      local st = star(uu / 3, vv / 3, 18.5, 10.5, 7)
      if st then return st end
    end })
  end)
  prune(g)
  L.outline(g, 'A', solid(''))
  -- os braços da estrela passam do caco
  for i = 1, 13 do
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local x, y = 55 + d[1] * (6 + i * 2), 31 + d[2] * (6 + i * 2)
      L.rect(g, x, y, x + 2, y + 2, i > 11 and 'S' or 's', '.')
    end
  end
  dust(g, 3, 0, { { 3, 5 }, { 28, 26, 's' }, { 6, 27 }, { 29, 12 }, { 2, 17, 's' }, { 13, 30 } })
  return g
end

-- ECO (Glimlet): beija-flor-tesoura pairando, em proporção natural. As asas são dois cacos de vidro de corte reto, o
-- bico é uma agulha de vidro e o papo é uma lente de farol. O detalhe errado: o reflexo na asa não é de nada em volta.
local function eco(k, S, off)
  local g = L.grid(S, S)
  paint(g, k, off, function(u, v) return bird(u, v, k) end)
  prune(g)
  L.outline(g, 'A', SOLID_ECO)
  dust(g, k, off, k > 1 and { { 3, 3.6, 's' }, { 11.4, 1.6 }, { 22.6, 5.4 }, { 24.6, 14.4, 's' }, { 20.4, 17.6 }, { 2.4, 14 }, { 12.6, 24.6 } }
    or { { 3, 3, 's' }, { 22, 14 } })
  return g
end

-- ESPÍRITO (Prismkin): o tronco virou um prisma de vidro; a luz entra branca pelo papo e sai separada na cauda.
-- Três asas de vidraça (duas de um lado, uma do outro), dois bicos, três olhos em fila.
local function espirito(k, S, off)
  local g = L.grid(S, S)
  local FR = { { 20.5, 13.5 }, { 23.5, 19.5 }, { 17.5, 20.5 } }
  local TOPF = { { 20.5, 13.5 }, { 17.5, 20.5 }, { 8.5, 25.5 }, { 11.5, 18.5 } }
  local BOT = { { 17.5, 20.5 }, { 23.5, 19.5 }, { 14.5, 24.5 }, { 8.5, 25.5 } }
  local W1 = { { 19.6, 14.2 }, { 17, 15.8 }, { 5.4, 8.4 }, { 8.4, 4.6 }, { 12.4, 6.6 } }
  local W2 = { { 20.8, 13 }, { 18.6, 14 }, { 13.4, 4.4 }, { 16.6, 3.2 }, { 19.4, 7.4 } }
  local W3 = { { 20.6, 20.6 }, { 22.8, 19.9 }, { 29.8, 27.2 }, { 28, 30 }, { 24.8, 28 } }
  local tail = {
    { 10.6, 22.6, 2.8, 23.4, 1.0, 0.45, 'R', 'R' }, { 10.4, 23.4, 3.4, 27.6, 1.0, 0.45, 'J', 'J' },
    { 10.6, 24.2, 5.6, 31, 1.0, 0.45, 'L', 'L' }, { 11.2, 24.6, 9, 32.6, 1.0, 0.45, 'B', 'B' },
  }
  local bills = { { 27, 10, 33.2, 7.8, 0.55, 0.45, 'z', 'Z' }, { 27, 11.2, 32.8, 13.4, 0.55, 0.45, 'z', 'Z' } }
  local function crack(u, v)
    local d = min(dseg(u, v, 12, 9.4, 9.6, 6.4), dseg(u, v, 12, 9.4, 8, 9.2), dseg(u, v, 12, 9.4, 14.4, 12.2))
    if d < 0.36 then return '5' end
    if abs((u - v) - 1.4) < 0.3 then return 'm' end          -- o caixilho da vidraça
  end
  paint(g, k, off, function(u, v, x, y)
    local d = sqrt((u - 24.6) ^ 2 + (v - 10.6) ^ 2)
    if d <= 2.8 then
      for n = 0, 2 do
        local ex, ey = 23.4 + n * 1.35, 9.6 + n * 0.5
        if k > 1 and (u - ex + 0.25) ^ 2 + (v - ey + 0.25) ^ 2 < 0.05 then return 'W' end
        if (u - ex) ^ 2 + (v - ey) ^ 2 < 0.3 then return 'o' end
      end
      local sh = (u - 24.6) * 0.5 + (v - 10.6)
      return sh < -1.2 and 'e' or (sh < 1 and 'f' or 'n')
    end
    local c = lens(u, v, 23, 13.9, 1.7, 0.6, k)
    if c then return c end
    c = glass(u, v, k, W1, { pal = '123', edge = 'G', c = 20, m = 1.5, len = 3.6, fn = crack })
    if c then return star(u, v, 8.4, 7.4, 1.6) or c end
    c = glass(u, v, k, FR, { pal = '123', edge = 'g', ew = 0.5 })
    if c then return c end
    c = glass(u, v, k, TOPF, { pal = '234', edge = 'g', ew = 0.5, fn = function(uu, vv)
      -- o raio branco entra e sai em quatro cores
      if dseg(uu, vv, 19.2, 16.6, 15.6, 19.2) < 0.45 then return 'Y' end
      for n, ch in ipairs({ 'R', 'J', 'L', 'B' }) do
        if dseg(uu, vv, 15.6, 19.2, 10.4, 19.6 + n * 1.15) < 0.4 then return ch end
      end
    end })
    if c then return c end
    c = glass(u, v, k, BOT, { pal = '455', edge = 'G', ew = 0.5 })
    if c then return c end
    if ((u - 22) / 2.7) ^ 2 + ((v - 13.2) / 2.3) ^ 2 <= 1 then return (u + v) % 2 < 1 and 'b' or 'c' end
    for _, s in ipairs(tail) do
      -- cada pena da cauda é escura na raiz e na borda, e acesa no miolo
      local dx, dy = s[3] - s[1], s[4] - s[2]
      local t = max(0, min(1, ((u - s[1]) * dx + (v - s[2]) * dy) / (dx * dx + dy * dy)))
      local dd = sqrt((u - s[1] - dx * t) ^ 2 + (v - s[2] - dy * t) ^ 2)
      local rr = s[5] + (s[6] - s[5]) * t
      if dd <= rr then
        if t < (k > 1 and 0.24 or 0.45) then return 'n' end
        return (k > 1 and dd > rr * 0.55) and 'f' or s[7]
      end
    end
    c = glass(u, v, k, W3, { pal = '234', edge = 'G', c = 49.4, m = -3, len = 3 })
    if c then return c end
    c = glass(u, v, k, W2, { pal = '345', edge = '5', c = 22, m = 7.4, len = 3 })
    if c then return c end
    return caps(u, v, bills)
  end)
  prune(g)
  L.outline(g, 'A', solid('zZRJLB'))                            -- a luz da cauda não tem contorno
  dust(g, k, off, k > 1 and { { 3.4, 3.6, 's' }, { 26.4, 3.4 }, { 31.4, 17.4 }, { 1.6, 20.4 }, { 1.4, 26.4, 's' }, { 3.2, 30.6 }, { 6.4, 33.6 }, { 14, 30, 's' }, { 32, 26.4 } }
    or { { 3, 3, 's' }, { 1, 26 }, { 3, 31, 's' }, { 6, 33 }, { 31, 17 } })
  return g
end

-- ENTIDADE MAIOR: um farol de lente no centro, três bicos de agulha e três vidraças em cata-vento, com penas atrás.
-- Não tem cabeça: os olhos só existem refletidos nas vidraças, e cada vidraça reflete uma hora diferente do mesmo céu.
local function entidade(k, S, off)
  local g = L.grid(S, S)
  local cx, cy = 23.5, 24.5
  local panes, thick, feathers = {}, {}, {}
  for i = 0, 2 do
    local a = -pi / 2 + 0.12 + i * 2 * pi / 3
    local b = a + pi / 3
    local p = {}
    for _, q in ipairs({ { 5.6, -0.1 }, { 13, -0.66 }, { 20.6, 0.06 }, { 15.6, 0.6 } }) do
      local px, py = pol(cx, cy, q[1], b + q[2]); p[#p + 1] = { px, py }
    end
    local ex, ey = pol(cx, cy, 12.4, b - 0.04)
    panes[i] = { pts = p, ex = ex, ey = ey }
    local x0, y0 = pol(cx, cy, 6.4, a); local x1, y1 = pol(cx, cy, 13.6, a + 0.05); local x2, y2 = pol(cx, cy, 20.4, a + 0.17)
    thick[#thick + 1] = { x0, y0, x1, y1, 1.35, 0.85, 'M', 'm' }
    thick[#thick + 1] = { x1, y1, x2, y2, 0.85, 0.35, 'M', 'm' }
    for n = 0, 3 do
      local fx0, fy0 = pol(cx, cy, 8.4 + n * 1.6, b + 0.5)
      local fx1, fy1 = pol(cx, cy, 14.4 + n * 2, b + 0.86 - n * 0.05)
      feathers[#feathers + 1] = { fx0, fy0, fx1, fy1, 1.25, 0.4, n % 2 == 0 and 'b' or 'e', n % 2 == 0 and 'c' or 'f' }
    end
  end
  local SKY = { [0] = { pal = 't12', ph = 0 }, { pal = 'uf4', ph = 1 }, { pal = 'vn5', ph = 2 } }
  paint(g, k, off, function(u, v, x, y)
    local c = lens(u, v, cx, cy, 5.6, 1.4, k)
    if c then return c end
    for i = 0, 2 do
      local P = panes[i]
      c = glass(u, v, k, P.pts, { pal = SKY[i].pal, ph = SKY[i].ph, edge = 'G', ew = 0.6, c = P.ex + P.ey + 2.6, m = P.ex - P.ey, len = 3.4,
        fn = function(uu, vv)
          local d = sqrt((uu - P.ex) ^ 2 + (vv - P.ey) ^ 2)
          if k > 1 and (uu - P.ex + 0.5) ^ 2 + (vv - P.ey + 0.5) ^ 2 < 0.12 then return 'W' end
          if d < 1.25 then return 'o' elseif d < 1.9 then return i == 2 and '4' or '5' end
          -- o sol num vidro, a lua no outro
          local sx, sy = P.ex + (P.pts[3][1] - P.ex) * 0.55, P.ey + (P.pts[3][2] - P.ey) * 0.55
          if i == 0 then return star(uu, vv, sx, sy, 1.6) end
          if i == 2 then
            local dm = sqrt((uu - sx) ^ 2 + (vv - sy) ^ 2)
            if dm < 1.5 and sqrt((uu - sx - 0.8) ^ 2 + (vv - sy + 0.4) ^ 2) > 1.2 then return 'J' end
          end
        end })
      if c then return c end
    end
    return caps(u, v, thick) or caps(u, v, feathers)
  end)
  prune(g)
  L.outline(g, 'A', SOLID)
  dust(g, k, off, { { 4, 6, 's' }, { 41, 7 }, { 44, 30, 's' }, { 3.4, 36 }, { 12, 44.6 }, { 36.6, 44, 's' }, { 30, 3.6 }, { 7.6, 18 } })
  return g
end

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)

-- ARQUÉTIPO: o beija-flor do Eco, pairando, grande demais e de vidro cinza; só a cabeça e a cauda guardam a cor. A asa
-- está em quatro lugares ao mesmo tempo, como cacos em leque, e o bico são três agulhas. Não tem olho. No papo, onde
-- ficava a lente do farol, a figura não fecha: o vão, aberto para a frente, e dentro dele o mesmo beija-flor virado
-- para o outro lado. A luz em volta dele faz curva.
local function arquetipo(k, S, ox, oy)
  ox, oy = ox or 0, oy or 0
  local g = L.grid(S, S)
  local SC, BX, BY = 2, 6, 6
  local GREY = { a = '7', b = '8', c = '9', d = '0', ['1'] = '6', ['2'] = '7', ['3'] = '8', ['4'] = 'G', ['5'] = 'g', o = 'n', W = 'n' }
  local function rot(pts, deg)
    local ca, sa, out = cos(math.rad(deg)), sin(math.rad(deg)), {}
    for i, q in ipairs(pts) do
      local dx, dy = q[1] - 15.4, q[2] - 12.8
      out[i] = { 15.4 + dx * ca - dy * sa, 12.8 + dx * sa + dy * ca }
    end
    return out
  end
  local FAN = { rot(WN, -34), rot(WN, -66), rot(WN, 30) }
  local BILLS = { { 20.6, 10.7, 25.2, 12.4, 0.5, 0.4, 'z', 'Z' }, { 20.4, 9.8, 24.6, 6.8, 0.5, 0.4, 'z', 'Z' } }
  local function fig(bu, bv)
    local c = bird(bu, bv, k * SC)
    if c then return GREY[c] or c end
    for i, pts in ipairs(FAN) do
      c = glass(bu, bv, k * SC, pts, { pal = i == 1 and '789' or '890', edge = i == 2 and 'H' or '9', ew = 0.4, ph = i, c = 12 + i * 3, m = 2, len = 3,
        fn = function(uu, vv)                                                       -- cada caco reflete outra hora do céu
          if abs((uu - vv * 0.6) % 5 - 2.5) < 0.5 then return ({ 'u', 'v', 't' })[i] end
        end })
      if c then return c end
    end
    return caps(bu, bv, BILLS)
  end
  local function UV(x, y) return (x + 0.5 - ox) / k, (y + 0.5 - oy) / k end
  for y = 0, S - 1 do for x = 0, S - 1 do
    local u, v = UV(x, y)
    local c = fig((u - BX) / SC, (v - BY) / SC)
    if c then
      local i = ('67890'):find(c, 1, true)                                          -- o vidro cinza é fosco: grão de dois tons
      if i and i < 5 and R.noise(max(1, floor(k / 2 + 0.5)), 3)(x, y) then c = ('67890'):sub(i + 1, i + 1) end
      g[y][x] = c
    end
  end end
  prune(g)
  L.outline(g, 'A', SOLID)
  -- o vão no papo, e o mesmo beija-flor lá dentro, virado
  local VX, VY, VR, IS = BX + 17.4 * SC, BY + 13.6 * SC, 6, 0.44
  local pk = max(1, floor(k / 2 + 0.5))
  for y = 0, S - 1 do for x = 0, S - 1 do
    local u, v = UV(x, y)
    local t = sqrt((u - VX) ^ 2 + (v - VY) ^ 2) / VR
    if t <= 1 then
      local was = g[y][x] ~= '.'
      g[y][x] = '.'
      local c = bird(17.4 - (u - VX) / (SC * IS), 13.6 + (v - VY) / (SC * IS), k)
      if t > 0.78 then if was then g[y][x] = 'X' end
      elseif c then g[y][x] = (('YJH'):find(c, 1, true) or c == 'z' or c == 'Z') and 's' or ((('12345'):find(c, 1, true)) and 'x' or 'X')
      elseif (x // pk + y // pk) % 2 == 0 and t > 0.3 then g[y][x] = 'x' end
    end
  end end
  -- a luz que faz curva, em volta
  for y = 0, S - 1 do for x = 0, S - 1 do
    if g[y][x] == '.' then
      local u, v = UV(x, y)
      local r, th = sqrt((u - 31.5) ^ 2 + (v - 32) ^ 2), math.atan(v - 32, u - 31.5)
      if r > 25 and r < 31.5 then
        local q = (th - (r - 25) * 0.085) * 12 / (2 * pi)
        if abs(q - floor(q + 0.5)) < 0.09 * 25 / r and floor(r * 1.2) % 4 ~= 0 then g[y][x] = r < 28 and 's' or 'S' end
      end
    end
  end end
  return g
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
  local m = C.save('glare', stage, kind, g, LEG, LIT, LOOSE)
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
out('arquetipo', 'mapa', arquetipo(1, 64))
out('arquetipo', 'retrato', arquetipo(3, 128, -63, -27))                            -- busto: a cabeça sem olho, as agulhas e o vão do papo
print('RESUMO ' .. table.concat(RES, ' | '))
print('ok glare')
