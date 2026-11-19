-- Conceitos da família Wyrm (Etapa 1): Fagulha, Eco, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- Teú + asfalto rachado e cratera + Dracônico (brasa nas juntas). Traço: escama em brasa (escama escura, junta acesa).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/wyrm/build.lua')
-- Cada etapa é uma função de (k, S): k = 1 no mapa; no retrato o mesmo esqueleto ganha escama maior, dente e unha.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs, max, min = math.floor, math.ceil, math.sqrt, math.abs, math.max, math.min
local sin, cos, rad, pi = math.sin, math.cos, math.rad, math.pi

local LEG = {
  A = '#1A1424',
  ['1'] = '#6A6670', ['2'] = '#4A4752', ['3'] = '#33313B', ['4'] = '#25232C', -- escama preta do teú
  c = '#BDB6A2', C = '#8F897B',                                               -- faixa e barriga cor de cinza
  p = '#5C5B60', P = '#45444A', Q = '#303036', g = '#7A7880',                 -- asfalto e a brita
  o = '#B89A3E', O = '#8A7430', w = '#C9C2A8',                                -- tinta de faixa, gasta
  e = '#6B4A3A', E = '#4A3229',                                               -- terra vermelha da cratera
  B = '#CFC9BA', D = '#A39E92', F = '#77736C', G = '#504D4C',                 -- cinza e osso (Arquétipo)
  k = '#D8D2C0', K = '#9C9484',                                               -- unha e dente
  j = '#5A2A1E', h = '#6B3A20', r = '#451C1A',                                -- emissivos apagados
  J = '#F0552A', H = '#FF9A3A', I = '#FFE2A0', R = '#B02A20',                 -- brasa: junta, nó, miolo, fundo
  S = '#F0552A', s = '#FF9A3A', N = '#B02A20', X = '#9B7BFF',                 -- fagulha solta e a borda do Véu
}
local LIT = { J = 'j', H = 'h', I = 'h', R = 'r' }
local LOOSE = 'SsNX'
local SOLID = ''
for ch in pairs(LEG) do
  if not ('AJHIRSsNX'):find(ch, 1, true) then SOLID = SOLID .. ch end
end

