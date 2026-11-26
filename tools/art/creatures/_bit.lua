-- Kit da arte final da família Bit (Digital): Bitling (Eco), Glitchkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run). As formas são as dos conceitos aprovados (tools/art/creatures/conceitos/bit/build.lua),
-- agora com pose: cada espécie dá draw(g, sg, k, o), o corpo em g (emissivos ACESOS) e o pixel solto em sg.
-- LUZ: só a do tipo (tools/art/ui/types/palette.lua, Digital: Q = d, P = m, R = l). O magenta do pescoço do pombo é
-- cor de pena (N, corpo), não luz: a ponta da faixa fora do lugar é N de um lado e P do outro (o traço da família).
-- leds = os subpixels do pescoço (G, piscam); glow = a franja do glitch, as telas, a costura, o vão e o pixel solto.
-- TEXTURA: no mapa, xadrez de 1 px; no retrato, pena em escamas e matriz de LED em passo de 3 (nunca bloco de 2).
-- Bicho de chão: o tronco sobe e desce (o.dy) e os pés ficam; só no salto da fuga (o.jump) sai tudo do chão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local L = K.L
local B = { L = L, K = K, hash = K.hash }
local floor, ceil, sqrt, abs, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max, math.sin, math.cos, math.rad

local DG
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'digital' then DG = c end end
local VEU = '#9B7BFF'

B.LEG = {
  A = '#1A1424',
  a = '#33373F', b = '#4E5560', c = '#6E7783', d = '#959DA8', e = '#BBC1C8', -- pena cinza-azulada
  f = '#26282F',                                              -- barras da asa e ponta da cauda
  i = '#8A5459', j = '#B57A7C',                               -- pés
  h = '#C9C4BE', q = '#3A3840', r = '#B0603A',                -- cera do bico, bico, olho
  ['1'] = '#1D1F26', ['2'] = '#2C2F38', ['3'] = '#40444F', ['4'] = '#59606B', -- vidro e moldura da tela
  N = '#A45C92',                                              -- o magenta do pescoço (pena, não luz)
  o = '#2A3320', k = '#1F2A1A', l = '#454C3A',                -- pixel apagado (corpo)
  G = DG.m,                                                   -- subpixel do pescoço (leds: pisca)
  P = DG.m, Q = DG.d, R = DG.l,                               -- pixel aceso (glow)
  p = DG.m, y = DG.d, t = DG.l, S = DG.m, s = DG.l,           -- pixel solto (só no glow; S e s são os do K.run)
  s = '#555A6C', Z = VEU,                                     -- costura do Véu apagada e acesa (glow)
  O = '#120D1C',                                              -- o vão apagado (mais escuro que o contorno)
  X = VEU, Y = '#5A45A8', U = DG.m, V = DG.l,                 -- o vão do Arquétipo (glow)
}
B.LIT = {
  G = { 'o', 'l' }, P = { 'o', 'w' }, Q = { 'k', 'w' }, R = { 'l', 'w' }, Z = { 's', 'w' },
  X = { 'O', 'w' }, Y = { 'O', 'w' }, U = { 'O', 'w' }, V = { 'O', 'w' },
}
B.NOPULL = 'ApytSs'
B.SOLID = ''
for ch in pairs(B.LEG) do if not B.NOPULL:find(ch, 1, true) then B.SOLID = B.SOLID .. ch end end
B.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'f', 'i', 'j', 'h', 'q', '1', '2', '3', '4', 'N' }

function B.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'Q' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'P'
    elseif c == 'P' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'R' end
  end end
end

