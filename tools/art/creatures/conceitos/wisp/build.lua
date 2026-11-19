-- Conceitos da família Wisp (Etapa 1): Fagulha, Eco, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- Coruja-buraqueira (Athene cunicularia) + vela e névoa + o Espectral como chama fria. Traço: olhos de vela (no lugar
-- de cada olho, uma chama de vela azul-clara, mais alta que larga, que sobe além da cabeça).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/wisp/build.lua')
-- O Eco do mapa é desenhado pixel a pixel; as outras etapas são funções de k (1 no mapa, textura mais fina no retrato).
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max, math.sin, math.cos, math.rad

local LEG = {
  A = '#1A1424',                                              -- contorno
  a = '#3E3128', b = '#5E4A38', c = '#85694C', d = '#AD9270', -- pena parda
  e = '#CFC2A4',                                              -- pinta, sobrancelha e barriga creme
  f = '#8E8468', l = '#B5A982',                               -- perna e bico
  m = '#5B6270', n = '#7C8492', o = '#A2A9B4', p = '#C9CED6', -- névoa (matéria)
  ['1'] = '#8C8676', ['2'] = '#B5AD98', ['3'] = '#D9D2BE',    -- cera
  k = '#2B2836',                                              -- pavio e o oco do manto
  s = '#3A3846', t = '#555362', u = '#74727F',                -- pano do manto
  ['6'] = '#C8C2B4', ['7'] = '#9A9488', ['8'] = '#6E6A66',    -- pena de cinza (Arquétipo)
  x = '#34435E', y = '#4C6182', z = '#6A82A4',                -- chama apagada
  F = '#6FA8E0', G = '#BFE3FF', H = '#F2FAFF',                -- chama fria
  N = '#6FA8E0', M = '#BFE3FF', O = '#F2FAFF', X = '#9B7BFF', Y = '#5A45A8', -- soltos (só emissivo); X e Y são o Véu no vão
}
local LIT = { F = 'x', G = 'y', H = 'z' }
local LOOSE = 'NMOXY'
local SOLID = ''
for ch in pairs(LEG) do if not ('AFGHNMOXY'):find(ch, 1, true) then SOLID = SOLID .. ch end end

local function hash(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ ((s or 0) * 83492791)
  v = v ~ (v >> 13)
  return ((v * 1274126177) & 0x7fffffff) / 0x7fffffff
end
local function pick(pal, v, st)
  local nn = #pal
  local i2 = floor(max(0, min(1, v)) * (nn - 2) + 0.5) + (st and 1 or 0)
  return pal:sub(i2 + 1, i2 + 1)
end
local function diag(p) return function(x, y) return floor((x + y) / p) % 2 == 0 end end
local function ver(p) return function(x, y) return floor(x / p) % 2 == 0 end end
local function chk(p) return function(x, y) return (floor(x / p) + floor(y / p)) % 2 == 0 end end
local function noise(p, s) return function(x, y) return hash(floor(x / p), floor(y / p), s) > 0.5 end end
local function PP(k) return max(1, floor(k / 2 + 0.5)) end
local function TH(k, w) return max(1, floor(k * (w or 1) + 0.5)) end

local function put(g, x, y, fn, mask)
  local ch = type(fn) == 'function' and fn(x, y) or fn
  if ch then L.set(g, x, y, ch, mask) end
end
local function ell(g, cx, cy, rx, ry, fn, mask)
  for y = floor(cy - ry), ceil(cy + ry) do
    for x = floor(cx - rx), ceil(cx + rx) do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then put(g, x, y, fn, mask) end
    end
  end
end
local function cap(g, x0, y0, x1, y1, r0, r1, fn, mask)
  local dx, dy = x1 - x0, y1 - y0
  local l2, R = dx * dx + dy * dy, max(r0, r1)
  for y = floor(min(y0, y1) - R), ceil(max(y0, y1) + R) do
    for x = floor(min(x0, x1) - R), ceil(max(x0, x1) + R) do
      local t = l2 == 0 and 0 or max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / l2))
      if (x - x0 - dx * t) ^ 2 + (y - y0 - dy * t) ^ 2 <= (r0 + (r1 - r0) * t) ^ 2 then put(g, x, y, fn, mask) end
    end
  end
end
local function polyf(g, pts, fn, mask)
  local y0, y1 = math.huge, -math.huge
  for _, q in ipairs(pts) do y0 = min(y0, q[2]); y1 = max(y1, q[2]) end
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
local function wire(g, pts, a, b, th, mask)
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
local function blit(dst, src, ox, oy)
  for y = 0, src.h - 1 do for x = 0, src.w - 1 do
    if src[y][x] ~= '.' then L.set(dst, x + (ox or 0), y + (oy or 0), src[y][x]) end
  end end
