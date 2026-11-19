-- Conceitos da família Frond (Etapa 1): Charnia (fronde ediacarana) + rachadura de calçada e raiz + a fronde fractal.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/frond/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local F = dofile(KENOMA_ART .. 'creatures/conceitos/soot/_forma.lua')(C)
local L = C.L
local floor, ceil, sqrt, abs, cos, sin, rad = math.floor, math.ceil, math.sqrt, math.abs, math.cos, math.sin, math.rad

local LEG = {
  A = '#1A1424',
  a = '#2B3324', b = '#3D4A30', c = '#566440', d = '#748354', e = '#96A070', -- folha (verde de calçada, sem brilho)
  n = '#5E4628', N = '#7E6038', M = '#A07C48',                               -- folha seca
  q = '#4C3D2E', p = '#735D42', o = '#9A8262',                               -- raiz
  J = '#454449', j = '#63625F', i = '#85847F', I = '#A9A8A2',                 -- concreto da calçada
  k = '#2A2630',                                                              -- junta, fundo da rachadura
  ['1'] = '#B9B4A6', ['2'] = '#928D80', ['3'] = '#6A665E', ['4'] = '#4A474A', -- pedra do fóssil (Arquétipo)
  r = '#22381F', u = '#2F4A2C',                                               -- nervura apagada (corpo)
  B = '#3A8E4A', D = '#6BD36A', E = '#B4F08A', Z = '#F0FFD0',                 -- nervura acesa
  T = '#3A8E4A', S = '#6BD36A', s = '#D8F8B0', X = '#9B7BFF',                 -- esporo solto e o Véu (só no emissivo)
  -- bases que o sombreado troca: f folha, g folha seca, h raiz, y concreto, z fóssil, m nervura
}
local LIT = { B = 'r', D = 'u', E = 'u', Z = 'u' }
local LOOSE = 'TSsX'
local THIN = 'ATSsX'
local function solid()
  local s = ''
  for ch in pairs(LEG) do if not THIN:find(ch, 1, true) then s = s .. ch end end
  return s
end
local LEAF, DRY, ROOT, CONC, STONE = 'edcba', 'MNn', 'opq', 'IijJ', '1234'

-- Ponto e direção ao longo de uma linha quebrada, t de 0 a 1.
local function along(pts, t)
  local total, acc = 0, 0
  for i = 1, #pts - 1 do total = total + sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2) end
  local want = t * total
  for i = 1, #pts - 1 do
    local dx, dy = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
    local len = sqrt(dx * dx + dy * dy)
    if want <= acc + len or i == #pts - 1 then
      local f = len > 0 and (want - acc) / len or 0
      return pts[i][1] + dx * f, pts[i][2] + dy * f, math.deg(math.atan(dy, dx)), total
    end
    acc = acc + len
  end
end

