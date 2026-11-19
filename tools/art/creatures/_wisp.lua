-- Kit da arte final da família Wisp (Espectral): Wisplet (Eco), Hollowkin (Espírito), Entidade Maior (o velário) e
-- Arquétipo (a procissão). A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes,
-- retrato, folha e a régua impressa ao gravar); aqui ficam a legenda, os emissivos e as ferramentas de desenho dos
-- conceitos aprovados (tools/art/creatures/conceitos/wisp/build.lua), agora com pose. Cada espécie dá
-- draw(g, sg, k, o): o corpo em g (emissivos ACESOS, sem contorno) e o que é solto em sg; k é a escala (1 no mapa) e
-- o é o quadro (ph fase do laço, pose 'alert' | 'crouch', dy, lean, jump, portrait).
-- Traço da família: olhos de vela (leds: piscam). A luz é a do tipo (tools/art/ui/types/palette.lua, Espectral:
-- d, m, l), sem o azul do conceito. Bicho de chão: o tronco sobe e desce (body_dy, aplicado no draw) e os pés ficam.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local S = dofile(ART .. 'creatures/_soot.lua')               -- só as ajudas que servem a qualquer família
local C, L, F, R = K.C, K.L, S.F, S.R
local Wi = { L = L, C = C, F = F, R = R, seam = S.seam, spark = S.spark, pick = R.pick, hash = R.hash }
local floor, ceil, sqrt, abs, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max,
  math.sin, math.cos, math.rad

local SP
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'spectral' then SP = c end end
local VEU = '#9B7BFF'

Wi.LEG = {
  A = '#1A1424',
  a = '#3E3128', b = '#5E4A38', c = '#85694C', d = '#AD9270', -- pena parda
  e = '#CFC2A4',                                              -- pinta, sobrancelha e barriga creme
  f = '#8E8468', l = '#B5A982',                               -- perna e bico
  m = '#5B6270', n = '#7C8492', o = '#A2A9B4', p = '#C9CED6', -- névoa (matéria)
  ['1'] = '#8C8676', ['2'] = '#B5AD98', ['3'] = '#D9D2BE',    -- cera
  j = '#8C8676', i = '#B5AD98',                               -- a mesma cera em pingo fino, sem contorno
  k = '#2B2836',                                             -- pavio e o oco do manto
  r = '#3A3846', t = '#555362', u = '#74727F',                -- pano do manto
  ['6'] = '#C8C2B4', ['7'] = '#9A9488', ['8'] = '#6E6A66',    -- pena de cinza (Arquétipo)
  x = '#34435E', y = '#4C6182', z = '#6A82A4',                -- chama apagada (corpo)
  F = SP.d, G = SP.m, H = SP.l,                               -- olho de vela (leds: pisca)
  B = SP.d, D = SP.m, E = SP.l,                               -- chama de vela (glow)
  T = SP.d, S = SP.m, s = SP.l,                               -- frio solto e chama solta (só no glow)
  ['5'] = '#735C4C', ['4'] = '#A49C94', ['0'] = '#4C4958',    -- costura do Véu apagada: pena, cera, pano
  X = VEU, ['9'] = VEU, Z = VEU,                              -- costura acesa (glow)
  Q = VEU, W = '#5A45A8', v = '#150F20',                      -- o vão do Arquétipo (apagado: v, mais escuro que o contorno)
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
Wi.LIT = {
  F = { 'x', 'l' }, G = { 'y', 'l' }, H = { 'z', 'l' }, B = { 'x', 'w' }, D = { 'y', 'w' }, E = { 'z', 'w' },
  X = { '5', 'w' }, ['9'] = { '4', 'w' }, Z = { '0', 'w' }, Q = { 'v', 'w' }, W = { 'v', 'w' },
}
Wi.NOPULL = 'ATSsFGHBDEij'                                    -- a chama e o pingo fino não têm contorno
function Wi.solid(nopull)
  local o = ''
  for ch in pairs(Wi.LEG) do if not (nopull or Wi.NOPULL):find(ch, 1, true) then o = o .. ch end end
  return o
end
Wi.SOLID = Wi.solid()
Wi.FEATHER, Wi.WAX, Wi.CLOTH, Wi.MIST, Wi.ASH = 'abcde', '123', 'rtu', 'mnop', '678'
-- cores do corpo que as variantes trocam (as apagadas e as emissivas ficam iguais em todas)
Wi.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'f', 'l', 'm', 'n', 'o', 'p', '1', '2', '3', 'r', 't', 'u', '6', '7', '8' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): a chama sobe um degrau da paleta.
local UP = { F = 'G', G = 'H', B = 'D', D = 'E' }
function Wi.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = UP[g[y][x]]
    if c and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = c end
  end end
