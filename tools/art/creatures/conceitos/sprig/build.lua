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

-- ENTIDADE MAIOR: a árvore da calçada pousada na própria gola de concreto. Sem cabeça: no lugar dela, três asas de
-- folha em cata-vento, cada uma numa estação (brotando, seca, só nervura). O rosto foi para o peito (o bico sai de um
-- oco na casca, três olhos em volta), três pés agarram a gola e as raízes pendem por baixo dela.
local function entidade(k, S)
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local rich = k > 1
  local p = rich and 2 or 1
  local cx, hy = P(28), P(15.5)
  -- gola: a tira de trás
  C.poly(g, { { P(12), P(36.5) }, { P(35), P(35) }, { P(36), P(37) }, { P(13), P(38.5) } }, 'P')
  -- a cauda virou raiz e atravessa a gola
  tube(g, seg(P(19.5), P(33), P(16.5), P(42), P(-1.5), 0), function(t) return P(2.6 - 1.2 * t) end, bark(BARK, max(1, k * 0.75)))
  -- corpo de perfil, sem cabeça: pena no peito, casca daí para baixo
  local fb = feather(BODY, p)
  ell(g, P(24), P(27), P(11.5), P(7.8), -68, function(x, y, u, v, l)
    local edge = u + v * 0.3 + ((hash(x // p, y // p, 4) % 5) - 2) * 0.07
    if edge < -0.05 then
      local i = l > 0.3 and 1 or l > -0.3 and 2 or 3
      return BARK[i + floor((x + y * 0.3) / max(1, k * 0.75)) % 2]
    end
    return fb(x, y, u, v, l)
  end)
  -- o rosto desceu para o peito: o bico sai de um oco, três olhos em volta
  ell(g, P(29.4), P(27), P(3.6), P(2.2), 90, function(x, y, u, v) return (u * u + v * v > 0.55) and 'x' or 'z' end)
  beak(g, P(30), P(26.2), 12, k * 2.5, true)
  for _, q in ipairs({ { 28.6, 22.4 }, { 27, 31.4 }, { 24.4, 26 } }) do eyeAt(g, P(q[1]), P(q[2]), max(k, 1.01) * 1.4) end
  -- gola: frente, com a rachadura
  C.poly(g, { { P(11), P(39) }, { P(36.5), P(37) }, { P(37.5), P(39) }, { P(12.5), P(41.2) } }, 'p')
  C.poly(g, { { P(12.5), P(41.3) }, { P(37.5), P(39.1) }, { P(37.5), P(41) }, { P(13), P(43.2) } }, 'Q')
  C.poly(g, { { P(11), P(39) }, { P(12), P(36.5) }, { P(14), P(36.6) }, { P(13.5), P(39) } }, 'P')
  C.poly(g, { { P(34), P(35.2) }, { P(36), P(35) }, { P(37.5), P(39) }, { P(35.5), P(37.3) } }, 'p')
  for x = floor(P(12)), floor(P(37)) do
    local h = hash(x // max(1, floor(k)), 7, 1) % 4
    if h == 0 then L.set(g, x, P(42.3) - (x - P(12)) * 0.088, 'P', 'Q') end
    if h == 1 then L.set(g, x, P(40.2) - (x - P(12)) * 0.088, 'P', 'p') end
  end
  wire(g, { { P(28), P(38) }, { P(29), P(40) }, { P(28.2), P(42.2) } }, 'z', 'z', 1, 'pPQ')
  -- três pés de ave agarrados à gola
  for _, x0 in ipairs({ 18, 24, 30 }) do
    for _, dx in ipairs({ -2.2, 0, 2.2 }) do
      tube(g, seg(P(x0), P(37.2), P(x0 + dx), P(40.8) - (x0 - 12) * 0.088 * k), function() return max(0.6, P(0.75)) end,
        function(x, y, t, dn, ds, r, l) return t > 0.8 and 'q' or (floor(ds / max(1, k * 0.8)) % 2 == 0 and 't' or 'T') end)
    end
  end
  -- raízes penduradas
  for n, q in ipairs({ { 17, 44.5 }, { 21, 45.4 }, { 25, 45 }, { 29, 45.2 }, { 33, 43.6 } }) do
    wire(g, { { P(q[1]), P(42.4) - (q[1] - 12) * 0.088 * k }, { P(q[1] + (n % 2 == 0 and 0.8 or -0.8)), P(q[2] - 1) }, { P(q[1]), P(q[2]) } },
      'i', 'l', k * 0.7)
  end
  -- o cata-vento no lugar da cabeça: três estações ao mesmo tempo
  ell(g, cx, hy + P(1.6), P(3.6), P(2.3), 22, feather(HEAD, p))
  local pals = { FRESH, NEAR, FAR }
  for n, ang in ipairs({ -100, 20, 140 }) do
    local a = rad(ang)
    leaf(g, { x = cx + cos(a) * P(1.8), y = hy + sin(a) * P(1.8), ang = ang, len = P(({ 11, 15, 14 })[n]), wid = P(3.5), pal = pals[n], k = k,
      vp = max(3, k * 1.6), notch = n == 2 and 6 or nil, skel = n == 3, litv = 0.85, spots = (rich and n == 2) and 3 or nil })
  end
  L.disc(g, cx, hy, P(2.1), 'z'); L.disc(g, cx, hy, P(1.1), 'H'); L.disc(g, cx, hy, P(0.45), 'I')
  L.outline(g, 'A', SOLID)
  dot(g, P(8), P(8), k * 0.6); dot(g, P(38), P(9), k * 0.6, 's'); dot(g, P(5), P(18), k * 0.6, 'N'); dot(g, P(42), P(20), k * 0.6)
  dot(g, P(13), P(5), k * 0.6, 's'); dot(g, P(36), P(15), k * 0.6); dot(g, P(40), P(32), k * 0.6, 'N'); dot(g, P(8), P(30), k * 0.6, 's')
  dot(g, P(33), P(4), k * 0.6, 'N'); dot(g, P(10), P(13), k * 0.6)
  return g
end

-- ARQUÉTIPO: a copa sem árvore. Três galhos de cinza em roda, cada um nascendo do meio do seguinte (nenhum tem
-- tronco, a roda não tem começo); três asas de folha morta que viram só nervura para a ponta; por dentro, bicos sem
-- cabeça fechando sobre o vão. A casca é clara do lado do vão e escura por fora: a luz dela vem do buraco.
local function arquetipo(k, S)
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local p = max(1, k * 0.75)
  local cx, cy = P(36) - 0.5, P(30.5)
  local TH = 121
  local function rad0(t) return P(11.5 + 3 * t) end
  local function arm(i)
    local th0 = TH + i * 120
    return function(t)
      local a = rad(th0 + t * 150)
      return cx + cos(a) * rad0(t), cy + sin(a) * rad0(t)
    end
  end
  local function ash(x, y, t, dn, ds, r)
    local l = (rad0(t) - sqrt((x - cx) ^ 2 + (y - cy) ^ 2)) / max(r, 0.5)
    if abs(dn) < 0.3 and floor(ds / p) % 3 ~= 0 and t > 0.45 then return 'J' end -- a seiva acesa, no meio do galho
    local i = l > 0.3 and 1 or l > -0.3 and 2 or 3
    return ASH[i + floor((dn * r + ds * 0.3 + 50) / p) % 2]
  end
  local function w(t) return P(2.6 - 1.8 * t) end
  -- raízes que pendem da roda, duas com uma Fagulha na ponta
  for n, q in ipairs({ { -7, 54, -1.5 }, { -3.5, 58.5, 1.2 }, { 0.5, 56, -1 }, { 4, 60, 1.4 }, { 7.5, 52.5, 1 } }) do
    local x0, y0 = cx + P(q[1]), cy + P(13)
    tube(g, seg(x0, y0, x0 + P(q[3]), P(q[2]), P(q[3]), 0), function(t) return max(0.5, P(1.1 - 0.9 * t)) end,
      function(x, y, t, dn, ds) return ({ 'T', 'x', 'E', 'G' })[1 + floor(ds / max(2, k * 1.5)) % 2 + (n % 2) * 2] end)
    if n == 1 or n == 5 then
      local ex, ey = x0 + P(q[3]), P(q[2])
      leaf(g, { x = ex, y = ey, ang = n == 1 and 110 or 70, len = P(4.5), wid = P(1.5), pal = FAR, k = k, vp = 99 })
    end
  end
  -- as três asas: folha morta perto da roda, só nervura para a ponta
  for i = 0, 2 do
    local x, y = arm(i)(1)
    leaf(g, { x = x, y = y, ang = TH + i * 120 + 150 + 60, len = P(18), wid = P(7),
      pal = { 'D', 'E', 'G', 'E' }, k = k, skel = true, skelFrom = 0.4, litv = 0.6, vp = max(3, k * 1.5) })
  end
  for i = 0, 2 do tube(g, arm(i), w, ash, 0.4, 1) end
  for i = 0, 2 do tube(g, arm(i), w, ash, 0, 0.4) end
  -- o que sobrou do bicho: um colar de pena onde cada galho nasce, e os bicos virados para o vão
  for i = 0, 2 do
    local x, y = arm(i)(0.02)
    ell(g, x, y, P(3.6), P(2.2), TH + i * 120 + 95, function(xx, yy, u, v, l)
      return ({ '3', '4', '7', '4' })[(l > 0 and 1 or 3) + floor((yy + xx * 0.5) / max(1, floor(p))) % 2]
    end)
  end
  -- a gola de pena escura em volta do vão e as duas fileiras de bicos, como dentes
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
      local a = math.atan(y - cy, x - cx)
      if d >= P(7.6) and d <= P(10.2 + 0.8 * sin(a * 7)) then
        g[y][x] = ({ '7', '4', 'G', '4' })[1 + (floor(a * 9 + d / max(1, floor(p))) % 2) + (d > P(9) and 2 or 0)]
      end
    end
  end
  for n = 0, 5 do
    local ang = n * 60 + 8
    local a = rad(ang)
    beak(g, cx + cos(a) * P(8), cy + sin(a) * P(8), ang + 180 - 16, k * (n % 2 == 0 and 1.7 or 1.35), true, { 'B', 'D', 'G' })
  end
  L.outline(g, 'A', SOLID)
  -- o vão: contorno por dentro, depois a borda do Véu e o pólen em espiral, só no emissivo
  for _, pass in ipairs({ { 'A', function(q) return q ~= '.' and q ~= 'A' end }, { 'X', function(q) return q == 'A' end } }) do
    local add = {}
    for y = 0, S - 1 do
      for x = 0, S - 1 do
        if g[y][x] == '.' and sqrt((x - cx) ^ 2 + (y - cy) ^ 2) < P(9) then
          for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if pass[2](L.get(g, x + dd[1], y + dd[2])) then add[#add + 1] = { x, y }; break end
          end
        end
      end
    end
    for _, q in ipairs(add) do g[q[2]][q[1]] = pass[1] end
  end
  for n = 0, 14 do
    local a, r = n * 0.9, P(0.3 + n * 0.22)
    dot(g, cx + cos(a) * r, cy + sin(a) * r, k * 0.6, n % 4 == 0 and 's' or n % 5 == 0 and 'N' or 'S')
  end
  for i = 0, 2 do
    local a = rad(-90 + i * 120 + 60)
    dot(g, cx + cos(a) * P(22), cy + sin(a) * P(22), k * 0.6, 's'); dot(g, cx + cos(a + 0.3) * P(18), cy + sin(a + 0.3) * P(18), k * 0.6)
    dot(g, cx + cos(a - 0.25) * P(25), cy + sin(a - 0.25) * P(25), k * 0.6, 'N')
  end
  dot(g, cx + P(-9.5), P(59.5), k * 0.6, 's'); dot(g, cx + P(9.5), P(58), k * 0.6, 's')
  return g
end

local function out(stage, kind, g) C.save('sprig', stage, kind, g, LEG, LIT, LOOSE) end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', eco(1, 28))
out('eco', 'retrato', eco(96 / 28, 96))
out('espirito', 'mapa', espirito(1, 36))
out('espirito', 'retrato', espirito(96 / 36, 96))
out('entidade', 'mapa', entidade(1, 48))
out('entidade', 'retrato', entidade(2, 96))
out('arquetipo', 'mapa', arquetipo(1, 64))
out('arquetipo', 'retrato', arquetipo(2, 128))
print('ok sprig')
