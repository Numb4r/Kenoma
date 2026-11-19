-- Conceitos da família Rill (Etapa 1): sapo-cururu + poça e sarjeta + o dorso que reflete o céu.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rill/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local F = dofile(KENOMA_ART .. 'creatures/conceitos/soot/_forma.lua')(C)
local L = C.L
local floor, ceil, sqrt, abs, cos, sin, rad = math.floor, math.ceil, math.sqrt, math.abs, math.cos, math.sin, math.rad

local LEG = {
  A = '#1A1424',
  a = '#2E2A22', b = '#453E30', c = '#5F553F', d = '#7D7052', e = '#9A8C68', -- pele de cururu (barro, água de poça)
  v = '#6A634F', w = '#8A8168', W = '#B0A685', V = '#CFC6A6',                 -- barriga creme
  o = '#8A6A2A', O = '#B8923A', k = '#241A2A',                                -- íris, pupila
  K = '#2B2233', M = '#9AA39A',                                               -- ovo e geleia do cordão de ovos
  J = '#454449', j = '#63625F', i = '#85847F', I = '#A9A8A2',                 -- concreto da guia
  g = '#8C7836', G = '#B59A45',                                               -- tinta amarela gasta da guia
  n = '#2F3038', N = '#44454F',                                               -- asfalto molhado
  ['1'] = '#B7B8A8', ['2'] = '#8E9082', ['3'] = '#676A60', ['4'] = '#474A48', -- pele sem cor, osso (Arquétipo)
  r = '#1B2638', q = '#243449', u = '#30455E',                                -- espelho apagado (corpo)
  B = '#2A6FC0', D = '#4AA8FF', E = '#A0D4FF', Z = '#FFFFFF',                 -- o céu no espelho
  T = '#2A6FC0', S = '#4AA8FF', s = '#D8EEFF', X = '#9B7BFF',                 -- gota solta e o Véu (só no emissivo)
  -- bases que o sombreado troca: f pele, h perna, x barriga, y concreto, z osso, m espelho
}
local LIT = { B = 'r', D = 'q', E = 'u', Z = 'u' }
local LOOSE = 'TSsX'
local THIN = 'ATSsXKM'
local function solid()
  local s = ''
  for ch in pairs(LEG) do if not THIN:find(ch, 1, true) then s = s .. ch end end
  return s
end
local SKIN, BELLY, CONC, GREY = 'edcba', 'VWwv', 'IijJ', '1234'