end

function Wi.chk(p) return function(x, y) return (floor(x / p) + floor(y / p)) % 2 == 0 end end
function Wi.noise(p, s) return function(x, y) return R.hash(floor(x / p), floor(y / p), s) > 0.5 end end
function Wi.lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end
function Wi.pp(k) return max(1, floor(k / 2 + 0.5)) end
function Wi.th(k, w) return max(1, floor(k * (w or 1) + 0.5)) end

-- Formas em pixels da grade (as do conceito). fn é um caractere ou function(x, y).
local function put(g, x, y, fn, mask)
  local ch = type(fn) == 'function' and fn(x, y) or fn
  if ch then L.set(g, x, y, ch, mask) end
end
function Wi.ell(g, cx, cy, rx, ry, fn, mask)
  for y = floor(cy - ry), ceil(cy + ry) do
    for x = floor(cx - rx), ceil(cx + rx) do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then put(g, x, y, fn, mask) end
    end
  end
end
function Wi.cap(g, x0, y0, x1, y1, r0, r1, fn, mask)
  local dx, dy = x1 - x0, y1 - y0
  local l2, rr = dx * dx + dy * dy, max(r0, r1)
  for y = floor(min(y0, y1) - rr), ceil(max(y0, y1) + rr) do
    for x = floor(min(x0, x1) - rr), ceil(max(x0, x1) + rr) do
      local t = l2 == 0 and 0 or max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / l2))
      if (x - x0 - dx * t) ^ 2 + (y - y0 - dy * t) ^ 2 <= (r0 + (r1 - r0) * t) ^ 2 then put(g, x, y, fn, mask) end
    end
  end
