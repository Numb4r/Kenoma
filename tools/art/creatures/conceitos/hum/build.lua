-- Conceitos da família Hum (Etapa 1): Fagulha, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- O Eco é o Humoth (hum_eco_*.png, copiado pelo folhas.py) e não sai daqui.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/hum/build.lua')
-- Cada etapa é uma função de k (1 no mapa). No retrato (k > 1) a pose é a mesma e entra o detalhe próprio dele:
-- olho em matriz de LED com pupila, antena com barbas, escamas na asa, veio da madeira, rebites, mais olhos no vão.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

local LEG = {
  A = '#1A1424',                                              -- contorno
  B = '#8F86C9', T = '#C4BDF0',                               -- antena
  C = '#2A2140', D = '#4A3D6B', R = '#6A5C94',                -- pelo
  G = '#34305E', F = '#4D4A8A', E = '#7672B8',                -- asa (pó índigo, as cores do Humoth)
  P = '#28244A', Q = '#3D3A70',                               -- asa na sombra
  ['1'] = '#A9A7BC', ['2'] = '#7E7C92', ['3'] = '#5C5A70', ['4'] = '#45435A', -- asa de cinza (Arquétipo)
  K = '#6B3A22', M = '#DDA060', c = '#A8663A',                -- cobre desencapado (c é o meio)
  n = '#2B2836', N = '#55525F',                               -- cabo de borracha
  u = '#33363F', U = '#4A4E5A', V = '#6E7380', W = '#9EA3AE', -- aço galvanizado
  o = '#6E3A2C', O = '#9A5A44',                               -- porcelana do isolador
  w = '#4E3C2E', x = '#75604A',                               -- madeira de poste e cruzeta
  z = '#0D0914',                                              -- o vão: o dentro mais escuro que o contorno
  h = '#17444C', i = '#245A62', j = '#6B5A44',                -- LED e veio apagados (corpo)
  H = '#5FD3C6', I = '#D9FFF6',                               -- olho de LED aceso
  J = '#FFD84A', Y = '#FFF3A8',                               -- veio aceso
  S = '#FFD84A', s = '#FFF3A8',                               -- faísca solta (só no emissivo)
}
LEG.q = LEG.K; LEG.k = LEG.c; LEG.m = LEG.M                   -- o mesmo cobre em fio fino, sem contorno
LEG.b = LEG.B                                                 -- barba de antena, sem contorno
local LIT = { H = 'h', I = 'i', J = 'j', Y = 'j' }
local LOOSE = 'Ss'
-- Contorno seletivo: fio fino, barba e veio não puxam contorno.
local SOLID = ''
for ch in pairs(LEG) do
  if not ('AqkmbJYSs'):find(ch, 1, true) then SOLID = SOLID .. ch end
end

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end

-- Asa de esfinge: o = { x, y (raiz), ang (graus, y para baixo), len, wid, side (+1 ou -1: lado da borda de fuga),
-- pal = { borda, meio, base, faixa }, torn = período do rasgo em px, clip = function(u, v) }.
local function wingGeo(o)
  local a = math.rad(o.ang)
  local dx, dy = math.cos(a), math.sin(a)
  return dx, dy, -dy * o.side, dx * o.side
end
local function wingEdges(o, u, raw)
  local s = math.sin(math.pi * u ^ 0.75)
  local tr = s > 0 and s ^ 0.7 or 0
  if o.torn and not raw and floor(u * o.len / o.torn) % 2 == 1 then tr = tr * 0.72 end
  return 0.16 * (1 - u) ^ 0.5 + 0.03, tr
end
local function wpt(o, u, t)
  local dx, dy, px, py = wingGeo(o)
  local le, tr = wingEdges(o, u, true)
  local v = (-le + t * (tr + le)) * o.wid
  return o.x + dx * u * o.len + px * v, o.y + dy * u * o.len + py * v
