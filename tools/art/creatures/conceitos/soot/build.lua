-- Conceitos da família Soot (Etapa 1): gambá-de-orelha-branca + bueiro e bituca + brasa no peito.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/soot/build.lua')
-- SOOT_ONLY = 'eco' (opcional) grava só uma etapa.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local F = dofile(KENOMA_ART .. 'creatures/conceitos/soot/_forma.lua')(C)
local L = C.L
local floor, ceil, sqrt, abs, cos, sin, rad = math.floor, math.ceil, math.sqrt, math.abs, math.cos, math.sin, math.rad

local LEG = {
  A = '#1A1424',
  a = '#2A2529', b = '#3B3539', c = '#514B4E', d = '#6E6866', e = '#8A8480', -- pelo de fuligem (e: ponta grisalha)
  v = '#6A6462', w = '#8E877F', W = '#B5ADA1', V = '#D2CBBE',                 -- cara branca suja, dente
  q = '#5A4044', p = '#8A6460', P = '#B08880',                                -- pele nua (orelha, rabo, mão, focinho)
  k = '#241A2A', K = '#3A2C3C',                                               -- olho, boca
  J = '#2A2C33', j = '#41444D', i = '#5F636C', I = '#858A92',                 -- ferro fundido
  n = '#5E4636', N = '#7C5B40',                                               -- ferrugem
  h = '#A39C90', H = '#CFC8BA',                                               -- cinza e papel da bituca
  o = '#8C6238', O = '#B88648',                                               -- filtro
  m = '#4A4753', M = '#6A6775',                                               -- fumaça
  ['1'] = '#B9B3A6', ['2'] = '#8F8A80', ['3'] = '#66625E', ['4'] = '#46434A', -- osso e cinza (Arquétipo)
  r = '#4A1F1A', u = '#6E2E1E',                                               -- brasa apagada (corpo)
  R = '#C8432A', E = '#FF7A45', Y = '#FFC46A', Z = '#FFF0B8',                 -- brasa acesa
  T = '#C8432A', S = '#FF7A45', s = '#FFC46A', X = '#9B7BFF',                 -- faísca solta e o Véu (só no emissivo)
  -- bases que o sombreado troca: f pelo, g pelo de trás, t pele, x cara, y ferro, z osso
}
local LIT = { R = 'r', E = 'r', Y = 'u', Z = 'u' }
local LOOSE = 'TSsX'
local THIN = 'AmMTSsX'
local function solid(extra)
  local s = ''
  for ch in pairs(LEG) do if not (THIN .. (extra or '')):find(ch, 1, true) then s = s .. ch end end
  return s
end
local FUR, FACE, SKIN, IRON = 'edcba', 'VWwv', 'Ppq', 'IijJ'

-- Brasa: miolo claro e rachaduras que se espalham. mask: onde pode queimar.
local function ember(g, cx, cy, r, seed, mask, arms)
  arms = arms or 5
  for n = 1, arms do
    local a = (n / arms) * 6.283 + F.rnd(n, seed, 3) * 1.2
    local x, y = cx, cy
    local len = r * (1.1 + F.rnd(n, seed, 5) * 0.9)
    for s = 0, floor(len) do
      a = a + (F.rnd(n, s, seed) - 0.5) * 1.1
      x, y = x + cos(a), y + sin(a)
      L.set(g, x, y, s > len * 0.6 and 'R' or 'E', mask)
    end
  end
  for y = floor(cy - r), ceil(cy + r) do for x = floor(cx - r), ceil(cx + r) do
    local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    if d <= r * 0.32 then L.set(g, x, y, 'Z', mask)
    elseif d <= r * 0.62 then L.set(g, x, y, 'Y', mask)
    elseif d <= r * 0.95 and F.rnd(x, y, seed) > 0.2 then L.set(g, x, y, 'E', mask) end
  end end
end

local function furShade(g, k, src, ramp, o)
  o = o or {}
  o.p = o.p or (k > 1 and 2 or 1); o.ax = o.ax or 0.5; o.ay = o.ay or 1
  if k > 1 then o.jit = o.jit or 2; o.jw = o.jw or 3 end
  F.shade(g, src, ramp, o)
end
local function skinShade(g, k, src)
  F.shade(g, src or 't', SKIN, { p = k > 1 and 3 or 2, ax = 1, ay = 1, zones = 2, within = src or 't' })
end
local function ironShade(g, k, src, o)
  o = o or {}
  o.p = o.p or (k > 1 and 3 or 2); o.ax = o.ax or 1; o.ay = o.ay or 0; o.zones = o.zones or 3
  F.shade(g, src or 'y', IRON, o)