end
function Wi.poly(g, pts, fn, mask)
  local y0, y1 = math.huge, -math.huge
  for _, q in ipairs(pts) do y0 = min(y0, q[2]); y1 = max(y1, q[2]) end
  for y = floor(y0), ceil(y1) do
    local xs = {}
    for i = 1, #pts do
      local a, b = pts[i], pts[i % #pts + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = ceil(xs[i] - 0.5), floor(xs[i + 1] + 0.5) do put(g, x, y, fn, mask) end
    end
  end
end
function Wi.wire(g, pts, a, b, th, mask)
  th = th or 1
  local n, o = 0, (th - 1) / 2
  for i = 1, #pts - 1 do
    local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
    local m = max(abs(x1 - x0), abs(y1 - y0))
    for s = 0, floor(m) do
      local t = m == 0 and 0 or s / m
      n = n + 1
      local ch = (b and (n // th) % 3 == 0) and b or a
      local x, y = floor(x0 + (x1 - x0) * t - o + 0.5), floor(y0 + (y1 - y0) * t - o + 0.5)
      for dy = 0, th - 1 do for dx = 0, th - 1 do L.set(g, x + dx, y + dy, ch, mask) end end
    end
  end
end
function Wi.blit(dst, src, ox, oy)
  for y = 0, src.h - 1 do for x = 0, src.w - 1 do
    if src[y][x] ~= '.' then L.set(dst, x + (ox or 0), y + (oy or 0), src[y][x]) end
  end end
end
-- camada: desenha à parte, contorna e cola por cima (o contorno separa do que está atrás)
-- Wi.flat = true (a silhueta escura do spawn): sem o contorno de dentro, que viraria corpo e engordaria a forma
function Wi.layer(g, draw, solid)
  local t = L.grid(g.w, g.h)
  draw(t)
  if not Wi.flat then L.outline(t, 'A', solid or Wi.SOLID) end
  Wi.blit(g, t)
  return t
end
-- frio solto: um bloco em sg, só onde o corpo de g está vazio
function Wi.dot(g, sg, x, y, k, ch)
  local n = Wi.th(k, 0.6)
  for j = 0, n - 1 do for i = 0, n - 1 do
    if L.get(g, floor(x) + i, floor(y) + j) == '.' then L.set(sg, floor(x) + i, floor(y) + j, ch or 'S') end
  end end
end
-- escala: posição do mapa -> pixel da grade (o centro do pixel ampliado), com deslocamento
function Wi.scale(k, ox, oy)
  ox, oy = (ox or 0) + (k - 1) / 2, (oy or 0) + (k - 1) / 2
  local function X(u) return u * k + ox end
  local function Y(v) return v * k + oy end
  local function pts(l, dx, dy)
    local o = {}
    for i, q in ipairs(l) do o[i] = { X(q[1] + (dx or 0)), Y(q[2] + (dy or 0)) } end
    return o
  end
  return X, Y, pts
end

-- Chama de vela: gota de base em (x, y), ponta na direção ang (graus, y para baixo). chars: borda, meio, miolo
-- ('FGH' olho, em leds; 'BDE' vela, em glow; 'TSs' solta).
function Wi.flame(g, x, y, ang, len, w, chars, mask)
  chars = chars or 'BDE'
  local a = rad(ang)
  local dx, dy = cos(a), sin(a)
  local rr = len + w
  for yy = floor(y - rr), ceil(y + rr) do
    for xx = floor(x - rr), ceil(x + rr) do
      local rx, ry = xx - x, yy - y
      local t = (rx * dx + ry * dy) / len
      local d = abs(-rx * dy + ry * dx)
      if t >= -0.12 and t <= 1 then
        local hw
        if t < 0 then hw = (w / 2) * 0.7 * (1 + t / 0.12) ^ 0.5
        elseif t < 0.3 then hw = (w / 2) * (0.7 + 0.3 * t / 0.3)
        else hw = (w / 2) * ((1 - t) / 0.7) ^ 0.8 end
        if d <= hw + 0.25 then
          local q = d / max(hw, 0.3)
          local i = 1
          if t < 0.6 and q < 0.5 then i = 3 elseif t < 0.85 and q < 0.85 then i = 2 end
          L.set(g, xx, yy, chars:sub(i, i), mask)
        end
      end
    end
  end
end
-- plumagem de coruja: xadrez de dois tons vizinhos com pintas creme
function Wi.feather(pal, p, seed, spots)
  return function(x, y, v)
    if R.hash(floor(x / p), floor(y / p), seed) < (spots or 0.12) then return 'e' end
    return R.pick(pal, v, (floor(x / p) + floor(y / p)) % 2 == 0)
  end
end
function Wi.wax(p, x0, w)
  return function(x, y) return R.pick('123', 0.9 - (x - x0) / w * 0.8, floor(x / p) % 2 == 0) end
end
-- névoa: um punhado de elipses, mais clara em cima
function Wi.mist(g, x, y, rx, ry, seed, p)
  local nz = Wi.noise(p or 1, seed)
  local function one(ox, oy, sx, sy)
    Wi.ell(g, x + ox, y + oy, sx, sy, function(xx, yy) return R.pick('mnop', 0.7 - (yy - (y + oy)) / sy * 0.45, nz(xx, yy)) end)
  end
  one(0, 0, rx * 0.62, ry * 0.75)
  for i = 0, 3 do
    one((R.hash(i, seed, 1) - 0.5) * rx * 1.1, (R.hash(i, seed, 2) - 0.5) * ry * 0.5,
      rx * (0.4 + 0.25 * R.hash(i, seed, 3)), ry * (0.5 + 0.3 * R.hash(i, seed, 4)))
  end
end
-- Frio solto que sobe e some (só no glow). list = { { x, y } } em unidades do mapa; NL = quadros do laço.
function Wi.motes(g, sg, X, Y, k, list, ph, NL)
  for n, q in ipairs(list) do
    local r = (ph + n) % NL
    if r < NL - 1 then Wi.dot(g, sg, X(q[1]), Y(q[2] - r * 0.9), k, n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'T')) end
  end
end
-- Recorte do busto: apaga o que cai fora de um quadro de lado size com canto em (x0, y0), a m px da borda, rasgado.
function Wi.tearBox(g, x0, y0, size, m)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local e = min(x - x0, y - y0, x0 + size - 1 - x, y0 + size - 1 - y)
    if e < m + (K.hash(x // 3, y // 3, 17) % 3) then g[y][x] = '.' end
  end end
end

function Wi.run(spec)
  spec.LEG = spec.LEG or Wi.LEG
  spec.LIT, spec.heat = Wi.LIT, Wi.heat
  spec.NOPULL = spec.NOPULL or Wi.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or Wi.BODY_KEYS
  spec.DARK = spec.DARK or 'a'
  spec.ownDy, spec.ownLean = true, true
  return K.run(spec)
end

return Wi