-- Pele: hachura e verrugas (um ponto claro com a sombra embaixo).
local function skin(g, k, src, ramp, o)
  o = o or {}
  ramp = ramp or SKIN
  o.p = o.p or (k > 1 and 2 or 1); o.ax = o.ax or 0.5; o.ay = o.ay or 1
  o.zones = o.zones or (#ramp - 2)
  if k > 1 then o.jit = 3; o.jw = 2 end
  local hit = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do if g[y][x] == src then hit[#hit + 1] = { x, y } end end end
  F.shade(g, src, ramp, o)
  local w = k > 1 and 2 or 1
  for _, q in ipairs(hit) do
    local x, y = q[1], q[2]
    if F.rnd(x // w, y // w, o.seed or 3) > (o.warts or 0.9) and (x // w + y // w) % 2 == 0 then
      local top = (y % w == 0)
      g[y][x] = top and ramp:sub(1, 1) or ramp:sub(#ramp - 1, #ramp - 1)
      if w == 1 then g[y][x] = ramp:sub(1, 1) end
    end
  end
end

-- Espelho: o céu refletido. mask: onde pode entrar. Devolve nada; escreve B, D, E, Z (acesos).
-- o = { rows = só linhas pares acesas abaixo de v0 (ondas), v0, clouds = semente, rot }
local function mirror(g, P, cx, cy, rx, ry, mask, o)
  o = o or {}
  local k = P.k
  local X0, Y0, RX, RY = P:X(cx), P:Y(cy), rx * k, ry * k
  local ca, sa = cos(rad(o.rot or 0)), sin(rad(o.rot or 0))
  local r = math.max(RX, RY) + 1
  for y = floor(Y0 - r), ceil(Y0 + r) do for x = floor(X0 - r), ceil(X0 + r) do
    local dx, dy = x - X0, y - Y0
    local u, v = (dx * ca + dy * sa) / RX, (-dx * sa + dy * ca) / RY
    local d = u * u + v * v
    if d <= 1 and (mask == nil or mask:find(L.get(g, x, y), 1, true)) then
      local ch
      local band = v + (F.rnd(x // (2 * k > 2 and 3 or 2), 0, 2) - 0.5) * 0.25
      if d > 0.8 then ch = 'B'
      elseif band < -0.25 then ch = (y % 2 == 0) and 'E' or 'D'
      elseif band < 0.3 then ch = (y % 2 == 0) and 'D' or 'E'
      else ch = (y % 2 == 0) and 'B' or 'D' end
      if o.clouds and v < 0.1 and v > -0.7 and F.rnd(x // ceil(2.4 * k), y // ceil(1.2 * k), o.clouds) > 0.62 then ch = 'Z' end
      if o.rows and v > (o.v0 or -2) and y % 2 == 1 then ch = (x % 4 == 0) and 'q' or 'r' end
      L.set(g, x, y, ch)
    end
  end end
end

-- Olho de cururu: o calombo já está na pele; aqui a íris ocre e a pupila deitada.
local function eye(g, P, x, y, sc)
  local k = P.k
  if k > 1 then
    P:ell(x, y, 1.25 * sc, 1.05 * sc, 'O'); P:ell(x, y + 0.5 * sc, 1.25 * sc, 0.5 * sc, 'o', 'O')
    P:ell(x, y, 1.0 * sc, 0.34 * sc, 'k')
    L.set(g, P:X(x) - 1, P:Y(y) - floor(0.7 * sc * k), 'V')
  else
    local px, py = floor(P:X(x) + 0.5), floor(P:Y(y) + 0.5)
    for _, q in ipairs({ { -1, 0, 'O' }, { 0, 0, 'k' }, { 1, 0, 'k' }, { 0, -1, 'O' }, { 1, -1, 'o' }, { -1, -1, 'o' } }) do
      L.set(g, px + q[1], py + q[2], q[3])
    end
    if sc > 1.05 then L.set(g, px + 2, py, 'O') end
  end
end
local function toes(P, x, y, n, len, c, dir)
  for t = 0, n - 1 do
    P:limb({ { x, y }, { x + (dir or 1) * (len * (0.55 + t * 0.25)), y + 0.4 - t * 0.4 } }, 0.42, 0.35, c)
  end
end
local function drop(g, P, x, y, up)
  local px, py = floor(P:X(x)), floor(P:Y(y))
  local k = math.max(1, floor(P.k * 0.6 + 0.5))
  local d = up and 1 or -1                                   -- a cauda fica para trás do movimento
  L.rect(g, px, py, px + k - 1, py + k - 1, 's', '.')
  L.rect(g, px, py + d * k, px + k - 1, py + d * k + k - 1, 'S', '.')
  L.rect(g, px, py + 2 * d * k, px + k - 1, py + 2 * d * k + k - 1, 'T', '.')
end

-- FAGULHA (Drip Mote): uma gota que cai de uma lasca de pele, ainda refletindo o céu.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '....AA......',
    '...AdcA.....',
    '..AecbaA....',
    '..AuEErA....',
    '.ADEZEDBA...',
    '.AEDEDBDA...',
    '.AqBDBDrA...',
    '..ABDBBA....',
    '...AAAA..s..',
    '.....S......',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local g = L.grid(96, 96)
  local P = F.pen(g, 1)
  -- lasca de pele
  P:ell(44, 17, 24, 11, 'f', nil, -8)
  P:ell(62, 14, 10, 7, 'f')
  P:poly({ { 30, 22 }, { 60, 22 }, { 51, 37 }, { 43, 37 } }, 'f')
  P:ell(40, 26, 12, 3.4, 'x', 'f')
  -- gota
  P:ell(47, 60, 23, 24, 'm')
  P:poly({ { 41, 30 }, { 53, 30 }, { 62, 44 }, { 32, 44 } }, 'm')
  skin(g, 2, 'f', SKIN, { warts = 0.86, within = 'fx' })
  F.shade(g, 'x', BELLY, { p = 3, ax = 1, ay = 0.3, zones = 3, within = 'x' })
  P:ell(60, 12, 6, 3, 'e', SKIN, -10); P:ell(60, 13, 5.4, 1.8, 'd', 'e', -10)
  for y = 0, 95 do for x = 0, 95 do
    if g[y][x] == 'm' then
      local v = (y - 30) / 54
      local d = sqrt(((x - 47) / 23) ^ 2 + ((y - 60) / 24) ^ 2)
      local ch = v < 0.35 and ((y % 2 == 0) and 'E' or 'D') or v < 0.62 and ((y % 3 == 0) and 'E' or 'D') or ((y % 2 == 0) and 'B' or 'D')
      if F.rnd(x // 7, y // 3, 5) > 0.66 and v > 0.2 and v < 0.6 then ch = 'Z' end
      -- a cidade de ponta-cabeça no reflexo
      local col = (x - 24) // 6
      local hgt = 7 + floor(F.rnd(col, 1, 9) * 13)
      if y >= 60 and y < 60 + hgt and x % 6 ~= 5 then ch = ((x + y) % 5 == 0 and y > 61) and 'u' or (y % 2 == 0 and 'r' or 'q') end
      if y == 59 then ch = 'u' end
      if d > 0.9 and y > 44 then ch = 'B' end
      g[y][x] = ch
    end
  end end
  for y = 38, 56 do L.set(g, 34 + floor((y - 38) / 6), y, 'Z', 'BDE') end
  L.set(g, 37, 60, 'Z', 'BDE'); L.set(g, 38, 60, 'Z', 'BDE'); L.set(g, 37, 61, 'Z', 'BDE')
  L.outline(g, 'A', solid())
  for _, q in ipairs({ { 20, 50 }, { 76, 40 }, { 80, 70 }, { 16, 74 }, { 47, 90 } }) do drop(g, F.pen(g, 3), q[1] / 3, q[2] / 3, false) end
  return g
end

-- ECO (Rillet): cururu sentado, em proporção natural. O errado: o dorso é um espelho d'água que reflete um céu
-- (com nuvem), e do queixo pinga.
local function eco(k, ox, oy)
  local S = k > 1 and 96 or 28
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  P:limb({ { 21.6, 19 }, { 23.4, 22.4 }, { 23, 24.6 } }, 1.1, 0.8, 'h')        -- braço de trás
  P:ell(11.4, 18.4, 8.3, 5.3, 'f', nil, -20)
  P:ell(8.6, 20.2, 5.2, 4.2, 'f')
  P:ell(19.2, 13.4, 5.2, 3.7, 'f', nil, -10)
  P:ell(22.8, 14.2, 2.9, 2.4, 'f')
  P:ell(20.2, 10.6, 2.0, 1.7, 'f')                                            -- calombo do olho
  P:ell(19.4, 17.2, 3.4, 2.2, 'x')
  P:ell(15.2, 21.6, 4.6, 2.4, 'x')
  P:limb({ { 17.6, 19.4 }, { 19.8, 22.6 }, { 19.4, 24.6 } }, 1.75, 1.3, 'a')
  P:limb({ { 18.2, 19.6 }, { 20.2, 22.6 }, { 19.6, 24.6 } }, 1.4, 0.95, 'h')
  P:ell(7.4, 20.6, 5.2, 3.8, 'a', nil, 24)
  P:ell(7.4, 21, 4.7, 3.3, 'h', nil, 24)
  P:limb({ { 4.2, 23 }, { 9.6, 24.5 } }, 1.3, 1.0, 'h')
  P:limb({ { 8.6, 25 }, { 14.2, 25 } }, 0.55, 0.5, 'h')
  toes(P, 19.4, 24.6, 3, 2.6, 'h')
  if k > 1 then toes(P, 22.8, 24.6, 3, 2.2, 'h'); toes(P, 12.6, 24.6, 3, 3.6, 'h') end
  skin(g, k, 'f', SKIN, { within = 'fxh' })
  skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', BELLY, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 3, within = 'x', jit = k > 1 and 2 or 0 })
  -- glândula atrás do olho
  P:ell(15.4, 11.9, 2.7, 1.3, 'e', SKIN, -14)
  P:ell(15.4, 12.3, 2.5, 0.8, 'd', 'e', -14)
  -- espelho no dorso
  mirror(g, P, 9.4, 15.6, 5.3, 2.3, SKIN, { rot = -20, clouds = 4 })
  -- boca, narina, olho
  P:limb({ { 17.6, 15.6 }, { 22, 15.5 }, { 25.2, 14.6 } }, 0.3, 0.3, 'a', SKIN .. BELLY)
  P:px(24.8, 12.8, 'a')
  eye(g, P, 20.4, 10.8, 1)
  L.outline(g, 'A', solid())
  drop(g, P, 24.4, 20.4, false)
  if k > 1 then drop(g, P, 23.6, 24, false); drop(g, P, 5, 11, true) end
  P:dot(3.6, 10.4, 's')
  return g
end

-- ESPÍRITO (Brookkin): o cururu tomado pela sarjeta. A boca virou boca de lobo (verga e soleira de concreto, a guia
-- com a tinta amarela gasta) e despeja água; três olhos em fila, três braços, e o espelho do dorso partiu em poças.
local function espirito(k, ox, oy)
  local S = k > 1 and 96 or 36
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  P:limb({ { 29.6, 26 }, { 31.8, 29.6 }, { 31.4, 32.6 } }, 1.3, 0.9, 'h')
  P:ell(14.6, 21.6, 10.4, 7.6, 'f', nil, -12)
  P:ell(11, 24, 6.6, 5.6, 'f')
  P:ell(23.6, 17.4, 7, 5.4, 'f', nil, -5)
  for _, q in ipairs({ { 19.6, 12.2 }, { 24.4, 11.4 }, { 28.6, 12.8 } }) do P:ell(q[1], q[2], 2.1, 1.8, 'f') end
  P:ell(20, 26.6, 5.6, 3, 'x')
  -- a boca de lobo
  P:poly({ { 20.4, 17.6 }, { 33.4, 16.6 }, { 34, 19.6 }, { 20.4, 20.8 } }, 'y')
  P:poly({ { 21.4, 20.8 }, { 33.8, 19.6 }, { 33.6, 22.4 }, { 21.4, 23.2 } }, 'k')
  P:poly({ { 20.4, 23.2 }, { 34, 22.4 }, { 33.4, 25.8 }, { 21, 26.6 } }, 'y')
  P:limb({ { 21.6, 26 }, { 24.4, 30 }, { 23.8, 32.6 } }, 1.6, 1.1, 'h')
  P:limb({ { 25.6, 26 }, { 28.2, 29.8 }, { 27.6, 32.6 } }, 1.5, 1.0, 'h')
  P:ell(8.6, 26.8, 6.2, 4.2, 'h', nil, 24)
  P:limb({ { 4.4, 29.6 }, { 11.4, 32.2 } }, 1.6, 1.2, 'h')
  P:limb({ { 10, 33 }, { 17.6, 33 } }, 0.6, 0.55, 'h')
  toes(P, 23.6, 32.6, 3, 2.8, 'h'); toes(P, 27.6, 32.6, 3, 2.6, 'h')
  if k > 1 then toes(P, 31.2, 32.6, 3, 2.2, 'h'); toes(P, 15.6, 32.6, 3, 3.6, 'h') end
  skin(g, k, 'f', SKIN, { within = 'fxhyk' })
  skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', BELLY, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 3, within = 'x' })
  F.shade(g, 'y', CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0.2, zones = 2, within = 'y', jit = k > 1 and 2 or 1, jw = 3 })
  -- tinta amarela gasta na quina da soleira, trinca na verga
  for x = 21, 33.6, 1 / k do
    if F.rnd(floor(x * k), 2, 6) > 0.3 then P:px(x, 23.4 - (x - 21) * 0.062, floor(x) % 3 == 0 and 'g' or 'G') end
  end
  P:limb({ { 26.4, 16.8 }, { 27, 18.6 }, { 26.4, 20 } }, 0.3, 0.3, 'J', CONC)
  P:ell(14.4, 13.6, 3.3, 1.5, 'e', SKIN, -12); P:ell(14.4, 14.1, 3.1, 0.9, 'd', 'e', -12)
  -- poças no dorso
  mirror(g, P, 8.6, 18.4, 4.6, 2.3, SKIN, { rot = -18, clouds = 4 })
  mirror(g, P, 15.4, 15.9, 3.2, 1.5, SKIN, { rot = -12 })
  mirror(g, P, 5.4, 22.4, 1.9, 1.1, SKIN, { rot = -30 })
  for _, q in ipairs({ { 19.8, 12.4 }, { 24.6, 11.6 }, { 28.8, 13 } }) do eye(g, P, q[1], q[2], 1.05) end
  -- a água que sai da boca
  for s = 0, floor(9.6 * k) do
    local t = s / (9.6 * k)
    local x0 = P:X(30.4 + t * 1.6)
    for wd = 0, floor(2.2 * k * (1 - t * 0.5)) do
      local ch = (wd == 0 or s % 3 == 0) and 'E' or ((s + wd) % 2 == 0 and 'D' or 'B')
      L.set(g, x0 + wd, P:Y(21.4) + s, ch, 'k')
    end
  end
  L.outline(g, 'A', solid())
  for s = 0, floor(10 * k) do
    local t = s / (10 * k)
    for wd = 0, floor(1.8 * k * (1 - t * 0.4)) do
      L.set(g, P:X(31.6 + t * 1.2) + wd, P:Y(23.4) + s, (wd == 0 or s % 3 == 0) and 's' or ((s + wd) % 2 == 0 and 'S' or 'T'), '.A')
    end
  end
  P:dot(30.4, 34, 's'); P:dot(34.4, 33.4, 'S'); P:dot(29, 33, 'T')
  drop(g, P, 3.4, 14.4, true)
  return g
end

-- ENTIDADE MAIOR: a poça em pé. O sapo virou o aro de pele em volta de um espelho d'água vertical; a cara dele só
-- existe no reflexo, de ponta-cabeça. Três pernas (duas andam, a terceira dobrou em cima), três mãos seguram a borda.
-- Regra quebrada: a água dela não cai; a poça fica em pé e a chuva sobe.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local P = F.pen(g, k)
  local cx, cy = 23.5, 21.5
  -- pernas
  for _, sg in ipairs({ -1, 1 }) do
    P:ell(cx + sg * 9.6, 37.4, 5.4, 3.3, 'h', nil, sg * 32)
    P:limb({ { cx + sg * 13.6, 39.6 }, { cx + sg * 7.4, 43.6 } }, 1.7, 1.2, 'h')
    P:limb({ { cx + sg * 8.4, 44.8 }, { cx + sg * 8.4 + 6.4, 44.8 } }, 0.7, 0.55, 'h')
    toes(P, cx + sg * 8.4 + 5, 44.4, 3, 3, 'h')
  end
  P:ell(cx + 1.5, 5.6, 5.2, 2.3, 'h', nil, -8)
  P:limb({ { cx - 3, 6.4 }, { cx - 8, 5 }, { cx - 12, 7.4 } }, 1.4, 0.9, 'h')
  toes(P, cx - 12, 7.4, 3, 3, 'h', -1)
  -- aro de pele e o espelho
  P:ell(cx, cy, 13.2, 16.2, 'f')
  -- o pedaço de baixo do aro é a guia: concreto com a tinta gasta, e a barriga creme por dentro
  for y = 0, S - 1 do for x = 0, S - 1 do
    if g[y][x] == 'f' then
      local uy = (y + 0.5) / k - 0.5
      if uy > cy + 10.4 then g[y][x] = 'y' elseif uy > cy + 8.2 then g[y][x] = 'x' end
    end
  end end
  skin(g, k, 'f', SKIN, { within = 'fxy', warts = 0.86 })
  skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', BELLY, { p = 2, ax = 1, ay = 0.3, zones = 3, within = 'x' })
  F.shade(g, 'y', CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0.2, zones = 2, within = 'y', jit = 1, jw = 3 })
  for x = cx - 9, cx + 9, 1 / k do
    if F.rnd(floor(x * k), 2, 6) > 0.35 then P:px(x, cy + 10.9, floor(x) % 3 == 0 and 'g' or 'G', CONC) end
  end
  local rx, ry = 8.8, 11.4
  mirror(g, P, cx, cy, rx, ry, nil, { clouds = 7, rows = true, v0 = 0.5 })
  -- a cara só existe no reflexo: três olhos de cururu (os do Eco) boiando no céu, de ponta-cabeça
  -- em cata-vento (um em cima, dois embaixo), cada um girado: não fecha numa cara
  for n = 0, 2 do
    local a = -90 + n * 120
    local ex, ey = cx + cos(rad(a)) * 4.9, cy + 0.6 + sin(rad(a)) * 5.4
    P:ell(ex, ey, 3.0, 2.1, 'a', nil, a + 90)
    P:ell(ex, ey, 2.3, 1.45, 'O', nil, a + 90)
    P:ell(ex + cos(rad(a)) * 0.5, ey + sin(rad(a)) * 0.5, 2.2, 0.8, 'o', 'O', a + 90)
    P:ell(ex, ey, 1.7, 0.45, 'k', nil, a + 90)
  end
  -- mãos na borda
  for n, a in ipairs({ -28, 208, 90 }) do
    local hx, hy = cx + cos(rad(a)) * (rx + 2.6), cy + sin(rad(a)) * (ry + 2.6)
    for f = -1, 1 do
      local aa = rad(a + 180 + f * 24)
      P:limb({ { hx + cos(rad(a + 90)) * f * 1.3, hy + sin(rad(a + 90)) * f * 1.3 }, { hx + cos(aa) * 3.6, hy + sin(aa) * 3.6 } }, 0.5, 0.42, f == 0 and 'V' or 'W')
    end
  end
  L.outline(g, 'A', solid())
  -- a chuva sobe
  for n, q in ipairs({ { 6, 12 }, { 11, 4.6 }, { 30.6, 2.2 }, { 38.6, 8 }, { 42.6, 17 }, { 3.6, 23 }, { 35.4, 0.6 }, { 43.6, 28 } }) do
    drop(g, P, q[1], q[2], true)
  end
  return g
end

-- ARQUÉTIPO: o céu de baixo. Uma sarjeta em anel (concreto, a água correndo sem fim) atravessada por uma coluna de
-- espinha e água; o arco de trás do anel passa pela frente da coluna e o da frente passa por trás. Em cima, no lugar
-- da cabeça, só a boca: um aro de lábio em volta do vão, com outro céu dentro. Três pernas de sapo pendem do anel.
-- Regra quebrada: a água dele cai para cima, da ponta da coluna até o vão.
local function arquetipo(k)
  local S = 64 * k
  local g = L.grid(S, S)
  local P = F.pen(g, k)
  local cx, ry0 = 31.5, 35
  local RX, RY, IX, IY = 22, 8, 16, 5
  -- pernas
  local legs = {
    { { 12, 38 }, { 6.6, 44.6 }, { 12.6, 50 }, { 8.4, 56.6 }, { 6.6, 60 } },
    { { 51, 38 }, { 56.4, 44.6 }, { 50.4, 50 }, { 54.6, 56.6 }, { 56.4, 60 } },
  }
  for n, pts in ipairs(legs) do
    P:limb(pts, 2.4, 1.1, 'h')
    toes(P, pts[5][1], pts[5][2], 3, 2.6, 'h', n == 1 and -1 or 1)
  end
  -- o couro do sapo, virado do avesso, pendurado no anel
  P:poly({ { 10.6, 40 }, { 22.6, 44 }, { 21.6, 50.5 }, { 19.6, 48 }, { 18, 55 }, { 16, 49.5 }, { 14, 53 }, { 12.4, 46.5 } }, 'x')
  P:limb({ { 12, 46 }, { 10.4, 51 }, { 11.4, 54.6 } }, 1.1, 0.7, 'x')
  local function ring(front)
    for y = 0, S - 1 do for x = 0, S - 1 do
      local ux, uy = (x + 0.5) / k - 0.5, (y + 0.5) / k - 0.5
      local dx, dy = ux - cx, uy - ry0
      if (dy > 0) == front then
        local o = (dx / RX) ^ 2 + (dy / RY) ^ 2
        local i = (dx / IX) ^ 2 + (dy / IY) ^ 2
        local wall = (dx / RX) ^ 2 + ((dy - 3) / RY) ^ 2          -- a parede de fora, 3 px para baixo
        local an = math.atan(dy / RY, dx / RX)
        local seg = floor((an + 3.1416) / 6.2832 * 24)
        if o <= 1 and i >= 1 then
          local mid = (dx / ((RX + IX) / 2)) ^ 2 + (dy / ((RY + IY) / 2)) ^ 2
          local ch
          if abs(mid - 1) < 0.16 then ch = (seg + floor(uy)) % 3 == 0 and 'E' or (seg % 2 == 0 and 'D' or 'B')
          else ch = (dx < -6) and (seg % 2 == 0 and 'I' or 'i') or (seg % 2 == 0 and 'i' or 'j') end
          if F.rnd(seg, floor(uy), 3) > 0.9 and ch ~= 'E' and ch ~= 'D' and ch ~= 'B' then ch = 'g' end
          g[y][x] = ch
        elseif front and wall <= 1 and o > 1 then
          g[y][x] = (seg % 2 == 0) and 'j' or 'J'
        end
      end
    end end
  end
  ring(true)
  -- a coluna: espinha e água
  for y = floor(P:Y(20)), floor(P:Y(48)) do
    local uy = (y + 0.5) / k - 0.5
    for x = floor(P:X(cx - 2.6)), floor(P:X(cx + 2.6)) do
      local ux = (x + 0.5) / k - 0.5
      local v = floor(uy) % 3
      local hw = v == 0 and 1.2 or 2.6
      if abs(ux - cx) <= hw then g[y][x] = v == 0 and '4' or (abs(ux - cx) < 1 and '1' or (ux < cx and '2' or '3')) end
    end
  end
  P:limb({ { cx, 48 }, { cx - 3.4, 52 }, { cx + 1.6, 56 }, { cx - 1, 59.4 }, { cx + 0.4, 60.6 } }, 2.0, 0.9, 'h')
  ring(false)
  -- cordões de ovos pendurados no arco da frente (fio de geleia com os ovos escuros)
  for n, ex in ipairs({ 25, 37.6, 43.6, 47.6, 28.6, 40.4 }) do
    local ey = ry0 + RY * sqrt(1 - ((ex - cx) / RX) ^ 2) + 3
    local len = 5 + floor(F.rnd(n, 4, 4) * 8)
    for s = 0, len * k do
      local uy = ey + s / k
      local x = P:X(ex + sin(uy * 0.7 + n) * 0.7)
      L.set(g, x, P:Y(ey) + s, (s // k) % 2 == 0 and 'K' or 'M')
      if k > 1 then L.set(g, x + 1, P:Y(ey) + s, 'M') end
    end
  end
  -- o lábio e o vão
  local vx, vy, vrx, vry = cx, 11.6, 9.8, 7.6
  P:ell(vx, vy, vrx, vry, 'f')
  P:ell(vx - 9.4, vy + 2.6, 2.8, 1.5, 'f', nil, 30); P:ell(vx + 9.4, vy + 2.6, 2.8, 1.5, 'f', nil, -30)
  skin(g, k, 'f', GREY, { within = 'f', warts = 0.84, zones = 2 })
  skin(g, k, 'h', '234', { within = 'h', seed = 5, zones = 1 })
  F.shade(g, 'x', 'VWwv', { p = 2, ax = 1, ay = 0.5, zones = 3, within = 'x', jit = 2, jw = 2 })
  for y = 0, S - 1 do for x = 0, S - 1 do
    local ux, uy = (x + 0.5) / k - 0.5, (y + 0.5) / k - 0.5
    local d = sqrt(((ux - vx) / vrx) ^ 2 + ((uy - vy) / vry) ^ 2)
    if d < 0.76 then
      local ch = '.'
      if d > 0.58 then ch = 'X'
      elseif d > 0.44 and (x + y) % 2 == 0 then ch = 'X'
      elseif F.rnd(x // k, y // k, 12) > 0.84 then ch = (x // k + y // k) % 2 == 0 and 's' or 'S' end
      g[y][x] = ch
    end
  end end
  local keep = {}
  for y = 0, S - 1 do for x = 0, S - 1 do
    if LOOSE:find(g[y][x], 1, true) then keep[#keep + 1] = { x, y, g[y][x] }; g[y][x] = '.' end
  end end
  L.outline(g, 'A', solid())
  for _, q in ipairs(keep) do if g[q[2]][q[1]] == '.' then g[q[2]][q[1]] = q[3] end end
  -- a água sobe pelos lados da coluna e em gotas
  for _, sg in ipairs({ -1, 1 }) do
    for y = floor(P:Y(20.4)), floor(P:Y(47)) do
      local uy = (y + 0.5) / k - 0.5
      for wd = 0, k - 1 do
        local x = P:X(cx + sg * (3.6 + sin(uy * 0.9 + sg) * 0.5)) + wd
        if floor(uy * 1.5 + sg) % 4 ~= 0 then L.set(g, x, y, floor(uy) % 3 == 0 and 's' or (floor(uy) % 3 == 1 and 'S' or 'T'), '.A') end
      end
    end
  end
  for _, q in ipairs({ { 22, 24 }, { 41, 22.6 }, { 17.6, 16 }, { 46, 14 }, { 9, 30 }, { 54, 28.6 }, { 25, 52 }, { 38.6, 50 } }) do
    drop(g, P, q[1], q[2], true)
  end
  return g
end

local function out(stage, kind, fn)
  C.save('rill', stage, kind, F.prune(fn(), LOOSE, stage .. ' ' .. kind), LEG, LIT, LOOSE)
end
out('fagulha', 'mapa', fagulhaMapa)
out('fagulha', 'retrato', fagulhaRetrato)
out('eco', 'mapa', function() return eco(1) end)
out('eco', 'retrato', function() return eco(3.3, 2, 0) end)
out('espirito', 'mapa', function() return espirito(1, -1, 0) end)
out('espirito', 'retrato', function() return espirito(2.6, 1, 1) end)
out('entidade', 'mapa', function() return entidade(1) end)
out('entidade', 'retrato', function() return entidade(2) end)
out('arquetipo', 'mapa', function() return arquetipo(1) end)
out('arquetipo', 'retrato', function() return arquetipo(2) end)
print('ok rill')