-- Fronde de Charnia: lobos alternados (um lado, depois o outro: simetria de deslize, não de espelho), cada lobo com
-- a costura escura em volta. o = { n = lobos por lado, w = função(t) comprimento do lobo, ang, t0, t1,
--   mat = função(i, lado) -> base, costura; side = só um lado; stem = false para não desenhar o talo; r0, r1 }
local function frond(P, pts, o)
  local n, t0, t1 = o.n, o.t0 or 0.05, o.t1 or 0.9
  local _, _, _, total = along(pts, 0)
  local step = total * (t1 - t0) / (2 * n)
  local lobes = {}
  for i = 0, 2 * n - 1 do
    local side = (i % 2 == 0) and -1 or 1
    if o.side == nil or o.side == side then
      local t = t0 + (t1 - t0) * (i + 0.5) / (2 * n)
      local x, y, da = along(pts, t)
      local la = da + side * (o.ang or 54)
      local len = o.w(t)
      local wid = math.max(1.1, step * (o.fat or 2.1))
      local base, seam = 'f', 'a'
      if o.mat then base, seam = o.mat(i, side) end
      local cx, cy = x + cos(rad(la)) * len * 0.5, y + sin(rad(la)) * len * 0.5
      P:ell(cx, cy, len * 0.5 + 0.5, wid * 0.5 + 0.5, seam, nil, la)
      P:ell(cx, cy, len * 0.5, wid * 0.5, base, nil, la)
      if P.k > 1 and len * P.k > 9 then
        -- a segunda ordem do fractal: cada lobo repartido em lobinhos, em espinha
        local ux, uy = cos(rad(la)), sin(rad(la))
        local vx, vy = cos(rad(la + side * 62)), sin(rad(la + side * 62))
        for sgm = 1, floor(len * P.k / 4) do
          local f = sgm * 4 / (len * P.k)
          local bx, by = P:X(x + ux * len * f), P:Y(y + uy * len * f)
          L.line(P.g, bx - vx * wid * P.k * 0.5, by - vy * wid * P.k * 0.5, bx + vx * wid * P.k * 0.5, by + vy * wid * P.k * 0.5, seam, base)
        end
      end
      lobes[#lobes + 1] = { x, y, x + cos(rad(la)) * len * 0.72, y + sin(rad(la)) * len * 0.72 }
    end
  end
  if o.stem ~= false then
    local th = P.k > 1 and 0.55 or 1                         -- no retrato o talo é fino: o fio de luz, não um cano
    P:limb(pts, (o.r0 or 0.5) * th, (o.r1 or 0.4) * th, 'm')
  end
  return lobes
end
-- Nervuras acesas: o talo (m) e, se pedido, o fio de cada lobo.
local function veins(g, P, lobes, mask)
  local k = P.k
  for _, q in ipairs(lobes or {}) do
    L.line(g, P:X(q[1]), P:Y(q[2]), P:X(q[3]), P:Y(q[4]), 'B', mask)
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == 'm' then g[y][x] = ((x + 2 * y) % 5 == 0) and 'E' or 'D' end
  end end
end
local function shadeAll(g, k)
  local p = k > 1 and 2 or 1
  F.shade(g, 'f', LEAF, { p = p, ax = 1, ay = 0.4, zones = 3, within = 'f', jit = k > 1 and 2 or 0, jw = 2 })
  F.shade(g, 'g', DRY, { p = p, ax = 1, ay = 0.4, zones = 1, within = 'g' })
  F.shade(g, 'h', ROOT, { p = k > 1 and 3 or 2, ax = 0.3, ay = 1, zones = 1, within = 'h' })
  F.shade(g, 'y', CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 2, within = 'y', jit = 1, jw = 3 })
  F.shade(g, 'z', STONE, { p = p, ax = 1, ay = 0.4, zones = 2, within = 'z' })
end
local function roots(P, list, r0, r1)
  for _, r in ipairs(list) do P:limb(r, r0 or 0.9, r1 or 0.45, 'h') end
end
local function spores(g, P, list)
  for n, q in ipairs(list) do P:dot(q[1], q[2], n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'T')) end
end

-- FAGULHA (Seed Mote): um lobo solto da fronde, com o fio da nervura aceso, girando como semente alada.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '......AAA...',
    '....AAedcA..',
    '...AeEdcbA..',
    '..AedDEcbA..',
    '..AdcbDEbA.s',
    '.AedcbBDcA..',
    '.AdcbaAoA...',
    '..AAAA.A....',
    '.......S....',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local g = L.grid(96, 96)
  local P = F.pen(g, 1)
  local stem = { { 20, 80 }, { 33, 62 }, { 48, 44 }, { 62, 30 }, { 72, 22 } }
  local lobes = frond(P, stem, { n = 6, t0 = 0.12, t1 = 0.94, ang = 50, fat = 2.9, r0 = 2.4, r1 = 1.0,
    w = function(t) return 10 + 22 * sin(3.14 * (0.1 + 0.85 * t)) ^ 0.9 end,
    mat = function(i) if i == 2 or i == 9 then return 'g', 'n' end return 'f', 'a' end })
  P:ell(19, 82, 5, 3.4, 'h', nil, -40)
  roots(P, { { { 17, 84 }, { 12, 88 }, { 12, 91.4 } }, { { 20, 85 }, { 22, 90 } } }, 1.3, 0.6)
  shadeAll(g, 2)
  veins(g, P, lobes, LEAF .. DRY)
  L.outline(g, 'A', solid())
  for n, q in ipairs({ { 14, 30 }, { 78, 60 }, { 60, 84 }, { 8, 58 }, { 88, 34 }, { 44, 10 } }) do
    L.rect(g, q[1], q[2], q[1] + 1, q[2] + 1, n % 2 == 0 and 's' or 'S', '.')
  end
  return g
end