end

-- Bituca na ponta de um rabo: cinza e brasa. (x, y) é a ponta, em unidades do mapa.
local function buttTip(P, k, x, y, dx, dy)
  P:disc(x - dx * 0.9, y - dy * 0.9, 0.85, 'h', 'Ppqt')
  if k > 1 then P:disc(x - dx * 1.2, y - dy * 1.2, 0.8, 'H', 'Ppqth') end
  P:disc(x, y, 0.75, 'E', 'PpqthH')
  P:disc(x + dx * 0.25, y + dy * 0.25, k > 1 and 0.4 or 0.1, 'Y', 'E')
end

-- Cabeça de gambá no referencial próprio: u para a frente (focinho), v para baixo; ang gira, sc escala.
-- o = { open = boca aberta, eyes = { {u, v}, ... }, ear = n, bone = caveira, flip = -1 espelha v }
local function head(P, k, x, y, ang, sc, o)
  o = o or {}
  local fl = o.flip or 1
  local ca, sa = cos(rad(ang)), sin(rad(ang))
  local function T(u, v) u, v = u * sc, v * sc * fl; return { x + u * ca - v * sa, y + u * sa + v * ca } end
  local function poly(pts, c, mask)
    local q = {}
    for n, p in ipairs(pts) do q[n] = T(p[1], p[2]) end
    P:poly(q, c, mask)
  end
  local base = o.bone and 'z' or 'x'
  if not o.bone then
    for n = 1, (o.ear or 1) do
      local e = T(-1.6 + (n - 1) * 1.9, -3.5 + (n - 1) * 0.3)
      P:ell(e[1], e[2], 1.8 * sc, 2.0 * sc, 'q'); P:ell(e[1] + 0.2 * sc, e[2] + 0.3 * sc, 0.9 * sc, 1.1 * sc, 'p')
    end
  end
  P:ell(x, y, 3.2 * sc, 3.0 * sc, base, nil, ang)
  poly({ { 0.2, -2.6 }, { 3.6, -1.2 }, { 6.6, 0.5 }, { 6.5, 1.3 }, { 0, 1.5 } }, base)
  if o.open then
    poly({ { 0.4, 1.4 }, { 6.3, 1.3 }, { 5.8, 4.8 }, { 0, 2.8 } }, 'k')
    if not o.bone then local th = T(1.4, 2.3); P:disc(th[1], th[2], 0.9 * sc, 'E', 'k') end
    poly({ { -1.2, 2.6 }, { 5.9, 4.7 }, { 5.4, 5.7 }, { -1.6, 4.0 } }, base)
    for u = 1.6, 5.8, (k > 1 and 0.9 or 1.4) do
      local t = T(u, 1.8); P:px(t[1], t[2], 'V')
      t = T(u - 0.5, 2.3 + (u + 0.7) / 7.1 * 2.1); P:px(t[1], t[2], 'V')
    end
  end
  return T
end
local function headFinish(P, k, T, sc, o)
  o = o or {}
  if not o.bone then
    local nz = T(6.3, 0.8); P:disc(nz[1], nz[2], 0.6 * sc, 'P')
  end
  for _, e in ipairs(o.eyes or {}) do
    local q = T(e[1], e[2])
    P:ell(q[1], q[2], 1.2 * sc, 0.95 * sc, 'v', FACE)
    P:disc(q[1], q[2], k > 1 and 0.8 * sc or 0.5, 'k')
    if e[3] then P:px(q[1], q[2], e[3]) end
  end
end