function B.rnd(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ ((s or 0) * 83492791)
  v = v ~ (v >> 13)
  return ((v * 1274126177) & 0x7fffffff) / 0x7fffffff
end
local rnd = B.rnd
local function pick(pal, v, st)
  local i2 = floor(max(0, min(1, v)) * (#pal - 2) + 0.5) + (st and 1 or 0)
  return pal:sub(i2 + 1, i2 + 1)
end
B.pick = pick
function B.chk(p) return function(x, y) return (floor(x / p) + floor(y / p)) % 2 == 0 end end
-- Pena: xadrez de 1 px no mapa; no retrato, escamas de 4 x 3 em fileiras alternadas (a aresta de baixo escura).
function B.plume(k)
  if k < 1.5 then return B.chk(1) end
  return function(x, y)
    local row = floor(y / 3)
    local xx = (x + (row % 2) * 2) % 4
    return y % 3 == 2 and xx ~= 0 or (y % 3 == 1 and xx == 0)
  end
end
function B.th(k, w) return max(1, floor(k * (w or 1) + 0.5)) end
local TH = B.th

local function put(g, x, y, fn, mask)
  local ch = type(fn) == 'function' and fn(x, y) or fn
  if ch then L.set(g, x, y, ch, mask) end
end
function B.ell(g, cx, cy, rx, ry, fn, mask)
  for y = floor(cy - ry), ceil(cy + ry) do
    for x = floor(cx - rx), ceil(cx + rx) do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then put(g, x, y, fn, mask) end
    end
  end
end
function B.cap(g, x0, y0, x1, y1, r0, r1, fn, mask)
  local dx, dy = x1 - x0, y1 - y0
  local l2, R = dx * dx + dy * dy, max(r0, r1)
  for y = floor(min(y0, y1) - R), ceil(max(y0, y1) + R) do
    for x = floor(min(x0, x1) - R), ceil(max(x0, x1) + R) do
      local t = l2 == 0 and 0 or max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / l2))
      if (x - x0 - dx * t) ^ 2 + (y - y0 - dy * t) ^ 2 <= (r0 + (r1 - r0) * t) ^ 2 then put(g, x, y, fn, mask) end
    end
  end
end
function B.polyf(g, pts, fn, mask)
  local y0, y1 = math.huge, -math.huge
  for _, q2 in ipairs(pts) do y0 = min(y0, q2[2]); y1 = max(y1, q2[2]) end
  for y = floor(y0), ceil(y1) do
    local xs = {}
    for i2 = 1, #pts do
      local a, b = pts[i2], pts[i2 % #pts + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i2 = 1, #xs - 1, 2 do
      for x = ceil(xs[i2] - 0.5), floor(xs[i2 + 1] + 0.5) do put(g, x, y, fn, mask) end
    end
  end
end
function B.wire(g, pts, a, b, th, mask)
  th = th or 1
  local nn, o = 0, (th - 1) / 2
  for i2 = 1, #pts - 1 do
    local x0, y0, x1, y1 = pts[i2][1], pts[i2][2], pts[i2 + 1][1], pts[i2 + 1][2]
    local mm = max(abs(x1 - x0), abs(y1 - y0))
    for s2 = 0, floor(mm) do
      local t = mm == 0 and 0 or s2 / mm
      nn = nn + 1
      local ch = (b and (nn // th) % 3 == 0) and b or a
      local x, y = floor(x0 + (x1 - x0) * t - o + 0.5), floor(y0 + (y1 - y0) * t - o + 0.5)
      for ddy = 0, th - 1 do for ddx = 0, th - 1 do L.set(g, x + ddx, y + ddy, ch, mask) end end
    end
  end
end
function B.blit(dst, src, ox, oy)
  for y = 0, src.h - 1 do for x = 0, src.w - 1 do
    if src[y][x] ~= '.' then L.set(dst, x + (ox or 0), y + (oy or 0), src[y][x]) end
  end end
end
-- camada: desenha à parte, contorna e cola por cima (o contorno separa do que está atrás)
function B.layer(g, draw, solid)
  local t = L.grid(g.w, g.h)
  draw(t)
  L.outline(t, 'A', solid or B.SOLID)
  B.blit(g, t)
  return t
end
local function lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end

-- O glitch: as linhas y0..y1 inteiras andam dx de lado; a ponta de trás fica magenta (pena) e a da frente acesa.
-- tips = false: só anda (o balanço da cabeça).
function B.tear(g, y0, y1, dx, tips)
  if dx == 0 then return end
  for y = max(0, floor(y0)), min(g.h - 1, floor(y1)) do
    local row, lo, hi = {}, nil, nil
    for x = 0, g.w - 1 do row[x] = '.' end
    for x = 0, g.w - 1 do
      local nx = x + dx
      if g[y][x] ~= '.' and nx >= 2 and nx <= g.w - 3 then   -- sobra 1 px para o contorno
        row[nx] = g[y][x]
        lo = lo and min(lo, nx) or nx; hi = hi and max(hi, nx) or nx
      end
    end
    if lo and tips ~= false then row[lo] = 'N'; row[hi] = 'P' end
    for x = 0, g.w - 1 do g[y][x] = row[x] end
  end
end
-- Fica só a peça maior (8 vizinhos); o que se soltou do corpo some.
function B.keepMain(t)
  local seen, comps = {}, {}
  for y = 0, t.h - 1 do for x = 0, t.w - 1 do
    if t[y][x] ~= '.' and not seen[y * t.w + x] then
      local list, stack = {}, { { x, y } }
      seen[y * t.w + x] = true
      while #stack > 0 do
        local q2 = table.remove(stack)
        list[#list + 1] = q2
        for ddy = -1, 1 do for ddx = -1, 1 do
          local nx, ny = q2[1] + ddx, q2[2] + ddy
          if L.get(t, nx, ny) ~= '.' and not seen[ny * t.w + nx] then seen[ny * t.w + nx] = true; stack[#stack + 1] = { nx, ny } end
        end end
      end
      comps[#comps + 1] = list
    end
  end end
  table.sort(comps, function(a, b) return #a > #b end)
  for i2 = 2, #comps do for _, q2 in ipairs(comps[i2]) do t[q2[2]][q2[1]] = '.' end end
end

-- Cabeça e pescoço de pombo. (nx, ny) base do pescoço, (hx, hy) cabeça, em pixels; mode: nil ave, 'scan' com linhas
-- de varredura, 'led' só matriz de pixels. roll: fase da varredura e da matriz.
function B.head(t, k, nx, ny, hx, hy, mode, roll)
  roll = roll or 0
  local ck = B.plume(k)
  local pl = k > 1.5 and 3 or 1                                 -- passo da matriz de LED
  local function cell(x, y) return (floor(x / pl) + floor(y / pl) + roll) % 2 == 0 end
  B.cap(t, nx, ny, hx, hy + 1.6 * k, 2.6 * k, 2 * k, function(x, y)
    if mode == 'led' then return cell(x, y) and ((floor(y / pl) % 2 == 0) and 'P' or 'Q') or '1' end
    -- o brilho do pescoço em subpixels: verde aceso e magenta de pena
    if (y - hy) / k > 2.4 and cell(x, y) and floor(x / pl) % 3 ~= 0 then return ((floor(y / pl) + roll) % 2 == 0) and 'G' or 'N' end
    return pick('abc', 0.6 - (x - nx) / (5 * k), ck(x, y))
  end)
  B.ell(t, hx, hy, 2.9 * k, 2.6 * k, function(x, y)
    if mode == 'led' then return cell(x, y) and ((floor(x / pl) % 2 == 0) and 'R' or 'Q') or '1' end
    if mode == 'scan' and (floor(y / (k > 1.5 and 2 or 1)) + roll) % 2 == 0 and (k < 1.5 or y % 2 == 0) then return '2' end
    return pick('bcde', lum(x, y, hx, hy, 2.9 * k, 2.6 * k), ck(x, y))
  end)
  B.polyf(t, { { hx + 2.5 * k, hy - 0.2 * k }, { hx + 5 * k, hy + 0.9 * k }, { hx + 2.5 * k, hy + 1.3 * k } }, mode == 'led' and 'Q' or 'q')
  if mode ~= 'led' then
    B.ell(t, hx + 2.7 * k, hy - 0.3 * k, 0.8 * k, 0.6 * k, 'h')
    if k > 1.5 then B.ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.75 * k, 0.75 * k, 'r'); B.ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.35 * k, 0.35 * k, '1')
    else L.set(t, hx + 1.2, hy - 0.4, 'r') end
  else
    B.ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.6 * k, 0.6 * k, 'R')
  end
end
-- Pombo de perfil no espaço do quadro de 28, deslocado de (ox, oy) pixels. o = { tails, legs, heads = { { nx, ny, hx,
-- hy, mode, dx } }, by = quanto o tronco sobe (px, negativo), step = { passo de cada perna }, roll }.
function B.pigeon(t, k, ox, oy, o)
  o = o or {}
  local ck = B.plume(k)
  local by = o.by or 0
  local function X(v) return v * k + (k - 1) / 2 + ox end
  local function F(v) return v * k + (k - 1) / 2 + oy end        -- o chão não sobe
  local function Y(v) return F(v) + by end
  for _, d in ipairs(o.tails or { 0 }) do
    B.polyf(t, { { X(7.6), Y(14.4 + d) }, { X(2.4 - d), Y(18 + d) }, { X(3 - d), Y(20.6 + d) }, { X(9), Y(19.4) } }, function(x, y)
      return x < X(4.8 - d) and pick('fa', 0, ck(x, y)) or pick('ab', 0, ck(x, y))
    end)
  end
  for n, lx in ipairs(o.legs or { 12.6, 16 }) do
    local sx = (o.step and o.step[n] or 0)
    B.wire(t, { { X(lx), Y(19.4) }, { X(lx + sx), F(23.2) } }, 'j', 'i', TH(k, 0.6))
    for _, d in ipairs({ { -1.2, 0.5 }, { 0.6, 0.8 }, { 1.9, 0.4 } }) do
      B.wire(t, { { X(lx + sx), F(23.2) }, { X(lx + sx + d[1]), F(23.2 + d[2]) } }, 'j', nil, TH(k, 0.45))
    end
  end
  B.ell(t, X(13.2), Y(15.8), 7.4 * k, 4.7 * k, function(x, y) return pick('abcd', lum(x, y, X(13.2), Y(15.8), 7.4 * k, 4.7 * k), ck(x, y)) end)
  B.ell(t, X(18.4), Y(13.8), 4 * k, 4.4 * k, function(x, y) return pick('bcde', lum(x, y, X(18.4), Y(13.8), 4 * k, 4.4 * k), ck(x, y)) end)
  -- asa fechada com as duas barras
  B.ell(t, X(11.2), Y(15.2), 6.2 * k, 3.5 * k, function(x, y)
    local s2 = (x - X(11.2)) / k + (y - Y(15.2)) / k * 0.7
    if (s2 > -1.6 and s2 < -0.2) or (s2 > 1.6 and s2 < 3) then return pick('fa', 0, ck(x, y)) end
    return pick('cde', lum(x, y, X(11.2), Y(15.2), 6.2 * k, 3.5 * k), ck(x, y))
  end)
  for _, hd in ipairs(o.heads or { { 18.6, 12, 18.8, 6.4 } }) do
    local dx = hd[6] or 0
    B.head(t, k, X(hd[1]), Y(hd[2]), X(hd[3] + dx), Y(hd[4]), hd[5], o.roll)
  end
end

-- Quadro em blocos de b pixels: cada bloco fica com a cor do próprio centro.
function B.mosaic(t, b)
  b = max(1, floor(b + 0.5))
  if b < 2 then return end
  local s = L.grid(t.w, t.h)
  for by = 0, t.h - 1, b do for bx = 0, t.w - 1, b do
    local c2 = L.get(t, bx + b // 2, by + b // 2)
    for y = by, min(t.h - 1, by + b - 1) do for x = bx, min(t.w - 1, bx + b - 1) do s[y][x] = c2 end end
  end end
  for y = 0, t.h - 1 do for x = 0, t.w - 1 do t[y][x] = s[y][x] end end
end
-- O corpo escorre: cada coluna de b pixels desce do ponto mais baixo, escurecendo, com a ponta acesa.
function B.melt(t, b, len, seed, x0, x1)
  b = max(1, floor(b + 0.5))
  for bx = (x0 or 0) - (x0 or 0) % b, (x1 or t.w - 1), b do
    local yb
    for y = t.h - 1, 0, -1 do if L.get(t, bx + b // 2, y) ~= '.' then yb = y; break end end
    local n = floor(rnd(bx // b, seed, 2) * len + 0.5)
    if yb and n > 0 and rnd(bx // b, seed, 5) > 0.25 then
      for i = 1, n do
        local ch = i > n - b and 'P' or (i > n * 0.55 and 'Q' or ((i // b) % 2 == 0 and 'a' or '2'))
        for x = bx, bx + b - 1 do if yb + i < t.h - 2 then L.set(t, x, yb + i, ch) end end
      end
    end
  end
end
local DARKER = { e = 'd', d = 'c', c = 'b', b = 'a', a = '2', h = 'd', j = 'i' }
function B.darken(t, n)
  for _ = 1, n do for y = 0, t.h - 1 do for x = 0, t.w - 1 do if DARKER[t[y][x]] then t[y][x] = DARKER[t[y][x]] end end end end
end
-- Costura do Véu: linha quebrada de w px (em pixels), só por cima do corpo; step: pontos atravessados (retrato).
function B.seam(g, pts, w, step)
  local mask = B.SOLID:gsub('[GPQRZXYUVO]', '')
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    B.wire(g, { a, b }, 'Z', nil, w, mask)
    if step then
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local len = sqrt(dx * dx + dy * dy)
      for s2 = step / 2, len, step do
        local x, y = a[1] + dx * s2 / len, a[2] + dy * s2 / len
        L.line(g, x - dy / len * (w + 1), y + dx / len * (w + 1), x + dy / len * (w + 1), y - dx / len * (w + 1), 'Z', mask)
      end
    end
  end
end
-- Pixel solto em sg (só no glow), onde o corpo está vazio: sobe em degraus e some. list = { { u, v, ch } }.
function B.dust(g, sg, k, ox, oy, list, ph, NL)
  local n = max(1, floor(k * 0.6 + 0.5))
  for i, d in ipairs(list) do
    local r = (ph + i) % NL
    if r < NL - 1 then
      local x, y = floor(d[1] * k + ox), floor((d[2] - r) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = d[3] or ({ 'p', 'y', 't' })[i % 3 + 1]
        end
      end end
    end
  end
end

function B.run(spec)
  spec.LEG = spec.LEG or B.LEG
  spec.LIT, spec.heat = B.LIT, B.heat
  spec.NOPULL = spec.NOPULL or B.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or B.BODY_KEYS
  spec.DARK = spec.DARK or 'a'
  spec.ownDy, spec.ownLean = true, true
  if not spec.over then
    spec.over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end }
  end
  return K.run(spec)
end

return B
