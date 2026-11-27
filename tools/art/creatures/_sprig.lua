-- Kit da arte final da família Sprig (Feérico): Sprigglet (Eco), Fairkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run). As formas são as dos conceitos aprovados (tools/art/creatures/conceitos/sprig/build.lua),
-- portadas para cá com pose: cada etapa é uma função de (k, S, a), em que a diz onde está cada parte naquele quadro
-- (asas, cabeça, respiração, inclinação). Sem a, a pose é a do conceito. A textura é no pixel (p = 1), também no
-- retrato. A Entidade Maior é a refeita pelo ajuste do dono (quatro cabeças de maritaca).
-- LUZ: só a do tipo (tools/art/ui/types/palette.lua, Feérico: O = d, W = m, L = l), pelo fae().
-- leds = o tom claro (L: o brilho do olho e a ponta das nervuras, pisca); glow = o resto (W, O), a costura e o vão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local L, C = K.L, K.C
local R = dofile(ART .. 'creatures/conceitos/_r2.lua')(C)
local hash = K.hash
local floor, ceil, sqrt, abs, max, min = math.floor, math.ceil, math.sqrt, math.abs, math.max, math.min
local sin, cos, rad, pi = math.sin, math.cos, math.rad, math.pi

local FA
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'fae' then FA = c end end

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
  h = '#6A4A58', g = '#3E2632',                                               -- pares apagados de L e de O (o de W é o e)
  -- J Y H I N: o pólen e o rosa do conceito, só de passagem no desenho (o fae() troca pela luz do tipo)
  J = '#CFEA6B', Y = '#F6FFC8', H = '#F5A3B5', I = '#FFE3EA', N = '#F5A3B5',
  W = '#FFA8E0', L = '#FFD6F1', O = '#C0669E',                                -- a luz do tipo Feérico
  M = '#FFA8E0', C = '#FFD6F1',                                               -- o pólen solto do desenho
  S = FA.m, s = FA.l,                                                         -- os soltos do K.run, na luz do tipo
  Z = '#9B7BFF', v = '#51465A',                                               -- costura do Véu e o par apagado
  X = '#9B7BFF', V = '#5A45A8', ['0'] = '#120D1C',                            -- o vão: borda, meio e o apagado
}
LEG.i = LEG.T; LEG.l = LEG.t                                                  -- graveto fino, sem contorno
-- o que puxa contorno no desenho (a nervura acesa e o solto não puxam)
local SOLID = '1234567uUrRkKqwabcdmnofFtTxzpPQBDEGjeyHIZv'

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
-- Pena: quatro tons, hachura de 1 px.
local function feather(pal)
  return function(x, y, u, v, l)
    local i = l > 0.4 and 1 or l > -0.15 and 2 or 3
    return pal[i + floor(y + x * 0.5) % 2]
  end
