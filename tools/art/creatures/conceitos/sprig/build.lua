-- Conceitos da família Sprig (Etapa 1): Fagulha, Eco, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- Maritaca + árvore de calçada e folha seca + Feérico (pólen verde-ouro e rosa do crepúsculo). Traço: asa de folha.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/sprig/build.lua')
-- Cada etapa é uma função de (k, S): k = 1 no mapa; no retrato o mesmo esqueleto ganha o detalhe de `rich`.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs, max, min = math.floor, math.ceil, math.sqrt, math.abs, math.max, math.min
local sin, cos, rad, pi = math.sin, math.cos, math.rad, math.pi

local LEG = {
  A = '#1A1424',
  ['1'] = '#8C9656', ['2'] = '#667240', ['3'] = '#4A5632', ['4'] = '#353F2A', -- pena verde-oliva da maritaca
  ['5'] = '#6E7B55', ['6'] = '#4F5B42', ['7'] = '#384234',                    -- cabeça, mais escura
  u = '#56608A', U = '#3E4668',                                               -- mancha azul da garganta
  r = '#9A4438', R = '#6E2E2A',                                               -- crisso vermelho
  k = '#D2BE7C', K = '#9A8650', q = '#5E5236',                                -- bico cor de chifre
  w = '#C9C6B4',                                                              -- anel de pele do olho
  a = '#D9B46C', b = '#B5853F', c = '#8C5A2B', d = '#5E3A22',                 -- folha seca
  m = '#8E6A3A', n = '#6E4A28', o = '#4E3220',                                -- folha seca na sombra
  f = '#A9B85E', F = '#7C9044',                                               -- folha nova
  t = '#8A7A66', T = '#63564A', x = '#463C36', z = '#2F2928',                 -- casca
  p = '#B4B0A6', P = '#8A877F', Q = '#5F5D5A',                                -- concreto e pedra portuguesa
  B = '#CFC9BA', D = '#A39E92', E = '#77736C', G = '#504D4C',                 -- cinza e osso (Arquétipo)
  j = '#5B5A2E', e = '#4A2C38', y = '#6E6A3A',                                -- emissivos apagados
  J = '#CFEA6B', Y = '#F6FFC8',                                               -- nervura acesa (pólen)
  H = '#F5A3B5', I = '#FFE3EA',                                               -- rosa do crepúsculo (olho, garganta)
  S = '#CFEA6B', s = '#F6FFC8', N = '#F5A3B5', X = '#9B7BFF',                 -- pólen solto e a borda do Véu
}
LEG.i = LEG.T; LEG.l = LEG.t                                                  -- graveto fino, sem contorno
local LIT = { J = 'j', Y = 'y', H = 'e', I = 'e' }
local LOOSE = 'SsNX'
local SOLID = ''
for ch in pairs(LEG) do
  if not ('AilJYSsNX'):find(ch, 1, true) then SOLID = SOLID .. ch end
end