end
-- camada: desenha à parte, contorna e cola por cima (o contorno separa do que está atrás)
local function layer(g, draw, solid)
  local t = L.grid(g.w, g.h)
  draw(t)
  L.outline(t, 'A', solid or SOLID)
  blit(g, t)
  return t
end
local function dot(g, x, y, k, ch)
  local s2 = TH(k, 0.6)
  L.rect(g, floor(x), floor(y), floor(x) + s2 - 1, floor(y) + s2 - 1, ch or 'M', '.')
end
local function scale(k)
  local function U(v) return v * k + (k - 1) / 2 end
  local function pts(l) local r2 = {} for i2, q in ipairs(l) do r2[i2] = { U(q[1]), U(q[2]) } end return r2 end
  return U, pts
end
local function lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end

-- chama de vela: gota de base em (x, y), ponta na direção ang; loose troca as cores pelas soltas (sem par no corpo)
local function flame(g, x, y, ang, len, w, loose, mask)
  local a = rad(ang)
  local dx, dy = cos(a), sin(a)
  local R = len + w
  for yy = floor(y - R), ceil(y + R) do
    for xx = floor(x - R), ceil(x + R) do
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
          local ch = 'F'
          if t < 0.6 and q < 0.5 then ch = 'H' elseif t < 0.85 and q < 0.85 then ch = 'G' end
          if loose then ch = ({ F = 'N', G = 'M', H = 'O' })[ch] end
          L.set(g, xx, yy, ch, mask)
        end
      end
    end
  end
end
-- plumagem de coruja: xadrez de dois tons vizinhos com pintas creme
local function feather(pal, p, seed, spots)
  return function(x, y, v)
    if hash(floor(x / p), floor(y / p), seed) < (spots or 0.12) then return 'e' end
    return pick(pal, v, (floor(x / p) + floor(y / p)) % 2 == 0)
  end
end
local function wax(p, x0, w)
  return function(x, y) return pick('123', 0.9 - (x - x0) / w * 0.8, floor(x / p) % 2 == 0) end
end
-- névoa: um punhado de elipses, mais clara em cima
local function mist(g, x, y, rx, ry, seed, p)
  local nz = noise(p or 1, seed)
  local function one(ox, oy, sx, sy)
    ell(g, x + ox, y + oy, sx, sy, function(xx, yy) return pick('mnop', 0.7 - (yy - (y + oy)) / sy * 0.45, nz(xx, yy)) end)
  end
  one(0, 0, rx * 0.62, ry * 0.75)
  for i2 = 0, 3 do
    one((hash(i2, seed, 1) - 0.5) * rx * 1.1, (hash(i2, seed, 2) - 0.5) * ry * 0.5,
      rx * (0.4 + 0.25 * hash(i2, seed, 3)), ry * (0.5 + 0.3 * hash(i2, seed, 4)))
  end
end
-- asa: lâmina a partir de (x, y) na direção ang; fn(x, y, u, t) com u ao longo e t da borda de ataque (0) à de fuga (1)
local function blade(g, x, y, ang, len, wid, side, fn, sc)
  local a = rad(ang)
  local dx, dy = cos(a), sin(a)
  local px, py = -dy * side, dx * side
  local R = len + wid
  for yy = floor(y - R), ceil(y + R) do
    for xx = floor(x - R), ceil(x + R) do
      local rx, ry = xx - x, yy - y
      local u = (rx * dx + ry * dy) / len
      if u >= 0 and u <= 1 then
        local v = (rx * px + ry * py) / wid
        local tr = sin(math.pi * u ^ 0.7) ^ 0.6
        if sc and floor(u * len / sc) % 2 == 1 then tr = tr * 0.8 end
        local le = 0.16 * (1 - u) ^ 0.5 + 0.04
        if v >= -le and v <= tr then
          local ch = fn(xx, yy, u, (v + le) / (tr + le))
          if ch then L.set(g, xx, yy, ch) end
        end
      end
    end
  end
end