-- FAGULHA (Ember Mote): um tufo do peito arrancado, com a brasa dentro e um resto de bituca.
local function fagulhaMapa()
  return L.frame({
    '............',
    '.....S......',
    '...AA.A.....',
    '..AdcAbA....',
    '.AdcbEbaA...',
    '.AcbEYEbA...',
    '.AbEYZYEaA..',
    '.AbaEYEbaA..',
    '..AabEbHhA..',
    '...AaabhA...',
    '....AAAA..s.',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local g = L.grid(96, 96)
  local k = 7
  local P = F.pen(g, k, 6, 6)
  -- bituca espetada no tufo
  P:limb({ { 6.5, 7.4 }, { 9.3, 9.6 } }, 0.95, 0.95, 'O')
  P:limb({ { 8.6, 9.0 }, { 9.3, 9.6 } }, 0.95, 0.95, 'o')
  P:limb({ { 6.6, 7.5 }, { 7.6, 8.3 } }, 0.95, 0.95, 'H')
  P:ell(5.4, 6, 3.7, 3.4, 'f')
  for n = 0, 15 do
    local a = n / 16 * 6.283 + F.rnd(n, 1, 2) * 0.3
    local r0, r1 = 3.2, 4.1 + F.rnd(n, 2, 2) * 0.9
    if not (a > 0.3 and a < 1.3) then
      P:limb({ { 5.4 + cos(a) * r0, 6 + sin(a) * r0 * 0.92 }, { 5.4 + cos(a + 0.25) * r1, 6 + sin(a + 0.25) * r1 * 0.92 } }, 0.5, 0.12, 'f')
    end
  end
  furShade(g, k, 'f', FUR, { zones = 3, p = 2 })
  ember(g, P:X(5.5), P:Y(6.3), 15, 5, FUR, 11)
  L.outline(g, 'A', solid())
  for n, q in ipairs({ { 1.2, 1.5, 'S' }, { 9.6, 2.4, 's' }, { 10.6, 5.2, 'T' }, { 0.6, 9.4, 's' }, { 3, 11.2, 'S' }, { 10.4, 11, 'S' }, { 7.6, 0.6, 'T' } }) do
    L.rect(g, floor(P:X(q[1])), floor(P:Y(q[2])), floor(P:X(q[1])) + 1, floor(P:Y(q[2])) + 1, q[3], '.')
  end
  return g
end

-- ECO (Sootling): gambá de fuligem em proporção natural. O errado: o rabo pelado queima na ponta como bituca
-- e a brasa aparece pelas falhas do pelo do peito.
local function eco(k, ox, oy)
  local S = k > 1 and 96 or 28
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  local tail = { { 6, 17 }, { 3.4, 14.5 }, { 2.9, 11 }, { 3.8, 7.6 }, { 6.2, 5.6 }, { 8.8, 6.2 }, { 9.8, 8.4 }, { 8.8, 10.2 } }
  P:limb(tail, 1.3, 0.85, 't')
  P:limb({ { 17, 20 }, { 16.6, 22.5 }, { 17.2, 24.6 } }, 1.1, 0.8, 'g')
  P:limb({ { 10.8, 20 }, { 11.8, 22.5 }, { 11.2, 24.6 } }, 1.3, 0.8, 'g')
  P:ell(12.6, 17, 7.4, 4.8, 'f')
  P:ell(8.4, 16.8, 4.4, 4.9, 'f')
  P:ell(17.5, 16, 3.6, 4.2, 'f')
  P:ell(21.3, 10.9, 1.3, 1.6, 'q')
  P:ell(20.3, 14.4, 3.2, 3.0, 'x')
  P:poly({ { 21, 12.2 }, { 23.4, 13.6 }, { 24.8, 15.8 }, { 24.6, 16.9 }, { 23, 17.6 }, { 20, 17.4 } }, 'x')
  P:ell(18.2, 13, 2.7, 2.4, 'f')
  P:ell(18.9, 10.6, 1.8, 2.0, 'q')
  P:ell(19.1, 10.9, 0.9, 1.1, 'p')
  P:ell(8.4, 19.8, 2.8, 2.9, 'f')
  P:limb({ { 7.8, 21.5 }, { 6.8, 23.2 }, { 7.6, 24.6 } }, 1.4, 0.9, 'f')
  P:limb({ { 19.2, 19 }, { 19.7, 22.2 }, { 19.3, 24.6 } }, 1.2, 0.85, 'f')
  for _, m in ipairs({ { 17.2, 25, 'q' }, { 11.2, 25, 'q' }, { 7.6, 25, 'p' }, { 19.3, 25, 'p' } }) do
    P:limb({ { m[1] - 0.3, m[2] }, { m[1] + 1.4, m[2] } }, 0.5, 0.5, m[3])
    if k > 1 then
      for f = 0, 3 do L.line(g, P:X(m[1] + 0.3 + f * 0.35), P:Y(m[2]) - 1, P:X(m[1] + 1 + f * 0.5), P:Y(m[2]) + 2, m[3]) end
    end
  end
  furShade(g, k, 'f', k > 1 and FUR or 'dcba', { zones = k > 1 and 3 or 2, bias = k > 1 and 0 or 0.1 })
  furShade(g, k, 'g', 'ba', { zones = 1 })
  F.shade(g, 'x', FACE, { p = k > 1 and 3 or 2, ax = 1, ay = 0.4, zones = 3, within = 'x', jit = k > 1 and 2 or 0 })
  skinShade(g, k)
  P:ell(22.4, 14.4, 1.2, 0.9, 'v', FACE)
  P:limb({ { 22.6, 17.2 }, { 24.2, 17 } }, 0.3, 0.3, 'K', FACE)
  if k > 1 then
    P:disc(22.5, 14.5, 0.75, 'k')
    L.set(g, P:X(22.4) - 1, P:Y(14.4) - 1, 'W')
    P:ell(24.8, 16.2, 0.8, 0.7, 'P'); L.set(g, P:X(24.7), P:Y(16), 'V')
  else
    for _, q in ipairs({ { 21, 13, 'W' }, { 22, 13, 'V' }, { 23, 14, 'V' }, { 21, 14, 'w' }, { 22, 14, 'k' }, { 24, 15, 'V' }, { 23, 15, 'W' }, { 25, 16, 'P' } }) do
      g[q[2]][q[1]] = q[3]
    end
  end
  buttTip(P, k, 8.8, 10.2, -0.5, 0.86)
  ember(g, P:X(20), P:Y(19.4), (k > 1 and 3.3 or 3.2) * k, 11, FUR .. (k > 1 and FACE or ''), k > 1 and 11 or 6)
  L.outline(g, 'A', solid())
  if k > 1 then
    for _, a in ipairs({ -20, 5, 30 }) do
      local x0, y0 = P:X(24), P:Y(16.4)
      L.line(g, x0, y0, x0 + cos(rad(a)) * 9, y0 + sin(rad(a)) * 9, 'h', '.A')
    end
    for x = 5, 17, 1.1 do
      local yy = 11.6 - 0.5 * sin((x - 4) / 14 * 3.14)
      if F.rnd(x * 10, 1, 7) > 0.3 then
        L.line(g, P:X(x), P:Y(yy) + 2, P:X(x) - 2, P:Y(yy) - 1 - floor(F.rnd(x * 10, 2, 7) * 2), 'c', '.A')
      end
    end
  end
  P:dot(23.8, 21, 'S'); P:dot(22.2, 23, 's'); P:dot(11, 8.6, 'T'); P:dot(12.4, 5.6, 's')
  return g
end

-- ESPÍRITO (Cinderkin): o gambá tomado pelo bueiro. O flanco virou grelha de ferro com a brasa atrás das barras,
-- dois rabos (um arrasta), dois olhos do mesmo lado, três orelhas e os filhotes de fuligem agarrados no lombo.
local function espirito(k, ox, oy)
  local S = k > 1 and 96 or 36
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  P:limb({ { 7, 21 }, { 4, 18 }, { 3.2, 13.5 }, { 4.4, 9 }, { 7.4, 6.2 }, { 10.6, 6.8 }, { 11.8, 9.4 }, { 10.6, 11.6 } }, 1.5, 0.9, 't')
  P:limb({ { 7, 24 }, { 3.6, 26 }, { 2.6, 29.5 }, { 4.6, 32.4 }, { 8, 32.8 } }, 1.4, 0.8, 't')
  P:limb({ { 22, 26 }, { 21.4, 29.5 }, { 22.2, 32.6 } }, 1.3, 0.9, 'g')
  P:limb({ { 13.6, 26 }, { 15, 29.5 }, { 14.2, 32.6 } }, 1.5, 0.9, 'g')
  P:ell(16, 21.5, 9.2, 6, 'f')
  P:ell(10.6, 21, 5.4, 6.2, 'f')
  P:ell(22.5, 20, 4.4, 5.2, 'f')
  -- filhotes no lombo
  local pups = { { 10.4, 14.4 }, { 14.4, 13.8 }, { 18.4, 14.4 } }
  for _, q in ipairs(pups) do P:ell(q[1], q[2], 1.9, 1.5, 'g'); P:ell(q[1] + 1.6, q[2] + 0.4, 1.0, 0.8, 'g') end
  -- cabeça
  local T = head(P, k, 26, 17.6, 14, 1.12, { open = true, ear = 3 })
  P:ell(23.4, 15.8, 3.2, 2.8, 'f')
  P:ell(10.6, 25.4, 3.4, 3.6, 'f')
  P:limb({ { 9.8, 27.5 }, { 8.6, 30.4 }, { 9.6, 32.6 } }, 1.7, 1.0, 'f')
  P:limb({ { 24.6, 24.5 }, { 25.2, 29 }, { 24.8, 32.6 } }, 1.5, 1.0, 'f')
  for _, m in ipairs({ { 22.2, 33, 'q' }, { 14.2, 33, 'q' }, { 9.6, 33, 'p' }, { 24.8, 33, 'p' } }) do
    P:limb({ { m[1] - 0.4, m[2] }, { m[1] + 1.8, m[2] } }, 0.55, 0.55, m[3])
  end
  -- a grelha no flanco: barras de ferro, a brasa nos vãos
  local gx0, gx1, gy0, gy1 = 12, 21.6, 17.4, 26.2
  local bw = k > 1 and floor(k) or 1
  for y = floor(P:Y(gy0)), floor(P:Y(gy1)) do for x = floor(P:X(gx0)), floor(P:X(gx1)) do
    if L.get(g, x, y) == 'f' then
      local u, v = (x - P:X(gx0)) / (P:X(gx1) - P:X(gx0)), (y - P:Y(gy0)) / (P:Y(gy1) - P:Y(gy0))
      local col = floor((x - floor(P:X(gx0))) / bw)
      if v < 0.1 or v > 0.9 or u < 0.04 or u > 0.96 then g[y][x] = 'y'
      elseif col % 2 == 0 then g[y][x] = 'y'
      else
        local heat = 1 - abs(v - 0.55) * 2.2 - abs(u - 0.5) * 0.9 + (F.rnd(x, y, 9) - 0.5) * 0.25
        g[y][x] = heat > 0.62 and 'Y' or heat > 0.3 and 'E' or heat > -0.25 and 'R' or 'r'
      end
    end
  end end
  furShade(g, k, 'f', FUR, { zones = 3, within = 'fygYERr' })
  furShade(g, k, 'g', 'ba', { zones = 1 })
  ironShade(g, k, 'y', { within = 'yYERr', p = 2, ax = 0, ay = 1 })
  F.shade(g, 'x', FACE, { p = k > 1 and 3 or 2, ax = 1, ay = 0.4, zones = 3, within = 'x', jit = k > 1 and 2 or 0 })
  skinShade(g, k)
  headFinish(P, k, T, 1.12, { eyes = { { 2.0, -0.5, 'E' }, { 0.2, -1.5, 'E' } } })
  for _, q in ipairs(pups) do P:px(q[1] + 1.8, q[2] + 0.2, 'E') end
  buttTip(P, k, 10.6, 11.6, -0.5, 0.86)
  buttTip(P, k, 8, 32.8, 1, 0.1)
  ember(g, P:X(25), P:Y(23.6), 3 * k, 21, FUR, k > 1 and 11 or 7)
  L.outline(g, 'A', solid())
  -- fumaça da bituca de cima, sem contorno
  local sx, sy = 12, 9.5
  for n = 0, (k > 1 and 16 or 5) do
    local t = n / (k > 1 and 16 or 5)
    L.set(g, P:X(sx + sin(t * 5) * 1.2 + t * 2), P:Y(sy - 1.5 - t * 5.5), n % 2 == 0 and 'M' or 'm', '.')
    if k > 1 then L.set(g, P:X(sx + sin(t * 5) * 1.2 + t * 2) + 1, P:Y(sy - 1.5 - t * 5.5), 'm', '.') end
  end
  P:dot(30, 26, 'S'); P:dot(28.4, 29, 's'); P:dot(32.4, 24, 'T'); P:dot(11, 33.6, 's'); P:dot(13, 31, 'S')
  return g
end

-- ENTIDADE MAIOR: a tampa do bueiro é o corpo. Três pescoços de gambá em cata-vento, sem olhos, só a boca aberta;
-- os olhos ficaram na tampa. Três rabos entre eles. Regra quebrada: o fogo dela pende, queima para baixo como baba.
local function entidade(k, ox, oy)
  local S = 48 * (k > 1 and 2 or 1)
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  local cx, cy = 23.5, 24.2
  local function pol(a, r) return { cx + cos(rad(a)) * r, cy + sin(rad(a)) * r } end
  local drips, heads = {}, {}
  for n = 0, 2 do
    local a = -100 + n * 120
    P:limb({ pol(a + 62, 9.5), pol(a + 72, 13), pol(a + 86, 16.6), pol(a + 102, 18.8), pol(a + 116, 19.2) }, 1.5, 0.85, 't')
    drips[#drips + 1] = pol(a + 116, 19.2)
  end
  for n = 0, 2 do
    local a = -100 + n * 120
    P:limb({ pol(a, 8.5), pol(a + 14, 12.5), pol(a + 28, 14.4) }, 2.6, 2.1, 'f')
    local h = pol(a + 40, 15.6)
    heads[#heads + 1] = { head(P, k, h[1], h[2], a + 40 + 74, 1.0, { open = true, ear = 1 }), a }
    local m = heads[#heads][1](5, 3.6)
    drips[#drips + 1] = m
  end
  -- tampa
  local R = 10.4
  local X0, Y0, RR = P:X(cx), P:Y(cy), R * k
  for y = floor(Y0 - RR), ceil(Y0 + RR) do for x = floor(X0 - RR), ceil(X0 + RR) do
    local dx, dy = x - X0, y - Y0
    local d = sqrt(dx * dx + dy * dy) / k
    if d <= R then
      local an = math.atan(dy, dx)
      local lt = (-dx - dy) / (RR * 1.414)                 -- 1 do lado da luz
      local idx = lt > 0.35 and 0 or lt > -0.25 and 1 or 2
      local seg = (floor((an + 3.1416) / 6.2832 * 12) + floor(d / 2.1)) % 2
      local ch
      if d > R - 1.1 then ch = IRON:sub(math.min(4, idx + 2), math.min(4, idx + 2))
      elseif abs(d - 4.2) < 0.5 then ch = 'R'
      elseif abs(d - 8.2) < 0.4 then ch = seg == 0 and 'R' or 'J'
      else ch = IRON:sub(math.min(4, idx + 1 + seg), math.min(4, idx + 1 + seg)) end
      if d < R - 1.1 and d > 5 and F.rnd(floor(x / k), floor(y / k), 4) > 0.94 then ch = seg == 0 and 'N' or 'n' end
      g[y][x] = ch
    end
  end end
  furShade(g, k, 'f', 'dcba', { zones = 2, within = 'f', bias = 0.1 })
  F.shade(g, 'x', FACE, { p = 2, ax = 1, ay = 0.4, zones = 2, within = 'x' })
  skinShade(g, k)
  for _, hd in ipairs(heads) do headFinish(P, k, hd[1], 1.0, {}) end
  -- os olhos na tampa
  for n = 0, 5 do
    local e = pol(n * 60 + 35, 6.4)
    P:ell(e[1], e[2], 2.0, 1.4, 'J')
    if k > 1 then P:ell(e[1], e[2], 1.25, 0.85, 'V'); P:disc(e[1], e[2], 0.55, 'k'); P:px(e[1], e[2], 'E')
    else P:px(e[1] - 1, e[2], 'V'); P:px(e[1] + 1, e[2], 'V'); P:px(e[1], e[2], 'E') end
  end
  -- a brasa no furo do meio e a chama que escorre pela tampa
  ember(g, X0, Y0, 3.3 * k, 31, IRON .. 'nNR', 0)
  for n = 0, 2 do
    local x = cx - 1.6 + n * 1.6
    local len = 6 + F.rnd(n, 3, 3) * 2.4
    for s = 0, len * k do
      local t = s / (len * k)
      for wdt = 0, (k > 1 and 1 or 0) do
        L.set(g, P:X(x + sin(t * 4 + n) * 0.5) + wdt, P:Y(cy + 2) + s, t < 0.35 and 'Y' or t < 0.75 and 'E' or 'R', IRON .. 'nNR')
      end
    end
  end
  for n = 0, 2 do
    local b = pol(-100 + n * 120 + 62, 9.8); buttTip(P, k, drips[n + 1][1], drips[n + 1][2], 0, 0.2)
  end
  L.outline(g, 'A', solid())
  -- o fogo pende das pontas dos rabos e das bocas (só no emissivo)
  for n, q in ipairs(drips) do
    local len = (n <= 3 and 5 or 3.4) + F.rnd(n, 1, 6) * 2
    for s = 1, floor(len * k) do
      local t = s / (len * k)
      local wd = (k > 1 and (t < 0.5 and 1 or 0) or 0)
      for wdt = 0, wd do
        L.set(g, P:X(q[1]) + wdt + floor(sin(t * 5 + n) * 0.8 + 0.5), P:Y(q[2] + 0.8) + s, t < 0.3 and 's' or t < 0.7 and 'S' or 'T', '.A')
      end
    end
    P:dot(q[1] + (n % 2 == 0 and 1.6 or -1.6), q[2] + len + 2, 'T')
  end
  return g
end

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.y = '#5A45A8'                                            -- o fundo do vão (solto)
LOOSE = LOOSE .. 'y'; THIN = THIN .. 'y'

-- ARQUÉTIPO: o saruê de perfil, grande demais, de boca aberta além do que a queixada deixa. Não tem olho; a boca é o
-- vão, e dentro dela há outra queixada aberta, e outra dentro dessa, cada uma menor. O flanco é a tampa do bueiro, com
-- a brasa atrás das fendas; os filhotes no lombo são caveiras, cada uma menor, até o rabo, que dá voltas demais.
-- O fogo dele tira luz: o pelo e o ferro escurecem quanto mais perto da brasa.
local function arquetipo(k, S, ox, oy)
  local min, sqrt, abs, cos, sin, rad, floor = math.min, math.sqrt, math.abs, math.cos, math.sin, math.rad, math.floor
  local d = R.ctx(S or 64 * k, k, ox, oy)
  local p = d:pp()
  local SOL = solid()
  local EX, EY = 33, 41                                                           -- a brasa do peito
  local function dark(u, v) return min(1, sqrt((u - EX) ^ 2 + (v - EY) ^ 2) / 20) end
  local fur = R.mat('ab4321', R.noise(p, 3), dark)
  local HX, HY = 39, 29                                                            -- a dobradiça da queixada
  d:layer(function(t)                                                              -- o rabo, com voltas demais, e a bituca
    local pts = {}
    for i = 0, 40 do
      local a = rad(200 + i * 26)
      local r = 1.2 + i * 0.14
      pts[#pts + 1] = { 9.6 + cos(a) * r, 40 + sin(a) * r }
    end
    pts[#pts + 1] = { 12, 36 }
    t:wire(pts, 'q', 'p', 1.1)
    t:ell(9.6, 40, 0.9, 0.9, 'E')
  end, SOL)
  d:layer(function(t)                                                              -- pernas de lá
    t:cap(18, 42, 16.6, 52, 2.6, 1.6, R.mat('ab4', R.noise(p, 3), 0.3)); t:cap(34, 44, 36, 53, 2.2, 1.4, R.mat('ab4', R.noise(p, 3), 0.3))
  end, SOL)
  d:layer(function(t)
    t:ell(24, 34, 15.6, 11.6, fur)                                                  -- o lombo
    t:cap(34, 30, 40, 27, 7, 5.6, fur)                                              -- pescoço e nuca
    -- a tampa do bueiro no flanco: ferro, fendas com a brasa atrás
    t:ell(22, 35, 7.6, 7.6, function(x, y, u, v)
      local r = sqrt((u - 22) ^ 2 + (v - 35) ^ 2)
      if r > 6.4 then return R.pick('JjiI', dark(u, v) * 0.8, R.noise(p, 5)(x, y)) end
      if (floor(u * 0.8 + 0.4)) % 2 == 0 and r < 5.6 then return r < 2.4 and 'Y' or (r < 4.2 and 'E' or 'R') end
      return R.pick('Jji', dark(u, v) * 0.7, R.ver(p)(x, y))
    end)
    -- os filhotes no lombo: caveiras, cada uma menor, até o rabo
    for n, q in ipairs({ { 31, 22.4, 3 }, { 24.4, 21.6, 2.4 }, { 18.6, 22.6, 1.9 }, { 13.6, 25, 1.5 }, { 10, 28.4, 1.1 } }) do
      t:cap(q[1], q[2], q[1] + q[3] * 1.5, q[2] + q[3] * 0.4, q[3], q[3] * 0.4, R.mat('321', R.noise(p, 7), 0.6))
      t:ell(q[1] - q[3] * 0.5, q[2] - q[3] * 0.9, q[3] * 0.5, q[3] * 0.6, 'p')
      if q[3] > 1.4 then t:ell(q[1] + q[3] * 0.3, q[2] - q[3] * 0.1, q[3] * 0.3, q[3] * 0.3, 'k') end
    end
    -- a cabeça: maxila em cima, mandíbula escancarada embaixo, sem olho; orelha pelada
    t:ell(38.6, 17.6, 2.6, 3.4, R.mat('qpP', R.ver(p), 0.5))
    t:poly({ { 36, 20 }, { 44, 18.6 }, { 59, 21.4 }, { 60.4, 24 }, { 58, 25.6 }, { HX, HY } }, R.mat('4321', R.noise(p, 9), function(u, v) return 0.9 - (v - 18) / 10 end))
    t:poly({ { 35, 31 }, { HX, HY }, { 53.6, 50.4 }, { 51.6, 53.4 }, { 47.6, 53 }, { 35, 39 } }, R.mat('4321', R.noise(p, 9), function(u, v) return 0.7 - (v - 30) / 30 end))
    t:ell(59.6, 22.6, 1.3, 1.2, 'q')
    t:ell(43.6, 21.6, 1.7, 1.3, 'k')                                                -- a órbita, vazia
    for i = 0, 8 do                                                                 -- dentes: muitos
      local f = 0.2 + i * 0.09
      local ux, uy = HX + (58 - HX) * f, HY + (25.6 - HY) * f
      t:poly({ { ux - 0.7, uy }, { ux + 0.7, uy - 0.1 }, { ux + 0.2, uy + 2.2 - i * 0.08 } }, i % 3 == 0 and 'V' or 'W')
      local lx, ly = HX + (53.6 - HX) * f, HY + (50.4 - HY) * f
      t:poly({ { lx - 0.4, ly + 0.6 }, { lx + 0.6, ly - 0.6 }, { lx + 2, ly - 1.4 + i * 0.05 } }, i % 3 == 0 and 'V' or 'W')
    end
    -- patas de cá: mão que parece de gente
    for _, q in ipairs({ { 20, 43, 21, 53.4 }, { 31.6, 44.6, 30.6, 54 } }) do
      t:cap(q[1], q[2], q[3], q[4], 2.7, 1.6, fur)
      for i = -2, 2 do t:wire({ { q[3], q[4] }, { q[3] + i * 1.2 + 1, q[4] + 3.2 - abs(i) * 0.5 } }, 'p', 'q', 0.5) end
    end
    -- a brasa no peito, em rachaduras
    for i = 0, 6 do
      local a = rad(i * 51 + 10)
      t:wire({ { EX, EY }, { EX + cos(a) * 2.6, EY + sin(a) * 2.6 }, { EX + cos(a + 0.4) * (6 + (i % 3)), EY + sin(a + 0.4) * (6 + (i % 3)) } }, 'E', 'R', 0.5)
    end
    t:ell(EX, EY, 1.7, 1.7, 'Y'); t:ell(EX, EY, 0.8, 0.8, 'Z')
  end, SOL)
  -- o vão: a boca. Fecha nas duas queixadas e fica aberta para a frente
  local a0, a1 = math.atan(25.6 - HY, 58 - HX), math.atan(50.4 - HY, 53.6 - HX)
  local function gape(u, v)
    local dx, dy = u - HX, v - HY
    local r, a = sqrt(dx * dx + dy * dy), math.atan(dy, dx)
    if r < 2 or r > 21 or a < a0 + 0.1 or a > a1 - 0.08 then return nil end
    return abs(a - (a0 + a1) / 2) / ((a1 - a0) / 2 - 0.09) * (r > 17.6 and 0.6 or 1)
  end
  d:vao(gape, 'X', 'y', 0.8)
  for lv, f in ipairs({ 0.62, 0.36, 0.18 }) do                                       -- queixada dentro de queixada
    local ch = lv == 1 and 'X' or (lv == 2 and 'S' or 's')
    local bx, by = HX + 3.4 * lv, HY + 2.6 * lv
    local m = (a0 + a1) / 2
    for _, sg in ipairs({ -1, 1 }) do
      local a = m + sg * (a1 - a0) / 2 * 0.62
      d:wire({ { bx, by }, { bx + cos(a) * 15 * f, by + sin(a) * 15 * f } }, ch, nil, 0.5, '.y')
      for i = 1, 3 do
        local tx, ty = bx + cos(a) * 15 * f * i / 3.4, by + sin(a) * 15 * f * i / 3.4
        d:wire({ { tx, ty }, { tx + cos(a - sg * 1.3) * 1.6 * f * 2, ty + sin(a - sg * 1.3) * 1.6 * f * 2 } }, ch, nil, 0.5, '.y')
      end
    end
  end
  for n = 0, 17 do
    d:dot(4 + (n * 23) % 56, 6 + (n * 11) % 9 + (n % 3 == 0 and 50 or 0), n % 3 == 0 and 'T' or (n % 3 == 1 and 'S' or 's'))
  end
  return d.g
end

local only = SOOT_ONLY
local function out(stage, kind, fn)
  if only and only ~= stage then return end
  C.save('soot', stage, kind, F.prune(fn(), LOOSE, stage .. ' ' .. kind), LEG, LIT, LOOSE)
end
out('fagulha', 'mapa', fagulhaMapa)
out('fagulha', 'retrato', fagulhaRetrato)
out('eco', 'mapa', function() return eco(1) end)
out('eco', 'retrato', function() return eco(3.3, 2, 0) end)
out('espirito', 'mapa', function() return espirito(1) end)
out('espirito', 'retrato', function() return espirito(2.6, 1, 1) end)
out('entidade', 'mapa', function() return entidade(1) end)
out('entidade', 'retrato', function() return entidade(2) end)
out('arquetipo', 'mapa', function() return arquetipo(1) end)
out('arquetipo', 'retrato', function() return arquetipo(3, 128, -64, -30) end)     -- busto: a cabeça sem olho, a boca e a brasa
print('ok soot')