-- ECO (Frondling): uma fronde de Charnia em pé, a ponta enrolada em báculo virada para a direita, andando sobre
-- as raízes do disco de fixação. O errado: os lobos não se espelham (um lado, depois o outro) e a nervura brilha.
local function eco(k, ox, oy)
  local S = k > 1 and 96 or 28
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  local stem = { { 12.4, 21 }, { 12.4, 17 }, { 13.4, 13 }, { 15.6, 9.4 }, { 18.8, 6.8 }, { 22, 6 }, { 24.2, 7.4 }, { 24.2, 10 }, { 22.4, 11 }, { 21, 9.8 } }
  roots(P, { { { 11.4, 21.4 }, { 7.4, 19.8 }, { 4, 24.4 } }, { { 11.8, 22 }, { 9.8, 23 }, { 8.6, 24.6 } }, { { 12.6, 22.4 }, { 12.8, 23.6 }, { 12.2, 24.8 } },
    { { 13.2, 22 }, { 15.2, 23 }, { 16.2, 24.6 } }, { { 13.6, 21.4 }, { 17.8, 19.8 }, { 21, 24.4 } } }, 1.25, 0.7)
  -- o báculo: a ponta ainda enrolada
  P:limb({ { 18.8, 6.8 }, { 22, 6 }, { 24.2, 7.4 }, { 24.2, 10 }, { 22.4, 11 } }, 1.2, 0.8, 'f')
  local lobes = frond(P, stem, { n = 7, t0 = 0.04, t1 = 0.6, ang = 48, fat = 2.6,
    w = function(t) return 2.2 + 4.6 * sin(3.14 * (0.14 + 0.82 * t / 0.6)) ^ 0.8 end,
    mat = function(i) if i == 3 then return 'g', 'n' end return 'f', 'a' end })
  P:ell(12.5, 21.8, 2.2, 1.4, 'h')
  P:poly({ { 14.4, 21 }, { 16.2, 20.6 }, { 16.6, 22 }, { 14.8, 22.4 } }, 'y')   -- uma lasca de calçada presa na raiz
  shadeAll(g, k)
  veins(g, P, k > 1 and lobes or nil, LEAF .. DRY)
  P:px(21, 9.8, 'Z')
  L.outline(g, 'A', solid())
  spores(g, P, { { 25.6, 13.4 }, { 5.4, 9 }, { 24.4, 17.6 } })
  return g
end