-- FAGULHA (Chill Mote): um toco de vela com a chama fria, solta de qualquer olho.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '......F.....',
    '.....FG.....',
    '.....GHF....',
    '....FGHG....',
    '.....FGF.M..',
    '....AAkAA...',
    '...A32321A..',
    '..A3231212A.',
    '..AAAAAAAAA.',
    '..N.........',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  layer(g, function(t) mist(t, 26, 76, 16, 6, 11, 2); mist(t, 70, 78, 15, 5, 12, 2) end)
  layer(g, function(t)
    local wx = wax(2, 30, 36)
    -- poça de cera e o toco
    polyf(t, { { 24, 82 }, { 28, 74 }, { 38, 71 }, { 58, 71 }, { 68, 75 }, { 72, 82 }, { 62, 86 }, { 34, 86 } }, wx)
    polyf(t, { { 38, 52 }, { 58, 52 }, { 60, 74 }, { 36, 74 } }, wx)
    ell(t, 48, 52, 10, 3, function(x, y) return pick('23', 0.5, chk(2)(x, y)) end)
    -- pingos
    cap(t, 39, 54, 39, 66, 2.4, 1.6, '3'); ell(t, 39, 67, 2.4, 2.8, '3')
    cap(t, 55, 54, 55.5, 61, 2.2, 1.4, '2'); ell(t, 55.5, 62, 2, 2.4, '2')
    cap(t, 46, 54, 46, 58, 1.6, 1.2, '3')
    wire(t, { { 48, 52 }, { 48, 46 }, { 49, 43 } }, 'k', nil, 2)
    flame(t, 48.5, 44, -88, 34, 15)
  end)
  layer(g, function(t) mist(t, 44, 86, 14, 4, 13, 2) end)
  for _, q in ipairs({ { 20, 30 }, { 74, 24 }, { 80, 46 }, { 16, 54 }, { 66, 12 }, { 30, 14 }, { 84, 64 } }) do
    dot(g, q[1], q[2], 4, (q[1] % 3 == 0) and 'N' or 'M')
  end
  return g
end

-- ECO (Wisplet): a coruja-buraqueira de pé nas pernas compridas, numa poça de névoa; no lugar dos olhos, duas chamas
-- de vela que sobem além da cabeça, e uma lágrima de cera embaixo de cada uma.
local function ecoMapa()
  local f = L.frame({
    '............................',
    '............................',
    '............................',
    '............................',
    '............F...F...........',
    '............G...G...........',
    '..........AAGAAAGA..........',
    '.........AcFHdcFHcA.........',
    '........AbeGHeeGHebA........',
    '........AbcFGclFGcbA........',
    '........Aaca3dla3dbA........',
    '........Aabe2efeeeaA........',
    '.......AabcbdcdcdcbA........',
    '.......AabebcededecA........',
    '.......AacbabcbcbcbA........',
    '.......AabebdededecA........',
    '.......AacbabcbcbcbA........',
    '.......AabebdededcA.........',
    '........AababcbcbbA.........',
    '........AabdededcA..........',
    '........AabcdAcdA...........',
    '......AAAAAAlAAlAAAA........',
    '.....AAnopomlnplonmAA.......',
    '...AAmnoGonmlfplfonomA......',
    '..AmnmnonoponGnmnmnmA.......',
    '...AAAAAAmnmnAAAAAAA........',
    '.........AAAA...............',
    '............................',
  }, 28, 28, 'eco')
  local g = L.grid(28, 28)
  blit(g, f, 2, 0)                                            -- o corpo no centro do quadro
  dot(g, 24, 8, 1); dot(g, 4, 15, 1, 'N'); dot(g, 25, 18, 1); dot(g, 22, 3, 1, 'N'); dot(g, 6, 9, 1)
  return g
