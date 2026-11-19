-- Conceitos da família Bit (Etapa 1): Fagulha, Eco, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- Pombo (Columba livia) + tela e letreiro digital + o Digital como pixel aceso. Traço: glitch na plumagem (uma faixa
-- do corpo deslocada de lado, com franja de cor, e o brilho do pescoço em subpixels verdes e magenta).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/bit/build.lua')
-- O Eco do mapa é desenhado pixel a pixel; as outras etapas são funções de k (1 no mapa, textura mais fina no retrato).
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max, math.sin, math.cos, math.rad

local LEG = {
  A = '#1A1424',                                              -- contorno
  a = '#33373F', b = '#4E5560', c = '#6E7783', d = '#959DA8', e = '#BBC1C8', -- pena cinza-azulada
  f = '#26282F',                                              -- barras da asa e ponta da cauda
  i = '#8A5459', j = '#B57A7C',                               -- pés
  h = '#C9C4BE', q = '#3A3840', r = '#B0603A',                -- cera do bico, bico, olho
  ['1'] = '#1D1F26', ['2'] = '#2C2F38', ['3'] = '#40444F', ['4'] = '#59606B', -- vidro e moldura da tela
  ['6'] = '#C8C2B4', ['7'] = '#9A9488', ['8'] = '#6E6A66',    -- pena de cinza (Arquétipo)
  u = '#17302A', v = '#351C36', w = '#1B2440', z = '#44464F', -- pixel apagado: verde, magenta, azul, branco
  G = '#6FE08A', M = '#E070C8', B = '#5A8CFF', W = '#F2F2FF', -- pixel aceso
  g = '#6FE08A', m = '#E070C8', n = '#5A8CFF', x = '#F2F2FF', X = '#9B7BFF', Y = '#5A45A8', -- soltos (só emissivo)
}
local LIT = { G = 'u', M = 'v', B = 'w', W = 'z' }
local LOOSE = 'gmnxXY'
local SOLID = ''
for ch in pairs(LEG) do if not ('AgmnxXY'):find(ch, 1, true) then SOLID = SOLID .. ch end end

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
local function chk(p) return function(x, y) return (floor(x / p) + floor(y / p)) % 2 == 0 end end
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
local function layer(g, draw, solid)
  local t = L.grid(g.w, g.h)
  draw(t)
  L.outline(t, 'A', solid or SOLID)
  blit(g, t)
  return t
end
local function dot(g, x, y, k, ch)
  local s2 = TH(k, 0.8)
  L.rect(g, floor(x), floor(y), floor(x) + s2 - 1, floor(y) + s2 - 1, ch or 'g', '.')
end
local function scale(k)
  local function U(v) return v * k + (k - 1) / 2 end
  local function pts(l) local r2 = {} for i2, q2 in ipairs(l) do r2[i2] = { U(q2[1]), U(q2[2]) } end return r2 end
  return U, pts
end
local function lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end

-- o glitch: as linhas y0..y1 inteiras andam dx de lado; a ponta de um lado fica magenta e a do outro verde
local function tear(g, y0, y1, dx)
  for y = max(0, floor(y0)), min(g.h - 1, floor(y1)) do
    local row, lo, hi = {}, nil, nil
    for x = 0, g.w - 1 do row[x] = '.' end
    for x = 0, g.w - 1 do
      local nx = x + dx
      if g[y][x] ~= '.' and nx >= 1 and nx <= g.w - 2 then
        row[nx] = g[y][x]
        if not LOOSE:find(g[y][x], 1, true) then lo = lo and min(lo, nx) or nx; hi = hi and max(hi, nx) or nx end
      end
    end
    if lo then row[lo] = 'M'; row[hi] = 'G' end
    for x = 0, g.w - 1 do g[y][x] = row[x] end
  end
