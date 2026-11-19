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

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.Q, LEG.p, LEG.Y = '#9B7BFF', '#5E586A', '#5A45A8'        -- costura do Véu e o par apagado; Y é o fundo do vão (solto)
LIT.Q = 'p'; LOOSE = LOOSE .. 'Y'; THIN = THIN .. 'Y'
local function hide(pal, p, cx, cy, rx, ry, seed)              -- pele de cururu: barro em hachura, com verrugas
  local nz, lm = R.noise(p, seed or 3), R.lum(cx, cy, rx, ry)
  return function(x, y, u, v)
    if R.hash(x // p, y // p, 11) > 0.93 and (x // p + y // p) % 2 == 0 then return pal:sub(#pal, #pal) end
    return R.pick(pal, lm(u, v), nz(x, y))
  end
end
local function sky(p, cy, ry)                                  -- o céu no espelho: faixas, com nuvem
  return function(x, y, u, v)
    local b = (v - cy) / ry
    if R.hash(x // (3 * p), y // p, 5) > 0.74 and b < 0.2 then return 'Z' end
    return b < -0.3 and (y // p % 2 == 0 and 'E' or 'D') or (b < 0.35 and (y // p % 2 == 0 and 'D' or 'E') or (y // p % 2 == 0 and 'B' or 'D'))
  end
end
local function ceye(t, x, y, r, rot)                           -- olho de cururu: calombo, íris ocre, pupila deitada (ou de pé)
  t:ell(x, y, r, r * 0.85, 'O'); t:ell(x, y + r * 0.4, r, r * 0.45, 'o', 'O')
  if rot then t:ell(x, y, r * 0.3, r * 0.75, 'k') else t:ell(x, y, r * 0.8, r * 0.3, 'k') end
end

-- ENTIDADE MAIOR: a sarjeta inteira. O corpo é um trecho de guia e de asfalto; a boca é a boca de lobo, e por cima do
-- concreto sobrou o dorso de verruga com dois olhos. Seis membros: duas pernas de sapo dobradas nas pontas, dois braços
-- saindo da boca, dois agarrados na guia. A água sai da boca de lobo e sobe: a enxurrada corre para o céu e junta
-- numa poça que fica deitada no ar, em cima dela, com o terceiro olho boiando no reflexo.
local function entidade(k)
  local d = R.ctx(48 * k, k)
  local p = d:pp()
  local SOL = solid()
  d:layer(function(t)                                                              -- pernas de trás, dobradas, uma em cada ponta
    for _, s in ipairs({ -1, 1 }) do
      local cx = 23.5 + s * 17.4
      t:cap(cx - s * 3, 37, cx + s * 1.6, 30.6, 2.5, 1.9, hide('abcd', p, cx, 34, 5, 5))
      t:cap(cx + s * 1.6, 30.6, cx - s * 1, 42.6, 1.7, 1.2, hide('abcd', p, cx, 36, 4, 7))
      for i = -1, 1 do t:wire({ { cx - s * 1, 42.6 }, { cx - s * 1 + i * 1.8 + s, 45 } }, 'c', 'd', 0.6) end
    end
  end, SOL)
  d:layer(function(t)
    t:poly({ { 6, 40 }, { 41, 40 }, { 39.4, 45 }, { 8, 45 } }, R.mat('nN', R.noise(p, 2), 0))                    -- o asfalto
    t:ell(23.5, 29.6, 15.6, 6.4, hide('abcde', p, 23.5, 29.6, 15.6, 6.4))                                         -- o dorso
    t:ell(13.4, 25.6, 2.9, 2.5, hide('bcde', p, 13.4, 25.6, 3, 3)); t:ell(33.6, 25.6, 2.9, 2.5, hide('bcde', p, 33.6, 25.6, 3, 3))
    ceye(t, 13.4, 25.4, 1.7); ceye(t, 33.6, 25.4, 1.7, true)
    t:suture({ { 17.6, 26.4 }, { 21, 30.4 } }, 'Q', 1.4, nil)                                                     -- a costura
    t:poly({ { 5, 31 }, { 42, 31 }, { 43.6, 33.6 }, { 43.6, 40 }, { 3.4, 40 }, { 3.4, 33.6 } }, function(x, y, u, v)  -- a guia
      if v < 33.2 then return (R.hash(x // (2 * p), 0, 7) > 0.45) and R.pick('gG', 0, R.chk(p)(x, y)) or R.pick('iI', 0, R.noise(p, 4)(x, y)) end
      return R.pick('Jji', 0.7 - (v - 33) / 9, R.noise(p, 4)(x, y))
    end)
    t:rect(12.6, 34.6, 34.4, 38.4, function(x, y, u, v)                                                           -- a boca de lobo
      if v > 37.4 or v < 35.2 then return R.pick('ka', 0, R.ver(p)(x, y)) end
      return (x // p) % 3 == 0 and 'k' or (y // p % 2 == 0 and 'B' or 'D')
    end)
    for _, s in ipairs({ -1, 1 }) do                                                                              -- braços: da boca, e na guia
      t:cap(23.5 + s * 10, 38, 23.5 + s * 12.6, 43, 1.3, 1, hide('bcd', p, 23.5 + s * 11, 40, 3, 4))
      for i = -1, 1 do t:wire({ { 23.5 + s * 12.6, 43 }, { 23.5 + s * 12.6 + i * 1.5, 45 } }, 'c', 'd', 0.5) end
      t:cap(23.5 + s * 15, 27.6, 23.5 + s * 16.6, 32, 1.3, 1, hide('bcd', p, 23.5 + s * 16, 30, 3, 4))
      for i = -1, 1 do t:wire({ { 23.5 + s * 16.6, 32 }, { 23.5 + s * 16.6 + i * 1.4, 34.2 } }, 'c', 'd', 0.5) end
    end
  end, SOL)
  d:layer(function(t)                                                              -- a enxurrada sobe, e a poça no ar
    t:poly({ { 21, 37.4 }, { 26, 37.4 }, { 24.6, 24 }, { 25, 14 }, { 26.4, 8.6 }, { 20.6, 8.6 }, { 22, 14 }, { 22.4, 24 } }, function(x, y, u, v)
      return (x // p) % 3 == 0 and 'B' or ((x // p + y // p) % 2 == 0 and 'D' or 'E')
    end)
    t:ell(23.5, 7.4, 14.6, 3.5, 'q')
    t:ell(23.5, 7.2, 13.6, 2.8, sky(p, 7.2, 2.8))
    ceye(t, 30.6, 7.2, 1.5)
  end, SOL)
  for n2, q in ipairs({ { 6, 22 }, { 9.6, 15 }, { 4, 11 }, { 39, 19 }, { 42.6, 13 }, { 36.4, 14.6 }, { 15, 18.6 }, { 31.6, 20 } }) do
    drop(d.g, d, q[1], q[2], true)
  end
  return d.g
end

-- ARQUÉTIPO: o sapo de frente, sentado em cima do próprio reflexo. O de cima é pequeno, pele sem cor, e não tem rosto:
-- os calombos dos olhos estão lá, cegos. O de baixo, de ponta-cabeça, é maior que ele e tem o que ele não tem: os
-- olhos abertos, um terceiro, dois braços a mais. Entre os dois, na linha d'água, a imagem não fecha: o vão.
local function arquetipo(k, S, ox, oy)
  local d = R.ctx(S or 64 * k, k, ox, oy)
  local p = d:pp()
  local SOL = solid()
  local cx, WL = 31.5, 27.5
  d:layer(function(t)                                                              -- o reflexo: maior, virado, com rosto
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 13, 40, cx + s * 25.6, 47, 3.6, 2.6, hide('4321', p, cx + s * 19, 43, 8, 6))                  -- coxas
      t:cap(cx + s * 25.6, 47, cx + s * 22, 32.6, 2.2, 1.5, hide('4321', p, cx + s * 24, 40, 4, 9))
      for i = -1, 1 do t:wire({ { cx + s * 22, 32.6 }, { cx + s * (22 + i * 2), 29.6 } }, '2', '3', 0.6) end
      t:cap(cx + s * 9, 37, cx + s * 12.6, 30.4, 1.9, 1.3, hide('4321', p, cx + s * 11, 34, 3, 5))                 -- quatro braços
      t:cap(cx + s * 4, 36, cx + s * 5.6, 30, 1.7, 1.2, hide('4321', p, cx + s * 5, 33, 3, 5))
    end
    t:ell(cx, 42, 16.6, 11.6, hide('4321', p, cx, 42, 16.6, 11.6))
    t:ell(cx, 39, 9, 5, sky(p, 39, 5))                                                                             -- o dorso que reflete o céu, no ventre dele
    t:ell(cx, 46.4, 9.6, 3.4, R.mat('vwWV', R.noise(p, 6), 0.5))
    for _, q in ipairs({ { -10.6, 52.4, 4.4 }, { 10.6, 52.4, 4.4 }, { 0, 56, 3.6, true } }) do
      t:ell(cx + q[1], q[2], q[3], q[3] * 0.9, hide('b321', p, cx + q[1], q[2], q[3], q[3]))
      ceye(t, cx + q[1], q[2] + 0.4, q[3] * 0.62, q[4])
    end
    t:wire({ { cx - 8, 48.6 }, { cx, 50.4 }, { cx + 8, 48.6 } }, 'a', nil, 0.6)                                    -- a boca, virada
  end, SOL)
  d:layer(function(t)                                                              -- o de cima: pequeno, sem rosto
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 8, 21, cx + s * 15.6, 17.4, 2.6, 2, hide('4321', p, cx + s * 12, 19, 5, 4))
      t:cap(cx + s * 15.6, 17.4, cx + s * 13, 25.6, 1.6, 1.1, hide('4321', p, cx + s * 14, 21, 3, 5))
    end
    t:ell(cx, 18.6, 10.6, 7.6, hide('4321', p, cx, 18.6, 10.6, 7.6))
    t:ell(cx - 6.4, 11.6, 3.2, 2.9, hide('321', p, cx - 6.4, 11.6, 3.2, 3)); t:ell(cx + 6.4, 11.6, 3.2, 2.9, hide('321', p, cx + 6.4, 11.6, 3.2, 3))
    t:ell(cx, 15.4, 5.6, 2.6, sky(p, 15.4, 2.6))
    t:ell(cx, 23, 6.6, 2.4, R.mat('vwWV', R.noise(p, 6), R.lum(cx, 23, 6.6, 2.4)))
    t:wire({ { cx - 6, 20.4 }, { cx, 21.4 }, { cx + 6, 20.4 } }, 'a', nil, 0.6)
    for _, s in ipairs({ -1, 1 }) do t:wire({ { cx + s * 8, 11.8 }, { cx + s * 4.8, 11.8 } }, 'b', nil, 0.5) end   -- os olhos, fechados por cima
  end, SOL)
  local function lens(u, v, s)
    local q = (u - cx) / (21 * s)
    if abs(q) >= 1 then return nil end
    local t = abs(v - WL) / (4.6 * s * (1 - q * q) ^ 0.7)
    return t <= 1 and t or nil
  end
  d:vao(function(u, v) return lens(u, v, 1) end, 'X', 'Y', 0.7)
  for lv, s in ipairs({ 0.55, 0.28 }) do                                             -- o mesmo sapo e o mesmo reflexo, para dentro
    local w = 21 * s
    local ch = lv == 1 and 'X' or 's'
    d:wire({ { cx - w, WL }, { cx - w * 0.6, WL - 2.2 * s }, { cx - w * 0.3, WL - 1.2 * s }, { cx + w * 0.3, WL - 1.2 * s }, { cx + w * 0.6, WL - 2.2 * s }, { cx + w, WL } }, ch, nil, 0.5, '.Y')
    d:wire({ { cx - w, WL }, { cx - w * 0.6, WL + 2.6 * s }, { cx, WL + 1.4 * s }, { cx + w * 0.6, WL + 2.6 * s }, { cx + w, WL } }, ch, nil, 0.5, '.Y')
  end
  d:layer(function(t)                                                              -- os braços dele atravessam a linha d'água
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 7, 22.6, cx + s * 9, 33, 1.2, 0.9, hide('b321', p, cx + s * 8, 27, 2, 5))
      for i = -1, 1 do t:wire({ { cx + s * 9, 33 }, { cx + s * 9 + i * 1.5, 35.4 } }, 'd', 'c', 0.5) end
      t:ell(cx + s * 6.4, 10.4, 0.6, 0.6, 'e')
    end
  end, SOL)
  for n2 = 0, 13 do
    drop(d.g, d, cx + ((n2 * 37) % 56) - 28, 4 + (n2 * 5) % 6 + (n2 % 2) * 54 - (n2 % 2) * 4, n2 % 2 == 0)
  end
  return d.g
end

local function out(stage, kind, fn)
  if R.skip(stage) then return end
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
out('arquetipo', 'retrato', function() return arquetipo(3, 128, -31, -14) end)     -- busto: o sapo sem rosto, a linha d'água e o alto do reflexo
print('ok rill')