end
local function wing(g, o)
  local dx, dy, px, py = wingGeo(o)
  local r = o.len + o.wid + 2
  for y = floor(o.y - r), ceil(o.y + r) do
    for x = floor(o.x - r), ceil(o.x + r) do
      local rx, ry = x - o.x, y - o.y
      local u = (rx * dx + ry * dy) / o.len
      if u >= 0 and u <= 1 then
        local v = (rx * px + ry * py) / o.wid
        local le, tr = wingEdges(o, u)
        if v >= -le and v <= tr and (not o.clip or o.clip(u, v)) then
          local t = (v + le) / (tr + le)
          local band = floor(u * o.len / (o.band or 2)) % 2
          local ch = o.pal[3]
          if t < 0.16 then
            ch = o.pal[1]
            -- letreiro: uma fileira de LEDs na borda de ataque
            if o.marquee and floor(u * o.len / o.marquee[1]) % o.marquee[2] == 1 and u > 0.15 and u < 0.9 then ch = 'H' end
          elseif t < 0.42 then ch = (o.rich and band == 1) and o.pal[3] or o.pal[2]
          elseif t > 0.88 and band == 0 then ch = o.pal[2]
          elseif band == 1 and (t > 0.58 or o.rich) then ch = o.pal[4] end
          L.set(g, x, y, ch)
        end
      end
    end
  end
end
local function veins(g, o, list, th)
  local mask = table.concat(o.pal)
  for _, q in ipairs(list) do
    local x0, y0 = wpt(o, q[1], q[2]); local x1, y1 = wpt(o, q[3], q[4])
    for d = 0, (th or 1) - 1 do L.line(g, x0 + d, y0, x1 + d, y1, 'J', mask) end
  end
end

-- Olho de LED. Pequeno: o bloco 4x4 do Humoth. Médio: disco cheio. Grande: matriz de LED com aro.
-- pupil = { dx, dy, r }: LEDs apagados dentro do olho; mask: o que o olho pode cobrir.
local function eye(g, cx, cy, r, pupil, mask)
  if r < 2.2 then
    L.put(g, floor(cx - 1), floor(cy - 1), { '.HH.', 'HIIH', 'HIIH', '.HH.' })
    return
  end
  for y = floor(cy - r - 1), ceil(cy + r + 1) do
    for x = floor(cx - r - 1), ceil(cx + r + 1) do
      local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
      if r < 3.4 then
        if d <= r then L.set(g, x, y, d < r * 0.55 and 'I' or 'H', mask) end
      elseif d <= r + 1 and d > r then L.set(g, x, y, 'A', mask)
      elseif d <= r then
        local ch = 'h'
        if (x + y) % 2 == 0 then ch = d < r * 0.4 and 'I' or 'H' end
        if pupil and sqrt((x - cx - pupil[1]) ^ 2 + (y - cy - pupil[2]) ^ 2) <= pupil[3] then ch = (x + y) % 2 == 0 and 'i' or 'h' end
        L.set(g, x, y, ch, mask)
      end
    end
  end
end
-- Olho das etapas altas: no retrato é sempre matriz, com a pupila apontando para um lado próprio (seed).
local function E(g, x, y, rmap, k, seed, mask)
  if k == 1 then return eye(g, x, y, rmap, nil, mask) end
  local r = math.max(rmap * k, 3.6)
  local a = (hash(seed, 7, 3) % 8) * math.pi / 4
  eye(g, x, y, r, { math.cos(a) * r * 0.32, math.sin(a) * r * 0.32, r * 0.4 }, mask)
end

-- Pelo em escamas (C, D, com R do lado da luz) e bobina de cobre (voltas inclinadas).
local function fur(g, cx, y0, y1, hw, p)
  for y = floor(y0), floor(y1) do
    local w = hw(y)
    for x = ceil(cx - w), floor(cx + w) do
      local row = floor((y + abs(x - cx) * 0.7) / p)
      local ch = row % 2 == 0 and 'C' or 'D'
      if ch == 'D' and x < cx - w * 0.25 and row % 4 == 1 then ch = 'R' end
      L.set(g, x, y, ch)
    end
  end
