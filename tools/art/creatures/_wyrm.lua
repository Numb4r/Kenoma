-- Kit da arte final da família Wyrm (Dracônico): Wyrmlet (Eco), Wyrmkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar); aqui ficam a legenda, os emissivos e as formas dos conceitos aprovados
-- (tools/art/creatures/conceitos/wyrm/build.lua), agora com pose. Cada espécie dá draw(g, sg, k, o): o corpo em g
-- (emissivos ACESOS, sem contorno) e a faísca solta em sg; k é a escala (1 no mapa) e o é o quadro (ph fase do laço,
-- pose 'alert' | 'crouch', dy, lean, jump, portrait). As formas recebem coordenadas já em pixels (unidade * k).
-- TRAÇO DA FAMÍLIA: escama em brasa (escama escura com a junta acesa em volta).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Dracônico: d, m, l); o laranja do conceito saiu.
-- Bicho de chão (ownDy): o body_dy é o tronco que sobe com os pés plantados; na deriva anda, na fuga salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local C, L = K.C, K.L
local W = { L = L, C = C, hash = K.hash }
local floor, ceil, sqrt, abs, max, min = math.floor, math.ceil, math.sqrt, math.abs, math.max, math.min
local sin, cos, rad = math.sin, math.cos, math.rad
local hash = K.hash

local DR
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'draconic' then DR = c end end
local VEU = '#9B7BFF'