end
local function ecoRetrato(k)
  local S = 28 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  layer(g, function(t) mist(t, U(8), U(23.2), 6 * k, 2.6 * k, 1, p); mist(t, U(19), U(23.4), 5.4 * k, 2.4 * k, 2, p) end)
  layer(g, function(t)
    local fe = feather('abcd', p, 2)
    polyf(t, pts({ { 8.8, 16.6 }, { 7.4, 21.6 }, { 10.4, 20.6 }, { 11.2, 17.4 } }), function(x, y) return pick('ab', 0, ck(x, y)) end)
    for _, lx in ipairs({ 12.2, 15.4 }) do
      wire(t, { { U(lx), U(20) }, { U(lx), U(24) } }, 'l', 'f', TH(k, 0.6))
      for _, q in ipairs({ { -1.3, 0.7 }, { 0.3, 1 }, { 1.8, 0.6 } }) do
        wire(t, { { U(lx), U(24) }, { U(lx + q[1]), U(24 + q[2]) } }, 'l', nil, TH(k, 0.4))
      end
    end
    -- corpo: barriga creme barrada de pardo
    ell(t, U(13.6), U(15.6), 5.2 * k, 5.8 * k, function(x, y)
      local band = floor((y + (x - U(13.6)) * 0.2) / (1.4 * k)) % 2 == 0
      if band then return pick('de', 0, ck(x, y)) end
      return pick('abc', lum(x, y, U(13.6), U(15.6), 5.2 * k, 5.8 * k), ck(x, y))
    end)
    -- asa fechada, do lado das costas
    ell(t, U(10.2), U(15.8), 2.7 * k, 5.4 * k, function(x, y) return fe(x, y, lum(x, y, U(10.2), U(15.8), 2.7 * k, 5.4 * k)) end)
    wire(t, { { U(11.8), U(11.6) }, { U(12.8), U(16) }, { U(12), U(20.4) } }, 'a', nil, TH(k, 0.4))
    for _, lx in ipairs({ 12.2, 15.3 }) do
      ell(t, U(lx), U(20.2), 1.5 * k, 1.3 * k, function(x, y) return pick('cd', 0, ck(x, y)) end)
    end
    -- cabeça chata, sem tufos
    ell(t, U(13.8), U(9.4), 5.1 * k, 3.7 * k, function(x, y) return fe(x, y, lum(x, y, U(13.8), U(9.4), 5.1 * k, 3.7 * k)) end)
    wire(t, { { U(9.6), U(8.8) }, { U(11.6), U(7.7) }, { U(13.4), U(8.9) } }, 'e', nil, TH(k, 0.6))
    wire(t, { { U(14.4), U(8.9) }, { U(16.2), U(7.7) }, { U(18.2), U(8.8) } }, 'e', nil, TH(k, 0.6))
    wire(t, { { U(10.4), U(12) }, { U(13.8), U(12.7) }, { U(17.2), U(12) } }, 'e', nil, TH(k, 0.6))
    ell(t, U(11.8), U(10), 1.4 * k, 1.2 * k, 'a'); ell(t, U(16), U(10), 1.4 * k, 1.2 * k, 'a')
    polyf(t, pts({ { 13.3, 9.7 }, { 14.6, 9.7 }, { 13.9, 12 } }), function(x, y) return x < U(13.9) and 'l' or 'f' end)
    -- lágrimas de cera
    cap(t, U(12.3), U(11), U(12.5), U(12.8), 0.45 * k, 0.3 * k, '3'); ell(t, U(12.5), U(13), 0.5 * k, 0.6 * k, '2')
    cap(t, U(16.4), U(11), U(16.4), U(11.9), 0.45 * k, 0.3 * k, '3')
    flame(t, U(11.8), U(10.3), -86, 6 * k, 2.3 * k); flame(t, U(16), U(10.3), -82, 5.6 * k, 2.3 * k)
  end)
  layer(g, function(t) mist(t, U(13.6), U(24.8), 5.4 * k, 1.5 * k, 3, p) end)
  for _, q in ipairs({ { 22, 8 }, { 4, 15 }, { 23, 18 }, { 21, 3 }, { 6, 9 }, { 24, 13 } }) do
    dot(g, U(q[1]), U(q[2]), k, q[1] % 2 == 0 and 'M' or 'N')
  end
  return g
end