end
-- fica só a peça maior (8 vizinhos); o que se soltou do corpo some
local function keepMain(t)
  local seen, comps = {}, {}
  local function solid(x, y) local c2 = L.get(t, x, y); return c2 ~= '.' and not LOOSE:find(c2, 1, true) end
  for y = 0, t.h - 1 do for x = 0, t.w - 1 do
    if solid(x, y) and not seen[y * t.w + x] then
      local list, stack = {}, { { x, y } }
      seen[y * t.w + x] = true
      while #stack > 0 do
        local q2 = table.remove(stack)
        list[#list + 1] = q2
        for ddy = -1, 1 do for ddx = -1, 1 do
          local nx, ny = q2[1] + ddx, q2[2] + ddy
          if solid(nx, ny) and not seen[ny * t.w + nx] then seen[ny * t.w + nx] = true; stack[#stack + 1] = { nx, ny } end
        end end
      end
      comps[#comps + 1] = list
    end
  end end
  table.sort(comps, function(a, b) return #a > #b end)
  for i2 = 2, #comps do for _, q2 in ipairs(comps[i2]) do t[q2[2]][q2[1]] = '.' end end
end
-- lâmina de asa (a mesma das outras famílias): fn(x, y, u, t)
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
        if sc and floor(u * len / sc) % 2 == 1 then tr = tr * 0.82 end
        local le = 0.16 * (1 - u) ^ 0.5 + 0.04
        if v >= -le and v <= tr then
          local ch = fn(xx, yy, u, (v + le) / (tr + le))
          if ch then L.set(g, xx, yy, ch) end
        end
      end
    end
  end
end
-- asa de pombo: cobertura clara, duas barras escuras, ponta escura; pal de três tons e a cor da barra
local function wingFn(p, pal, bar, len)
  local ck = chk(p)
  return function(x, y, u, t)
    if u > 0.88 then return pick(bar .. pal:sub(1, 1), 0, ck(x, y)) end
    local s2 = u * len + t * 3
    if t > 0.3 and ((s2 > len * 0.42 and s2 < len * 0.42 + 1.6) or (s2 > len * 0.66 and s2 < len * 0.66 + 1.6)) then
      return pick(bar .. pal:sub(1, 1), 0, ck(x, y))
    end
    return pick(pal, 0.9 - t * 0.8, ck(x, y))
  end
end

-- cabeça e pescoço de pombo. (nx, ny) base do pescoço, (hx, hy) cabeça, em pixels; mode: nil ave, 'scan' com linhas
-- de varredura, 'led' só matriz de pixels acesos
local function head(t, k, nx, ny, hx, hy, mode)
  local p = PP(k)
  local ck = chk(p)
  cap(t, nx, ny, hx, hy + 1.6 * k, 2.6 * k, 2 * k, function(x, y)
    if mode == 'led' then return ck(x, y) and ((floor(y / p) % 2 == 0) and 'G' or 'M') or '1' end
    -- o brilho do pescoço em subpixels
    if (y - hy) / k > 2.4 and ck(x, y) and floor(x / p) % 3 ~= 0 then return (floor(y / p) % 2 == 0) and 'G' or 'M' end
    return pick('abc', 0.6 - (x - nx) / (5 * k), ck(x, y))
  end)
  ell(t, hx, hy, 2.9 * k, 2.6 * k, function(x, y)
    if mode == 'led' then return ck(x, y) and ((floor(x / p) % 2 == 0) and 'W' or 'B') or '1' end
    if mode == 'scan' and floor(y / p) % 2 == 0 then return '2' end
    return pick('bcde', lum(x, y, hx, hy, 2.9 * k, 2.6 * k), ck(x, y))
  end)
  polyf(t, { { hx + 2.5 * k, hy - 0.2 * k }, { hx + 5 * k, hy + 0.9 * k }, { hx + 2.5 * k, hy + 1.3 * k } }, mode == 'led' and 'M' or 'q')
  if mode ~= 'led' then
    ell(t, hx + 2.7 * k, hy - 0.3 * k, 0.8 * k, 0.6 * k, 'h')
    if k > 1 then ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.75 * k, 0.75 * k, 'r'); ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.35 * k, 0.35 * k, '1')
    else L.set(t, hx + 1.2, hy - 0.4, 'r') end
  else
    ell(t, hx + 1.2 * k, hy - 0.4 * k, 0.6 * k, 0.6 * k, 'W')
  end
end
-- pombo de perfil no espaço do quadro de 28, deslocado de (ox, oy) pixels
local function pigeon(t, k, ox, oy, o)
  o = o or {}
  local p = PP(k)
  local ck = chk(p)
  local function X(v) return v * k + (k - 1) / 2 + ox end
  local function Y(v) return v * k + (k - 1) / 2 + oy end
  for _, d in ipairs(o.tails or { 0 }) do
    polyf(t, { { X(7.6), Y(14.4 + d) }, { X(2.4 - d), Y(18 + d) }, { X(3 - d), Y(20.6 + d) }, { X(9), Y(19.4) } }, function(x, y)
      return x < X(4.8 - d) and pick('fa', 0, ck(x, y)) or pick('ab', 0, ck(x, y))
    end)
  end
  for _, lx in ipairs(o.legs or { 12.6, 16 }) do
    wire(t, { { X(lx), Y(19.4) }, { X(lx), Y(23.2) } }, 'j', 'i', TH(k, 0.6))
    for _, d in ipairs({ { -1.2, 0.5 }, { 0.6, 0.8 }, { 1.9, 0.4 } }) do
      wire(t, { { X(lx), Y(23.2) }, { X(lx + d[1]), Y(23.2 + d[2]) } }, 'j', nil, TH(k, 0.45))
    end
  end
  ell(t, X(13.2), Y(15.8), 7.4 * k, 4.7 * k, function(x, y) return pick('abcd', lum(x, y, X(13.2), Y(15.8), 7.4 * k, 4.7 * k), ck(x, y)) end)
  ell(t, X(18.4), Y(13.8), 4 * k, 4.4 * k, function(x, y) return pick('bcde', lum(x, y, X(18.4), Y(13.8), 4 * k, 4.4 * k), ck(x, y)) end)
  -- asa fechada com as duas barras
  ell(t, X(11.2), Y(15.2), 6.2 * k, 3.5 * k, function(x, y)
    local s2 = (x - X(11.2)) / k + (y - Y(15.2)) / k * 0.7
    if (s2 > -1.6 and s2 < -0.2) or (s2 > 1.6 and s2 < 3) then return pick('fa', 0, ck(x, y)) end
    return pick('cde', lum(x, y, X(11.2), Y(15.2), 6.2 * k, 3.5 * k), ck(x, y))
  end)
  for _, hd in ipairs(o.heads or { { 18.6, 12, 18.8, 6.4 } }) do
    head(t, k, X(hd[1]), Y(hd[2]), X(hd[3]), Y(hd[4]), hd[5])
  end
end

-- FAGULHA (Static Mote): uma pena de pombo que se desfaz em pixels pela ponta.
local function fagulhaMapa()
  return L.frame({
    '............',
    '..........m.',
    '......AAA.g.',
    '.....AGdcA..',
    '....AdMcbdA.',
    '...AdcbGcdA.',
    '..AecbBbcA..',
    '..AdMbcbA...',
    '.AhcbAAA....',
    '.AhAA.......',
    '.AA....x.g..',
    '............',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local ck = chk(3)
  layer(g, function(t)
    -- a pena: raque e barbas, da base (embaixo, à esquerda) à ponta
    blade(t, 16, 84, -48, 78, 20, 1, function(x, y, u, tt)
      if u > 0.72 and hash(x // 6, y // 6, 3) < (u - 0.72) * 3.2 then return nil end
      if tt < 0.42 and tt > 0.34 then return 'h' end
      local barb = floor((x * 0.6 + y * (tt < 0.38 and -1 or 1)) / 3) % 2 == 0
      local ch = pick('bcde', 0.85 - tt * 0.7, barb)
      if u > 0.62 and hash(x // 6, y // 6, 5) < (u - 0.6) * 1.6 then
        return ({ 'G', 'M', 'B', 'W' })[1 + floor(hash(x // 6, y // 6, 7) * 4)]
      end
      return ch
    end, 9)
    blade(t, 16, 84, -48, 78, 20, -1, function(x, y, u, tt)
      if u > 0.72 and hash(x // 6, y // 6, 4) < (u - 0.72) * 3.2 then return nil end
      if tt < 0.2 then return 'h' end
      local barb = floor((x * 0.6 - y) / 3) % 2 == 0
      if u > 0.62 and hash(x // 6, y // 6, 6) < (u - 0.6) * 1.6 then
        return ({ 'G', 'M', 'B', 'W' })[1 + floor(hash(x // 6, y // 6, 8) * 4)]
      end
      return pick('abcd', 0.6 - tt * 0.5, barb)
    end, 9)
    wire(t, { { 10, 90 }, { 16, 84 } }, 'h', 'e', 3)
    keepMain(t)
  end)
  -- os pixels que já se soltaram
  for _, q2 in ipairs({ { 72, 12 }, { 80, 22 }, { 84, 8 }, { 66, 6 }, { 88, 34 }, { 78, 40 }, { 60, 16 }, { 90, 18 }, { 74, 28 } }) do
    dot(g, q2[1] - q2[1] % 6, q2[2] - q2[2] % 6, 6, ({ 'g', 'm', 'n', 'x' })[1 + (q2[1] + q2[2]) % 4])
  end
  return g
end

-- ECO (Bitling): o pombo de perfil, em proporção de pombo; o brilho do pescoço é feito de subpixels acesos e uma
-- faixa do corpo está dois pixels fora do lugar.
local function ecoMapa()
  local g = L.frame({
    '............................',
    '............................',
    '............................',
    '.................AAAA.......',
    '................AcddcA......',
    '...............AbcdedcA.....',
    '...............AbcdcrdhA....',
    '...............AabcdccqqA...',
    '...............AaGbMcAAA....',
    '..............AaMbGbcA......',
    '............AAabGbMBcdA.....',
    '.........AAAabcbGbMccdeA....',
    '.......AAabccdcdccbccdeeA...',
    '......AabcdcdcfdcfccdedeA...',
    '.....AabcdcdcffdcffcdcdeA...',
    '....AabcbcdcdffcdffcdcdA....',
    '...AfabcbcdcdcffdcffdccA....',
    '..AffabcbcbcdcdffcfcbbA.....',
    '..AfafabcbcbcbcdcdcbaA......',
    '..AfafAababcbcbcbcbaA.......',
    '..AfAA.AAAAAbAAAbAAA........',
    '...A.......AjA.AjA..........',
    '...........AiA.AiA..........',
    '..........AjijjjijjA........',
    '...........AAAAAAAA.........',
    '............................',
    '............................',
    '............................',
  }, 28, 28, 'eco')
  tear(g, 15, 16, 2)
  for y = 15, 16 do for x = 0, 27 do if g[y][x] == 'f' then g[y][x] = 'B' end end end
  dot(g, 1, 14, 1, 'm'); dot(g, 26, 17, 1, 'g'); dot(g, 2, 22, 1, 'n'); dot(g, 5, 23, 1, 'g'); dot(g, 1, 20, 1, 'x'); dot(g, 24, 10, 1, 'm')
  return g
end
local function ecoRetrato(k)
  local S = 28 * k
  local g = L.grid(S, S)
  layer(g, function(t) pigeon(t, k, 0, 0) end)
  tear(g, 15 * k, 16.4 * k, 2 * k)
  tear(g, 9.4 * k, 9.9 * k, -k)
  for y = floor(15 * k), floor(16.4 * k) do for x = 0, S - 1 do
    if g[y][x] == 'f' and (x // 2 + y // 2) % 2 == 0 then g[y][x] = 'B' end
  end end
  for _, q2 in ipairs({ { 1, 14 }, { 26, 17 }, { 1.4, 22 }, { 4.6, 23.4 }, { 0.6, 19.6 }, { 24, 10 }, { 3, 12 } }) do
    dot(g, floor(q2[1] * k), floor(q2[2] * k), k * 0.8, ({ 'g', 'm', 'n', 'x' })[1 + floor(q2[1] + q2[2]) % 4])
  end
  return g
end

-- ESPÍRITO (Glitchkin): o pombo feito de quadros repetidos. O balanço da cabeça ficou preso: três pescoços e três
-- cabeças, a segunda já com linhas de varredura e a terceira só matriz de pixels; três pernas, duas caudas, uma tela
-- rachada no peito e a asa em fatias fora do lugar.
local function espirito(k)
  local S = 36 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local ck = chk(p)
  local kk = k
  k = k * 1.1                                                 -- maior que o Eco
  local ox, oy = 1.5 * kk, 5 * kk
  local function X(v) return v * k + (k - 1) / 2 + ox end
  local function Y(v) return v * k + (k - 1) / 2 + oy end
  layer(g, function(t)
    pigeon(t, k, ox, oy, { tails = { 0, 1.6 }, legs = { 11.4, 14, 16.8 },
      heads = { { 20.4, 11.8, 23.6, 7.2, 'led' }, { 19.4, 11.6, 19.8, 4.4, 'scan' }, { 18, 12, 15.8, 6.8 } } })
    -- a tela no peito
    local x0, y0, x1, y1 = floor(X(15.4)), floor(Y(12.2)), floor(X(21.4)), floor(Y(17.2))
    local b = TH(k, 0.8)
    for y = y0, y1 do for x = x0, x1 do
      local ch
      if x < x0 + b or y < y0 + b then ch = '4' elseif x > x1 - b or y > y1 - b then ch = '2'
      else
        local col = floor((x - x0) / p)
        ch = ck(x, y) and '1' or '2'
        if col % 4 == 1 and floor(y / p) % 2 == 0 then ch = ({ 'G', 'M', 'B' })[1 + (col // 4) % 3] end
      end
      t[y][x] = ch
    end end
    wire(t, { { X(16.4), Y(13.4) }, { X(18.6), Y(14.8) }, { X(18), Y(16) }, { X(20.2), Y(16.6) } }, '4', 'e', TH(k, 0.4))
  end)
  -- a asa em fatias
  tear(g, Y(13.4), Y(14.2), -floor(kk + 0.5))
  tear(g, Y(15.2), Y(16), floor(2 * kk + 0.5))
  tear(g, Y(17.2), Y(17.8), -floor(2 * kk + 0.5))
  k = kk
  for _, q2 in ipairs({ { 2, 12 }, { 4, 9 }, { 31, 20 }, { 33, 16 }, { 30, 28 }, { 3, 30 }, { 12, 5 }, { 8, 8 }, { 33, 24 } }) do
    dot(g, floor(q2[1] * k), floor(q2[2] * k), k * 0.8, ({ 'g', 'm', 'n', 'x' })[1 + (q2[1] + q2[2]) % 4])
  end
  return g
end

-- ENTIDADE MAIOR: o painel de LED da fachada. Três asas em cata-vento saem de dentro da tela (lá dentro são imagem,
-- cá fora são pena); o rosto está na tela, deitado: um olho só. Em cima, três pescoços sem cabeça; embaixo, três
-- pernas que não pisam em nada, e os cabos soltos.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  local cx, cy = 23.5, 23
  local px0, py0, px1, py1 = floor(U(14.6)), floor(U(17.4)), floor(U(32.4)), floor(U(28.6))
  local b = TH(k, 1.4)
  local function inScreen(x, y) return x >= px0 + b and x <= px1 - b and y >= py0 + b and y <= py1 - b end
  local function inPanel(x, y) return x >= px0 and x <= px1 and y >= py0 and y <= py1 end
  -- pernas e cabos
  layer(g, function(t)
    for _, q2 in ipairs({ { 16.4, 43.4 }, { 23.5, 45 }, { 30.6, 43.4 } }) do
      wire(t, { { U(q2[1]), U(30) }, { U(q2[1] + (q2[1] - cx) * 0.08), U(q2[2]) } }, 'j', 'i', TH(k, 0.9))
      for _, d in ipairs({ { -1.8, 0.8 }, { 0.2, 1.2 }, { 2, 0.7 } }) do
        wire(t, { { U(q2[1] + (q2[1] - cx) * 0.08), U(q2[2]) }, { U(q2[1] + d[1]), U(q2[2] + d[2]) } }, 'j', nil, TH(k, 0.5))
      end
    end
    cap(t, U(cx), U(29), U(cx), U(33), 4 * k, 2.4 * k, function(x, y) return pick('abcd', 0.5 - (x - U(cx)) / (8 * k), ck(x, y)) end)
    wire(t, { { U(31), U(29) }, { U(35.4), U(34.6) }, { U(34.4), U(38) } }, '2', '3', TH(k, 0.7))
    L.rect(t, floor(U(33.6)), floor(U(38)), floor(U(35.4)), floor(U(39.6)), '3')
  end, SOLID:gsub('[ij]', ''))
  -- as três asas
  local wg = L.grid(S, S)
  for _, ang in ipairs({ -90, 30, 150 }) do
    local a = rad(ang)
    blade(wg, U(cx + cos(a) * 1.5), U(cy + sin(a) * 1.5), ang, 18.6 * k, 9 * k, 1, wingFn(p, 'cde', 'f', 18.6), 2.4 * k)
  end
  layer(g, function(t)
    for y = 0, S - 1 do for x = 0, S - 1 do if wg[y][x] ~= '.' and not inPanel(x, y) then t[y][x] = wg[y][x] end end end
  end)
  -- o painel
  layer(g, function(t)
    for y = py0, py1 do for x = px0, px1 do
      local ch
      if x < px0 + b or y < py0 + b then ch = '4' elseif x > px1 - b or y > py1 - b then ch = '2'
      else
        ch = (floor(y / p) % 2 == 0) and '1' or '2'
        -- o olho, deitado
        local d = sqrt(((x - U(cx)) / (2.7 * k)) ^ 2 + ((y - U(cy)) / (4.3 * k)) ^ 2)
        if d < 1.3 then
          ch = '1'
          if d > 0.78 and d < 1.06 then ch = 'W' elseif d > 0.3 and d < 0.6 then ch = 'M' elseif d >= 0.6 and d <= 0.78 and ck(x, y) then ch = 'z' end
        elseif wg[y][x] ~= '.' and ck(x, y) then
          ch = ({ f = 'M', c = 'B', d = 'G', e = 'G' })[wg[y][x]] or 'B'
        elseif hash(x // p, y // p, 31) < 0.1 then ch = 'B' end
      end
      t[y][x] = ch
    end end
  end)
  -- três pescoços sem cabeça
  layer(g, function(t)
    for n2, q2 in ipairs({ { 16.4, 12, 6.4 }, { 19.6, 10.6, 4.6 }, { 30.4, 12, 6.6 } }) do
      local tx, ty = q2[1] + 1.6, q2[2] - q2[3] * 0.5
      cap(t, U(q2[1]), U(17.4), U(tx), U(ty), 2 * k, 1.7 * k, function(x, y)
        if ck(x, y) and floor(x / p) % 3 ~= 0 and y < U(14.6) then return (floor(y / p) % 2 == 0) and 'G' or 'M' end
        return pick('abc', 0.6 - (x - U(q2[1])) / (4 * k), ck(x, y))
      end)
      ell(t, U(tx), U(ty - 0.6), 1.7 * k, 0.9 * k, function(x, y) return ck(x, y) and 'W' or 'z' end)
    end
  end)
  tear(g, U(26.6), U(27.6), 3 * k)
  tear(g, U(13), U(13.8), -2 * k)
  tear(g, U(8.6), U(9.2), k)
  keepMain(g)
  for _, q2 in ipairs({ { 4, 10 }, { 42, 12 }, { 6, 36 }, { 41, 38 }, { 9, 5 }, { 38, 4 }, { 44, 22 }, { 3, 24 }, { 28, 2 }, { 20, 43 }, { 27, 41 } }) do
    dot(g, floor(q2[1] * k), floor(q2[2] * k), k * 0.8, ({ 'g', 'm', 'n', 'x' })[1 + (q2[1] + q2[2]) % 4])
  end
  return g
end

-- ARQUÉTIPO: o quadro repetido. Nove telas em roda em volta do vão, cada uma na frente da anterior (e a primeira na
-- frente da última); em todas, o mesmo pombo no mesmo instante. Do bicho sobram três asas de cinza, os pés pendurados
-- e as penas que sobem em pixels.
local GLYPH = { '....M..', '.WWWW..', 'WWWWW..', '.WWW...', '..G.G..' } -- o pombo sem cabeça
local function arquetipo(k)
  local S = 64 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local ck = chk(p)
  local cx, cy = 31.5, 29
  -- pés pendurados
  layer(g, function(t)
    for n2, q2 in ipairs({ { 17, 42, 9 }, { 21.6, 45, 12 }, { 26.4, 46, 8 }, { 31, 47, 13 }, { 35.6, 46, 9 }, { 40.4, 45, 12 }, { 45, 42, 8 } }) do
      local y1 = min(59, q2[2] + q2[3])
      wire(t, { { U(q2[1]), U(q2[2]) }, { U(q2[1] + (n2 % 2) * 0.6), U(y1) } }, '7', '8', TH(k, 0.8))
      for _, d in ipairs({ { -1.6, 1 }, { 0.2, 1.6 }, { 1.8, 0.9 } }) do
        wire(t, { { U(q2[1] + (n2 % 2) * 0.6), U(y1) }, { U(q2[1] + d[1]), U(y1 + d[2]) } }, n2 % 2 == 0 and 'j' or 'i', nil, TH(k, 0.5))
      end
    end
  end, SOLID:gsub('[ij78]', ''))
  -- as telas
  local N = 9
  local fr = {}
  for n2 = 1, N do
    local t = L.grid(S, S)
    fr[n2] = t
    local a = rad(-90 + (n2 - 1) * 360 / N)
    local r2 = 15.6 + (n2 % 3) * 1.4
    local w2, h2 = 13 + (n2 * 5) % 4, 10 + (n2 * 3) % 3
    local fx, fy = cx + cos(a) * r2, cy + sin(a) * r2 * 0.94
    local x0, y0, x1, y1 = floor(U(fx - w2 / 2)), floor(U(fy - h2 / 2)), floor(U(fx + w2 / 2)), floor(U(fy + h2 / 2))
    local b = TH(k, 1)
    for y = y0, y1 do for x = x0, x1 do
      local ch
      if x < x0 + b or y < y0 + b then ch = '4' elseif x > x1 - b or y > y1 - b then ch = '3'
      else
        ch = pick('12', 0, (floor((x + y) / p) % 2 == 0))
        if hash(x // p, y // p, n2) < 0.11 then ch = ({ 'B', 'G', 'M' })[1 + floor(hash(x // p, y // p, n2 + 20) * 3)] end
        if n2 % 4 == 0 and floor((x - x0) / p) % 5 == 2 and floor(y / p) % 2 == 0 then ch = 'B' end
      end
      L.set(t, x, y, ch)
    end end
    -- o mesmo pombo, no mesmo lugar de cada tela
    local gk = TH(k, 1)
    local gx, gy = floor((x0 + x1) / 2 - 3.5 * gk), floor((y0 + y1) / 2 - 2.5 * gk)
    for j2, row in ipairs(GLYPH) do
      for i2 = 1, #row do
        local c2 = row:sub(i2, i2)
        if c2 ~= '.' then L.rect(t, gx + (i2 - 1) * gk, gy + (j2 - 1) * gk, gx + i2 * gk - 1, gy + j2 * gk - 1, c2, '12BGM') end
      end
    end
    if n2 % 3 == 1 then wire(t, { { x0 + 2 * b, y0 + 2 * b }, { (x0 + x1) / 2, y0 + (y1 - y0) * 0.4 }, { x0 + (x1 - x0) * 0.4, y1 - b } }, '4', nil, 1, '12') end
    L.outline(t, 'A', SOLID)
  end
  for n2 = 1, N do blit(g, fr[n2]) end
  -- a roda impossível: a primeira tela fica na frente da última
  for y = 0, S - 1 do for x = 0, S - 1 do
    if fr[1][y][x] ~= '.' and fr[N][y][x] ~= '.' then
      local free = true
      for n2 = 2, N - 1 do if fr[n2][y][x] ~= '.' then free = false; break end end
      if free then g[y][x] = fr[1][y][x] end
    end
  end end
  -- três asas de cinza saem das telas, por cima delas, e umas penas de pombo ainda presas nas molduras
  for i2, ang in ipairs({ -84, 36, 156 }) do
    layer(g, function(t)
      local a = rad(ang)
      blade(t, U(cx + cos(a) * 16.5), U(cy + sin(a) * 16.5), ang + 14, (i2 == 1 and 9.6 or 12) * k, 8 * k, 1, wingFn(p, '876', '8', 12), 2.4 * k)
    end)
  end
  for n2 = 0, 5 do
    local a = rad(n2 * 60 + 25)
    local fx, fy = cx + cos(a) * 22.4, cy + sin(a) * 21
    layer(g, function(t)
      blade(t, U(fx), U(fy), n2 * 60 + 70, 5 * k, 2.6 * k, 1, function(x, y, u, tt) return pick('bcd', 0.9 - tt * 0.8, ck(x, y)) end)
    end, 'A')
  end
  -- o vão
  for y = 0, S - 1 do for x = 0, S - 1 do
    local r2 = sqrt((x - U(cx)) ^ 2 + ((y - U(cy)) / 0.94) ^ 2) / k
    if r2 < 7.4 then
      g[y][x] = '.'
      if r2 > 4.4 then g[y][x] = 'X' elseif r2 > 1.5 and (x // TH(k, 1) + y // TH(k, 1)) % 2 == 0 then g[y][x] = 'Y' end
    elseif r2 < 7.4 + 1 / k and g[y][x] ~= '.' then g[y][x] = 'A' end
  end end
  tear(g, U(18), U(19), 3 * k)
  tear(g, U(37), U(37.8), -3 * k)
  tear(g, U(26), U(26.8), 2 * k)
  -- as penas que sobem em pixels
  for n2 = 1, 34 do
    local x, y = 4 + (n2 * 37) % 56, 2 + (n2 * 23) % 58
    if sqrt((x - cx) ^ 2 + (y - cy) ^ 2) > 22 then dot(g, floor(x * k), floor(y * k), k * 0.8, ({ 'g', 'm', 'n', 'x' })[1 + n2 % 4]) end
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
local function out(stage, kind, g) C.save('bit', stage, kind, g, LEG, LIT, LOOSE) end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', ecoMapa())
out('eco', 'retrato', fit(ecoRetrato(3), 96))
out('espirito', 'mapa', espirito(1))
out('espirito', 'retrato', fit(espirito(2.5), 96))
out('entidade', 'mapa', entidade(1))
out('entidade', 'retrato', entidade(2))
out('arquetipo', 'mapa', arquetipo(1))
out('arquetipo', 'retrato', arquetipo(2))
print('ok bit')