-- ESPÍRITO (Thicketkin): a fronde tomada pela calçada. O disco de fixação virou um pedaço de laje levantado pelas
-- raízes, com a rachadura acesa; da rachadura saem frondes em número errado (uma grande, uma torta, um báculo que não
-- abriu), e alguns lobos já são lascas de concreto ou folha seca.
local function espirito(k, ox, oy)
  local S = k > 1 and 96 or 36
  local g = L.grid(S, S)
  local P = F.pen(g, k, ox, oy)
  roots(P, { { { 9, 28 }, { 4.6, 27.6 }, { 2.8, 33 } }, { { 11, 29 }, { 8, 30.4 }, { 7.4, 33.2 } }, { { 15, 29 }, { 14, 31.4 }, { 14.6, 33.4 } },
    { { 20, 28 }, { 20.6, 31 }, { 19.8, 33.4 } }, { { 24, 27 }, { 26.6, 29.8 }, { 26, 33.2 } }, { { 27, 26 }, { 31.6, 26.6 }, { 33, 32.6 } },
    { { 17, 29 }, { 17.4, 31 }, { 17, 32.4 } } }, 1.15, 0.5)
  -- fronde torta, atrás
  local s2 = { { 11, 26 }, { 8.6, 21 }, { 6.6, 16 }, { 5.8, 11 }, { 6.6, 7 } }
  local l2 = frond(P, s2, { n = 5, t0 = 0.1, t1 = 0.95, ang = 50, w = function(t) return 1.6 + 3.6 * sin(3.14 * (0.15 + 0.8 * t)) end,
    mat = function(i) if i % 3 == 1 then return 'g', 'n' end return 'f', 'a' end })
  -- laje
  P:poly({ { 5.6, 24.4 }, { 27.4, 21.4 }, { 30.6, 25.6 }, { 9, 29.4 } }, 'y')
  P:poly({ { 9, 29.4 }, { 30.6, 25.6 }, { 30.6, 27.6 }, { 9.4, 31.2 } }, 'J')
  P:poly({ { 5.6, 24.4 }, { 9, 29.4 }, { 9.4, 31.2 }, { 5.8, 26.4 } }, 'j')
  -- fronde grande
  local s1 = { { 17, 25.4 }, { 17.6, 20.4 }, { 19.4, 15.4 }, { 22.4, 10.8 }, { 26, 7.8 }, { 29.2, 7.6 }, { 30.4, 9.4 }, { 29.4, 11 }, { 28, 10.4 } }
  local l1 = frond(P, s1, { n = 8, t0 = 0.05, t1 = 0.72, ang = 52, r0 = 0.9, r1 = 0.45,
    w = function(t) return 2.4 + 5.6 * sin(3.14 * (0.14 + 0.82 * t / 0.72)) ^ 0.8 end,
    mat = function(i) if i % 5 == 2 then return 'y', 'J' elseif i % 5 == 4 then return 'g', 'n' end return 'f', 'a' end })
  -- o báculo que não abriu
  P:limb({ { 23.6, 23.4 }, { 25.6, 19.6 }, { 28.4, 17.6 }, { 30.4, 18.6 }, { 30, 20.6 }, { 28.6, 20.4 } }, 0.8, 0.45, 'm')
  shadeAll(g, k)
  veins(g, P, k > 1 and l1 or nil, LEAF .. DRY)
  -- rachadura acesa na laje
  local cr = { { 7.6, 26.4 }, { 11, 26.6 }, { 13.6, 25 }, { 17, 25.6 }, { 20.4, 23.8 }, { 23.6, 24 }, { 27.4, 22.6 } }
  for n = 1, #cr - 1 do
    for th = 0, (k > 1 and 1 or 0) do
      L.line(g, P:X(cr[n][1]), P:Y(cr[n][2]) + th, P:X(cr[n + 1][1]), P:Y(cr[n + 1][2]) + th, th == 0 and (n % 2 == 0 and 'E' or 'D') or 'B', CONC)
    end
  end
  P:px(28.6, 20.4, 'Z'); P:px(28, 10.4, 'Z')
  L.outline(g, 'A', solid())
  spores(g, P, { { 32.6, 13 }, { 2.6, 13.4 }, { 12.6, 6 }, { 33.4, 20 }, { 14, 12.4 } })
  return g
end