-- ESPÍRITO (Hollowkin): o manto de penas ficou de pé e vazio. No capuz, só o bico e três chamas (duas de um lado);
-- no peito aberto, a vela. Um ombro derreteu em cera, sobra uma perna só, e no lugar da outra escorre cera.
local function espirito(k)
  local S = 36 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  layer(g, function(t) mist(t, U(8.6), U(31.2), 5.4 * k, 2 * k, 4, p); mist(t, U(27), U(31.4), 5 * k, 1.9 * k, 5, p) end)
  layer(g, function(t)
    wire(t, { { U(14.4), U(28) }, { U(14.2), U(32.4) } }, 'l', 'f', TH(k, 0.7))
    for _, q in ipairs({ { -1.6, 0.6 }, { 0.2, 0.8 }, { 1.7, 0.5 } }) do
      wire(t, { { U(14.2), U(32.4) }, { U(14.2 + q[1]), U(32.4 + q[2]) } }, 'l', nil, TH(k, 0.5))
    end
    cap(t, U(21.2), U(28), U(21.4), U(32.2), 1.2 * k, 0.7 * k, wax(p, U(20), 3 * k))
    ell(t, U(21.5), U(32.8), 1 * k, 0.8 * k, '2')
  end)
  layer(g, function(t)
    local fe = feather('abcd', p, 3)
    polyf(t, pts({ { 14.6, 2.4 }, { 18, 3 }, { 21, 4.6 }, { 22.6, 8 }, { 21.6, 11.8 }, { 26.4, 14.6 }, { 27.2, 22 }, { 26.6, 29.6 }, { 25, 31.4 },
      { 23.4, 29.4 }, { 21.8, 31.6 }, { 20, 29.6 }, { 18.4, 31.2 }, { 16.6, 29.4 }, { 15, 31.6 }, { 13.2, 29.6 }, { 11.6, 31.4 },
      { 10, 29.4 }, { 8.4, 30.6 }, { 7.8, 22 }, { 8.6, 14.6 }, { 13.4, 11.8 }, { 12.4, 8 }, { 13.4, 4.6 } }), function(x, y)
      -- fileiras de penas: a ponta de cada uma é escura
      local row = floor((y + abs(x - U(17.5)) * 0.25) / (2 * k))
      if (y + abs(x - U(17.5)) * 0.25) % (2 * k) >= 2 * k - p then return (floor(x / p) + row) % 3 == 0 and 'b' or 'a' end
      return fe(x, y, 0.85 - (x - U(8)) / (19 * k) * 0.75)
    end)
    -- o ombro que derreteu
    local wx = wax(p, U(20), 7 * k)
    polyf(t, pts({ { 20.4, 4.4 }, { 22.6, 8 }, { 22.4, 11.6 }, { 26.4, 14.6 }, { 27, 20.4 }, { 25.8, 17.6 }, { 24.8, 22.4 }, { 23.6, 16.6 },
      { 22.6, 19.4 }, { 21.8, 13 }, { 20.8, 10 } }), wx)
    -- o oco do capuz e a fenda do peito
    ell(t, U(17.4), U(8.2), 3.3 * k, 3.5 * k, 'k')
    polyf(t, pts({ { 17.6, 13.4 }, { 20.2, 21 }, { 20.6, 29 }, { 18.4, 30.6 }, { 16.6, 29 }, { 14.8, 29 }, { 15, 21 } }), 'k')
    -- a luz da vela na borda de dentro
    local add = {}
    for y = 0, S - 1 do for x = 0, S - 1 do
      if t[y][x] == 'k' and y > U(13) then
        for _, q in ipairs({ { 1, 0 }, { -1, 0 } }) do
          local c2 = L.get(t, x + q[1], y)
          if c2 ~= 'k' and c2 ~= '.' and hash(x // p, y // p, 8) > (k > 1 and 0.2 or 0.55) then add[#add + 1] = { x, y } end
        end
      end
    end end
    for _, q in ipairs(add) do t[q[2]][q[1]] = 'F' end
    -- bico no escuro
    polyf(t, pts({ { 16.8, 9.8 }, { 18.2, 9.8 }, { 17.5, 12.2 } }), function(x, y) return x < U(17.5) and 'l' or 'f' end)
    -- a vela de dentro
    cap(t, U(17.7), U(24.6), U(17.7), U(28.2), 1.3 * k, 1.5 * k, wax(p, U(16.2), 3 * k))
    wire(t, { { U(17.7), U(23.6) }, { U(17.7), U(22.6) } }, 'k', nil, TH(k, 0.4))
    cap(t, U(16.5), U(25), U(16.4), U(26.6), 0.45 * k, 0.3 * k, '3')
    flame(t, U(17.7), U(22.8), -90, 6.4 * k, 2.8 * k)
    -- três olhos
    flame(t, U(15.6), U(9.2), -92, 3.4 * k, 1.6 * k); flame(t, U(16.6), U(6.8), -88, 2.8 * k, 1.4 * k)
    flame(t, U(19.6), U(8.8), -86, 3.4 * k, 1.6 * k)
    if k > 1 then
      wire(t, { { U(10), U(15) }, { U(9.2), U(22) }, { U(9.6), U(28.4) } }, 'a')
      wire(t, { { U(13), U(12.4) }, { U(12.6), U(20) } }, 'a')
    end
  end)
  layer(g, function(t) mist(t, U(17.6), U(32.6), 4 * k, 1.2 * k, 6, p) end)
  for _, q in ipairs({ { 4, 12 }, { 30, 9 }, { 31, 22 }, { 5, 24 }, { 25, 3 }, { 10, 5 } }) do
    dot(g, U(q[1]), U(q[2]), k, q[1] % 2 == 0 and 'M' or 'N')
  end
  return g
end

-- ENTIDADE MAIOR: a toca e o velário. Três asas em cata-vento em volta do disco da cara, que está de ponta-cabeça;
-- das órbitas as chamas queimam para baixo; três pernas apoiadas num monte de cera derretida com a toca no meio, e a
-- cera pinga para cima.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  local cx, cy = 23.5, 20
  -- monte de cera, a toca e a cera que sobe
  layer(g, function(t)
    mist(t, U(8.4), U(43.6), 5 * k, 1.9 * k, 6, p); mist(t, U(38.6), U(43.6), 5 * k, 1.9 * k, 7, p)
    polyf(t, pts({ { 9.4, 45 }, { 10.6, 41.6 }, { 14, 39.6 }, { 18, 38.2 }, { 23.5, 37.6 }, { 29, 38.2 }, { 33, 39.6 }, { 36.4, 41.6 }, { 37.6, 45 } }), function(x, y)
      return pick('123', 0.95 - (y - U(37.6)) / (7.4 * k) * 0.9 - (x - U(23.5)) / (14 * k) * 0.2, floor(x / p) % 2 == 0)
    end)
    for _, q in ipairs({ { 13.4, 39.6, 33.4 }, { 18.4, 38.2, 30 }, { 28.8, 38.2, 31.2 }, { 33.6, 39.6, 34.6 } }) do
      cap(t, U(q[1]), U(q[2]), U(q[1]), U(q[3] + 1), 1.5 * k, 0.8 * k, wax(p, U(q[1] - 1.5), 3 * k))
      ell(t, U(q[1]), U(q[3]), 1.2 * k, 1.3 * k, '3')
      flame(t, U(q[1]), U(q[3] + 0.6), 90, 3 * k, 1.5 * k)
    end
    ell(t, U(23.5), U(42), 4.4 * k, 2.3 * k, 'k')
    flame(t, U(21.4), U(41.2), 90, 1.9 * k, 1.2 * k); flame(t, U(23.6), U(41.6), 90, 1.9 * k, 1.2 * k); flame(t, U(25.7), U(41.2), 90, 1.9 * k, 1.2 * k)
  end, SOLID:gsub('[mnop]', ''))
  -- três pernas
  layer(g, function(t)
    for _, q in ipairs({ { -2, 16.4, 37.6 }, { 0, 23.5, 36.8 }, { 2, 30.6, 37.6 } }) do
      local mx, my = (cx + q[1] + q[2]) / 2 + q[1] * 0.8, 31.6
      cap(t, U(cx + q[1]), U(25), U(mx), U(my), 1.2 * k, 0.8 * k, function(x, y) return pick('lf', 0, ck(x, y)) end)
      cap(t, U(mx), U(my), U(q[2]), U(q[3]), 0.8 * k, 0.7 * k, function(x, y) return pick('lf', 0, ck(x, y)) end)
      for _, d in ipairs({ { -1.6, 0.7 }, { 0, 1.1 }, { 1.6, 0.7 } }) do
        wire(t, { { U(q[2]), U(q[3]) }, { U(q[2] + d[1]), U(q[3] + d[2]) } }, 'l', nil, TH(k, 0.5))
      end
    end
    ell(t, U(cx), U(26), 4 * k, 2.6 * k, function(x, y) return pick('bcd', 0.6, ck(x, y)) end)
  end)
  -- asas
  for _, ang in ipairs({ -90, 30, 150 }) do
    layer(g, function(t)
      local a = rad(ang)
      blade(t, U(cx + cos(a) * 3), U(cy + sin(a) * 3), ang, 14 * k, 10.5 * k, 1, function(x, y, u, v)
        if v < 0.3 then
          if hash(x // p, y // p, 5) < 0.2 then return 'e' end
          return pick('bcd', 0.8, ck(x, y))
        end
        if u > 0.9 then return pick('ab', 0, ck(x, y)) end
        local band = floor(u * 14 / 1.5) % 2 == 0
        return band and pick('ab', 0.2, ck(x, y)) or pick('cde', v < 0.7 and 0.3 or 0.8, ck(x, y))
      end, 2.2 * k)
      for _, r2 in ipairs({ 7, 11.4 }) do
        local ex, ey = U(cx + cos(a) * r2 - sin(a) * 2.6), U(cy + sin(a) * r2 + cos(a) * 2.6)
        ell(t, ex, ey, 1 * k, 1 * k, 'a')
        flame(t, ex, ey + 0.2 * k, 90, 4.2 * k, 2 * k)
      end
    end)
  end
  -- o disco da cara, de ponta-cabeça
  layer(g, function(t)
    ell(t, U(cx), U(cy), 5.8 * k, 5.6 * k, function(x, y)
      local an = math.atan(y - U(cy), x - U(cx))
      return pick('bcd', 0.3 + 0.5 * lum(x, y, U(cx), U(cy), 5.8 * k, 5.6 * k), floor(an / (math.pi / 14)) % 2 == 0)
    end)
    ell(t, U(cx), U(cy), 4.3 * k, 4.1 * k, function(x, y) return pick('cde', lum(x, y, U(cx), U(cy), 4.3 * k, 4.1 * k) + 0.2, ck(x, y)) end)
    -- sobrancelhas embaixo, bico para cima
    wire(t, { { U(cx - 3.8), U(cy + 1.6) }, { U(cx - 2), U(cy + 3) }, { U(cx - 0.4), U(cy + 1.6) } }, 'e', nil, TH(k, 0.6))
    wire(t, { { U(cx + 0.4), U(cy + 1.6) }, { U(cx + 2), U(cy + 3) }, { U(cx + 3.8), U(cy + 1.6) } }, 'e', nil, TH(k, 0.6))
    polyf(t, pts({ { cx - 0.8, cy + 0.2 }, { cx + 0.8, cy + 0.2 }, { cx, cy - 2.6 } }), function(x, y) return x < U(cx) and 'l' or 'f' end)
    ell(t, U(cx - 2.1), U(cy + 0.6), 1.3 * k, 1.2 * k, 'a'); ell(t, U(cx + 2.1), U(cy + 0.6), 1.3 * k, 1.2 * k, 'a')
    flame(t, U(cx - 2.1), U(cy + 0.4), 92, 8 * k, 2.8 * k); flame(t, U(cx + 2.1), U(cy + 0.4), 88, 7 * k, 2.8 * k)
  end)
  -- gotas de cera soltas no ar não existem no corpo: viram brilho frio em volta
  for _, q in ipairs({ { 13.4, 30.6 }, { 18.4, 27 }, { 28.8, 28.2 }, { 33.6, 31.6 }, { 5, 20 }, { 42, 22 }, { 8, 8 }, { 39, 7 }, { 4, 34 }, { 43, 35 },
    { 10, 14 }, { 37, 15 }, { 6, 28 }, { 41, 29 }, { 15, 5 }, { 32, 4 }, { 3, 40 }, { 44, 40 } }) do
    dot(g, U(q[1]), U(q[2]), k, q[1] % 2 == 0 and 'M' or 'N')
  end
  return g
end

-- ARQUÉTIPO: a procissão. Três mantos vazios em roda, cada um entrando pelo capuz do seguinte (um pano só, sem lado
-- de dentro); no meio, o disco de penas de uma cara que não tem olhos nem bico, só o vão. Três pernas penduradas que
-- não tocam nada, tiras de mortalha acesas na ponta, e uma roda de chamas: todas apontam para o vão.
local function arquetipo(k)
  local S = 64 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  local cx, cy = 31.5, 27
  local function cloth(x, y)
    local an = math.atan(y - U(cy), x - U(cx))
    return pick('stu', 0.5 - 0.3 * (x - U(cx)) / (20 * k) - 0.3 * (y - U(cy)) / (20 * k), floor(an / (math.pi / 26) + (y / (3 * k))) % 2 == 0)
  end
  local function toC(x, y) return math.deg(math.atan(cy - y, cx - x)) end
  -- tiras da mortalha, penduradas do anel, com a ponta acesa
  layer(g, function(t)
    for n2, q in ipairs({ { 152, 17 }, { 134, 24 }, { 116, 14 }, { 98, 27 }, { 82, 19 }, { 64, 25 }, { 46, 15 }, { 28, 21 } }) do
      local a = rad(q[1])
      local x0, y0 = cx + cos(a) * 17.5, cy + sin(a) * 17.5
      local y1 = min(58, y0 + q[2])
      local x1 = x0 + ((n2 % 3) - 1) * 1.4
      cap(t, U(x0), U(y0), U(x1), U(y1), 2 * k, 0.8 * k, function(x, y) return pick('stu', 0.3, floor((y + x * 0.3) / p) % 2 == 0) end)
      flame(t, U(x1), U(y1), toC(x1, y1), 4 * k, 2 * k)
    end
  end)
  -- o anel de pano e os três capuzes
  layer(g, function(t)
    for an = 0, 359, 2 do
      local a = rad(an)
      local r2 = 2.5 + 0.7 * sin(rad(an * 3 + 40))
      ell(t, U(cx + cos(a) * 17.5), U(cy + sin(a) * 17.5), r2 * k, r2 * k, cloth)
    end
    for i2 = 0, 2 do
      local an = -90 + i2 * 120 - 14
      local a = rad(an)
      local hx, hy = cx + cos(a) * 18, cy + sin(a) * 18
      local tx, ty = -sin(a), cos(a)
      -- capuz: bojo e bico para trás
      ell(t, U(hx), U(hy), 6.2 * k, 6.2 * k, cloth)
      polyf(t, pts({ { hx - tx * 3 + cos(a) * 5.4, hy - ty * 3 + sin(a) * 5.4 }, { hx - tx * 11 + cos(a) * 4, hy - ty * 11 + sin(a) * 4 },
        { hx - tx * 5 - cos(a) * 3.6, hy - ty * 5 - sin(a) * 3.6 } }), cloth)
      -- a boca do capuz, virada para o seguinte, e o manto de trás entrando por ela
      ell(t, U(hx + tx * 2.4), U(hy + ty * 2.4), 3.8 * k, 4.4 * k, 'k')
      cap(t, U(hx + tx * 7.4), U(hy + ty * 7.4), U(hx + tx * 2), U(hy + ty * 2), 2.4 * k, 0.5 * k, cloth)
      flame(t, U(hx + tx * 1 - cos(a) * 1.4), U(hy + ty * 1 - sin(a) * 1.4), toC(hx, hy), 4 * k, 2 * k)
    end
  end)
  -- pernas penduradas
  layer(g, function(t)
    for _, q in ipairs({ { -5.4, 10.6, 48 }, { 0, 12, 55 }, { 5.4, 10.6, 50 } }) do
      wire(t, { { U(cx + q[1]), U(cy + q[2]) }, { U(cx + q[1] * 1.15), U((cy + q[2] + q[3]) / 2) }, { U(cx + q[1] * 1.1), U(q[3]) } }, 'l', 'f', TH(k, 0.8))
      for _, d in ipairs({ { -1.8, 1.4 }, { 0, 2 }, { 1.8, 1.4 } }) do
        wire(t, { { U(cx + q[1] * 1.1), U(q[3]) }, { U(cx + q[1] * 1.1 + d[1]), U(q[3] + d[2]) }, { U(cx + q[1] * 1.1 + d[1] * 0.7), U(q[3] + d[2] + 1) } }, '6', '7', TH(k, 0.5))
      end
    end
  end, SOLID:gsub('[67]', ''))
  -- o disco de penas em volta do vão
  layer(g, function(t)
    for y = 0, S - 1 do for x = 0, S - 1 do
      local rx, ry = (x - U(cx)) / k, (y - U(cy)) / k
      local r2 = sqrt(rx * rx + ry * ry)
      local an = math.atan(ry, rx)
      local st = floor(an / (math.pi / 22)) % 2 == 0
      if r2 >= 6.4 and r2 <= 12.4 + (st and 0.9 or 0) then
        local v = (r2 - 6.4) / 6.4
        local ch = pick('876', 0.75 - v * 0.6 + 0.2 * lum(x, y, U(cx), U(cy), 13 * k, 13 * k), st)
        if r2 > 9 and r2 < 10 and not st then ch = '8' end
        t[y][x] = ch
      end
    end end
    -- tocos de vela presos na borda do vão, a chama virada para dentro
    for n2 = 0, 8 do
      local a = rad(n2 * 40 + 12)
      local x0, y0 = cx + cos(a) * 9.6, cy + sin(a) * 9.6
      local x1, y1 = cx + cos(a) * 7.4, cy + sin(a) * 7.4
      cap(t, U(x0), U(y0), U(x1), U(y1), 1.1 * k, 0.9 * k, function(x, y) return pick('123', n2 % 2, ck(x, y)) end)
      flame(t, U(x1), U(y1), math.deg(a) + 180, 3 * k, 1.6 * k)
    end
  end)
  -- o vão
  for y = 0, S - 1 do for x = 0, S - 1 do
    local r2 = sqrt((x - U(cx)) ^ 2 + (y - U(cy)) ^ 2) / k
    if r2 < 6.4 then
      if ('FGH'):find(g[y][x], 1, true) then goto continue end
      g[y][x] = '.'
      if r2 > 3.8 then g[y][x] = 'X' elseif r2 > 1.5 and (x // TH(k, 1) + y // TH(k, 1)) % 2 == 0 then g[y][x] = 'Y' end
    elseif r2 < 6.4 + 1 / k and g[y][x] ~= '.' and not ('123FGH'):find(g[y][x], 1, true) then g[y][x] = 'A' end
    ::continue::
  end end
  -- a roda de chamas, todas viradas para o vão
  for n2 = 0, 21 do
    local a = rad(n2 * 16.4 + 8)
    local r2 = 26 + (n2 % 3) * 1.6
    local x, y = cx + cos(a) * r2, cy + sin(a) * r2 * 0.92
    if y < 61 and y > 3 and x > 3 and x < 60 then
      local t = L.grid(S, S)
      flame(t, U(x), U(y), toC(x, y), 4.2 * k, 2.2 * k, true)
      for yy = 0, S - 1 do for xx = 0, S - 1 do if t[yy][xx] ~= '.' and g[yy][xx] == '.' then g[yy][xx] = t[yy][xx] end end end
    end
  end
  return g
end

local function fit(src, size, dx)
  local g = L.grid(size, size)
  blit(g, src, (size - src.w) // 2 + (dx or 0), (size - src.h) // 2)
  return g
end
do -- as medidas saem numa linha só por sprite
  local raw = print
  print = function(sx) if tostring(sx):find('opacos') then raw((tostring(sx):gsub('^%s+', ''))) end end
end
local function out(stage, kind, g) C.save('wisp', stage, kind, g, LEG, LIT, LOOSE) end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', ecoMapa())
out('eco', 'retrato', fit(ecoRetrato(3), 96, 3))
out('espirito', 'mapa', espirito(1))
out('espirito', 'retrato', fit(espirito(2.5), 96))
out('entidade', 'mapa', entidade(1))
out('entidade', 'retrato', entidade(2))
out('arquetipo', 'mapa', arquetipo(1))
out('arquetipo', 'retrato', arquetipo(2))
print('ok wisp')