local function hash(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ (s * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end

-- Elipse girada; sh(x, y, u, v, l) devolve o caractere (l: luz de cima à esquerda, -1..1).
local function ell(g, cx, cy, rx, ry, deg, sh, mask)
  local a = rad(deg)
  local ca, sa = cos(a), sin(a)
  local r = max(rx, ry) + 1
  for y = floor(cy - r), ceil(cy + r) do
    for x = floor(cx - r), ceil(cx + r) do
      local dx, dy = x - cx, y - cy
      local u, v = (dx * ca + dy * sa) / rx, (-dx * sa + dy * ca) / ry
      if u * u + v * v <= 1 then
        local ch = sh(x, y, u, v, -(dy * 0.8 + dx * 0.45) / (r - 1))
        if ch then L.set(g, x, y, ch, mask) end
      end
    end
  end
end
-- Pena: quatro tons, hachura de 1 px no mapa e escamas em V no retrato.
local function feather(pal, p)
  return function(x, y, u, v, l)
    local i = l > 0.4 and 1 or l > -0.15 and 2 or 3
    local alt
    if p <= 1 then alt = floor(y + x * 0.5) % 2
    else alt = floor((y + abs((x % (2 * p)) - p) * 0.7) / p) % 2 end
    return pal[i + alt]
  end
end
local function stripes(a, b, p)
  return function(x, y) return floor((x + y) / p) % 2 == 0 and a or b end
end

-- Tubo que afina: path(t) -> x, y; w(t) -> raio; sh(x, y, t, dn, ds, r, l).
local function tube(g, path, w, sh, t0, t1, mask)
  t0, t1 = t0 or 0, t1 or 1
  local n, acc = 240, 0
  local px, py = path(t0)
  for i = 0, n do
    local t = t0 + (t1 - t0) * i / n
    local x0, y0 = path(t)
    local xa, ya = path(max(0, t - 0.01))
    local xb, yb = path(min(1, t + 0.01))
    local tx, ty = xb - xa, yb - ya
    local tl = sqrt(tx * tx + ty * ty)
    if tl == 0 then tl = 1 end
    tx, ty = tx / tl, ty / tl
    acc = acc + sqrt((x0 - px) ^ 2 + (y0 - py) ^ 2); px, py = x0, y0
    local r = w(t)
    for y = floor(y0 - r), ceil(y0 + r) do
      for x = floor(x0 - r), ceil(x0 + r) do
        local dx, dy = x - x0, y - y0
        if dx * dx + dy * dy <= r * r then
          local rr = max(r, 0.5)
          local ch = sh(x, y, t, (dx * -ty + dy * tx) / rr, acc + dx * tx + dy * ty, r, -(dy * 0.8 + dx * 0.5) / rr)
          if ch then L.set(g, x, y, ch, mask) end
        end
      end
    end
  end
end
local function bark(pal, p)
  return function(x, y, t, dn, ds, r, l)
    local i = l > 0.3 and 1 or l > -0.3 and 2 or 3
    return pal[i + floor((dn * r + ds * 0.3 + 50) / p) % 2]
  end
end
local function seg(x0, y0, x1, y1, bx, by)
  bx, by = bx or 0, by or 0
  return function(t)
    local s = 4 * t * (1 - t)
    return x0 + (x1 - x0) * t + bx * s, y0 + (y1 - y0) * t + by * s
  end
end

-- Asa de folha. o = { x, y (pecíolo), ang, len, wid (meia largura), pal = { claro, meio, escuro, borda },
-- k, side (lado da luz), notch (semente das mordidas), skel (só nervura e borda; skelFrom: a partir de que fração do
-- comprimento), litv (fração da largura com nervura lateral acesa), spots (manchas de folha seca, em px) }.
local function leaf(g, o, mask)
  local a = rad(o.ang)
  local dx, dy = cos(a), sin(a)
  local px, py = -dy, dx
  local k = o.k or 1
  local rw = o.rw or max(0.5, 0.3 * k)
  local vp = o.vp or max(3, 1.5 * k)
  local ew = o.ew or max(1, 0.4 * k)
  local side = o.side or 1
  local r = o.len + 2
  for y = floor(o.y - r), ceil(o.y + r) do
    for x = floor(o.x - r), ceil(o.x + r) do
      local qx, qy = x - o.x, y - o.y
      local t = qx * dx + qy * dy
      local u = t / o.len
      if u >= 0 and u <= 1 then
        local w = qx * px + qy * py
        local aw = abs(w)
        local hw = o.wid * sin(pi * u ^ 0.7) ^ 0.95
        if o.notch and hash(floor(t / vp), o.notch, w > 0 and 1 or 2) % 5 == 0 then hw = hw * 0.72 end
        hw = max(hw, rw)
        if aw <= hw then
          local ch
          local sk = o.skel and u >= (o.skelFrom or 0)
          if aw < rw then ch = (t % vp) < max(1, rw) and 'Y' or 'J'
          elseif (t - aw * 0.8) % vp < (o.vt or (sk and 1.7 or 1)) and aw < hw - (sk and 0 or ew * 0.5) and u > 0.08 then
            ch = (sk or (o.litv and aw < hw * o.litv)) and 'J' or (o.vein or o.pal[3])
          elseif sk then ch = aw > hw - 1.5 and o.pal[4] or nil
          elseif aw > hw - ew then ch = (w * side < 0) and o.pal[1] or o.pal[4]
          else
            local band = floor((t - aw * 0.8) / vp * 2) % 2
            if w * side < 0 then ch = band == 0 and o.pal[1] or o.pal[2] else ch = band == 0 and o.pal[2] or o.pal[3] end
            if o.spots and hash(x // o.spots, y // o.spots, 5) % 9 == 0 then ch = o.pal[4] end
          end
          if ch then L.set(g, x, y, ch, mask) end
        end
      end
    end
  end
end
local NEAR, FAR, FRESH, DARK = { 'a', 'b', 'c', 'd' }, { 'm', 'n', 'o', 'o' }, { 'f', 'F', '3', '4' }, { 'b', 'c', 'd', 'o' }
local BODY, HEAD, BARK, ASH = { '1', '2', '3', '4' }, { '5', '6', '7', '4' }, { 't', 'T', 'x', 'z' }, { 'B', 'D', 'E', 'G' }

local function wire(g, pts, a, b, th, mask)
  local n = 0
  th = max(1, floor((th or 1) + 0.5))
  for i = 1, #pts - 1 do
    local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
    local m = max(abs(x1 - x0), abs(y1 - y0))
    for s = 0, floor(m) do
      local t = m == 0 and 0 or s / m
      n = n + 1
      for d = 0, th - 1 do L.set(g, x0 + (x1 - x0) * t + d, y0 + (y1 - y0) * t, (n // th) % 3 == 0 and b or a, mask) end
    end
  end
end
local function dot(g, x, y, k, ch)
  k = max(1, floor(k + 0.5))
  L.rect(g, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, ch or 'S', '.')
end
local function plus(g, x, y, k)
  k = max(1, floor(k + 0.5))
  dot(g, x, y, k, 's')
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do dot(g, floor(x) + d[1] * k, floor(y) + d[2] * k, k, 'S') end
end

-- Bico de maritaca: base em (bx, by), apontando para ang, tamanho s. lit: a garganta acesa entre as mandíbulas.
local function beak(g, bx, by, ang, s, lit, pal)
  pal = pal or { 'k', 'K', 'q' }
  local a = rad(ang)
  local ca, sa = cos(a), sin(a)
  local function pts(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = { bx + s * (p[1] * ca - p[2] * sa), by + s * (p[1] * sa + p[2] * ca) } end
    return out
  end
  C.poly(g, pts({ { 0.2, 1.2 }, { 1.6, 1.3 }, { 1.9, 1.9 }, { 1.1, 2.7 }, { 0.2, 2.3 } }), pal[2])
  if lit then C.poly(g, pts({ { 0.2, 0.9 }, { 1.7, 1.0 }, { 1.5, 1.5 }, { 0.2, 1.4 } }), 'H') end
  C.poly(g, pts({ { 0, -1.4 }, { 1.6, -1.5 }, { 2.7, -0.6 }, { 3.2, 0.8 }, { 2.9, 2.4 }, { 2.3, 1.3 }, { 1.6, 0.9 }, { 0.2, 0.9 } }), pal[1])
  C.poly(g, pts({ { 2.3, 1.3 }, { 2.9, 2.4 }, { 3.2, 0.8 }, { 2.6, 0.5 } }), pal[2])
  C.poly(g, pts({ { 0, -1.4 }, { 0.5, -1.4 }, { 0.5, 0.9 }, { 0, 0.9 } }), pal[3])
  if s >= 2 then -- bico grande: a linha da boca e a narina
    local q = pts({ { 0.5, 0.9 }, { 1.7, 1.0 }, { 0.9, -0.5 } })
    L.line(g, q[1][1], q[1][2], q[2][1], q[2][2], lit and 'H' or pal[3])
    L.set(g, q[3][1], q[3][2], pal[3])
  end
end
local function eyeAt(g, x, y, k)
  if k <= 1 then
    L.set(g, x - 1, y, 'w'); L.set(g, x, y, 'H')
    return
  end
  L.disc(g, x, y, 0.8 * k, 'w'); L.disc(g, x, y, 0.5 * k, 'H'); L.disc(g, x + 0.1 * k, y - 0.1 * k, 0.2 * k, 'I')
end

-- FAGULHA (Pollen Mote): uma sâmara de tipuana cuja semente é um grão de pólen aceso; a asa é a folha seca.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '..AAAA......',
    '.AabbaA..S..',
    '.AbJbbaA....',
    '.AabJbcA....',
    '..AbcJbcA...',
    '...AdcJYYA..',
    '....AAYIIYA.',
    '..s...AYIYA.',
    '....S..AAA..',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local g = L.grid(96, 96)
  leaf(g, { x = 62, y = 66, ang = -135, len = 62, wid = 17, pal = NEAR, k = 4, vp = 7, notch = 3, litv = 0.45, spots = 3 })
  -- o grão: retículo aceso sobre a casca ocre, com espinhos
  local bx, by, br = 66, 70, 12
  for i = 0, 11 do
    local a = rad(i * 30 + 10)
    L.line(g, bx + cos(a) * br, by + sin(a) * br, bx + cos(a) * (br + 3.5), by + sin(a) * (br + 3.5), 'J')
  end
  for y = by - br, by + br do
    for x = bx - br, bx + br do
      local d = sqrt((x - bx) ^ 2 + (y - by) ^ 2)
      if d <= br then
        local row = (y - by + 40) // 4
        local lx = (x - bx + 40 + (row % 2) * 2) % 4
        local ch = (-(y - by) - (x - bx) * 0.5) / br > 0.25 and 'k' or 'K'
        if d > br - 1.5 then ch = 'q' end
        if lx == 0 or (y - by + 40) % 4 == 0 then ch = d < br * 0.45 and 'I' or d < br * 0.8 and 'Y' or 'J' end
        g[y][x] = ch
      end
    end
  end
  L.outline(g, 'A', SOLID)
  plus(g, 30, 60, 2); plus(g, 78, 30, 2); plus(g, 84, 84, 2)
  dot(g, 20, 44, 2); dot(g, 42, 80, 2, 's'); dot(g, 70, 16, 2); dot(g, 86, 52, 2, 'N'); dot(g, 14, 70, 2, 'N')
  dot(g, 52, 88, 2); dot(g, 88, 66, 2, 's')
  return g
end

-- ECO (Sprigglet): a maritaca em proporção natural, pairando; as duas asas são folhas secas com a nervura acesa.
local function eco(k, S)
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local rich = k > 1
  local p = rich and 2 or 1
  leaf(g, { x = P(16.5), y = P(13.8), ang = -68, len = P(11), wid = P(3.4), pal = FAR, k = k, notch = rich and 7 or nil, spots = rich and 3 or nil })
  -- cauda curta e o crisso vermelho
  tube(g, seg(P(9.5), P(19.5), P(3.8), P(23.3)), function(t) return P(2 - 0.5 * t) end, function(x, y, t, dn, ds, r, l)
    return (floor(ds / p) % 2 == 0) and (l > 0 and '2' or '3') or (l > 0 and '3' or '4')
  end)
  ell(g, P(9.6), P(21.6), P(2.8), P(1.3), -35, stripes('r', 'R', p))
  -- pés recolhidos
  wire(g, { { P(15), P(21) }, { P(16.2), P(22.6) } }, 'T', 'x', k * 0.8)
  wire(g, { { P(17.2), P(20.6) }, { P(18.4), P(22) } }, 'T', 'x', k * 0.8)
  ell(g, P(13.5), P(17.5), P(6.2), P(4.3), -28, feather(BODY, p))
  ell(g, P(17.4), P(14), P(3), P(2.6), -40, feather(BODY, p))
  ell(g, P(19.2), P(11.8), P(3.3), P(3.2), 0, feather(HEAD, p))
  ell(g, P(20), P(14.5), P(2.1), P(1.1), 20, stripes('u', 'U', p))
  beak(g, P(22), P(11.6), 0, k * 0.95)
  eyeAt(g, P(20.6), P(11), k)
  leaf(g, { x = P(14), y = P(15.8), ang = -125, len = P(15), wid = P(4.2), pal = NEAR, k = k, notch = rich and 11 or nil,
    litv = rich and 0.4 or nil, spots = rich and 3 or nil })
  -- coberteiras por cima do pecíolo
  ell(g, P(14.6), P(16.2), P(2.3), P(1.6), -28, feather(BODY, p))
  L.outline(g, 'A', SOLID)
  dot(g, P(3), P(8), k * 0.6); dot(g, P(12), P(2.6), k * 0.6, 's'); dot(g, P(24.5), P(5), k * 0.6)
  dot(g, P(2.5), P(15), k * 0.6, 'N'); dot(g, P(24), P(19), k * 0.6); dot(g, P(6.5), P(16), k * 0.6, 's')
  if rich then plus(g, P(22.5), P(23), 2); plus(g, P(3), P(3.5), 2) end
  return g
end

-- ESPÍRITO (Fairkin): a maritaca tomada pela árvore de calçada. Quatro asas de folha (uma já só nervura), dois olhos
-- do mesmo lado, uma folha de topete, casca subindo pela barriga e as raízes agarradas a um caco de pedra portuguesa.
local function espirito(k, S)
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local rich = k > 1
  local p = rich and 2 or 1
  leaf(g, { x = P(18), y = P(15), ang = -62, len = P(11.5), wid = P(3.4), pal = FAR, k = k, notch = rich and 5 or nil, spots = rich and 3 or nil })
  -- rabo de graveto
  wire(g, { { P(12.5), P(24) }, { P(8.5), P(26.4) }, { P(5.5), P(27.2) } }, 'i', 'l', k * 0.7)
  leaf(g, { x = P(8.5), y = P(26.4), ang = 150, len = P(5), wid = P(1.5), pal = NEAR, k = k, vp = 99 })
  -- caco de calçada: pedra portuguesa em cima, concreto de frente
  C.poly(g, { { P(8), P(29) }, { P(23), P(28) }, { P(25), P(30.6) }, { P(10), P(31.6) } }, 'p')
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      if g[y][x] == 'p' then
        local h = hash(floor((x + y * 0.5) / max(2, k * 1.2)), floor(y / max(1, k * 0.8)), 9) % 5
        g[y][x] = h == 0 and 'z' or h < 3 and 'p' or 'P'
      end
    end
  end
  C.poly(g, { { P(10), P(31.7) }, { P(25), P(30.7) }, { P(25), P(32.6) }, { P(10.4), P(33.4) } }, 'Q')
  for x = floor(P(10)), floor(P(25)) do
    if hash(x // max(1, floor(k)), 3, 2) % 3 == 0 then L.set(g, x, P(32.2) - (x - P(10)) / 15, 'P', 'Q') end
  end
  -- raízes
  for _, q in ipairs({ { 15.4, 25.5, 12.5, 29.6, -1 }, { 17.6, 26, 19.5, 29.2, 0.6 }, { 16.4, 26, 16, 29.6, 0 } }) do
    tube(g, seg(P(q[1]), P(q[2]), P(q[3]), P(q[4]), P(q[5]), 0), function(t) return P(1 - 0.4 * t) end, bark(BARK, p))
  end
  wire(g, { { P(12.5), P(29.6) }, { P(11.2), P(31) }, { P(11.6), P(33) } }, 'i', 'l', k * 0.7)
  wire(g, { { P(19.5), P(29.2) }, { P(21.5), P(30) }, { P(22), P(32.6) } }, 'i', 'l', k * 0.7)
  -- corpo: pena em cima, casca tomando a barriga
  local fb = feather(BODY, p)
  ell(g, P(16.5), P(20.5), P(7), P(4.6), -62, function(x, y, u, v, l)
    local edge = u + v * 0.6 + ((hash(x // p, y // p, 4) % 5) - 2) * 0.06
    if edge < -0.15 then
      local i = l > 0.3 and 1 or l > -0.3 and 2 or 3
      return BARK[i + floor((x + y * 0.3) / p) % 2]
    end
    return fb(x, y, u, v, l)
  end)
  ell(g, P(21.5), P(11.5), P(3.6), P(3.5), 0, feather(HEAD, p))
  ell(g, P(21.6), P(14.6), P(2.3), P(1.2), 25, stripes('u', 'U', p))
  beak(g, P(24.4), P(11.2), 8, k * 1.1, true)
  eyeAt(g, P(23), P(10.2), k); eyeAt(g, P(21.4), P(12.6), k)
  leaf(g, { x = P(20.6), y = P(8.8), ang = -100, len = P(5), wid = P(1.5), pal = FRESH, k = k, vp = 99 })
  -- as asas de perto: a que já é só nervura, a seca escura e a seca maior
  leaf(g, { x = P(14.5), y = P(18), ang = 150, len = P(12.5), wid = P(3.4), pal = FAR, k = k, skel = true, vp = max(3, k * 1.5) })
  leaf(g, { x = P(14.5), y = P(17.2), ang = -168, len = P(13), wid = P(3.6), pal = DARK, k = k, notch = rich and 2 or nil,
    litv = rich and 0.35 or nil, spots = rich and 3 or nil })
  leaf(g, { x = P(14.8), y = P(16.6), ang = -122, len = P(15), wid = P(4.2), pal = NEAR, k = k, notch = rich and 13 or nil,
    litv = rich and 0.4 or nil, spots = rich and 3 or nil })
  ell(g, P(15.4), P(17.2), P(2.4), P(1.7), -50, feather(BODY, p))
  L.outline(g, 'A', SOLID)
  dot(g, P(3), P(6), k * 0.6); dot(g, P(13), P(1.5), k * 0.6, 's'); dot(g, P(29), P(5), k * 0.6); dot(g, P(2), P(13), k * 0.6, 'N')
  dot(g, P(4), P(31), k * 0.6, 's'); dot(g, P(29), P(18), k * 0.6); dot(g, P(27.5), P(26), k * 0.6, 'N'); dot(g, P(31), P(11), k * 0.6, 's')
  if rich then plus(g, P(30), P(22), 2); plus(g, P(6), P(3), 2) end
  return g
end

-- RODADA 2
local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
LEG.Z, LEG.v, LEG.V = '#9B7BFF', '#51465A', '#5A45A8'      -- costura do Véu e o par apagado; V é o fundo do vão (solto)
LIT.Z = 'v'; LOOSE = LOOSE .. 'V'; SOLID = SOLID .. 'Zv'

-- ENTIDADE MAIOR: a árvore da calçada de cabeça para baixo. A copa é um bando fundido (três cabeças de maritaca, uma
-- delas virada, sem olhos) e anda sobre as pontas das asas de folha; o tronco sobe e as raízes, que são pés de ave,
-- seguram no alto o pedaço de calçada de onde ela saiu. As folhas que caem dela caem para cima.
-- RODADA 3. A luz é a do tipo Feérico na paleta: W (m), L (l), O (d); M e C são os soltos. fae() troca o pólen verde
-- e o rosa antigo pelos tons da paleta, depois do contorno.
LEG.W, LEG.L, LEG.O = '#FFA8E0', '#FFD6F1', '#C0669E'
LEG.h, LEG.g = '#6A4A58', '#3E2632'                          -- pares apagados de L e de O (o de W é o e)
LEG.M, LEG.C = '#FFA8E0', '#FFD6F1'
LIT.W = 'e'; LIT.L = 'h'; LIT.O = 'g'; LOOSE = LOOSE .. 'MC'
local function fae(g)
  local M = { Y = 'L', H = 'W', I = 'L', S = 'M', s = 'C', N = 'M' }
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'J' then g[y][x] = (x + y) % 3 == 0 and 'O' or 'W' elseif M[c] then g[y][x] = M[c] end
  end end
end

-- ENTIDADE MAIOR: o bando fundido. Um corpo só de pena verde-oliva, do tamanho de cinco maritacas, com cinco cabeças
-- viradas cada uma para um lado, todas de bico aberto, gritando, a garganta acesa. Sete asas de folha seca saem dele
-- em todas as direções, cada uma num ponto diferente da batida; dois rabos, pés que seguram uns nos outros.
local function entidade(k, S)
  local d = R.ctx(S, k)
  local g = d.g
  local function P(v) return v * k + (k - 1) / 2 end
  local rich = k > 1
  local p = rich and 2 or 1
  local function wing(x, y, ang, len, pal, n, wid)
    leaf(g, { x = P(x), y = P(y), ang = ang, len = k * len, wid = k * (wid or 3.6), pal = pal, k = k, notch = rich and n or nil,
      spots = rich and 3 or nil, litv = 0.64 })
  end
  -- bico aberto, gritando: o de baixo caído, a garganta acesa entre os dois. f = -1 espelha (cabeça virada para trás)
  local function scream(bx, by, ang, s, f)
    local a = rad(ang)
    local ca, sa = cos(a), sin(a)
    local function pts(list)
      local out = {}
      for i, q in ipairs(list) do out[i] = { bx + s * (q[1] * ca - q[2] * f * sa), by + s * (q[1] * sa + q[2] * f * ca) } end
      return out
    end
    C.poly(g, pts({ { 0, 0.6 }, { 2.1, 0.9 }, { 1.7, 2.6 }, { 0, 2.4 } }), 'H')
    C.poly(g, pts({ { 0, 2.1 }, { 1.5, 2.4 }, { 1.8, 3.1 }, { 0.9, 3.8 }, { 0, 3.3 } }), 'K')
    C.poly(g, pts({ { 0, -1.4 }, { 1.6, -1.5 }, { 2.7, -0.6 }, { 3.2, 0.8 }, { 2.9, 2.4 }, { 2.3, 1.3 }, { 1.6, 0.9 }, { 0, 0.9 } }), 'k')
    C.poly(g, pts({ { 2.3, 1.3 }, { 2.9, 2.4 }, { 3.2, 0.8 }, { 2.6, 0.5 } }), 'K')
    C.poly(g, pts({ { 0, -1.4 }, { 0.5, -1.4 }, { 0.5, 0.9 }, { 0, 0.9 } }), 'q')
  end
  local function head(x, y, r, ang, s, nx, ny)
    local a = rad(ang)
    local f = cos(a) < 0 and -1 or 1
    if nx then                                                                      -- o pescoço, até o corpo
      tube(g, seg(P(nx), P(ny), P(x), P(y)), function(t) return k * r * (1 - 0.25 * sin(pi * t)) * 0.8 end, function(x2, y2, t, dn, ds, rr, l)
        return feather(BODY, p)(x2, y2, 0, 0, l)
      end)
    end
    ell(g, P(x), P(y), k * r, k * r * 0.94, 0, feather(HEAD, p))
    ell(g, P(x - sin(a) * f * r * 0.75 + cos(a) * r * 0.2), P(y + cos(a) * f * r * 0.75 + sin(a) * r * 0.2), k * r * 0.62, k * r * 0.32, ang, stripes('u', 'U', p))
    scream(P(x + cos(a) * r * 0.62), P(y + sin(a) * r * 0.62), ang, k * s, f)
    eyeAt(g, P(x + cos(a) * r * 0.25 + sin(a) * f * r * 0.35), P(y + sin(a) * r * 0.25 - cos(a) * f * r * 0.35), max(k, 1.01) * 1.6)
  end
  -- as asas de trás, em leque
  wing(22, 25, -78, 21, FAR, 1); wing(20.6, 25, -104, 22.6, DARK, 2); wing(19, 26, -156, 17.6, FAR, 3)
  -- dois rabos, com o crisso vermelho
  for _, q in ipairs({ { 13, 31, 5, 38 }, { 17, 34, 12, 42.6 } }) do
    tube(g, seg(P(q[1]), P(q[2]), P(q[3]), P(q[4])), function(t) return k * (2 - 0.5 * t) end, function(x, y, t, dn, ds, r, l)
      return (floor(ds / p) % 2 == 0) and (l > 0 and '2' or '3') or (l > 0 and '3' or '4')
    end)
    ell(g, P(q[1] - 1.6), P(q[2] + 2.6), k * 2.4, k * 1.2, -40, stripes('r', 'R', p))
  end
  -- pés que seguram uns nos outros
  for _, q in ipairs({ { 19, 34, 20.6, 39 }, { 23, 35, 20.6, 39 }, { 20.6, 39, 19, 42 }, { 20.6, 39, 22.6, 41.6 } }) do
    wire(g, { { P(q[1]), P(q[2]) }, { P(q[3]), P(q[4]) } }, 'T', 'x', k * 0.8)
  end
  -- o corpo: os peitos num só
  ell(g, P(21), P(28), k * 10, k * 7.4, -10, feather(BODY, p))
  -- as cabeças, gritando, cada uma para um lado
  head(33.6, 38, 3.8, 42, 1.3, 26, 31)
  head(36.6, 13.6, 4.2, -24, 1.45, 27, 23)
  head(38, 26.6, 4.5, 6, 1.6, 27, 28)
  d:suture({ { 22.6, 22 }, { 25.6, 27.6 }, { 23.6, 33 } }, 'Z', 1.4, nil, '1234')
  -- a asa de cá
  wing(19.6, 26, -130, 21.6, NEAR, 9, 4.4)
  ell(g, P(20), P(27.6), k * 3.2, k * 2.2, -30, feather(BODY, p))
  head(7.6, 28.6, 3.4, 186, 1.2, 14, 28)                                            -- e uma virada para trás
  L.outline(g, 'A', SOLID .. 'JY')
  fae(g)
  for n, q in ipairs({ { 4, 8 }, { 44, 9 }, { 42.6, 33 }, { 3, 21 }, { 36, 4 }, { 10, 4.6 }, { 44.6, 41 }, { 15, 44 }, { 38.6, 44.6 }, { 2.6, 43 } }) do
    dot(g, P(q[1]), P(q[2]), k * 0.6, n % 3 == 0 and 'C' or 'M')
  end
  return g
end
local function entidadeR2(k, S)
  local d = R.ctx(S, k)
  local g = d.g
  local function P(v) return v * k + (k - 1) / 2 end
  local rich = k > 1
  local p = rich and 2 or 1
  -- copa: as asas de trás
  for n, q in ipairs({ { 196, 11, FAR }, { 160, 15, DARK }, { 125, 15.5, FAR }, { 55, 15.5, FAR }, { 20, 15, DARK }, { -16, 11, FAR } }) do
    leaf(g, { x = P(24), y = P(29), ang = q[1], len = k * q[2], wid = k * 3.5, pal = q[3], k = k, notch = rich and n or nil, spots = rich and 3 or nil, litv = 0.45 })
  end
  -- tronco
  tube(g, seg(P(24), P(28), P(23), P(10), k * 1.6, 0), function(t) return k * (3.2 - 0.9 * t) end, bark(BARK, max(1, k * 0.75)))
  d:suture({ { 20.2, 18.6 }, { 28.6, 20 } }, 'Z', 1.5, nil, 'tTxz')
  d:suture({ { 21.6, 14 }, { 27.6, 13.4 } }, 'Z', 0.9, nil, 'tTxz')
  -- o bando fundido
  ell(g, P(24), P(28.5), k * 9, k * 4.6, 0, feather(BODY, p))
  leaf(g, { x = P(24), y = P(30), ang = 90, len = k * 14.5, wid = k * 3.8, pal = NEAR, k = k, notch = rich and 9 or nil, litv = 0.5, spots = rich and 3 or nil })
  leaf(g, { x = P(22), y = P(30), ang = 142, len = k * 16, wid = k * 3.8, pal = NEAR, k = k, notch = rich and 4 or nil, litv = 0.5, spots = rich and 3 or nil })
  leaf(g, { x = P(26), y = P(30), ang = 38, len = k * 16, wid = k * 3.8, pal = FRESH, k = k, litv = 0.5 })
  -- as três cabeças
  ell(g, P(14.4), P(26.6), k * 3.6, k * 3.4, 0, feather(HEAD, p))
  beak(g, P(12), P(26.2), 180, k * 1.5, true)
  eyeAt(g, P(13.6), P(25.4), max(k, 1.01) * 1.2)
  ell(g, P(33.6), P(26.6), k * 3.6, k * 3.4, 0, feather(HEAD, p))
  beak(g, P(36), P(26.2), 0, k * 1.5, true)
  eyeAt(g, P(34.6), P(25), max(k, 1.01) * 1.2); eyeAt(g, P(32.6), P(27.6), max(k, 1.01) * 1.2); eyeAt(g, P(35), P(28.6), max(k, 1.01))
  ell(g, P(24), P(31), k * 3.4, k * 3.2, 0, feather(HEAD, p))
  beak(g, P(24), P(33.4), 90, k * 1.9, true)
  ell(g, P(24), P(28.4), k * 2.2, k * 1.1, 0, stripes('u', 'U', p))
  -- a calçada, no alto: pedra portuguesa em cima, concreto de frente
  C.poly(g, { { P(8.5), P(6.4) }, { P(37), P(3.6) }, { P(39.5), P(6.2) }, { P(11), P(9) } }, 'p')
  for y = 0, S - 1 do for x = 0, S - 1 do
    if g[y][x] == 'p' then
      local h = hash(floor((x + y * 0.5) / max(2, k * 1.2)), floor(y / max(1, k * 0.8)), 9) % 5
      g[y][x] = h == 0 and 'z' or h < 3 and 'p' or 'P'
    end
  end end
  C.poly(g, { { P(11), P(9.2) }, { P(39.5), P(6.4) }, { P(39.5), P(8.6) }, { P(11.4), P(11.4) } }, 'Q')
  for x = floor(P(11)), floor(P(39.5)) do
    if hash(x // max(1, floor(k)), 3, 2) % 3 == 0 then L.set(g, x, P(10.2) - (x - P(11)) * 0.098, 'P', 'Q') end
  end
  -- raízes que são pés de ave, agarradas por baixo; e as que atravessam e sobem
  for _, x0 in ipairs({ 18.5, 23.5, 28.5 }) do
    for _, dx in ipairs({ -2.4, 0, 2.4 }) do
      tube(g, seg(P(x0 + dx * 0.2), P(13.6), P(x0 + dx), P(10.4) - (x0 + dx - 11) * 0.098 * k), function() return max(0.6, k * 0.75) end,
        function(x, y, t, dn, ds) return t > 0.75 and 'q' or (floor(ds / max(1, k * 0.8)) % 2 == 0 and 't' or 'T') end)
    end
  end
  for n, q in ipairs({ { 14, 2.6 }, { 21, 2 }, { 29, 2.2 }, { 35, 1.8 } }) do
    local y0 = 6 - (q[1] - 8.5) * 0.098
    wire(g, { { P(q[1]), P(y0) }, { P(q[1] + (n % 2 == 0 and 0.9 or -0.9)), P((y0 + q[2]) / 2) }, { P(q[1]), P(q[2]) } }, 'i', 'l', k * 0.7)
  end
  L.outline(g, 'A', SOLID)
  -- as folhas caem para cima
  for n, q in ipairs({ { 5, 22 }, { 3.6, 14 }, { 6.6, 9 }, { 42, 20 }, { 44, 12 }, { 41.6, 5 }, { 10, 17 }, { 38, 15 }, { 17, 20 }, { 31.6, 18 } }) do
    dot(g, P(q[1]), P(q[2]), k * 0.6, n % 3 == 0 and 'N' or n % 3 == 1 and 'S' or 's')
    if n % 2 == 0 then dot(g, P(q[1]) + 1 * k, P(q[2] + 1), k * 0.6, 'S') end
  end
  if rich then plus(g, P(6), P(30), 2); plus(g, P(43), P(28), 2) end
  return g
end

-- ARQUÉTIPO: a maritaca de frente, de asas erguidas, igual demais dos dois lados. São dois perfis da mesma cabeça,
-- de costas um para o outro, e entre eles não há cabeça: o vão, em forma de folha, desce do pescoço ao peito, e dentro
-- dele os bicos se repetem, cada par menor. As asas são folha morta que para a ponta é só nervura; o galho em que ela
-- pousa nasce da própria cauda.
-- RODADA 3. ARQUÉTIPO: o bando inteiro como uma criatura só, sem corpo. Seis maritacas cinza, sem olho, de tamanhos
-- diferentes, cada uma gritando para um lado, e os pescoços delas saem todos de um mesmo anel de pena. Dentro do anel,
-- onde ficaria o coração, não há peito: o vão. As asas são folhas mortas que da metade para a ponta são só nervura.
local function arquetipo(k, S, ox, oy)
  local d = R.ctx(S, k, ox, oy)
  local g = d.g
  local function PX(v) return d:X(v) end
  local function PY(v) return d:Y(v) end
  local p = k > 1 and 2 or 1
  local CX, CY = 34, 32.6
  local ASHL, ASHD = { 'D', 'E', 'G', 'E' }, { 'D', 'E', 'G', 'G' }
  local ashf, ashd = feather(ASH, p), feather(ASHD, p)
  local function pol(a, r) return CX + cos(rad(a)) * r, CY + sin(rad(a)) * r end
  local function scream(bx, by, ang, s, f)
    local a = rad(ang)
    local ca, sa = cos(a), sin(a)
    local function pts(list)
      local out = {}
      for i, q in ipairs(list) do out[i] = { bx + s * (q[1] * ca - q[2] * f * sa), by + s * (q[1] * sa + q[2] * f * ca) } end
      return out
    end
    C.poly(g, pts({ { 0, 0.6 }, { 2.1, 0.9 }, { 1.7, 2.6 }, { 0, 2.4 } }), 'H')
    C.poly(g, pts({ { 0, 2.1 }, { 1.5, 2.4 }, { 1.8, 3.1 }, { 0.9, 3.8 }, { 0, 3.3 } }), 'K')
    C.poly(g, pts({ { 0, -1.4 }, { 1.6, -1.5 }, { 2.7, -0.6 }, { 3.2, 0.8 }, { 2.9, 2.4 }, { 2.3, 1.3 }, { 1.6, 0.9 }, { 0, 0.9 } }), 'k')
    C.poly(g, pts({ { 2.3, 1.3 }, { 2.9, 2.4 }, { 3.2, 0.8 }, { 2.6, 0.5 } }), 'K')
    C.poly(g, pts({ { 0, -1.4 }, { 0.5, -1.4 }, { 0.5, 0.9 }, { 0, 0.9 } }), 'q')
  end
  -- uma do bando: ang e dist dizem onde está a cabeça; face, para onde ela grita
  local function one(ang, dist, r, s, face)
    local hx, hy = pol(ang, dist)
    local nx, ny = pol(ang, 10)
    local a = rad(face)
    local f = cos(a) < 0 and -1 or 1
    tube(g, seg(PX(nx), PY(ny), PX(hx), PY(hy)), function(t) return k * r * (0.95 - 0.3 * sin(pi * t)) end, function(x2, y2, t, dn, ds, rr, l)
      return ashf(x2, y2, 0, 0, l)
    end)
    ell(g, PX(hx), PY(hy), k * r, k * r * 0.94, 0, ashd)
    ell(g, PX(hx - cos(a) * r * 0.3 + sin(a) * f * r * 0.5), PY(hy - sin(a) * r * 0.3 - cos(a) * f * r * 0.5), k * r * 0.62, k * r * 0.36, face, stripes('6', '7', p))
    ell(g, PX(hx - sin(a) * f * r * 0.75 + cos(a) * r * 0.2), PY(hy + cos(a) * f * r * 0.75 + sin(a) * r * 0.2), k * r * 0.6, k * r * 0.3, face, stripes('u', 'U', p))
    scream(PX(hx + cos(a) * r * 0.62), PY(hy + sin(a) * r * 0.62), face, k * s, f)
  end
  -- as asas: folha morta, da metade para a ponta só nervura
  for n, q in ipairs({ { -160, 23 }, { -134, 21 }, { 174, 24 }, { 150, 21 }, { 126, 16 }, { -112, 15 } }) do
    local x, y = pol(q[1], 8)
    leaf(g, { x = PX(x), y = PY(y), ang = q[1] + (n % 2 == 0 and 5 or -4), len = k * q[2], wid = k * 5.2, pal = n % 2 == 0 and { 'B', 'D', 'E', 'G' } or ASHL, k = k,
      skel = true, skelFrom = 0.66, litv = 0.3, vp = max(3, k * 1.5) })
  end
  -- dois rabos, o crisso ainda vermelho
  for _, a in ipairs({ 163, 200 }) do
    local x0, y0 = pol(a, 10)
    local x1, y1 = pol(a + 6, 21)
    tube(g, seg(PX(x0), PY(y0), PX(x1), PY(y1)), function(t) return k * (2.2 - 0.7 * t) end, function(x, y, t, dn, ds, r, l)
      return (floor(ds / p) % 2 == 0) and (l > 0 and 'D' or 'E') or (l > 0 and 'E' or 'G')
    end)
    local xr, yr = pol(a - 8, 13.6)
    ell(g, PX(xr), PY(yr), k * 2.2, k * 1.1, a, stripes('r', 'R', p))
  end
  -- o anel de pena de onde saem os pescoços
  ell(g, PX(CX), PY(CY), k * 12.6, k * 10.6, 0, ashf)
  one(-150, 15, 3, 1.1, 205)                                                        -- uma olha para trás
  one(-98, 15, 3.4, 1.25, -78)
  one(98, 14.6, 3.3, 1.2, 84)
  one(-46, 17, 4.1, 1.5, -28)
  one(44, 16.6, 3.9, 1.45, 32)
  one(-3, 17.6, 5.4, 1.9, 2)
  L.outline(g, 'A', SOLID .. 'JY')
  fae(g)
  -- o vão, onde ficaria o coração; dentro dele as cabeças se repetem, viradas para dentro
  local function hole(u, v)
    local a = math.atan(v - CY, u - CX)
    local r = sqrt((u - CX) ^ 2 + ((v - CY) * 1.1) ^ 2) / (7.4 + 1.2 * sin(a * 3 + 0.6) + 0.7 * sin(a * 5))
    return r <= 1 and r or nil
  end
  d:vao(hole, 'X', 'V', 0.8)
  for _, q in ipairs({ { -78, 4.6, 1.6 }, { 104, 4.4, 1.5 }, { -2, 4.8, 2 }, { -168, 4.6, 1.3 } }) do
    local hx, hy = pol(q[1], q[2])
    local t = L.grid(S, S)
    L.disc(t, PX(hx), PY(hy), k * q[3], 'X')
    L.disc(t, PX(hx), PY(hy), k * q[3] - max(1, k * 0.5), '.')
    local bx, by = pol(q[1], q[2] - q[3] - 0.6)
    L.disc(t, PX(bx), PY(by), max(0.6, k * 0.6), 'X')
    for y = 0, S - 1 do for x = 0, S - 1 do
      if t[y][x] == 'X' and (g[y][x] == '.' or g[y][x] == 'V') then g[y][x] = 'X' end
    end end
  end
  for n = 0, 17 do
    local a, r = n * 2.4, 26 + (n * 7) % 5
    d:dot(31 + cos(a) * r * 1.08, 31.5 + sin(a) * r, n % 3 == 0 and 'C' or 'M')
  end
  return g
end
-- tentativa descartada na rodada 3 (o bando em mosaico dentro da silhueta de uma maritaca grande: virou pedra)
local function arquetipoMosaico(k, S, ox, oy)
  local d = R.ctx(S, k, ox, oy)
  local g = d.g
  local WN = { { 23, 33 }, { 11, 22 }, { 4, 5 }, { 16, 3.6 }, { 27, 13 }, { 33, 28 } }
  local WF = { { 30, 27 }, { 27, 12 }, { 30, 6 }, { 35, 14 }, { 35, 26 } }
  local TL = { { 18, 39 }, { 2.6, 53 }, { 7, 58 }, { 23, 46 } }
  local function inpoly(u, v, P)
    local c, j = false, #P
    for i = 1, #P do
      local a, b = P[i], P[j]
      if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end
      j = i
    end
    return c
  end
  local cb, sb = cos(rad(-20)), sin(rad(-20))
  local function big(u, v)                                                          -- a maritaca grande: onde há bando
    if (u - 47) ^ 2 + (v - 22.6) ^ 2 <= 56 then return 'h' end
    local a, b = (u - 31) * cb + (v - 36) * sb, -(u - 31) * sb + (v - 36) * cb
    if (a / 16) ^ 2 + (b / 9.4) ^ 2 <= 1 then return 'b' end
    if inpoly(u, v, WN) or inpoly(u, v, WF) then return 'w' end
    if inpoly(u, v, TL) then return 't' end
  end
  -- uma maritaca do bando, virada para a direita: asa erguida, corpo, bico (W, aceso), rabo
  local BIRD = {
    '...EE......',
    '...EDE.....',
    '...EDDE....',
    '....EDDEDD.',
    '..EEEDDBBBW',
    '.EDDBBBBBD.',
    'EDDDBBBDD..',
    'EE.EDDD....',
  }
  local TONE = { {}, { B = 'D', D = 'E', E = 'G' }, { B = '1', D = '2', E = 'r' }, { B = 'D', D = 'E', E = 'G' } }
  local kk = max(1, floor(k + 0.5))
  for y = 0, S - 1 do for x = 0, S - 1 do                                           -- o escuro entre elas
    local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
    if big(u, v) and big(u - 1.6, v) and big(u + 1.6, v) and big(u, v - 1.6) and big(u, v + 1.6) then g[y][x] = 'G' end
  end end
  for j = -1, 11 do for i = 8, -1, -1 do
    local h = hash(i, j, 7)
    local u0 = i * 8.4 + (j % 2) * 4.2 + (h % 3) - 1
    local v0 = j * 5.6 + ((h >> 4) % 3) - 1
    local part = big(u0 + 5.6, v0 + 5)
    if part then
      local lightv = 0.5 - (v0 - 30) * 0.02 - (u0 - 30) * 0.008 + ((h >> 8) % 5 - 2) * 0.12
      local tone = TONE[(h >> 12) % 7 == 0 and 3 or (lightv < 0.42 and 2 or 1)]
      for gy, row in ipairs(BIRD) do
        for gx = 1, #row do
          local c = row:sub(gx, gx)
          if c ~= '.' then
            c = tone[c] or c
            local x0, y0 = floor(d:X(u0 + gx - 1) - (k - 1) / 2), floor(d:Y(v0 + gy - 1) - (k - 1) / 2)
            for yy = y0, y0 + kk - 1 do for xx = x0, x0 + kk - 1 do
              local cc = c
              if k > 1 and c ~= 'W' and (xx + yy) % 4 == 0 then cc = ({ B = 'D', D = 'E', E = 'G', ['1'] = '2', ['2'] = '3', ['3'] = '4' })[c] or c end
              L.set(g, xx, yy, cc)
            end end
          end
        end
      end
    end
  end end
  -- o bico: a única peça inteira
  d:poly({ { 52.6, 16.6 }, { 58.6, 18.6 }, { 61.4, 24 }, { 60, 32 }, { 57, 27.6 }, { 53, 27 } }, function(x, y, u, v)
    return R.pick('qKk', 0.75 - (v - 18) / 13 - (u - 56) / 20, R.hor(d:pp())(x, y))
  end)
  d:poly({ { 52.6, 27.6 }, { 56.6, 28.6 }, { 55.6, 32.6 }, { 52.6, 31.4 } }, R.mat('qK', R.hor(d:pp()), 0.3))
  -- a asa ainda é folha: a nervura acesa passa por cima do bando
  for _, q in ipairs({ { { 25, 31 }, { 17, 17 }, { 9, 6 } }, { { 17, 17 }, { 24, 13.6 } }, { { 21, 24 }, { 29, 23 } }, { { 13, 11 }, { 17.6, 6.6 } },
    { { 14.6, 13.6 }, { 8.6, 12 } }, { { 19.6, 21 }, { 12.6, 20.4 } } }) do
    d:wire(q, 'W', 'L', 0.5, 'BDEG123')
  end
  -- só a peça maior fica
  do
    local seen, best, comps = {}, nil, {}
    for y = 0, S - 1 do for x = 0, S - 1 do
      if g[y][x] ~= '.' and not seen[y * S + x] then
        local list, stack = {}, { { x, y } }
        seen[y * S + x] = true
        while #stack > 0 do
          local q = table.remove(stack)
          list[#list + 1] = q
          for dy = -1, 1 do for dx = -1, 1 do
            local nx, ny = q[1] + dx, q[2] + dy
            if nx >= 0 and ny >= 0 and nx < S and ny < S and g[ny][nx] ~= '.' and not seen[ny * S + nx] then
              seen[ny * S + nx] = true; stack[#stack + 1] = { nx, ny }
            end
          end end
        end
        comps[#comps + 1] = list
        if not best or #list > #best then best = list end
      end
    end end
    for _, list in ipairs(comps) do if list ~= best then for _, q in ipairs(list) do g[q[2]][q[1]] = '.' end end end
  end
  L.outline(g, 'A', SOLID .. 'WLO')
  -- o vão, onde ficaria o coração; as que estão na beira dele acendem
  local VX, VY = 33, 34.6
  local function hole(u, v, s)
    local a = math.atan(v - VY, u - VX)
    local r = sqrt((u - VX) ^ 2 + ((v - VY) * 1.15) ^ 2) / ((6.6 + 1.3 * sin(a * 3 + 0.6) + 0.8 * sin(a * 5)) * (s or 1))
    return r <= 1 and r or nil
  end
  for y = 0, S - 1 do for x = 0, S - 1 do
    local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
    if not hole(u, v) and hole(u, v, 1.22) and g[y][x] ~= '.' and g[y][x] ~= 'A' then g[y][x] = (x // kk + y // kk) % 2 == 0 and 'W' or 'O' end
  end end
  d:vao(function(u, v) return hole(u, v) end, 'X', 'V', 0.74)
  for y = 0, S - 1 do for x = 0, S - 1 do                                           -- o mesmo bando, lá dentro
    local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
    if (g[y][x] == '.' or g[y][x] == 'V') and big((u - VX) / 0.15 + 32, (v - VY) / 0.15 + 30) and hole(u, v, 0.8) then g[y][x] = 'X' end
  end end
  for n = 0, 17 do
    local a, r = n * 2.4, 25 + (n * 7) % 6
    d:dot(31 + cos(a) * r * 1.1, 31 + sin(a) * r, n % 3 == 0 and 'C' or 'M')
  end
  return g
end
local function arquetipoR2(k, S, ox, oy)
  local d = R.ctx(S, k, ox, oy)
  local g = d.g
  local function PX(v) return d:X(v) end
  local function PY(v) return d:Y(v) end
  local p = max(1, k * 0.75)
  local cx = 31.5
  local ASHL = { 'D', 'E', 'G', 'E' }
  local function ashf(x, y, u, v, l)
    return ASH[(l > 0.3 and 1 or l > -0.2 and 2 or 3) + floor((y + abs((x % (2 * p)) - p) * 0.7) / p) % 2]
  end
  -- cauda e o galho que nasce dela
  for _, a in ipairs({ 97, 110 }) do
    leaf(g, { x = PX(cx - 1), y = PY(45), ang = a, len = k * 14, wid = k * 2.6, pal = ASHL, k = k, skel = true, skelFrom = 0.55, litv = 0.6, vp = max(3, k * 1.5) })
  end
  tube(g, function(t)
    local a = rad(90 + t * 118)
    return PX(cx + cos(a) * 19 * (0.25 + 0.75 * t) + 1.5 * (1 - t)), PY(45.5 + sin(a) * 13.5)
  end, function(t) return k * (1.1 + 0.9 * sin(pi * min(1, t * 1.3))) end, function(x, y, t, dn, ds, r, l)
    return (t < 0.5 and BARK or ASH)[(l > 0.3 and 1 or l > -0.3 and 2 or 3) + floor((dn * r + ds * 0.3 + 50) / p) % 2]
  end)
  -- asa: quatro folhas mortas em leque
  for n, q in ipairs({ { -178, 18 }, { -158, 23 }, { -138, 24 }, { -119, 19 } }) do
    leaf(g, { x = PX(25), y = PY(36), ang = q[1], len = k * q[2], wid = k * 4.6, pal = n % 2 == 0 and ASHL or { 'E', 'G', 'G', 'E' }, k = k,
      skel = true, skelFrom = 0.55, litv = 0.6, vp = max(3, k * 1.5) })
  end
  -- tronco de pena cinza (o verde só sobra embaixo), pés de casca
  ell(g, PX(cx - 3), PY(39), k * 6.4, k * 9, 8, function(x, y, u, v, l)
    if (y - d.oy) / k > 43 + ((hash(x // max(1, floor(p)), 3, 6) % 3) - 1) then return feather({ '7', '3', '4', '4' }, max(1, floor(p)))(x, y, u, v, l) end
    return ashf(x, y, u, v, l)
  end)
  for _, dx in ipairs({ -1.8, 0, 1.8 }) do
    tube(g, seg(PX(26.4), PY(46.4), PX(25.4 + dx), PY(51.6)), function() return max(0.6, k * 0.7) end,
      function(x, y, t) return t > 0.75 and 'q' or (floor(y / max(1, k * 0.8)) % 2 == 0 and 't' or 'T') end)
  end
  -- o perfil: pescoço comprido demais, cabeça sem olho (a órbita acesa, vazia), bico de osso
  ell(g, PX(27.4), PY(24), k * 2.7, k * 8.6, 6, ashf)
  ell(g, PX(25.6), PY(14.6), k * 4.6, k * 4.4, 0, ashf)
  ell(g, PX(26.4), PY(11.6), k * 3.4, k * 1.7, 12, function(x, y) return ({ '6', '7' })[1 + floor((x + y) / max(1, floor(p))) % 2] end)
  ell(g, PX(27.6), PY(29), k * 2.2, k * 1.6, 0, stripes('u', 'U', max(1, floor(p))))
  do -- o bico, espelhado para olhar para fora
    local t = L.grid(S, S)
    beak(t, 2 * PX(cx) - PX(22.4), PY(14.4), 0, k * 2.2, false, { 'B', 'D', 'q' })
    for y = 0, S - 1 do for x = 0, S - 1 do
      local m = floor(2 * PX(cx) - x + 0.5)
      if t[y][x] ~= '.' and m >= 0 and m < S then g[y][m] = t[y][x] end
    end end
  end
  L.disc(g, PX(25.4), PY(13.6), max(0.8, k * 0.95), 'x')
  if k > 1 then L.disc(g, PX(25.4), PY(13.6), k * 0.5, 'H') else L.set(g, PX(25.4), PY(13.6), 'H') end
  d:mirror(cx)
  L.outline(g, 'A', SOLID)
  -- o vão em forma de folha, e os bicos para dentro
  d:vao(function(u, v)
    local q = (v - 30.5) / 15.5
    if abs(q) >= 1 then return nil end
    local w = 4.8 * sin(pi * ((q + 1) / 2) ^ 0.8) ^ 0.9
    local t = abs(u - cx) / max(w, 0.01)
    return t <= 1 and t or nil
  end, 'X', 'V', 0.68)
  for _, q in ipairs({ { 24, 1.05 }, { 31.4, 0.75 }, { 37, 0.5 } }) do
    local t = L.grid(S, S)
    beak(t, PX(cx - 0.4), PY(q[1]), 180, k * q[2], false, { 'X', 'X', 'V' })
    for y = 0, S - 1 do for x = 0, S - 1 do
      if t[y][x] ~= '.' and (g[y][x] == '.' or g[y][x] == 'V') then
        local m = floor(2 * PX(cx) - x + 0.5)
        g[y][x] = t[y][x]
        if m >= 0 and m < S and (g[y][m] == '.' or g[y][m] == 'V') then g[y][m] = t[y][x] end
      end
    end end
  end
  for n = 0, 21 do
    local a, r = n * 2.4, 22 + (n * 7) % 9
    dot(g, PX(cx + cos(a) * r * 1.15), PY(30 + sin(a) * r), k * 0.6, n % 4 == 0 and 's' or n % 5 == 0 and 'N' or 'S')
  end
  return g
end

local function out(stage, kind, g) if not R.skip(stage) then C.save('sprig', stage, kind, g, LEG, LIT, LOOSE) end end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', eco(1, 28))
out('eco', 'retrato', eco(96 / 28, 96))
out('espirito', 'mapa', espirito(1, 36))
out('espirito', 'retrato', espirito(96 / 36, 96))
out('entidade', 'mapa', entidade(1, 48))
out('entidade', 'retrato', entidade(2, 96))
out('arquetipo', 'mapa', arquetipo(1, 64))
out('arquetipo', 'retrato', arquetipo(3, 128, -60, -36))                     -- busto: a cabeça maior, gritando, e o vão atrás dela
print('ok sprig')