-- ENTIDADE MAIOR: a calçada inteira. Um disco de laje partido em três por uma rachadura em espiral (o desenho do
-- Tribrachidium), três frondes em cata-vento saindo das pontas, as raízes embaixo como pernas e três nós de raiz
-- sem rosto nenhum. Regra quebrada: a rachadura não para na pedra, continua pelo ar.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local P = F.pen(g, k)
  local cx, cy, R = 23.5, 23.6, 9.6
  local function pol(a, r) return { cx + cos(rad(a)) * r, cy + sin(rad(a)) * r } end
  roots(P, { { pol(60, 8), { 31, 37 }, { 34.6, 40 }, { 33.6, 44.4 } }, { pol(80, 8), { 26.6, 38 }, { 28.4, 41.4 }, { 27, 44.6 } },
    { pol(100, 8), { 20.4, 38 }, { 18.6, 41.4 }, { 20, 44.6 } }, { pol(120, 8), { 16, 37 }, { 12.4, 40 }, { 13.4, 44.4 } },
    { pol(90, 8), { 23.5, 39 }, { 23, 43.6 } }, { pol(140, 9), { 11, 34 }, { 7.6, 38 }, { 8.4, 42.6 } }, { pol(40, 9), { 36, 34 }, { 39.4, 38 }, { 38.6, 42.6 } } }, 1.5, 0.55)
  -- três frondes em cata-vento
  local all = {}
  for n = 0, 2 do
    local a = -100 + n * 120
    local st = { pol(a, R - 2), pol(a + 16, R + 2.6), pol(a + 34, R + 5), pol(a + 54, R + 6.4), pol(a + 72, R + 6.4) }
    local lb = frond(P, st, { n = 6, t0 = 0.1, t1 = 0.97, ang = 56, r0 = 1.0, r1 = 0.5,
      w = function(t) return 1.8 + 3.4 * sin(3.14 * (0.12 + 0.8 * t)) end,
      mat = function(i) local m = (i + n) % 4; if m == 1 then return 'y', 'J' elseif m == 3 then return 'g', 'n' end return 'f', 'a' end })
    for _, q in ipairs(lb) do all[#all + 1] = q end
  end
  -- o disco de laje e a rachadura em espiral
  local X0, Y0 = P:X(cx), P:Y(cy)
  local air = {}
  for y = 0, S - 1 do for x = 0, S - 1 do
    local dx, dy = (x - X0) / k, (y - Y0) / k
    local d = sqrt(dx * dx + dy * dy)
    local an = math.deg(math.atan(dy, dx))
    local edge = R + (F.rnd(floor((an + 180) / 12), 1, 4) - 0.5) * 1.6
    -- braço da espiral mais perto: ângulo do braço cresce com o raio
    local best = 99
    for n = 0, 2 do
      local arm = -100 + n * 120 + d * 7
      local diff = ((an - arm + 180) % 360) - 180
      best = math.min(best, abs(diff) * d * 0.01745)
    end
    local wcr = d < 2 and 1.4 or (0.9 - d * 0.03)
    if d <= edge then
      if best < wcr * 0.5 + 0.2 then g[y][x] = (best < 0.35) and 'E' or 'D'
      else
        local sector = floor(((an + 100 - d * 7) % 360) / 120)
        local tile = (floor((dx * cos(sector) + dy * sin(sector)) / 3) + floor((-dx * sin(sector) + dy * cos(sector)) / 3)) % 2
        local lt = (-dx - dy) / (R * 1.414)
        local idx = (lt > 0.25 and 0 or lt > -0.3 and 1 or 2) + tile
        g[y][x] = CONC:sub(math.min(4, idx + 1), math.min(4, idx + 1))
      end
    elseif d <= edge + 8 and best < 0.45 and g[y][x] == '.' and y >= 2 * k and x >= k and x < S - k then
      air[#air + 1] = { x, y, d - edge }
    end
  end end
  -- a espessura da laje, embaixo
  for y = S - 2, 0, -1 do for x = 0, S - 1 do
    if CONC:find(g[y][x], 1, true) or g[y][x] == 'D' or g[y][x] == 'E' then
      for s = 1, floor(1.6 * k) do
        local c = L.get(g, x, y + s)
        if y + s < S and (c == '.' or c == 'h') then g[y + s][x] = (x // k) % 3 == 0 and 'k' or 'J' else break end
      end
    end
  end end
  shadeAll(g, k)
  veins(g, P, k > 1 and all or nil, LEAF .. DRY)
  L.outline(g, 'A', solid())
  -- a rachadura continua pelo ar
  for _, q in ipairs(air) do
    if g[q[2]][q[1]] == '.' or g[q[2]][q[1]] == 'A' then g[q[2]][q[1]] = q[3] < 3 and 's' or (q[3] < 6 and 'S' or 'T') end
  end
  spores(g, P, { { 5, 8 }, { 43, 14 }, { 40, 44 }, { 4.6, 30 } })
  return g
end

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.y = '#5A45A8'                                            -- o fundo do vão (solto)
LOOSE = LOOSE .. 'y'; THIN = THIN .. 'y'

-- ARQUÉTIPO: a fronde de pé, de pedra, grande demais. Está errada de três jeitos: os lobos se espelham (a Charnia
-- nunca se espelha), crescem para a ponta em vez de afinar, e o báculo abriu em dois, um para cada lado. O talo não
-- existe: no lugar dele, o vão, de cima a baixo, e dentro dele a mesma fronde se repete, menor, e outra dentro dela.
-- Embaixo, o disco de fixação é um caco de calçada em cima de raízes finas demais para o peso.
local function arquetipo(k, S, ox, oy)
  local abs, sin, cos, rad, floor, pi = math.abs, math.sin, math.cos, math.rad, math.floor, math.pi
  local d = R.ctx(S or 64 * k, k, ox, oy)
  local p = d:pp()
  local SOL = solid()
  local cx = 31.5
  d:layer(function(t)                                                              -- as raízes: finas demais
    for i = -2, 2 do
      t:wire({ { cx + i * 2.4, 52 }, { cx + i * 4.6, 56 }, { cx + i * 5.2 + (i % 2), 60.4 } }, 'p', 'q', 0.7)
    end
  end, SOL)
  d:layer(function(t)
    for i = 0, 6 do                                                                 -- os lobos, de baixo para cima, crescendo
      local y0, len, w = 46.6 - i * 4.5, 6.5 + i * 1.5, 2.4 + i * 0.16
      local ex, ey = cx - 2 - len * 0.92, y0 - len * 0.42
      t:cap(cx - 2.4, y0, (cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.4, w * 0.8, w, function(x, y, u, v)
        local s = ((u - cx) * 0.92 + (v - y0) * -0.42)
        if floor(s * 1.1) % 3 == 0 then return v > y0 - len * 0.2 and '4' or '3' end   -- os lobinhos
        return R.pick(i == 5 and 'nnNM' or '4321', 0.75 - (v - (y0 - len * 0.45)) / (w * 2.4), R.noise(p, 3 + i)(x, y))
      end)
      t:cap((cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.4, ex, ey, w, 0.5, function(x, y, u, v)
        local s = ((u - cx) * 0.92 + (v - y0) * -0.42)
        if floor(s * 1.1) % 3 == 0 then return i == 6 and ((x + y) % 2 == 0 and 'b' or 'c') or (i == 4 and ((x + y) % 2 == 0 and 'J' or 'j') or '3') end
        return R.pick(i == 5 and 'nnNM' or '4321', 0.8 - (v - ey) / (w * 2.2), R.noise(p, 3 + i)(x, y))
      end)
      t:wire({ { cx - 3.4, y0 - 0.4 }, { (cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.6 }, { ex + 1.6, ey + 0.4 } }, 'D', i % 2 == 0 and 'E' or 'B', 0.5)   -- a nervura acesa
    end
    -- o báculo, um de cada lado
    local pts = {}
    for n = 0, 15 do
      local a = rad(20 - n * 30)
      local r = 6.6 - n * 0.36
      pts[#pts + 1] = { cx - 9.6 + cos(a) * r, 10.6 + sin(a) * r * 0.86 }
    end
    table.insert(pts, 1, { cx - 2.6, 17.6 })
    t:wire(pts, 'p', 'o', 1.5)
    t:wire(pts, 'D', 'E', 0.5)
    -- o disco de fixação: um caco de calçada, com a junta acesa
    t:poly({ { cx - 9, 49.6 }, { cx, 48.6 }, { cx, 53.6 }, { cx - 7.6, 53 } }, R.mat('JjiI', R.noise(p, 5), function(u, v) return 0.9 - (v - 48.6) / 5 end))
    t:wire({ { cx - 6, 49.6 }, { cx - 4.4, 51.4 }, { cx - 5, 53 } }, 'B', 'D', 0.5)
    t:mirror(cx)
  end, SOL)
  local function slit(u, v, s, cy)
    local q = (v - cy) / (18 * s)
    if abs(q) >= 1 then return nil end
    local t = abs(u - cx) / (3 * s * (1 - q * q) ^ 0.6 + 0.01)
    return t <= 1 and t or nil
  end
  d:vao(function(u, v) return slit(u, v, 1, 32.6) end, 'X', 'y', 0.62)
  for lv, f in ipairs({ 0.5, 0.26 }) do                                              -- a mesma fronde, para dentro
    local ch = lv == 1 and 'X' or 's'
    for i = 0, 6 do
      local y0, len = 32.6 + (46.6 - i * 4.5 - 32.6) * f, (6.5 + i * 1.5) * f * 0.42
      for _, sg in ipairs({ -1, 1 }) do
        d:wire({ { cx, y0 }, { cx + sg * len, y0 - len * 0.6 } }, ch, nil, 0.5, '.y')
      end
    end
  end
  for _, y in ipairs({ 20.6, 30.6, 40.6 }) do                                        -- três lobinhos de pedra ainda atravessam o vão
    d:wire({ { cx - 3.6, y }, { cx, y + 1.2 }, { cx + 3.6, y } }, '3', '2', 0.5)
  end
  for n = 0, 21 do
    d:dot(3 + (n * 31) % 59, 3 + (n * 17) % 58, n % 3 == 0 and 'T' or (n % 3 == 1 and 'S' or 's'))
  end
  return d.g
end

local function out(stage, kind, fn)
  if R.skip(stage) then return end
  C.save('frond', stage, kind, F.prune(fn(), LOOSE, stage .. ' ' .. kind), LEG, LIT, LOOSE)
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
out('arquetipo', 'retrato', function() return arquetipo(3, 128, -31, -8) end)      -- busto: os dois báculos, os lobos de cima e o vão
print('ok frond')