end
local function stripes(a, b)
  return function(x, y) return floor(x + y) % 2 == 0 and a or b end
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
local function bark(pal)
  return function(x, y, t, dn, ds, r, l)
    local i = l > 0.3 and 1 or l > -0.3 and 2 or 3
    return pal[i + floor(dn * r + ds * 0.3 + 50) % 2]
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
local function beak(g, bx, by, ang, s, lit)
  local a = rad(ang)
  local ca, sa = cos(a), sin(a)
  local function pts(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = { bx + s * (p[1] * ca - p[2] * sa), by + s * (p[1] * sa + p[2] * ca) } end
    return out
  end
  C.poly(g, pts({ { 0.2, 1.2 }, { 1.6, 1.3 }, { 1.9, 1.9 }, { 1.1, 2.7 }, { 0.2, 2.3 } }), 'K')
  if lit then C.poly(g, pts({ { 0.2, 0.9 }, { 1.7, 1.0 }, { 1.5, 1.5 }, { 0.2, 1.4 } }), 'H') end
  C.poly(g, pts({ { 0, -1.4 }, { 1.6, -1.5 }, { 2.7, -0.6 }, { 3.2, 0.8 }, { 2.9, 2.4 }, { 2.3, 1.3 }, { 1.6, 0.9 }, { 0.2, 0.9 } }), 'k')
  C.poly(g, pts({ { 2.3, 1.3 }, { 2.9, 2.4 }, { 3.2, 0.8 }, { 2.6, 0.5 } }), 'K')
  C.poly(g, pts({ { 0, -1.4 }, { 0.5, -1.4 }, { 0.5, 0.9 }, { 0, 0.9 } }), 'q')
  if s >= 2 then -- bico grande: a linha da boca e a narina
    local q = pts({ { 0.5, 0.9 }, { 1.7, 1.0 }, { 0.9, -0.5 } })
    L.line(g, q[1][1], q[1][2], q[2][1], q[2][2], lit and 'H' or 'q')
    L.set(g, q[3][1], q[3][2], 'q')
  end
end
-- Bico aberto, gritando: o de baixo caído, a garganta acesa entre os dois. f = -1 espelha (cabeça virada para trás);
-- gape 1 = todo aberto, 0 = quase fechado.
local function scream(g, bx, by, ang, s, f, gape)
  local a = rad(ang)
  local ca, sa = cos(a), sin(a)
  local c = (1 - (gape or 1)) * 1.3
  local function pts(list)
    local out = {}
    for i, q in ipairs(list) do out[i] = { bx + s * (q[1] * ca - q[2] * f * sa), by + s * (q[1] * sa + q[2] * f * ca) } end
    return out
  end
  C.poly(g, pts({ { 0, 0.6 }, { 2.1, 0.9 }, { 1.7, 2.6 - c }, { 0, 2.4 - c } }), 'H')
  C.poly(g, pts({ { 0, 2.1 - c }, { 1.5, 2.4 - c }, { 1.8, 3.1 - c }, { 0.9, 3.8 - c }, { 0, 3.3 - c } }), 'K')
  C.poly(g, pts({ { 0, -1.4 }, { 1.6, -1.5 }, { 2.7, -0.6 }, { 3.2, 0.8 }, { 2.9, 2.4 }, { 2.3, 1.3 }, { 1.6, 0.9 }, { 0, 0.9 } }), 'k')
  C.poly(g, pts({ { 2.3, 1.3 }, { 2.9, 2.4 }, { 3.2, 0.8 }, { 2.6, 0.5 } }), 'K')
  C.poly(g, pts({ { 0, -1.4 }, { 0.5, -1.4 }, { 0.5, 0.9 }, { 0, 0.9 } }), 'q')
end
local function eyeAt(g, x, y, k)
  if k <= 1 then
    L.set(g, x - 1, y, 'w'); L.set(g, x, y, 'H')
    return
  end
  L.disc(g, x, y, 0.8 * k, 'w'); L.disc(g, x, y, 0.5 * k, 'H'); L.disc(g, x + 0.1 * k, y - 0.1 * k, 0.2 * k, 'I')
end
-- Troca o pólen verde e o rosa do desenho pelos tons da paleta do tipo, depois do contorno.
local function fae(g)
  local M = { Y = 'L', H = 'W', I = 'L', S = 'M', s = 'C', N = 'M' }
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'J' then g[y][x] = (x + y) % 3 == 0 and 'O' or 'W' elseif M[c] then g[y][x] = M[c] end
  end end
end
-- Giro de (x, y) em volta de (cx, cy), em graus; com 0 devolve o próprio ponto (a pose do conceito não muda).
local function spin(x, y, cx, cy, deg)
  if deg == 0 then return x, y end
  local c, s = cos(rad(deg)), sin(rad(deg))
  return cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c
end
local function seamLine(g, x0, y0, x1, y1, w)
  for d = 0, w - 1 do L.line(g, x0, y0 + d, x1, y1 + d, 'Z', '1234567') end
end

-- ECO (Sprigglet): a maritaca em proporção natural, pairando; as duas asas são folhas secas com a nervura acesa.
-- a = { wn, wf = graus a mais na asa de cá e na de lá (negativo desce a de cá para trás); ln, lf = fator do
--   comprimento (a asa vindo para a frente encurta); wwn = fator da largura; hd = graus da cabeça (positivo: bico
--   para baixo), hx, hy = quanto ela anda; br = respiração (-1..1); tilt = graus do corpo inteiro (positivo: bico
--   para baixo); tail = graus do rabo (positivo: sobe) }
local function eco(k, S, a)
  a = a or {}
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local rich = k > 1
  local tl, hd, hx, hy, br = a.tilt or 0, a.hd or 0, a.hx or 0, a.hy or 0, a.br or 0
  local function pt(x, y)
    x, y = spin(x, y, 13.5, 17.5, tl)
    return x * k, y * k
  end
  local function hp(x, y)
    x, y = spin(x, y, 19.2, 11.8, hd)
    return pt(x + hx, y + hy)
  end
  local function E(f, x, y, rx, ry, ang, sh)
    local X, Y = f(x, y)
    ell(g, X, Y, P(rx), P(ry), ang + tl + (f == hp and hd or 0), sh)
  end
  local function wing(x, y, ang, len, wid, o)
    o.x, o.y = pt(x, y)
    o.ang, o.len, o.wid, o.k = ang + tl, P(len), P(wid), k
    leaf(g, o)
  end
  wing(16.5, 13.8, -68 + (a.wf or 0), 11 * (a.lf or 1), 3.4, { pal = FAR, notch = rich and 7 or nil, spots = rich and 3 or nil })
  -- cauda curta e o crisso vermelho
  do
    local x0, y0 = pt(9.5, 19.5)
    local x1, y1 = pt(spin(3.8, 23.3, 9.5, 19.5, a.tail or 0))
    tube(g, seg(x0, y0, x1, y1), function(t) return P(2 - 0.5 * t) end, function(x, y, t, dn, ds, r, l)
      return (floor(ds) % 2 == 0) and (l > 0 and '2' or '3') or (l > 0 and '3' or '4')
    end)
  end
  E(pt, 9.6, 21.6, 2.8, 1.3, -35, stripes('r', 'R'))
  -- pés recolhidos
  for _, q in ipairs({ { 15, 21, 16.2, 22.6 }, { 17.2, 20.6, 18.4, 22 } }) do
    local x0, y0 = pt(q[1], q[2])
    local x1, y1 = pt(q[3], q[4])
    wire(g, { { x0, y0 }, { x1, y1 } }, 'T', 'x', k * 0.8)
  end
  E(pt, 13.5, 17.5, 6.2, 4.3 + 0.35 * br, -28, feather(BODY))
  E(pt, 17.4, 14, 3, 2.6, -40, feather(BODY))
  E(hp, 19.2, 11.8, 3.3, 3.2, 0, feather(HEAD))
  E(hp, 20, 14.5, 2.1, 1.1, 20, stripes('u', 'U'))
  do
    local x, y = hp(22, 11.6)
    beak(g, x, y, tl + hd, k * 0.95)
    x, y = hp(20.6, 11)
    eyeAt(g, x, y, k)
  end
  wing(14, 15.8, -125 + (a.wn or 0), 15 * (a.ln or 1), 4.2 * (a.wwn or 1), { pal = NEAR, notch = rich and 11 or nil,
    litv = rich and 0.4 or nil, spots = rich and 3 or nil })
  -- coberteiras por cima do pecíolo
  E(pt, 14.6, 16.2, 2.3, 1.6, -28, feather(BODY))
  L.outline(g, 'A', SOLID)
  dot(g, P(3), P(8), k * 0.6); dot(g, P(12), P(2.6), k * 0.6, 's'); dot(g, P(24.5), P(5), k * 0.6)
  dot(g, P(2.5), P(15), k * 0.6, 'N'); dot(g, P(24), P(19), k * 0.6); dot(g, P(6.5), P(16), k * 0.6, 's')
  if rich then plus(g, P(22.5), P(23), 2); plus(g, P(3), P(3.5), 2) end
  fae(g)
  -- costuras do Véu: três, curtas e de 1 px, na pena do corpo (duas) e da cabeça (uma)
  for _, q in ipairs({ { pt, 13, 17, 15, 18 }, { pt, 16.4, 19.4, 18.4, 20.4 }, { hp, 19, 12.4, 20.6, 13.2 } }) do
    local x0, y0 = q[1](q[2], q[3])
    local x1, y1 = q[1](q[4], q[5])
    seamLine(g, x0, y0, x1, y1, 1)
  end
  return g
end

-- ESPÍRITO (Fairkin): a maritaca tomada pela árvore de calçada. Quatro asas de folha (uma já só nervura), dois olhos
-- do mesmo lado, uma folha de topete, casca subindo pela barriga e as raízes agarradas a um caco de pedra portuguesa.
-- a = { w = { lá, nervura, escura, cá } graus a mais em cada asa; l = fatores do comprimento; hd, hx, hy = a cabeça
--   (como no Eco); top = graus da folha de topete; br = respiração; tilt = graus do corpo sobre as raízes (a pedra
--   fica); sq = quanto o corpo desce sobre a pedra; tw = quanto o rabo de graveto balança (px do mapa) }
local function espirito(k, S, a)
  a = a or {}
  local g = L.grid(S, S)
  local function P(v) return v * k end
  local rich = k > 1
  local tl, hd, hx, hy, br, sq = a.tilt or 0, a.hd or 0, a.hx or 0, a.hy or 0, a.br or 0, a.sq or 0
  local w, l = a.w or { 0, 0, 0, 0 }, a.l or { 1, 1, 1, 1 }
  local function pt(x, y)
    x, y = spin(x, y, 16.5, 27, tl)
    return x * k, (y + sq) * k
  end
  local function hp(x, y)
    x, y = spin(x, y, 21.5, 11.5, hd)
    return pt(x + hx, y + hy)
  end
  local function E(f, x, y, rx, ry, ang, sh)
    local X, Y = f(x, y)
    ell(g, X, Y, P(rx), P(ry), ang + tl + (f == hp and hd or 0), sh)
  end
  local function wing(f, x, y, ang, len, wid, o)
    o.x, o.y = f(x, y)
    o.ang, o.len, o.wid, o.k = ang + tl, P(len), P(wid), k
    leaf(g, o)
  end
  wing(pt, 18, 15, -62 + w[1], 11.5 * l[1], 3.4, { pal = FAR, notch = rich and 5 or nil, spots = rich and 3 or nil })
  -- rabo de graveto
  do
    local tw = a.tw or 0
    local x0, y0 = pt(12.5, 24)
    wire(g, { { x0, y0 }, { P(8.5), P(26.4 + tw * 0.5) }, { P(5.5), P(27.2 + tw) } }, 'i', 'l', k * 0.7)
    leaf(g, { x = P(8.5), y = P(26.4 + tw * 0.5), ang = 150 - tw * 12, len = P(5), wid = P(1.5), pal = NEAR, k = k, vp = 99 })
  end
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
  -- raízes: saem do corpo (que se mexe) e seguram a pedra (que fica)
  for _, q in ipairs({ { 15.4, 25.5, 12.5, 29.6, -1 }, { 17.6, 26, 19.5, 29.2, 0.6 }, { 16.4, 26, 16, 29.6, 0 } }) do
    local x0, y0 = pt(q[1], q[2])
    tube(g, seg(x0, y0, P(q[3]), P(q[4]), P(q[5]), 0), function(t) return P(1 - 0.4 * t) end, bark(BARK))
  end
  wire(g, { { P(12.5), P(29.6) }, { P(11.2), P(31) }, { P(11.6), P(33) } }, 'i', 'l', k * 0.7)
  wire(g, { { P(19.5), P(29.2) }, { P(21.5), P(30) }, { P(22), P(32.6) } }, 'i', 'l', k * 0.7)
  -- corpo: pena em cima, casca tomando a barriga
  local fb = feather(BODY)
  E(pt, 16.5, 20.5, 7, 4.6 + 0.35 * br, -62, function(x, y, u, v, lt)
    local edge = u + v * 0.6 + ((hash(x, y, 4) % 5) - 2) * 0.06
    if edge < -0.15 then
      local i = lt > 0.3 and 1 or lt > -0.3 and 2 or 3
      return BARK[i + floor(x + y * 0.3) % 2]
    end
    return fb(x, y, u, v, lt)
  end)
  E(hp, 21.5, 11.5, 3.6, 3.5, 0, feather(HEAD))
  E(hp, 21.6, 14.6, 2.3, 1.2, 25, stripes('u', 'U'))
  do
    local x, y = hp(24.4, 11.2)
    beak(g, x, y, 8 + tl + hd, k * 1.1, true)
    x, y = hp(23, 10.2); eyeAt(g, x, y, k)
    x, y = hp(21.4, 12.6); eyeAt(g, x, y, k)
  end
  wing(hp, 20.6, 8.8, -100 + hd + (a.top or 0), 5, 1.5, { pal = FRESH, vp = 99 })
  -- as asas de perto: a que já é só nervura, a seca escura e a seca maior
  wing(pt, 14.5, 18, 150 + w[2], 12.5 * l[2], 3.4, { pal = FAR, skel = true, vp = max(3, k * 1.5) })
  wing(pt, 14.5, 17.2, -168 + w[3], 13 * l[3], 3.6, { pal = DARK, notch = rich and 2 or nil,
    litv = rich and 0.35 or nil, spots = rich and 3 or nil })
  wing(pt, 14.8, 16.6, -122 + w[4], 15 * l[4], 4.2, { pal = NEAR, notch = rich and 13 or nil,
    litv = rich and 0.4 or nil, spots = rich and 3 or nil })
  E(pt, 15.4, 17.2, 2.4, 1.7, -50, feather(BODY))
  L.outline(g, 'A', SOLID)
  dot(g, P(3), P(6), k * 0.6); dot(g, P(13), P(1.5), k * 0.6, 's'); dot(g, P(29), P(5), k * 0.6); dot(g, P(2), P(13), k * 0.6, 'N')
  dot(g, P(4), P(31), k * 0.6, 's'); dot(g, P(29), P(18), k * 0.6); dot(g, P(27.5), P(26), k * 0.6, 'N'); dot(g, P(31), P(11), k * 0.6, 's')
  if rich then plus(g, P(30), P(22), 2); plus(g, P(6), P(3), 2) end
  fae(g)
  -- costuras do Véu: duas, mais largas que as do Eco, na pena do corpo
  for _, q in ipairs({ { 19, 17, 21.4, 19 }, { 20, 22, 22.4, 24 } }) do
    local x0, y0 = pt(q[1], q[2])
    local x1, y1 = pt(q[3], q[4])
    seamLine(g, x0, y0, x1, y1, rich and 3 or 2)
  end
  return g
end

-- ENTIDADE MAIOR (arte final, ajuste do dono): o bando fundido num corpo só de pena verde-oliva. Quatro cabeças de
-- maritaca, cada uma no seu pescoço e virada para um lado (para cima, para a frente, para baixo e para trás), com o
-- anel do olho, a mancha azul e o bico cor de chifre; a da frente grita, com a garganta acesa. A folha seca fica só
-- nas duas asas. Dois rabos com o crisso vermelho, pés que se seguram, e a costura larga no peito.
-- a = { t = fase (0 a 2 pi), flap = -1..1, crouch }
local function entidade(k, S, a)
  local d = R.ctx(S, k)
  local g = d.g
  local function P(v) return v * k + (k - 1) / 2 end
  local rich = k > 1
  local t = a.t or 0
  local flap = a.flap or sin(t)
  local function head(x, y, r, ang, s, nx, ny, open)
    local an = rad(ang)
    local f = cos(an) < 0 and -1 or 1
    tube(g, seg(P(nx), P(ny), P(x), P(y)), function(tt) return k * r * (1 - 0.3 * sin(pi * tt)) * 0.7 end, function(x2, y2, tt, dn, ds, rr, l)
      return feather(BODY)(x2, y2, 0, 0, l)
    end)
    ell(g, P(x), P(y), k * r, k * r * 0.94, 0, feather(HEAD))
    ell(g, P(x - sin(an) * f * r * 0.75 + cos(an) * r * 0.2), P(y + cos(an) * f * r * 0.75 + sin(an) * r * 0.2), k * r * 0.62, k * r * 0.32, ang, stripes('u', 'U'))
    scream(g, P(x + cos(an) * r * 0.62), P(y + sin(an) * r * 0.62), ang, k * s, f)
    local ex, ey = P(x + cos(an) * r * 0.2 + sin(an) * f * r * 0.38), P(y + sin(an) * r * 0.2 - cos(an) * f * r * 0.38)
    L.disc(g, ex, ey, 1.15 * k, 'w'); L.disc(g, ex, ey, 0.62 * k, 'z')          -- olho de maritaca: pequeno, escuro, anel claro fino
    L.set(g, ex - (rich and 1 or 0), ey - 1, 'I')                              -- o brilho, 1 px
  end
  local function wing(x, y, ang, len, pal, n, wid)
    leaf(g, { x = P(x), y = P(y), ang = ang, len = k * len, wid = k * (wid or 3.6), pal = pal, k = k, notch = rich and n or nil,
      spots = rich and 3 or nil, litv = 0.64 })
  end
  local function bob(n) return a.crouch and 1 or 0.8 * sin(t + n * 1.6) end
  wing(21, 25, -96 + flap * 9, 19.6, FAR, 1)                                           -- a asa de lá
  for _, q in ipairs({ { 14, 31, 6, 38 }, { 17.6, 34, 12.6, 41 } }) do                 -- dois rabos, com o crisso vermelho
    tube(g, seg(P(q[1]), P(q[2]), P(q[3]), P(q[4])), function(tt) return k * (2 - 0.5 * tt) end, function(x, y, tt, dn, ds, r, l)
      return (floor(ds) % 2 == 0) and (l > 0 and '2' or '3') or (l > 0 and '3' or '4')
    end)
    ell(g, P(q[1] - 1.6), P(q[2] + 2.6), k * 2.4, k * 1.2, -40, stripes('r', 'R'))
  end
  for _, q in ipairs({ { 19, 34, 20.6, 39 }, { 23, 35, 20.6, 39 }, { 20.6, 39, 19, 42 }, { 20.6, 39, 22.6, 41.6 } }) do   -- pés que se seguram
    wire(g, { { P(q[1]), P(q[2]) }, { P(q[3]), P(q[4]) } }, 'T', 'x', k * 0.8)
  end
  head(30, 37.4 + bob(3) * 0.5, 3.4, 62, 1.1, 25, 33, true)                           -- a de baixo
  ell(g, P(22), P(29), k * 8.6, k * 6.6, -10, feather(BODY))                          -- o corpo: os peitos num só
  head(35.6, 12.4 + bob(1), 4.3, -22, 1.4, 27, 24, true)                              -- a de cima
  head(36, 29 + bob(2), 4.8, 6, 1.5, 28, 29, true)                                    -- a da frente, gritando
  d:suture({ { 21.6, 24 }, { 24, 29 }, { 22.4, 33.6 } }, 'Z', 2.2, rich and 3 or nil, '1234')
  wing(19.6, 26.4, -138 - flap * 9, 20, NEAR, 9, 5)                                   -- a asa de cá
  ell(g, P(20), P(27.6), k * 3, k * 2.1, -30, feather(BODY))
  head(10.4, 22.6 + bob(0), 4.1, 184, 1.25, 15.6, 27, true)                           -- e a virada para trás
  L.outline(g, 'A', SOLID .. 'JY')
  fae(g)
  for n, q in ipairs({ { 4, 8 }, { 44, 9 }, { 42.6, 36 }, { 3, 33 }, { 36, 4 }, { 10, 4.6 }, { 44.6, 42 }, { 15, 45 }, { 38.6, 44.6 }, { 2.6, 43 }, { 24, 5 }, { 30, 3.6 }, { 45, 22 }, { 2.6, 14 }, { 8, 40 }, { 40, 40 }, { 18, 3 }, { 46, 30 }, { 1.6, 26 }, { 32, 45.4 }, { 12, 9 }, { 41, 3 }, { 6, 17 }, { 27, 45 }, { 46, 16 }, { 20, 2.6 } }) do
    dot(g, P(q[1]), P(q[2]), k * 0.6, n % 3 == 0 and 'C' or 'M')
  end
  return g
end

-- ARQUÉTIPO: o bando inteiro como uma criatura só, sem corpo. Seis maritacas cinza, sem olho, de tamanhos diferentes,
-- cada uma gritando para um lado, e os pescoços delas saem todos de um mesmo anel de pena. Dentro do anel, onde
-- ficaria o coração, não há peito: o vão. As asas são folhas mortas que da metade para a ponta são só nervura.
-- a = { t = fase do laço (0 a 2 pi); amp = quanto as cabeças se mexem (0 = paradas, a pose do conceito); reach = px
--   que os pescoços esticam (negativo encolhe); gape = bicos (1 abertos, 0 fechados; sem ele cada um abre e fecha no
--   seu passo); flap = graus das asas; inner = caractere das cabeças de dentro do vão (o retrato usa outro) }
-- cabeça = { ângulo no anel, distância, raio, bico, para onde grita }
local HEADS = { { -150, 15, 3, 1.1, 205 }, { -98, 15, 3.4, 1.25, -78 }, { 98, 14.6, 3.3, 1.2, 84 }, { -46, 17, 4.1, 1.5, -28 },
  { 44, 16.6, 3.9, 1.45, 32 }, { -3, 17.6, 5.4, 1.9, 2 } }
local function arquetipo(k, S, ox, oy, a)
  a = a or {}
  local d = R.ctx(S, k, ox, oy)
  local g = d.g
  local function PX(v) return d:X(v) end
  local function PY(v) return d:Y(v) end
  local t, am, fl = a.t or 0, a.amp or 0, a.flap or 0
  local CX, CY = 34, 32.6
  local ASHL, ASHD = { 'D', 'E', 'G', 'E' }, { 'D', 'E', 'G', 'G' }
  local ashf, ashd = feather(ASH), feather(ASHD)
  local function pol(an, r) return CX + cos(rad(an)) * r, CY + sin(rad(an)) * r end
  -- uma do bando: o pescoço sai do anel e leva a cabeça; cada uma balança, estica, vira e grita na sua fase
  local function one(i, q)
    local f1 = t + i * 2.2
    local dd = (a.reach or 0) + am * 1.3 * sin(f1 + 1.3)
    if i == 6 then dd = min(dd, 0) end                          -- a maior já está no limite do quadro: só encolhe
    local hx, hy = pol(q[1] + am * 6 * sin(f1), q[2] + dd)
    local nx, ny = pol(q[1], 10)
    local r, face = q[3], q[5] + am * 13 * sin(f1 + 2.4)
    local gape = a.gape or (am > 0 and 0.55 + 0.45 * sin(2 * t + i * 1.7) or 1)
    local an = rad(face)
    local f = cos(an) < 0 and -1 or 1
    tube(g, seg(PX(nx), PY(ny), PX(hx), PY(hy)), function(tt) return k * r * (0.95 - 0.3 * sin(pi * tt)) end, function(x2, y2, tt, dn, ds, rr, l)
      return ashf(x2, y2, 0, 0, l)
    end)
    ell(g, PX(hx), PY(hy), k * r, k * r * 0.94, 0, ashd)
    ell(g, PX(hx - cos(an) * r * 0.3 + sin(an) * f * r * 0.5), PY(hy - sin(an) * r * 0.3 - cos(an) * f * r * 0.5), k * r * 0.62, k * r * 0.36, face, stripes('6', '7'))
    ell(g, PX(hx - sin(an) * f * r * 0.75 + cos(an) * r * 0.2), PY(hy + cos(an) * f * r * 0.75 + sin(an) * r * 0.2), k * r * 0.6, k * r * 0.3, face, stripes('u', 'U'))
    scream(g, PX(hx + cos(an) * r * 0.62), PY(hy + sin(an) * r * 0.62), face, k * q[4], f, gape)
  end
  -- as asas: folha morta, da metade para a ponta só nervura; cada uma bate no seu passo
  for n, q in ipairs({ { -160, 23 }, { -134, 21 }, { 174, 24 }, { 150, 21 }, { 126, 16 }, { -112, 15 } }) do
    local x, y = pol(q[1], 8)
    leaf(g, { x = PX(x), y = PY(y), ang = q[1] + (n % 2 == 0 and 5 or -4) + fl * (n % 2 == 0 and -0.6 or 1) + am * 4 * sin(t + n * 1.3),
      len = k * q[2], wid = k * 5.2, pal = n % 2 == 0 and { 'B', 'D', 'E', 'G' } or ASHL, k = k,
      skel = true, skelFrom = 0.66, litv = 0.3, vp = max(3, k * 1.5) })
  end
  -- dois rabos, o crisso ainda vermelho
  for n, an in ipairs({ 163, 200 }) do
    local x0, y0 = pol(an, 10)
    local x1, y1 = pol(an + 6 + am * 5 * sin(t + n * 2.5), 21)
    tube(g, seg(PX(x0), PY(y0), PX(x1), PY(y1)), function(tt) return k * (2.2 - 0.7 * tt) end, function(x, y, tt, dn, ds, r, l)
      return (floor(ds) % 2 == 0) and (l > 0 and 'D' or 'E') or (l > 0 and 'E' or 'G')
    end)
    local xr, yr = pol(an - 8, 13.6)
    ell(g, PX(xr), PY(yr), k * 2.2, k * 1.1, an, stripes('r', 'R'))
  end
  -- o anel de pena de onde saem os pescoços
  ell(g, PX(CX), PY(CY), k * 12.6, k * 10.6, 0, ashf)
  for i, q in ipairs(HEADS) do one(i, q) end
  L.outline(g, 'A', SOLID .. 'JY')
  fae(g)
  -- o vão, onde ficaria o coração: a borda dele ondula no passo dele (os três lóbulos giram), e dentro as cabeças se
  -- repetem, viradas para dentro, afundando e voltando duas vezes por laço
  local function hole(u, v)
    local an = math.atan(v - CY, u - CX)
    local r = sqrt((u - CX) ^ 2 + ((v - CY) * 1.1) ^ 2) / (7.4 + 1.2 * sin(an * 3 + 0.6 + am * t) + 0.7 * sin(an * 5 - am * t))
    return r <= 1 and r or nil
  end
  d:vao(hole, 'X', 'V', 0.8)
  for n, q in ipairs({ { -78, 4.6, 1.6 }, { 104, 4.4, 1.5 }, { -2, 4.8, 2 }, { -168, 4.6, 1.3 } }) do
    local sink = am * sin(2 * t + n * 1.7)
    local ia, ir, rr = q[1] + am * 9 * sin(2 * t + n), q[2] - 0.9 * sink, q[3] * (1 - 0.18 * sink)
    local hx, hy = pol(ia, ir)
    local tg = L.grid(S, S)
    L.disc(tg, PX(hx), PY(hy), k * rr, 'X')
    L.disc(tg, PX(hx), PY(hy), k * rr - max(1, k * 0.5), '.')
    local bx, by = pol(ia, ir - rr - 0.6)
    L.disc(tg, PX(bx), PY(by), max(0.6, k * 0.6), 'X')
    for y = 0, S - 1 do for x = 0, S - 1 do
      if tg[y][x] == 'X' and (g[y][x] == '.' or g[y][x] == 'V') then g[y][x] = a.inner or 'X' end
    end end
  end
  for n = 0, 17 do
    local an, r = n * 2.4, 26 + (n * 7) % 5
    d:dot(31 + cos(an) * r * 1.08, 31.5 + sin(an) * r, n % 3 == 0 and 'C' or 'M')
  end
  return g
end

local Sp = { L = L, K = K, hash = hash, LEG = LEG }
Sp.C = { eco = eco, espirito = espirito, entidade = entidade, arquetipo = arquetipo, LEG = LEG }
Sp.LIT = {
  W = { 'e', 'w' }, L = { 'h', 'l' }, O = { 'g', 'w' }, Z = { 'v', 'w' }, X = { '0', 'w' }, V = { '0', 'w' },
}
Sp.NOPULL = 'AilSsMCJYHIN'
Sp.BODY_KEYS = { '1', '2', '3', '4', '5', '6', '7', 'u', 'U', 'r', 'R', 'k', 'K', 'q', 'w', 'a', 'b', 'c', 'd', 'm', 'n', 'o', 'f', 'F',
  't', 'T', 'x', 'z', 'p', 'P', 'Q', 'B', 'D', 'E', 'G' }
local LOOSE = 'MC'

function Sp.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'O' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'W'
    elseif c == 'W' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'L' end
  end end
end

-- Põe o quadro desenhado (src) em g e sg: o pólen solto vai para sg, subindo e sumindo no passo dele.
-- a = { ph, NL, k, sway = px no topo (a Entidade e o Arquétipo inclinam assim na deriva), piv = linha (unidades) onde
-- o balanço zera, squash, dark, hot }.
function Sp.place(g, sg, src, a)
  local k, ph, NL = a.k, a.ph, a.NL
  local piv = floor((a.piv or src.h / k * 0.75) * k)
  if a.hot and a.hot > 0 then Sp.heat(src, a.hot) end
  local n = 0
  for y = 0, src.h - 1 do
    local dx = (a.sway and y < piv) and floor(a.sway * (piv - y) / piv + 0.5) or 0
    local dy = (a.squash and y < piv) and a.squash or 0
    for x = 0, src.w - 1 do
      local c = src[y][x]
      if c ~= '.' then
        if LOOSE:find(c, 1, true) then                           -- o pólen solto sobe e some
          n = n + 1
          local r = (ph + n) % NL
          if r < NL - 1 then L.set(sg, x, y - floor(r * 0.8 * k), c == 'C' and 's' or 'S') end
        elseif not (a.dark and c == 'A') then
          L.set(g, x + dx, y + dy, c)
        end
      end
    end
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do if g[y][x] ~= '.' then sg[y][x] = '.' end end end
end

function Sp.run(spec)
  spec.LEG = spec.LEG or Sp.LEG
  spec.LIT, spec.heat = Sp.LIT, Sp.heat
  spec.NOPULL = spec.NOPULL or Sp.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or Sp.BODY_KEYS
  spec.DARK = spec.DARK or '4'
  spec.ownLean = true
  return K.run(spec)
end

Sp.H = { ell = ell, feather = feather, stripes = stripes, tube = tube, bark = bark, seg = seg, leaf = leaf, wire = wire, dot = dot,
  plus = plus, beak = beak, fae = fae, spin = spin, seamLine = seamLine, NEAR = NEAR, FAR = FAR, DARK = DARK, BODY = BODY,
  HEAD = HEAD, BARK = BARK, SOLID = SOLID }

return Sp