W.LEG = {
  A = '#1A1424',
  ['1'] = '#6A6670', ['2'] = '#4A4752', ['3'] = '#33313B', ['4'] = '#25232C', -- escama preta do teú
  c = '#BDB6A2', C = '#8F897B', w = '#C9C2A8',                                -- faixa e barriga cor de cinza
  p = '#5C5B60', P = '#45444A', Q = '#303036', g = '#7A7880',                 -- asfalto e a brita
  o = '#B89A3E', O = '#8A7430',                                               -- tinta de faixa, gasta
  e = '#6B4A3A', E = '#4A3229',                                               -- terra vermelha da cratera
  B = '#CFC9BA', D = '#A39E92', F = '#77736C', G = '#504D4C',                 -- cinza e osso (Arquétipo)
  k = '#D8D2C0', K = '#9C9484',                                               -- unha e dente
  j = '#4E2438', h = '#643046', r = '#3A1A2C',                                -- brasa apagada (corpo)
  J = DR.m, H = DR.l, R = DR.d,                                               -- brasa acesa (glow): junta, nó, fundo
  M = DR.m, T = DR.l,                                                         -- língua e olho (leds: piscam)
  S = DR.m, s = DR.l, N = DR.d,                                               -- fagulha solta (só no glow)
  v = '#3F3B4C', x = '#55525F', ['8'] = '#8C8780',                            -- costura apagada: escama, asfalto, barriga
  Z = VEU, X = VEU, ['9'] = VEU,                                              -- costura do Véu acesa (glow)
  z = '#120D1C',                                                              -- o vão apagado (mais escuro que o contorno)
  U = VEU, Y = '#5A45A8', V = DR.l, m = DR.m, d = DR.d,                       -- o vão do Arquétipo (glow)
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
W.LIT = {
  J = { 'j', 'w' }, H = { 'h', 'w' }, R = { 'r', 'w' }, M = { 'j', 'l' }, T = { 'h', 'l' },
  Z = { 'v', 'w' }, X = { 'x', 'w' }, ['9'] = { '8', 'w' },
  U = { 'z', 'w' }, Y = { 'z', 'w' }, V = { 'z', 'w' }, m = { 'z', 'w' }, d = { 'z', 'w' },
}
W.NOPULL = 'ASsNJHRMT'                                         -- a brasa e a língua não puxam contorno
W.SCALE = '1234cCwBDFG'                                       -- o que a costura pode cobrir no corpo
W.BODY_KEYS = { '1', '2', '3', '4', 'c', 'C', 'w', 'p', 'P', 'Q', 'g', 'o', 'O', 'e', 'E', 'B', 'D', 'F', 'G', 'k', 'K' }
W.DARK, W.FARLEG, W.ASHY = { '1', '2', '3', '4' }, { '3', '4', '4', '4' }, { 'D', 'F', 'G', '4' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): a brasa sobe um degrau da paleta.
function W.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'R' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'J'
    elseif c == 'J' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'H' end
  end end
end

function W.ell(g, cx, cy, rx, ry, deg, sh, mask)
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
function W.fillpoly(g, pts, sh, mask)
  local y0, y1 = math.huge, -math.huge
  for _, q in ipairs(pts) do y0 = min(y0, q[2]); y1 = max(y1, q[2]) end
  for y = max(0, floor(y0)), min(g.h - 1, ceil(y1)) do
    local xs = {}
    for i = 1, #pts do
      local a, b = pts[i], pts[i % #pts + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = max(0, ceil(xs[i] - 0.5)), min(g.w - 1, floor(xs[i + 1] + 0.5)) do
        local ch = sh(x, y)
        if ch then L.set(g, x, y, ch, mask) end
      end
    end
  end
end
-- Tubo que afina: path(t) -> x, y; w(t) -> raio; sh(x, y, t, dn, ds, r, l).
function W.tube(g, path, w, sh, t0, t1, mask)
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
function W.seg(x0, y0, x1, y1, bx, by)
  bx, by = bx or 0, by or 0
  return function(t)
    local s = 4 * t * (1 - t)
    return x0 + (x1 - x0) * t + bx * s, y0 + (y1 - y0) * t + by * s
  end
end
-- Curva de Catmull-Rom pelos pontos (já em pixels).
function W.spline(pts)
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
function W.scaled(pts, k, ox, oy)
  local out = {}
  for i, q in ipairs(pts) do out[i] = { q[1] * k + (ox or 0), q[2] * k + (oy or 0) } end
  return out
end
function W.prof(list, k)
  return function(t)
    for i = 1, #list - 1 do
      local a, b = list[i], list[i + 1]
      if t <= b[1] then return (a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])) * k end
    end
    return list[#list][2] * k
  end
end
function W.dirAt(path, t)
  local xa, ya = path(max(0, t - 0.01))
  local xb, yb = path(min(1, t + 0.01))
  local tx, ty = xb - xa, yb - ya
  local tl = sqrt(tx * tx + ty * ty)
  return tx / tl, ty / tl
end

-- Pele de teú: escama em xadrez de dois tons, faixas cor de cinza e, onde ember(t, dn) vale, a escama em brasa
-- (escama escura com a junta acesa). o = { p (px da escama), band (px), pal, ember, pale = false tira as faixas,
-- boff = deslocamento das faixas (o corpo escorre), tw = fase do brilho dos nós }.
function W.skin(o)
  local p, pal = o.p, o.pal or W.DARK
  local q = p + 2
  local off, tw = o.boff or 0, o.tw
  return function(x, y, t, dn, ds, r, l)
    local a, b = floor(ds), floor(dn * r + 60)
    if o.ember and o.ember(t, dn) then
      if a % q == 0 and b % q == 0 then return (tw and (a // q + b // q + tw) % 3 == 0) and 'J' or 'H' end
      if a % q == 0 or b % q == 0 then return 'J' end
      return ((a // q + b // q) % 2 == 0) and '4' or '3'
    end
    local chk = (a // p + b // p) % 2
    if l < -0.55 then return chk == 0 and 'C' or pal[3] end
    if o.pale ~= false and ((ds - off) % o.band) < o.band * 0.28 then return chk == 0 and (l > 0.35 and 'w' or 'c') or 'C' end
    return pal[(l > 0.35 and 1 or l > -0.2 and 2 or 3) + chk]
  end
end
function W.asphalt(lite)
  return function(x, y)
    local hh = hash(x, y, 11) % 7
    if lite then return hh == 0 and 'g' or hh < 4 and 'p' or 'P' end
    return hh == 0 and 'p' or hh < 4 and 'P' or 'Q'
  end
end

-- Cabeça de teú em (bx, by) (a nuca), apontando para ang, tamanho s. open: quanto a boca abre; eye: tem olho (leds);
-- tongue: 1 ou 2 línguas bifurcadas de brasa (leds), tl: quanto saem (0 a 1).
function W.head(g, bx, by, ang, s, o)
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
  local pal = o.pal or W.DARK
  local p = max(1, floor(s * 0.7))
  if op > 0 then W.fillpoly(g, pts({ { -0.5, 0.3 }, { 3.6, 0.2 }, { 3.4, 0.6 + op }, { -0.5, 0.9 } }), function() return 'R' end) end
  W.fillpoly(g, pts({ { -2.2, 0.8 }, { 0, 0.6 }, { 4, 0.5 + op }, { 3.7, 1.3 + op }, { 0.6, 1.9 + op * 0.5 }, { -1.8, 1.9 } }),
    function(x, y) return (x // p + y // p) % 2 == 0 and 'c' or 'C' end)
  W.fillpoly(g, pts({ { -2.4, 0.6 }, { -2.2, -1.5 }, { 0.5, -1.9 }, { 2.6, -1.3 }, { 4.2, -0.5 }, { 4.5, 0.3 }, { 0, 0.5 } }),
    function(x, y)
      local ly = (-(x - bx) * sa + (y - by) * ca) / s
      return pal[(ly < -0.9 and 1 or ly < -0.2 and 2 or 3) + (x // p + y // p) % 2]
    end)
  if o.eye then
    local ex, ey = pt(1.1, -0.8)
    if s < 1.6 then L.set(g, ex, ey, 'T')
    else L.disc(g, ex, ey, 0.42 * s, 'M'); L.disc(g, ex, ey, 0.24 * s, 'T'); L.line(g, ex, ey - 0.4 * s, ex, ey + 0.4 * s, '4') end
  end
  if s >= 1.6 then
    for i = 0, 5 do
      local x, y = pt(0.9 + i * 0.55, 0.5); L.set(g, x, y, 'k')
      if op > 0 then x, y = pt(0.9 + i * 0.55, 0.55 + op * (0.9 + i * 0.55) / 4); L.set(g, x, y, 'K') end
    end
    local nx, ny = pt(3.7, -0.4); L.set(g, nx, ny, '4')
  end
  local tl = o.tl or 1
  if tl > 0 then
    for n = 1, o.tongue or 0 do
      local dy = (n - 1) * 0.9 + op * 0.5
      local x0, y0 = pt(3.9, 0.45 + dy)
      local x1, y1 = pt(3.9 + 1.2 * tl, 0.5 + dy + (n - 1) * 0.5)
      L.line(g, x0, y0, x1, y1, 'M', '.')
      local xa, ya = pt(3.9 + 2.1 * tl, 0.5 - 0.7 * tl + dy + (n - 1) * 0.5)
      local xb, yb = pt(3.9 + 2.1 * tl, 0.5 + 0.7 * tl + dy + (n - 1) * 0.5)
      L.line(g, x1, y1, xa, ya, 'T', '.M'); L.line(g, x1, y1, xb, yb, 'T', '.M')
    end
  end
end
-- Perna: quadril, joelho, pé, e três dedos com unha apontando para dir (+1 ou -1). q em unidades do mapa.
function W.leg(g, q, k, pal, dir)
  local sh = W.skin({ p = max(1, floor(k * 0.7)), band = 99, pal = pal, pale = false })
  W.tube(g, W.seg(q[1] * k, q[2] * k, q[3] * k, q[4] * k), function(t) return (1.25 - 0.3 * t) * k end, sh)
  W.tube(g, W.seg(q[3] * k, q[4] * k, q[5] * k, q[6] * k), function(t) return (0.95 - 0.2 * t) * k end, sh)
  for _, d in ipairs({ -0.5, 0.3, 1.1 }) do
    -- dedo sujo de terra vermelha, unha clara
    L.line(g, q[5] * k, q[6] * k, (q[5] + dir * 1.9) * k, (q[6] + d * 0.9) * k, d > 1 and 'e' or 'K')
    L.set(g, (q[5] + dir * 1.9) * k, (q[6] + d * 0.9) * k, 'k')
  end
end
-- Placa de asfalto levantada: base em (bx, by), direção (nx, ny), largura w, altura h. paint: faixa de tinta.
function W.slab(g, bx, by, nx, ny, w, h, paint)
  local tx, ty = -ny, nx
  local a, d = W.asphalt(true), W.asphalt(false)
  W.fillpoly(g, { { bx - tx * w / 2, by - ty * w / 2 }, { bx + tx * w / 2, by + ty * w / 2 },
    { bx + tx * w * 0.32 + nx * h, by + ty * w * 0.32 + ny * h }, { bx - tx * w * 0.42 + nx * h * 0.8, by - ty * w * 0.42 + ny * h * 0.8 } },
    function(x, y)
      local u = ((x - bx) * nx + (y - by) * ny) / h
      local v = ((x - bx) * tx + (y - by) * ty) / w
      if paint and u > 0.3 and u < 0.56 then return (x + y) % 3 == 0 and 'O' or paint end
      if v > 0.18 then return d(x, y) end
      return a(x, y)
    end)
end

-- Costura do Véu: risco de wd px atravessando o tubo em t0, só por cima de mask (o material). skew inclina;
-- stitch (px): pontos atravessados, para o retrato.
function W.seam(g, path, w, t0, wd, ch, mask, skew, stitch)
  local x0, y0 = path(t0)
  local tx, ty = W.dirAt(path, t0)
  local r = w(t0)
  mask, skew = mask or W.SCALE, skew or 0
  for d = -r, r, 0.5 do
    local cx, cy = x0 - ty * d + tx * skew * d, y0 + tx * d + ty * skew * d
    local ext = (stitch and (d + r) % (stitch * 2) < 1) and stitch or 0
    for s = -(wd - 1) / 2 - ext, (wd - 1) / 2 + ext, 0.5 do L.set(g, cx + tx * s, cy + ty * s, ch, mask) end
  end
end

-- Faísca solta em sg (só no glow), onde o corpo está vazio e longe da borda. x, y em pixels.
function W.spark(g, sg, x, y, k, ch)
  local n = max(1, floor(k * 0.6 + 0.5))
  x, y = floor(x), floor(y)
  for j = 0, n - 1 do for i = 0, n - 1 do
    local px, py = x + i, y + j
    if px > 0 and py > 0 and px < sg.w - 1 and py < sg.h - 1 and g[py][px] == '.' then sg[py][px] = ch end
  end end
end
-- Fagulhas que sobem e somem. list = { { u, v, ch } } em unidades do mapa; NL = quadros do laço.
function W.dust(g, sg, list, ph, NL, k, ox, oy)
  for n, q in ipairs(list) do
    local r = (ph + n) % NL
    if r < NL - 1 then
      W.spark(g, sg, q[1] * k + (ox or 0), (q[2] - r * 0.9) * k + (oy or 0), k, q[3] or (n % 3 == 0 and 'N' or (n % 3 == 1 and 'S' or 's')))
    end
  end
end
-- Recorte do busto: apaga o que passa de uma moldura rasgada a m px da borda (o corpo não encosta no quadro).
function W.tear(g, m)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local e = min(x, y, g.w - 1 - x, g.h - 1 - y)
    if e < m + (hash(x // 3, y // 3, 17) % 3) then g[y][x] = '.' end
  end end
end
-- Fica só a maior peça (diagonal conta): o rasgo do busto pode soltar uma ponta de cauda.
function W.keepMain(g)
  local id, sizes, n = {}, {}, 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' and not id[y * g.w + x] then
      n = n + 1
      local st, sz = { { x, y } }, 0
      id[y * g.w + x] = n
      while #st > 0 do
        local q = table.remove(st)
        sz = sz + 1
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = q[1] + dx, q[2] + dy
          if L.get(g, nx, ny) ~= '.' and not id[ny * g.w + nx] then id[ny * g.w + nx] = n; st[#st + 1] = { nx, ny } end
        end end
      end
      sizes[n] = sz
    end
  end end
  local best = 1
  for i = 2, n do if sizes[i] > sizes[best] then best = i end end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' and id[y * g.w + x] ~= best then g[y][x] = '.' end
  end end
end
function W.count(g, chars)
  local n = 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do if chars:find(g[y][x], 1, true) then n = n + 1 end end end
  return n
end

function W.run(spec)
  spec.LEG = spec.LEG or W.LEG
  spec.LIT, spec.NOPULL, spec.heat = W.LIT, W.NOPULL, W.heat
  spec.BODY_KEYS = spec.BODY_KEYS or W.BODY_KEYS
  spec.DARK = spec.DARK or '4'
  spec.ownDy, spec.ownLean = true, true
  if not spec.over then
    spec.over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end }
  end
  return K.run(spec)
end

return W