local function hash(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ (s * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end

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
-- Polígono cheio com sombreador sh(x, y).
local function fillpoly(g, pts, sh, mask)
  local t = L.grid(g.w, g.h)
  C.poly(t, pts, '#')
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if t[y][x] == '#' then
        local ch = sh(x, y)
        if ch then L.set(g, x, y, ch, mask) end
      end
    end
  end
end
-- Tubo que afina: path(t) -> x, y; w(t) -> raio; sh(x, y, t, dn, ds, r, l).
local function tube(g, path, w, sh, t0, t1, mask)
  t0, t1 = t0 or 0, t1 or 1
  local n, acc = 260, 0
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
local function seg(x0, y0, x1, y1, bx, by)
  bx, by = bx or 0, by or 0
  return function(t)
    local s = 4 * t * (1 - t)
    return x0 + (x1 - x0) * t + bx * s, y0 + (y1 - y0) * t + by * s
  end
end
-- Curva de Catmull-Rom pelos pontos (já em pixels).
local function spline(pts)
  local n = #pts
  return function(t)
    local f = min(max(t, 0), 1) * (n - 1)
    local i = min(floor(f), n - 2)
    local u = f - i
    local a, b, c, d = pts[max(i, 1)], pts[i + 1], pts[i + 2], pts[min(i + 3, n)]
    local function cr(q)
      return 0.5 * (2 * b[q] + (-a[q] + c[q]) * u + (2 * a[q] - 5 * b[q] + 4 * c[q] - d[q]) * u * u + (-a[q] + 3 * b[q] - 3 * c[q] + d[q]) * u ^ 3)
    end
    return cr(1), cr(2)
  end
end
local function scaled(pts, k)
  local out = {}
  for i, q in ipairs(pts) do out[i] = { q[1] * k, q[2] * k } end
  return out
end
local function prof(list, k)
  return function(t)
    for i = 1, #list - 1 do
      local a, b = list[i], list[i + 1]
      if t <= b[1] then return (a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])) * k end
    end
    return list[#list][2] * k
  end
end
local function dirAt(path, t)
  local xa, ya = path(max(0, t - 0.01))
  local xb, yb = path(min(1, t + 0.01))
  local tx, ty = xb - xa, yb - ya
  local tl = sqrt(tx * tx + ty * ty)
  return tx / tl, ty / tl
end
local function dot(g, x, y, k, ch)
  k = max(1, floor(k + 0.5))
  L.rect(g, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, ch or 'S', '.')
end

-- Pele de teú: escama em xadrez de dois tons, faixas cor de cinza e, onde ember(t, dn) vale, a escama em brasa
-- (escama escura com a junta acesa). o = { p (px da escama), band (px), pal, ember, pale = false tira as faixas }.
local DARK, FARLEG, ASHY = { '1', '2', '3', '4' }, { '3', '4', '4', '4' }, { 'D', 'F', 'G', '4' }
local function skin(o)
  local p, pal = o.p, o.pal or DARK
  local q = p + 2
  return function(x, y, t, dn, ds, r, l)
    local a, b = floor(ds), floor(dn * r + 60)
    if o.ember and o.ember(t, dn) then
      if a % q == 0 and b % q == 0 then return 'H' end
      if a % q == 0 or b % q == 0 then return 'J' end
      return ((a // q + b // q) % 2 == 0) and '4' or '3'
    end
    local chk = (a // p + b // p) % 2
    if l < -0.55 then return chk == 0 and 'C' or pal[3] end
    if o.pale ~= false and (ds % o.band) < o.band * 0.28 then return chk == 0 and (l > 0.35 and 'w' or 'c') or 'C' end
    return pal[(l > 0.35 and 1 or l > -0.2 and 2 or 3) + chk]
  end
end
local function asphalt(lite)
  return function(x, y)
    local h = hash(x, y, 11) % 7
    if lite then return h == 0 and 'g' or h < 4 and 'p' or 'P' end
    return h == 0 and 'p' or h < 4 and 'P' or 'Q'
  end
end

-- Cabeça de teú em (bx, by) (a nuca), apontando para ang, tamanho s. open: quanto a boca abre; eye: tem olho;
-- tongue: 1 ou 2 línguas bifurcadas de brasa.
local function head(g, bx, by, ang, s, o)
  o = o or {}
  local a = rad(ang)
  local ca, sa = cos(a), sin(a)
  local function pt(x, y) return bx + s * (x * ca - y * sa), by + s * (x * sa + y * ca) end
  local function pts(list)
    local out = {}
    for i, q in ipairs(list) do local x, y = pt(q[1], q[2]); out[i] = { x, y } end
    return out
  end
  local op = o.open or 0
  local pal = o.pal or DARK
  local p = max(1, floor(s * 0.7))
  if op > 0 then fillpoly(g, pts({ { -0.5, 0.3 }, { 3.6, 0.2 }, { 3.4, 0.6 + op }, { -0.5, 0.9 } }), function() return 'R' end) end
  fillpoly(g, pts({ { -2.2, 0.8 }, { 0, 0.6 }, { 4, 0.5 + op }, { 3.7, 1.3 + op }, { 0.6, 1.9 + op * 0.5 }, { -1.8, 1.9 } }),
    function(x, y) return (x // p + y // p) % 2 == 0 and 'c' or 'C' end)
  fillpoly(g, pts({ { -2.4, 0.6 }, { -2.2, -1.5 }, { 0.5, -1.9 }, { 2.6, -1.3 }, { 4.2, -0.5 }, { 4.5, 0.3 }, { 0, 0.5 } }),
    function(x, y)
      local lx = ((x - bx) * ca + (y - by) * sa) / s
      local ly = (-(x - bx) * sa + (y - by) * ca) / s
      return pal[(ly < -0.9 and 1 or ly < -0.2 and 2 or 3) + (x // p + y // p) % 2]
    end)
  if o.eye then
    local ex, ey = pt(1.1, -0.8)
    if s < 1.6 then L.set(g, ex, ey, 'H') else L.disc(g, ex, ey, 0.42 * s, 'H'); L.line(g, ex, ey - 0.4 * s, ex, ey + 0.4 * s, '4') end
  end
  if s >= 1.6 then
    for i = 0, 5 do
      local x, y = pt(0.9 + i * 0.55, 0.5); L.set(g, x, y, 'k')
      if op > 0 then x, y = pt(0.9 + i * 0.55, 0.55 + op * (0.9 + i * 0.55) / 4); L.set(g, x, y, 'K') end
    end
    local nx, ny = pt(3.7, -0.4); L.set(g, nx, ny, '4')
  end
  for n = 1, o.tongue or 0 do
    local dy = (n - 1) * 0.9 + op * 0.5
    local x0, y0 = pt(3.9, 0.45 + dy)
    local x1, y1 = pt(5.1, 0.5 + dy + (n - 1) * 0.5)
    L.line(g, x0, y0, x1, y1, 'J')
    local xa, ya = pt(6, -0.2 + dy + (n - 1) * 0.5)
    local xb, yb = pt(6, 1.2 + dy + (n - 1) * 0.5)
    L.line(g, x1, y1, xa, ya, 'H'); L.line(g, x1, y1, xb, yb, 'H')
  end
end
-- Perna: quadril, joelho, pé, e três dedos com unha apontando para dir (+1 ou -1).
local function leg(g, q, k, pal, dir)
  local sh = skin({ p = max(1, floor(k * 0.7)), band = 99, pal = pal, pale = false })
  tube(g, seg(q[1] * k, q[2] * k, q[3] * k, q[4] * k), function(t) return (1.25 - 0.3 * t) * k end, sh)
  tube(g, seg(q[3] * k, q[4] * k, q[5] * k, q[6] * k), function(t) return (0.95 - 0.2 * t) * k end, sh)
  for _, d in ipairs({ -0.5, 0.3, 1.1 }) do
    -- dedo sujo de terra vermelha, unha clara
    L.line(g, q[5] * k, q[6] * k, (q[5] + dir * 1.9) * k, (q[6] + d * 0.9) * k, d > 1 and 'e' or 'K')
    L.set(g, (q[5] + dir * 1.9) * k, (q[6] + d * 0.9) * k, 'k')
  end
end
-- Placa de asfalto levantada: base em (bx, by), direção (nx, ny), largura w, altura h. paint: faixa de tinta.
local function slab(g, bx, by, nx, ny, w, h, paint)
  local tx, ty = -ny, nx
  local a = asphalt(true)
  fillpoly(g, { { bx - tx * w / 2, by - ty * w / 2 }, { bx + tx * w / 2, by + ty * w / 2 },
    { bx + tx * w * 0.32 + nx * h, by + ty * w * 0.32 + ny * h }, { bx - tx * w * 0.42 + nx * h * 0.8, by - ty * w * 0.42 + ny * h * 0.8 } },
    function(x, y)
      local u = ((x - bx) * nx + (y - by) * ny) / h
      local v = ((x - bx) * tx + (y - by) * ty) / w
      if paint and u > 0.3 and u < 0.56 then return (x + y) % 3 == 0 and 'O' or paint end
      if v > 0.18 then return asphalt(false)(x, y) end
      return a(x, y)
    end)
end

-- FAGULHA (Scale Mote): uma escama solta, escura, com a junta ainda acesa em volta e uma trinca no meio.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '....AAAA....',
    '...AJJJJA...',
    '..AJ1212JA..',
    '..AJ2H21JA.S',
    '..AJ32H3JA..',
    '..AJ43I4JA..',
    '.s.AJ34JA...',
    '....AJJA....',
    '..S..AA...s.',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local g = L.grid(96, 96)
  local cx, cy = 47, 46
  -- escama em escudo: larga em cima, ponta embaixo, com as linhas de crescimento
  local function inside(x, y, m)
    local dx, dy = abs(x - cx), y - cy
    local hw = dy < 0 and 26 * sqrt(max(0, 1 - (dy / 30) ^ 2)) or 26 * (1 - (dy / 38) ^ 1.6)
    return dy > -30 + m and dy < 38 - m * 1.5 and dx < hw - m
  end
  for y = 0, 95 do
    for x = 0, 95 do
      if inside(x, y, 0) then
        local ch
        if not inside(x, y, 4) then ch = (x + y) % 5 == 0 and 'H' or 'J'
        else
          local d = sqrt((x - cx) ^ 2 + ((y - cy - 30) * 0.8) ^ 2)
          local ring = floor(d / 5)
          local l = -((y - cy) * 0.8 + (x - cx) * 0.45) / 34
          ch = DARK[(l > 0.3 and 1 or l > -0.2 and 2 or 3) + ring % 2]
          if floor(d) % 5 == 0 and ring % 3 == 1 then ch = 'C' end
          -- brita de asfalto grudada na escama
          local hs = hash(x // 2, y // 2, 6) % 11
          if hs == 0 then ch = 'g' elseif hs == 1 then ch = 'P' elseif hs == 2 and l < 0 then ch = 'Q' end
        end
        g[y][x] = ch
      end
    end
  end
  -- a trinca: desce do meio, com um ramo
  local crack = { { 44, 22 }, { 49, 32 }, { 45, 41 }, { 50, 52 }, { 46, 62 }, { 48, 72 } }
  for i = 1, #crack - 1 do
    for d = 0, 2 do L.line(g, crack[i][1] + d, crack[i][2], crack[i + 1][1] + d, crack[i + 1][2], d == 1 and 'I' or 'H') end
  end
  for d = 0, 1 do L.line(g, 50 + d, 52, 60 + d, 58, 'J'); L.line(g, 45 + d, 41, 36 + d, 47, 'J') end
  L.outline(g, 'A', SOLID .. 'JH')
  for _, q in ipairs({ { 14, 30, 'S' }, { 22, 70, 's' }, { 78, 24, 's' }, { 82, 60, 'S' }, { 70, 82, 'N' }, { 30, 12, 'N' }, { 12, 52, 's' },
    { 62, 90, 'S' }, { 86, 40, 'N' }, { 38, 88, 's' } }) do dot(g, q[1], q[2], 2, q[3]) end
  return g
end

-- ECO (Wyrmlet): um teú jovem em proporção natural, andando; nas costelas a escama em brasa, que respira, e a
-- língua bifurcada é uma chama pequena.
local function eco(k, S)
  local g = L.grid(S, S)
  local p = k > 1 and 2 or 1
  local body = spline(scaled({ { 6, 5 }, { 3.4, 8.4 }, { 3.4, 13.4 }, { 6.5, 16.6 }, { 11, 16.6 }, { 15.5, 15.4 }, { 18.6, 13.2 }, { 20.4, 10.6 } }, k))
  leg(g, { 17.8, 15, 19.6, 17.6, 21.2, 19.4 }, k, FARLEG, 1)
  leg(g, { 10.4, 16.2, 12.6, 18.4, 11.4, 20.2 }, k, FARLEG, 1)
  tube(g, body, prof({ { 0, 0.7 }, { 0.38, 2.6 }, { 0.62, 3.9 }, { 0.84, 3.4 }, { 1, 2.4 } }, k),
    skin({ p = p, band = 4.5 * k, ember = function(t, dn) return t > 0.52 and t < 0.82 and dn > -0.55 and dn < 0.65 end }))
  head(g, 20.6 * k, 9.8 * k, -16, k * 0.95, { eye = true, tongue = 1, open = k > 1 and 0.3 or 0 })
  leg(g, { 16, 16, 17.6, 18.8, 19.4, 20.6 }, k, DARK, 1)
  leg(g, { 8.4, 17, 10.6, 19.4, 9.2, 21.2 }, k, DARK, 1)
  L.outline(g, 'A', SOLID)
  for _, q in ipairs({ { 14, 9.5, 'S' }, { 16.5, 7, 's' }, { 12, 6.5, 'N' }, { 25, 5.5, 's' }, { 9, 10.5, 'S' }, { 11, 3.5, 's' } }) do
    dot(g, q[1] * k, q[2] * k, k * 0.6, q[3])
  end
  return g
end

-- ESPÍRITO (Wyrmkin): o teú tomado pelo asfalto. Placas de rua levantadas na espinha, ainda com a faixa pintada,
-- uma só asa de placa, cinco pernas, duas caudas e duas línguas; a brasa aparece onde o asfalto abriu.
local function espirito(k, S)
  local g = L.grid(S, S)
  local p = k > 1 and 2 or 1
  local body = spline(scaled({ { 6.5, 6.5 }, { 3.2, 11 }, { 3.6, 17.5 }, { 7.5, 22.6 }, { 13.5, 23.6 }, { 19.5, 22 }, { 23.4, 18 }, { 24.2, 13.4 },
    { 25.6, 10.6 } }, k))
  local w = prof({ { 0, 0.5 }, { 0.4, 2.6 }, { 0.62, 4 }, { 0.82, 3.3 }, { 1, 2.4 } }, k)
  leg(g, { 21.6, 21.4, 24.4, 25, 26.4, 27.6 }, k, FARLEG, 1)
  leg(g, { 11.6, 23, 13.6, 26.4, 12.6, 29 }, k, FARLEG, 1)
  -- a segunda cauda
  tube(g, spline(scaled({ { 5.4, 20.4 }, { 3.4, 23.4 }, { 3.2, 27 }, { 5.6, 29.6 } }, k)), prof({ { 0, 1.7 }, { 1, 0.5 } }, k),
    skin({ p = p, band = 4 * k }))
  -- placas na espinha (por trás do corpo) e a asa de placa
  for n, q in ipairs({ { 0.44, 3 }, { 0.53, 4.4 }, { 0.62, 5.6 }, { 0.71, 4.6 }, { 0.8, 3.2 } }) do
    local x, y = body(q[1])
    local tx, ty = dirAt(body, q[1])
    slab(g, x + ty * w(q[1]) * 0.6, y - tx * w(q[1]) * 0.6, ty * 0.92 - tx * 0.38, -tx * 0.92 - ty * 0.38, 3.6 * k, (q[2] + 2) * k,
      (n == 2 or n == 3 or n == 4) and 'o' or nil)
  end
  slab(g, 20.6 * k, 16 * k, -0.62, -0.78, 5 * k, 10.5 * k, 'w')
  tube(g, body, w, skin({ p = p, band = 5 * k, ember = function(t, dn) return t > 0.4 and t < 0.86 and dn > -0.8 and dn < 0.4 end }))
  head(g, 26 * k, 9.6 * k, -8, k * 1.15, { eye = true, tongue = 2, open = 0.5 })
  leg(g, { 19.6, 22.6, 21.8, 26.6, 23.8, 29.4 }, k, DARK, 1)
  leg(g, { 14.6, 23.8, 15.4, 27.6, 17.6, 30.6 }, k, DARK, 1)
  leg(g, { 8.6, 22.6, 7.6, 26.6, 9.8, 30 }, k, DARK, 1)
  L.outline(g, 'A', SOLID)
  for _, q in ipairs({ { 10, 14, 'S' }, { 12.5, 10.5, 's' }, { 8, 9, 'N' }, { 30, 5.5, 's' }, { 17, 5, 'S' }, { 28.5, 17, 'N' }, { 1.5, 31, 's' },
    { 31, 22, 'S' } }) do
    dot(g, q[1] * k, q[2] * k, k * 0.6, q[3])
  end
  return g
end

-- ENTIDADE MAIOR: a cratera que anda. Um pedaço de rua com o buraco no meio, em seis pernas de teú; do fundo da
-- borda sobe o tronco, que se abre em três pescoços em cata-vento, cada um com uma cabeça sem olhos. O olho ficou
-- no fundo do buraco, e o buraco é mais fundo do que a placa que o carrega.
local function entidade(k, S)
  local g = L.grid(S, S)
  local p = k > 1 and 2 or 1
  local function P(v) return v * k end
  local hx, hy = P(24) - 0.5, P(19)
  local sx, sy = P(24) - 0.5, P(36)
  -- pernas de trás
  for _, x in ipairs({ 13, 24, 35 }) do leg(g, { x, 38, x + 1.4, 40.6, x - 0.4, 42.4 }, k, FARLEG, 1) end
  -- tronco, com placas na espinha
  local trunk = spline(scaled({ { 24, 35 }, { 26.4, 30 }, { 22.6, 24.6 }, { 24, 18.5 } }, k))
  for n, t in ipairs({ 0.25, 0.5, 0.75 }) do
    local x, y = trunk(t)
    slab(g, x - P(2.6), y, -0.95, -0.3, P(3.6), P(5.4 - abs(n - 2)), n == 2 and 'o' or nil)
  end
  tube(g, trunk, prof({ { 0, 3.8 }, { 1, 3 } }, k), skin({ p = p, band = 5 * k,
    ember = function(t, dn) return t > 0.15 and t < 0.9 and abs(dn) < 0.6 end }))
  -- três pescoços em cata-vento
  for i = 0, 2 do
    local a0 = -90 + i * 120
    local function neck(t)
      local a = rad(a0 + 85 * t)
      local r = P(11) * t ^ 0.9
      return hx + cos(a) * r, hy + sin(a) * r
    end
    tube(g, neck, prof({ { 0, 3 }, { 1, 2.2 } }, k), skin({ p = p, band = 4 * k,
      ember = function(t, dn) return t > 0.2 and t < 0.9 and dn > -0.1 and dn < 0.9 end }))
    local x, y = neck(1)
    local tx, ty = dirAt(neck, 0.97)
    head(g, x, y, math.deg(math.atan(ty, tx)), k * 1.45, { tongue = 1, open = 1.3 })
  end
  ell(g, hx, hy, P(3.4), P(3.4), 0, function(x, y, u, v, l) return DARK[(l > 0.2 and 1 or 2) + (x // p + y // p) % 2] end)
  -- o pedaço de rua: a face de cima, a borda e o buraco
  local top = asphalt(true)
  for y = floor(sy - P(6)), ceil(sy + P(9)) do
    for x = floor(sx - P(18)), ceil(sx + P(18)) do
      local u, v = (x - sx) / P(17), (y - sy) / P(4.6)
      local d = u * u + v * v
      local vs = (y - sy - P(3)) / P(4.6)
      if d <= 1 then
        local ch = top(x, y)
        local hu, hv = (x - sx) / P(9), (y - sy + P(0.4)) / P(2.9)
        local hd = sqrt(hu * hu + hv * hv)
        if hd < 1 then
          -- o buraco: anéis de terra e asfalto que descem, a brasa lá embaixo e o olho de pupila em fenda
          local ring = floor(hd * 6)
          ch = ({ 'E', 'e', 'Q', 'E', 'e', 'Q' })[ring + 1]
          if ring == 3 or ring == 5 then ch = (x + y) % 2 == 0 and 'R' or ch end
          if hd < 0.42 then ch = hd < 0.2 and 'I' or 'H' end
          if abs(x - sx) < max(0.6, P(0.4)) and hd < 0.36 then ch = '4' end
        elseif hd < 1.14 then ch = (x + y) % 3 == 0 and 'J' or 'Q'
        elseif abs(v - 0.1 - u * 0.05) < 0.09 and floor(x / P(2.5)) % 2 == 0 then ch = 'o'
        elseif hash(x // max(1, floor(k * 3)), y // max(1, floor(k * 2)), 3) % 9 == 0 then ch = 'Q' end
        if g[y][x] == '.' or v > -0.25 or hd < 1.14 then g[y][x] = ch end
      elseif u * u + vs * vs <= 1 and g[y][x] == '.' then
        g[y][x] = asphalt(false)(x, y)
        if hash(x // max(1, floor(k * 2)), 5, 8) % 6 == 0 then g[y][x] = 'J' end
      end
    end
  end
  -- pernas da frente
  for _, x in ipairs({ 9.5, 19, 29, 38.5 }) do leg(g, { x, 39.2, x - 1.6, 41.6, x + 0.4, 43.4 }, k, DARK, 1) end
  L.outline(g, 'A', SOLID)
  for _, q in ipairs({ { 6, 12, 'S' }, { 41, 8, 's' }, { 44, 28, 'N' }, { 4, 27, 's' }, { 33, 3, 'S' }, { 15, 4, 'N' }, { 21, 30.5, 's' },
    { 27, 31.5, 'S' }, { 24, 29, 'N' }, { 8, 20, 'S' } }) do
    dot(g, q[1] * k, q[2] * k, k * 0.6, q[3])
  end
  return g
end

-- ARQUÉTIPO: o eclipse. No lugar do corpo, um disco vazio com a coroa de brasa em volta; a armação é um anel de
-- doze escamas de asfalto, cada uma por cima da seguinte em toda a volta; de dentro do vão, mãos de teú agarram o
-- anel; por fora, três caudas em cata-vento. Nenhuma cabeça.
local function arquetipo(k, S)
  local g = L.grid(S, S)
  local p = k > 1 and 2 or 1
  local function P(v) return v * k end
  local cx, cy = P(32) - 0.5, P(33)
  -- caudas
  for i = 0, 2 do
    local a0 = 35 + i * 120
    local function tail(t)
      local a = rad(a0 + 120 * t)
      local r = P(16.5 + 11.5 * t)
      return cx + cos(a) * r, cy + sin(a) * r
    end
    tube(g, tail, prof({ { 0, 3.4 }, { 0.6, 1.8 }, { 1, 0.5 } }, k), skin({ p = p, band = 5 * k, pal = ASHY,
      ember = function(t, dn) return t > 0.08 and t < 0.6 and abs(dn) < 0.45 end }))
  end
  -- o anel de escamas
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      local dx, dy = x - cx, y - cy
      local d = sqrt(dx * dx + dy * dy) / k
      local ang = math.deg(math.atan(dy, dx)) % 360
      local wob = 0.7 * sin(rad(ang * 5))
      if d >= 12.4 and d <= 19.4 + wob then
        local a = (ang - 9 * sin((d - 12.4) / 7 * pi)) % 360
        local f = (a % 30) / 30
        local ch
        if f < 0.13 then ch = (d > 14 and d < 17.5) and 'H' or 'J'
        elseif f < 0.18 then ch = 'R'
        elseif f < 0.3 then ch = (x + y) % 2 == 0 and 'Q' or '4'
        elseif f < 0.62 then ch = asphalt(false)(x, y)
        elseif f < 0.9 then ch = asphalt(true)(x, y)
        else ch = (x + y) % 2 == 0 and 'g' or 'D' end
        if d < 13.1 then ch = (x + y) % 2 == 0 and 'E' or 'e' end
        g[y][x] = ch
      end
    end
  end
  -- as mãos que saem do vão
  for n, q in ipairs({ { 20, 1 }, { 95, 0.85 }, { 150, 1.1 }, { 215, 0.9 }, { 290, 1.05 } }) do
    local a = rad(q[1])
    for _, da in ipairs({ -13, -4, 5, 14 }) do
      local b = rad(q[1] + da * q[2])
      tube(g, seg(cx + cos(a) * P(7.2), cy + sin(a) * P(7.2), cx + cos(b) * P(13.6), cy + sin(b) * P(13.6)),
        function(t) return max(0.6, P(0.95 - 0.3 * t)) end,
        function(x, y, t, dn, ds) return t > 0.72 and 'k' or t > 0.6 and 'K' or (floor(ds / max(1, k * 0.8)) % 2 == 0 and '3' or '2') end)
    end
    ell(g, cx + cos(a) * P(7.6), cy + sin(a) * P(7.6), P(1.9), P(1.6), q[1], function(x, y) return (x + y) % 2 == 0 and '3' or '4' end)
  end
  L.outline(g, 'A', SOLID)
  -- o vão: contorno por dentro, a borda do Véu e a coroa, só no emissivo
  for _, pass in ipairs({ { 'A', function(q) return q ~= '.' and q ~= 'A' end, 12.4 }, { 'X', function(q) return q == 'A' end, 8.4 } }) do
    local add = {}
    for y = 0, S - 1 do
      for x = 0, S - 1 do
        if g[y][x] == '.' and sqrt((x - cx) ^ 2 + (y - cy) ^ 2) < P(pass[3]) then
          for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if pass[2](L.get(g, x + dd[1], y + dd[2])) then add[#add + 1] = { x, y }; break end
          end
        end
      end
    end
    for _, q in ipairs(add) do g[q[2]][q[1]] = pass[1] end
  end
  for n = 0, 35 do
    local a = rad(n * 10 + 3)
    local len = P(1.8 + (hash(n, 3, 7) % 4) * 0.8)
    for s = 0, floor(len) do
      local r = P(6.4) - s
      dot(g, cx + cos(a) * r, cy + sin(a) * r, 1, s == 0 and 's' or s < len * 0.6 and 'S' or 'N')
    end
  end
  -- brasas que caem para dentro
  for n = 0, 11 do
    local a = rad(n * 30 + 17)
    local r = P(22 + (hash(n, 9, 2) % 5))
    dot(g, cx + cos(a) * r, cy + sin(a) * r, k * 0.6, 's'); dot(g, cx + cos(a) * (r + P(1.4)), cy + sin(a) * (r + P(1.4)), k * 0.6, 'S')
    dot(g, cx + cos(a) * (r + P(2.8)), cy + sin(a) * (r + P(2.8)), k * 0.6, 'N')
  end
  return g
end

local function out(stage, kind, g) C.save('wyrm', stage, kind, g, LEG, LIT, LOOSE) end
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
print('ok wyrm')