end
local function coil(g, cx, y0, y1, hw, p)
  for y = floor(y0), floor(y1) do
    local w = hw(y)
    for x = ceil(cx - w), floor(cx + w) do
      local ch = floor((y + (x - cx) * 0.5) / p) % 2 == 0 and 'c' or 'K'
      if ch == 'c' and x < cx - w * 0.2 and x >= cx - w * 0.2 - p then ch = 'M' end
      L.set(g, x, y, ch)
    end
  end
end
-- Fio ou antena: linha quebrada de espessura th, a com um b a cada três passos.
local function wire(g, pts, a, b, th, mask)
  local n = 0
  th = th or 1
  for i = 1, #pts - 1 do
    local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
    local m = math.max(abs(x1 - x0), abs(y1 - y0))
    for s = 0, floor(m) do
      local t = m == 0 and 0 or s / m
      n = n + 1
      for d = 0, th - 1 do L.set(g, x0 + (x1 - x0) * t + d, y0 + (y1 - y0) * t, (n // th) % 3 == 0 and b or a, mask) end
    end
  end
end
-- Antena de pluma: no retrato ganha barbas dos dois lados.
local function feather(g, pts, k, mask)
  if k > 1 then
    for i = 1, #pts - 1 do
      local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
      local len = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
      local ux, uy = (x1 - x0) / len, (y1 - y0) / len
      for s = 2, len, 3 do
        for _, sd in ipairs({ -1, 1 }) do
          local bx, by = x0 + ux * s, y0 + uy * s
          L.line(g, bx, by, bx + (-uy * sd * 0.8 + ux * 0.6) * 3.5, by + (ux * sd * 0.8 + uy * 0.6) * 3.5, 'b', '.b')
        end
      end
    end
  end
  wire(g, pts, 'B', 'T', k, mask)
end
local function plus(g, x, y, k)
  L.rect(g, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, 's')
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    L.rect(g, floor(x) + d[1] * k, floor(y) + d[2] * k, floor(x) + d[1] * k + k - 1, floor(y) + d[2] * k + k - 1, 'S', '.')
  end
end
local function dot(g, x, y, k, ch)
  L.rect(g, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, ch or 'S', '.')
end
local function led(g, x, y, k, ch)
  L.rect(g, floor(x + 0.5), floor(y + 0.5), floor(x + 0.5) + k - 1, floor(y + 0.5) + k - 1, ch or 'H')
end

-- FAGULHA (Arc Mote): um ocelo arrancado da asa, ainda aceso, com um veio pendurado soltando faísca.
local function fagulhaMapa()
  return L.frame({
    '............',
    '.....AA.....',
    '....AEEA....',
    '...AEFFFA...',
    '..AEFHHGGA..',
    '..AFHIIHGA..',
    '..AFHIIHPA..',
    '..AGGHHPA...',
    '...AGJPA.S..',
    '....AJA.....',
    '.....J..S...',
    '...S........',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local function zig(v, n) return (floor(v * n) % 2) * 0.05 end
  local o = { x = 14, y = 92, ang = -66, len = 104, wid = 34, side = 1, pal = { 'E', 'F', 'G', 'P' }, band = 2, rich = true,
    clip = function(u, v) return u > 0.22 + zig(v, 7) + v * 0.1 and u < 0.74 + zig(v, 5) - v * 0.12 end }
  wing(g, o)
  local ex, ey = wpt(o, 0.47, 0.52)
  veins(g, o, { { 0.42, 0.6, 0.30, 0.98 }, { 0.50, 0.6, 0.47, 0.99 }, { 0.55, 0.55, 0.66, 0.97 }, { 0.44, 0.4, 0.36, 0.12 } }, 2)
  eye(g, ex, ey, 12)
  -- o veio que sobrou: um fio de cobre pendurado da borda rasgada
  local fx, fy = wpt(o, 0.30, 0.98)
  wire(g, { { fx, fy }, { fx - 3, fy + 6 }, { fx + 1, fy + 11 }, { fx - 2, fy + 14 } }, 'c', 'M', 2)
  wire(g, { { fx, fy }, { fx - 2, fy + 4 } }, 'J', 'Y', 2)
  L.outline(g, 'A')
  plus(g, fx - 5, fy + 16, 2)
  dot(g, fx + 6, fy + 12, 2); dot(g, fx - 11, fy + 9, 2, 's'); dot(g, fx + 4, fy + 17, 2)
  dot(g, 76, 20, 2); dot(g, 82, 30, 2, 's'); dot(g, 20, 30, 2); dot(g, 14, 44, 2, 's')
  return g
end

-- ESPÍRITO (Coilkin): a mariposa tomada pelos fios. Abdômen em bobina de cobre, asas de trás só na armação de fio,
-- três antenas e três olhos (dois numa asa, um na outra).
local function espirito(k)
  local S = 36 * k
  local g = L.grid(S, S)
  local cx = S / 2 - 0.5
  local wings = {}
  for _, sg in ipairs({ -1, 1 }) do
    -- asas de trás: três fios de cobre e um resto de membrana
    local rx, ry = cx + sg * 2 * k, 17 * k
    local ends = { { cx + sg * 13 * k, 22 * k }, { cx + sg * 10.5 * k, 28 * k }, { cx + sg * 6 * k, 31.5 * k } }
    C.poly(g, { { rx, ry }, { cx + sg * 9 * k, 20.5 * k }, { cx + sg * 7.5 * k, 25 * k } }, 'P')
    C.poly(g, { { rx, ry }, { cx + sg * 6 * k, 19.5 * k }, { cx + sg * 5 * k, 22 * k } }, 'Q')
    for n, e in ipairs(ends) do
      wire(g, { { rx, ry }, { (rx + e[1]) / 2, (ry + e[2]) / 2 + (2 - n * 0.5) * k }, e }, 'k', n == 2 and 'm' or 'q', k)
      L.rect(g, floor(e[1] + 0.5), floor(e[2] + 0.5), floor(e[1] + 0.5) + ceil(k) - 1, floor(e[2] + 0.5) + ceil(k) - 1, 'Y')
    end
    local o = { x = cx + sg * 2.5 * k, y = 12.5 * k, ang = sg < 0 and 203 or -23, len = 14 * k, wid = 8 * k, side = sg,
      pal = { 'E', 'F', 'G', 'P' }, band = 2, torn = 3 * k, rich = k > 1 }
    wing(g, o)
    wings[sg] = o
  end
  local eyes = { { wings[-1], 0.30 }, { wings[-1], 0.68 }, { wings[1], 0.44 } }
  for _, e in ipairs(eyes) do
    veins(g, e[1], { { e[2] - 0.03, 0.6, e[2] - 0.10, 0.98 }, { e[2] + 0.06, 0.6, e[2] + 0.14, 0.98 },
      { e[2], 0.4, e[2] + 0.08, 0.1 } }, k > 1 and 2 or 1)
  end
  for _, e in ipairs(eyes) do
    local x, y = wpt(e[1], e[2], 0.5)
    eye(g, x, y, 1.6 * k)
  end
  -- corpo
  coil(g, cx, 17 * k, 31 * k, function(y) return (2.6 - 1.3 * (y - 17 * k) / (14 * k)) * k end, k)
  wire(g, { { cx, 31 * k }, { cx + 1.5 * k, 32.5 * k }, { cx + 0.6 * k, 33.6 * k } }, 'k', 'm', k)
  fur(g, cx, 10 * k, 17 * k - 1, function(y) return ((y < 11 * k or y >= 16 * k) and 2.2 or 3) * k end, k)
  fur(g, cx, 8 * k, 10 * k - 1, function() return 1.8 * k end, k)
  wire(g, { { cx - 3 * k, 11.5 * k }, { cx + 3 * k, 15 * k } }, 'n', 'N', k)
  -- antenas: duas de pluma, a terceira é um fio desencapado
  for _, sg in ipairs({ -1, 1 }) do
    wire(g, { { cx + sg * 1.4 * k, 8.4 * k }, { cx + sg * 4 * k, 5.2 * k }, { cx + sg * 9 * k, 3 * k } }, 'B', 'T', k)
    wire(g, { { cx + sg * 4 * k, 4.4 * k }, { cx + sg * 9 * k, 2.2 * k } }, 'B', 'T', k)
  end
  wire(g, { { cx + 0.5, 8 * k }, { cx + 0.5 + 0.4 * k, 5 * k }, { cx + 0.5 - 0.4 * k, 3 * k } }, 'k', 'm', k)
  L.outline(g, 'A', SOLID)
  plus(g, cx + 0.5 - 0.4 * k, 1 * k - (k > 1 and 3 or 1), k)
  for _, sg in ipairs({ -1, 1 }) do
    dot(g, cx + sg * 14.5 * k, 23.5 * k, k); dot(g, cx + sg * 11.5 * k, 30 * k, k, 's'); dot(g, cx + sg * 7.5 * k, 33.4 * k, k)
  end
  dot(g, cx + 2.5 * k, 34.5 * k, k, 's')
  return g
end

-- ENTIDADE MAIOR: o poste é o corpo. O transformador abriu numa boca de pé, com dentes de aleta e olhos lá dentro;
-- duas asas rasgadas pendem como mortalha e a terceira sobe atrás da cruzeta (três asas, olhos em número diferente
-- em cada uma); no pé do poste, cinco antenas servem de pernas. Os fios da cruzeta caem para cima.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local cx = S / 2 - 0.5
  local WP = { 'F', 'Q', 'P', 'G' }
  local function W(x, y, ang, len, wid, side)
    return { x = x, y = y, ang = ang, len = len * k, wid = wid * k, side = side, pal = WP, band = 2, rich = k > 1,
      torn = 3 * k }
  end
  local top = W(cx, 15 * k, -90, 12.5, 7, 1)
  wing(g, top)
  -- poste
  for y = floor(12 * k), floor(46 * k) - 1 do
    for x = ceil(cx - 1.5 * k), floor(cx + 1.5 * k) do
      local ch = x < cx - 0.5 * k and 'x' or 'w'
      if k > 1 and hash(x, y // 4, 5) % 4 == 0 then ch = ch == 'x' and 'w' or 'x' end
      L.set(g, x, y, ch)
    end
  end
  local wl, wr = W(cx - 3 * k, 19 * k, 118, 22, 9, 1), W(cx + 3 * k, 19 * k, 62, 22, 9, -1)
  wing(g, wl); wing(g, wr)
  local eyes = { { wl, 0.28, 2.4 }, { wl, 0.52, 1.5 }, { wl, 0.74, 1.5 }, { wr, 0.45, 3.0 }, { wr, 0.80, 1.5 },
    { top, 0.42, 1.5 }, { top, 0.74, 1.5 } }
  for _, e in ipairs(eyes) do
    veins(g, e[1], { { e[2], 0.6, e[2] - 0.06, 0.98 }, { e[2] + 0.04, 0.6, e[2] + 0.12, 0.98 } }, k > 1 and 2 or 1)
    if k > 1 then veins(g, e[1], { { e[2], 0.4, e[2] + 0.08, 0.06 }, { e[2] - 0.03, 0.75, e[2] - 0.16, 0.8 } }, 2) end
  end
  for n, e in ipairs(eyes) do
    local x, y = wpt(e[1], e[2], 0.5)
    E(g, x, y, e[3], k, n)
  end
  -- cruzeta, isoladores e os fios que sobem
  local tips = {}
  L.rect(g, floor(cx - 14 * k), floor(11 * k), ceil(cx + 14 * k), floor(13 * k) - 1, 'w')
  L.rect(g, floor(cx - 14 * k), floor(11 * k), ceil(cx + 14 * k), floor(11 * k) + ceil(k / 2) - 1, 'x')
  for n, ix in ipairs({ -13, -8, 8, 13 }) do
    local ex = cx + ix * k
    for r = 0, 3 * k - 1 do
      local hw = (floor(r / k) % 2 == 0) and 1.6 * k or 1 * k
      L.rect(g, ceil(ex - hw), floor(11 * k - 1 - r), floor(ex + hw), floor(11 * k - 1 - r), floor(r / k) % 2 == 0 and 'O' or 'o')
    end
    local topY = ({ 2.5, 5, 4, 2 })[n] * k
    local y, pts, step = 8 * k, {}, 0
    while y > topY do
      pts[#pts + 1] = { ex + ((step % 2) * 2 - 1) * 0.7 * k * (step > 0 and 1 or 0), y }
      y = y - 2 * k; step = step + 1
    end
    pts[#pts + 1] = { ex + (n % 2 == 0 and 1 or -1) * 0.8 * k, topY }
    wire(g, pts, 'k', 'm', k)
    tips[#tips + 1] = pts[#pts]
  end
  -- transformador, com a boca
  local x0, x1 = ceil(cx - 4.5 * k), floor(cx + 4.5 * k)
  for y = floor(14 * k), floor(27 * k) - 1 do
    for x = x0, x1 do
      local col = floor((x - x0) / k)
      local ch = col % 2 == 0 and 'V' or 'U'
      if col == 1 then ch = 'W' elseif col >= 8 then ch = 'u' end
      if y < 15 * k then ch = col >= 8 and 'U' or 'W' end
      if floor(y / k) == 26 then ch = col == 1 and 'N' or 'n' end
      local t = (y - 15.5 * k) / (10 * k)
      if t > 0 and t < 1 then
        local m = 1.9 * k * math.sin(math.pi * t) ^ 0.8
        local d = abs(x - cx)
        if d <= m then
          ch = 'z'
          if floor(y / k) % 2 == 0 and d > m - 1.1 * k and m > 1.2 * k then ch = (k > 1 and x > cx) and 'V' or 'W' end
        elseif k > 1 and d <= m + 1 then ch = 'u' end
      end
      L.set(g, x, y, ch)
    end
  end
  if k == 1 then
    led(g, cx - 0.5, 19, 1); led(g, cx + 0.5, 22, 1); led(g, cx - 0.5, 23, 1, 'I')
  else
    eye(g, cx + 0.5, 18.4 * k, 1.5); eye(g, cx - 0.5, 21.6 * k, 1.5); led(g, cx + 0.5, 24 * k, 1); led(g, cx - 1.5, 16.6 * k, 1)
  end
  -- olhos soltos no poste
  led(g, cx - 1 * k, 30 * k, k); led(g, cx + 0.5 * k, 33 * k, k, 'I'); led(g, cx - 0.5 * k, 36.5 * k, k)
  -- cinco antenas no lugar das pernas
  for _, dx in ipairs({ -12, -7, 2, 8, 13 }) do
    local leg = { { cx, 40 * k }, { cx + dx * 0.6 * k, (37.5 - abs(dx) * 0.12) * k }, { cx + dx * k, 45 * k } }
    -- no mapa a perna é um fio de 1 px, sem contorno; no retrato é a antena inteira, com barbas
    if k == 1 then wire(g, leg, 'b', 'b', 1) else feather(g, leg, k) end
  end
  L.outline(g, 'A', SOLID)
  for n, t in ipairs(tips) do
    if n % 2 == 1 then plus(g, t[1], t[2] - 2 * k, k) else dot(g, t[1], t[2] - 2 * k, k, 's') end
    dot(g, t[1] + (n % 2 == 1 and 2 or -2) * k, t[2] + 1 * k, k)
  end
  return g
end

-- ARQUÉTIPO: a forma original. No lugar do corpo, uma boca redonda de armação de letreiro, com dentes, e dentro dela
-- um túnel de armações que afunda mais do que o corpo tem de fundo, com o olho de LED lá no fim e outros pelo caminho.
-- Três asas de cinza de tamanhos diferentes, olhos em número diferente em cada uma, sete antenas sem cabeça em volta
-- da gola de pelo. A armação está partida embaixo e o vão escorre para fora; o raio sai dali.
local function arquetipo(k)
  local S = 64 * k
  local g = L.grid(S, S)
  local cx, cy = S / 2 - 0.5, 31 * k
  local WA = { '1', '2', '3', '4' }
  local defs = {
    { -78, 18, { { 0.42, 2.4 }, { 0.66, 1.5 }, { 0.85, 1.5 } } },
    { 42, 18, { { 0.55, 3.0 } } },
    { 162, 17, { { 0.48, 1.5 }, { 0.74, 2.4 } } },
  }
  local seed = 0
  for n, d in ipairs(defs) do
    local a = math.rad(d[1])
    local o = { x = cx + math.cos(a) * 10 * k, y = cy + math.sin(a) * 10 * k, ang = d[1], len = d[2] * k, wid = 11 * k, side = 1,
      pal = WA, band = 2, rich = k > 1, torn = n == 2 and 3 * k or nil }
    wing(g, o)
    for _, e in ipairs(d[3]) do
      veins(g, o, { { e[1], 0.5, 0.05, 0.5 }, { e[1], 0.6, e[1] + 0.1, 0.98 } }, k > 1 and 2 or 1)
      if k > 1 then veins(g, o, { { e[1], 0.4, e[1] + 0.08, 0.06 }, { e[1] - 0.03, 0.75, e[1] - 0.16, 0.85 } }, 2) end
    end
    for _, e in ipairs(d[3]) do
      local x, y = wpt(o, e[1], 0.5)
      seed = seed + 1
      E(g, x, y, e[2], k, seed + 20)
    end
  end
  -- antenas onde não devia haver nenhuma
  for n, d in ipairs({ { -12, 9 }, { 12, 6 }, { 122, 9 }, { 140, 7 }, { 215, 8 }, { 236, 10 }, { 255, 6 } }) do
    local a, curl = math.rad(d[1]), (n % 2 == 0 and 0.35 or -0.3)
    local r0, r1 = 13 * k, (14 + d[2]) * k
    feather(g, { { cx + math.cos(a) * r0, cy + math.sin(a) * r0 }, { cx + math.cos(a) * (r0 + r1) / 2, cy + math.sin(a) * (r0 + r1) / 2 },
      { cx + math.cos(a + curl) * r1, cy + math.sin(a + curl) * r1 } }, k, '.BTb')
  end
  -- gola de pelo, armação, vão, dentes e o túnel
  local c2x, c2y, c3x, c3y = cx + 1.5 * k, cy + 1 * k, cx + 2.6 * k, cy + 1.7 * k
  local NT = 12
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      local dx, dy = x - cx, y - cy
      local r = sqrt(dx * dx + dy * dy)
      if r < 16 * k then
        local deg = math.deg(math.atan(dy, dx)) % 360
        local tn = deg / 360
        local gap = deg > 92 and deg < 118
        local lit = deg > 170 and deg < 310          -- o lado da luz
        local ch
        if r >= 13 * k then
          if r < (14.2 + (hash(floor(tn * 24), 3, 1) % 3) * 0.6) * k then
            local row = floor((r + tn * 72 * k) / k)
            ch = row % 2 == 0 and 'C' or 'D'
            if ch == 'D' and lit and row % 4 == 1 then ch = 'R' end
          end
        elseif r >= 11 * k then
          if gap then ch = 'z' else
            ch = r >= 12.2 * k and (lit and 'W' or 'V') or (lit and 'V' or 'U')
            if k > 1 and (tn * 24) % 1 < 0.1 then ch = 'u' end
            if abs(r - 12 * k) < 0.5 * k and hash(floor(tn * 9), 1, 2) % 4 ~= 0 then ch = (tn * 36) % 1 < 0.2 and 'Y' or 'J' end
          end
        else
          ch = 'z'
          local phi = (tn * NT + 0.5) % 1 - 0.5
          if r >= 7.6 * k and not gap and abs(phi) < 0.44 * (r - 7.6 * k) / (3.4 * k) then ch = phi < 0 and 'W' or 'V' end
          local r2 = sqrt((x - c2x) ^ 2 + (y - c2y) ^ 2)
          local t2 = (math.deg(math.atan(y - c2y, x - c2x)) % 360) / 360
          if r2 >= 6 * k and r2 < 7 * k then
            ch = 'U'
            if hash(floor(t2 * 7), 4, 4) % 3 == 0 then ch = 'J' elseif k > 1 and (t2 * 14) % 1 < 0.15 then ch = 'u' end
          elseif k > 1 and r2 >= 4.8 * k and r2 < 6 * k and abs((t2 * 9) % 1 - 0.5) < 0.22 * (r2 - 4.8 * k) / (1.2 * k) then ch = 'V' end
          local r3 = sqrt((x - c3x) ^ 2 + (y - c3y) ^ 2)
          if k > 1 and r3 >= 3.7 * k and r3 < 4.2 * k then ch = 'u' end
        end
        if ch then g[y][x] = ch end
      end
    end
  end
  -- o vão escorre pela armação partida
  local gx, gy = cx + math.cos(math.rad(105)) * 12.5 * k, cy + math.sin(math.rad(105)) * 12.5 * k
  for t = 0, 6 * k do
    local hw = 1.8 * k * (1 - t / (6 * k)) + 0.4
    L.rect(g, ceil(gx - hw), floor(gy + t), floor(gx + hw), floor(gy + t), 'z')
  end
  -- olhos no vão: o do fundo é o maior; os outros estão pelo caminho, em espiral
  E(g, c3x + 0.5, c3y, 2.4, k, 3)
  for n = 1, 6 do
    local a, rr = math.rad(n * 137.5 + 200), (9.4 - n * 0.9) * k
    local ex, ey = cx + math.cos(a) * rr, cy + math.sin(a) * rr
    if k > 1 and n % 2 == 1 then eye(g, ex, ey, 1.5) else led(g, ex, ey, k, n % 3 == 0 and 'I' or 'H') end
  end
  L.outline(g, 'A', SOLID)
  -- o raio sai do vão que escorre e não acaba no quadro
  local by = gy + 6 * k
  local bolt = { { gx, by + 1 }, { gx - 2.5 * k, by + 4 * k }, { gx + 2 * k, by + 6 * k }, { gx - 1.5 * k, by + 9 * k }, { gx + 1 * k, by + 12 * k } }
  wire(g, bolt, 'S', 's', k, '.')
  if k > 1 then
    for n, p in ipairs(bolt) do bolt[n] = { p[1] + k, p[2] } end
    wire(g, bolt, 'S', 'S', 1, '.')
  end
  dot(g, gx - 5 * k, by + 8 * k, k); dot(g, gx + 5 * k, by + 11 * k, k, 's'); dot(g, gx + 6 * k, by + 3 * k, k)
  dot(g, cx + 24 * k, cy + 23 * k, k, 's'); dot(g, cx + 26 * k, cy + 20 * k, k); dot(g, cx + 22 * k, cy + 26 * k, k)
  return g
end

local function out(stage, kind, g) C.save('hum', stage, kind, g, LEG, LIT, LOOSE) end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('espirito', 'mapa', espirito(1))
do -- o retrato do Espírito é o desenho de 36 ampliado 2,5 vezes num quadro de 96 (sobra 3 px de cada lado)
  local s, g = espirito(2.5), L.grid(96, 96)
  for y = 0, s.h - 1 do for x = 0, s.w - 1 do if s[y][x] ~= '.' then L.set(g, x + 3, y + 3, s[y][x]) end end end
  out('espirito', 'retrato', g)
end
out('entidade', 'mapa', entidade(1))
out('entidade', 'retrato', entidade(2))
out('arquetipo', 'mapa', arquetipo(1))
out('arquetipo', 'retrato', arquetipo(2))
do -- o Eco é o Humoth: só mede, para a régua
  local d = C.DIR .. 'hum/hum_eco_'
  for _, kind in ipairs({ 'mapa', 'retrato' }) do
    local m = C.measure(C.png(d .. kind .. '.png'), C.png(d .. kind .. '_emissivo.png'))
    print(string.format('  eco %s (Humoth): opacos %d, cores %d, detalhe %.2f, contorno %.2f, emissivo %.2f', kind, m.opacos, m.cores, m.detalhe, m.contorno, m.emissivo))
  end
end
print('ok hum')
