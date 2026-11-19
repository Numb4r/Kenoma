-- Conceitos da família Shade (Etapa 1): Fagulha, Eco, Espírito, Entidade Maior e Arquétipo, um quadro parado cada.
-- Morcego-da-cara-branca (Artibeus lituratus) + marquise + a sombra como matéria. Traço: a sombra não acompanha o corpo
-- (tem outra pose e é ela que tem os olhos, na luz do crepúsculo).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/shade/build.lua')
-- Cada etapa é uma função de k (1 no mapa); no retrato a textura é mais fina e entram os detalhes de k > 1.
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local floor, ceil, sqrt, abs, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max, math.sin, math.cos, math.rad

local LEG = {
  A = '#1A1424',                                              -- contorno
  a = '#3A2E2C', b = '#574639', c = '#7A654F', d = '#A08A6C', -- pelo pardo
  m = '#2B2230', n = '#40323F', o = '#5A4652',                -- membrana
  i = '#6B5560', j = '#927C80',                               -- osso do dedo, garra
  w = '#D8CDB8',                                              -- listras da cara
  ['1'] = '#45454E', ['2'] = '#63636B', ['3'] = '#87868A', ['4'] = '#ACA9A4', ['5'] = '#34343E', -- concreto e sujeira
  r = '#7A4630', q = '#A0623C',                               -- vergalhão
  s = '#231E33', t = '#2F2942', u = '#3C3552',                -- sombra (matéria)
  ['6'] = '#C8C2B4', ['7'] = '#9A9488', ['8'] = '#6E6A66',    -- osso (Arquétipo)
  x = '#463245', y = '#5A4450', z = '#6E5A62', g = '#77737C', h = '#5E5A64', -- apagados
  R = '#C4667C', P = '#F4B6A2', W = '#FFF1E6',                -- luz do crepúsculo (olhos e borda da sombra)
  T = '#FFE9D6', V = '#F2B79A',                               -- lâmpada tubular da marquise
  K = '#C4667C', k = '#F4B6A2', X = '#9B7BFF', Y = '#5A45A8', -- soltos (só emissivo); X e Y são o Véu no vão
}
local LIT = { R = 'x', P = 'y', W = 'z', T = 'g', V = 'h' }
local LOOSE = 'KkXY'
local SOLID = ''
for ch in pairs(LEG) do if not ('AKkXY'):find(ch, 1, true) then SOLID = SOLID .. ch end end
local SOLIDB = SOLID:gsub('[678P]', '')                       -- contorno seletivo: osso fino e ponta acesa ficam sem

local function hash(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ ((s or 0) * 83492791)
  v = v ~ (v >> 13)
  return ((v * 1274126177) & 0x7fffffff) / 0x7fffffff
end
-- tom da rampa (escuro -> claro) em v (0..1), alternando com o vizinho pelo padrão st
local function pick(pal, v, st)
  local nn = #pal
  local i2 = floor(max(0, min(1, v)) * (nn - 2) + 0.5) + (st and 1 or 0)
  return pal:sub(i2 + 1, i2 + 1)
end
local function diag(p) return function(x, y) return floor((x + y) / p) % 2 == 0 end end
local function ver(p) return function(x, y) return floor(x / p) % 2 == 0 end end
local function chev(cx, p) return function(x, y) return floor((y + abs(x - cx) * 0.7) / p) % 2 == 0 end end
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
-- linha quebrada de espessura th; b entra a cada três passos
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
  L.rect(g, floor(x), floor(y), floor(x) + s2 - 1, floor(y) + s2 - 1, ch or 'K', '.')
end
-- escala: U posição (centro do pixel), pts lista de pontos
local function scale(k)
  local function U(v) return v * k + (k - 1) / 2 end
  local function pts(l) local r2 = {} for i2, q in ipairs(l) do r2[i2] = { U(q[1]), U(q[2]) } end return r2 end
  return U, pts
end
-- mão de asa: n dedos em leque a partir de (x, y); mem pinta a membrana entre eles (borda em arco para dentro)
local function hand(g, x, y, ang, len, spread, n2, bone, mem, th, vary)
  local tips = {}
  for i2 = 0, n2 - 1 do
    local a = rad(ang + (i2 / (n2 - 1) - 0.5) * spread)
    local l = len * (1 - (vary or 0.2) * (0.5 + 0.5 * sin(i2 * 2.1 + 1)))
    tips[#tips + 1] = { x + cos(a) * l, y + sin(a) * l }
  end
  if mem then
    for i2 = 1, n2 - 1 do
      local a, b = tips[i2], tips[i2 + 1]
      local mx, my = x + ((a[1] + b[1]) / 2 - x) * 0.7, y + ((a[2] + b[2]) / 2 - y) * 0.7
      polyf(g, { { x, y }, { a[1], a[2] }, { mx, my }, { b[1], b[2] } }, mem)
    end
  end
  for _, t in ipairs(tips) do wire(g, { { x, y }, t }, bone[1], bone[2], th) end
  return tips
end
-- borda de luz: os pixels de [chars] encostados no vazio (só de cima e da esquerda, ou em volta toda com all)
-- viram c; th passadas engrossam; skip deixa falhas
local function rim(t, chars, c, all, th, skip)
  for _ = 1, th or 1 do
    local add = {}
    local function e(x, y) local q = L.get(t, x, y); return q == '.' or q == c end
    for y = 0, t.h - 1 do for x = 0, t.w - 1 do
      if chars:find(t[y][x], 1, true) and (e(x - 1, y) or e(x, y - 1) or (all and (e(x + 1, y) or e(x, y + 1))))
        and not (skip and hash(x // skip, y // skip, 4) < 0.3) then add[#add + 1] = { x, y } end
    end end
    for _, q in ipairs(add) do t[q[2]][q[1]] = c end
  end
end
local function lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end

-- FAGULHA (Dusk Mote): uma lasca de marquise e, presa nela, uma sombra que não é a dela: um pedaço de asa, com um olho.
local function fagulhaMapa()
  return L.frame({
    '............',
    '............',
    '.....AAAAA..',
    '....A4343rA.',
    '....A12312A.',
    '...AsRtstAA.',
    '..AtRWPtstA.',
    '..AsRtRstsA.',
    '.AsRtsAtRsA.',
    '.AtRtA.AstA.',
    '.AAAA.K.AA..',
    '...k....K...',
  }, 12, 12, 'fagulha')
end
local function fagulhaRetrato()
  local S = 96
  local g = L.grid(S, S)
  local p = 3
  local sf = function(x, y) return pick('stu', 0.9 - (y - 30) / 60, diag(p)(x, y)) end
  layer(g, function(t)
    local tips = hand(t, 60, 34, 118, 56, 78, 4, { 'u', 't' }, sf, 2, 0.3)
    ell(t, 52, 46, 13, 11, sf)
    rim(t, 'stu', 'R', false, 2, 3)
    -- olho: pequeno, fundo na sombra
    ell(t, 50, 47, 5, 4, 'R'); ell(t, 50.5, 47, 3, 2.4, 'P'); ell(t, 51, 47, 1.4, 1.2, 'W')
    for _, q in ipairs(tips) do ell(t, q[1], q[2], 2, 2, 'P') end
  end)
  layer(g, function(t)
    local nz = noise(2, 3)
    polyf(t, { { 44, 16 }, { 74, 12 }, { 82, 20 }, { 78, 34 }, { 60, 38 }, { 46, 32 }, { 40, 24 } }, function(x, y)
      local v = y < 20 + (x - 44) * -0.1 and 0.95 or (y < 31 and 0.55 or 0.1)
      return pick('1234', v, nz(x, y))
    end)
    wire(t, { { 50, 30 }, { 56, 26 }, { 55, 20 } }, '5', nil, 1)
    wire(t, { { 68, 33 }, { 70, 27 } }, '5', nil, 1)
    wire(t, { { 78, 24 }, { 86, 20 }, { 90, 22 } }, 'r', 'q', 2)
    wire(t, { { 76, 30 }, { 84, 31 } }, 'r', 'q', 2)
  end)
  dot(g, 14, 70, 4); dot(g, 22, 82, 4, 'k'); dot(g, 74, 62, 4, 'k'); dot(g, 82, 74, 4); dot(g, 30, 22, 4, 'k'); dot(g, 66, 84, 4)
  return g
end

-- ECO (Umbrel): o morcego dorme pendurado, fechado como um guarda-chuva; a sombra dele está de pé, de asa aberta,
-- e é ela que tem os olhos.
local function eco(k)
  local S = 28 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local dg = diag(p)
  local function sf(x, y) return pick('stu', y < U(11) and 0.7 or 0.2, dg(x, y)) end
  layer(g, function(t)
    local cx = 9.5
    local half = { { 0, 10.6 }, { 4, 8.6 }, { 7.5, 9.6 }, { 7, 14.6 }, { 5.6, 12.6 }, { 4.8, 18 }, { 3.6, 15.6 }, { 2.6, 20.8 }, { 0, 24 } }
    local poly = {}
    for i2 = 1, #half do poly[#poly + 1] = { cx + half[i2][1], half[i2][2] } end
    for i2 = #half, 1, -1 do poly[#poly + 1] = { cx - half[i2][1], half[i2][2] } end
    polyf(t, pts(poly), sf)
    ell(t, U(cx), U(9), 3.2 * k, 2.9 * k, sf)
    ell(t, U(cx), U(17), 3 * k, 6.4 * k, sf)
    for _, sg in ipairs({ -1, 1 }) do
      polyf(t, pts({ { cx + sg * 2.4, 8 }, { cx + sg * 2.6, 4 }, { cx + sg * 0.3, 6.8 } }), sf)
      for _, e in ipairs({ { 6.8, 13.6 }, { 4.6, 16.6 }, { 1.8, 19 } }) do
        wire(t, { { U(cx + sg * 4), U(9.6) }, { U(cx + sg * e[1]), U(e[2]) } }, 'u', nil, TH(k, 0.4), 'st')
      end
    end
    rim(t, 'stu', 'R', false, TH(k, 0.6), k > 1 and 3 or nil)
    for _, sg in ipairs({ -1, 1 }) do
      if k > 1 then
        ell(t, U(cx + sg * 1.1), U(9), 0.8 * k, 0.6 * k, 'R'); ell(t, U(cx + sg * 1.1), U(9), 0.5 * k, 0.35 * k, 'W')
      else
        L.set(t, cx + sg, 9, 'W')
      end
    end
  end)
  layer(g, function(t)
    local bx = 20.5
    local nz = noise(p, 5)
    -- lasca de marquise
    polyf(t, pts({ { 13.4, 3 }, { 24.4, 3 }, { 25, 4.2 }, { 24, 5.4 }, { 14.2, 5.4 }, { 12.8, 4.2 } }), function(x, y)
      local v = y < U(3.6) and 0.95 or (y < U(4.6) and 0.5 or 0.05)
      return pick('1234', v, nz(x, y))
    end)
    wire(t, { { U(24.6), U(4.4) }, { U(25.2), U(4.6) } }, 'r', 'q', TH(k, 0.6))
    if k == 1 then return end
    if k > 1 then
      wire(t, { { U(18), U(3.4) }, { U(18.6), U(4.6) }, { U(18.2), U(5.6) } }, '5')
      wire(t, { { U(22.4), U(4.4) }, { U(23), U(5.8) } }, '5')
    end
    -- asas fechadas em capa
    local vr = ver(p)
    polyf(t, pts({ { bx - 0.8, 6.4 }, { bx + 0.8, 6.4 }, { bx + 2.8, 9.4 }, { bx + 3.8, 14 }, { bx + 3, 17.2 }, { bx - 3, 17.2 }, { bx - 3.8, 14 }, { bx - 2.8, 9.4 } }), function(x, y)
      return pick('mno', 0.95 - (x - U(bx - 3.8)) / (7.6 * k) * 0.9, vr(x, y))
    end)
    -- uma asa meio aberta, como guarda-chuva mal fechado
    polyf(t, pts({ { bx + 2.6, 9.6 }, { bx + 5, 9 }, { bx + 5.2, 13 }, { bx + 4.4, 12.2 }, { bx + 4.4, 16.6 }, { bx + 3.4, 15 } }), function(x, y)
      return pick('mno', 0.1, vr(x, y))
    end)
    wire(t, { { U(bx + 2.6), U(10) }, { U(bx + 5), U(9) }, { U(bx + 4.4), U(16.4) } }, 'i', 'j', TH(k, 0.5))
    -- peito no vão das asas
    local cv = chev(U(bx), p)
    ell(t, U(bx), U(13), 1.4 * k, 3.6 * k, function(x, y) return pick('bcd', lum(x, y, U(bx), U(13), 1.4 * k, 3.6 * k), cv(x, y)) end)
    for _, sg in ipairs({ -1, 1 }) do
      wire(t, { { U(bx + sg * 0.6), U(7) }, { U(bx + sg * 3.2), U(13.4) } }, 'j', 'i', TH(k, 0.5))                 -- antebraço
      wire(t, { { U(bx + sg * 3.2), U(13.4) }, { U(bx + sg * 1.4), U(16.8) } }, 'i', nil, TH(k, 0.5))             -- dedos dobrados
      if k > 1 then wire(t, { { U(bx + sg * 3), U(13.4) }, { U(bx + sg * 2.6), U(16.8) } }, 'i', nil, 1, 'mno') end
    end
    -- pés agarrados na laje
    wire(t, { { U(bx - 0.6), U(5.6) }, { U(bx - 0.6), U(6.6) } }, 'j', nil, TH(k, 0.5))
    wire(t, { { U(bx + 0.6), U(5.6) }, { U(bx + 0.6), U(6.6) } }, 'j', nil, TH(k, 0.5))
    -- cabeça (de ponta-cabeça: orelhas para baixo e para fora)
    for _, e in ipairs({ { bx - 2.6, 20, bx - 4.4, 23.6, bx - 1, 22.4 }, { bx + 0.8, 22.6, bx + 3.4, 24.4, bx + 3, 21 } }) do
      polyf(t, pts({ { e[1], e[2] }, { e[3], e[4] }, { e[5], e[6] } }), function(x, y) return pick('no', 0.6, dg(x, y)) end)
    end
    ell(t, U(bx + 0.2), U(19.6), 3.1 * k, 2.8 * k, function(x, y) return pick('abcd', 0.2 + lum(x, y, U(bx), U(19.6), 3.1 * k, 2.8 * k), cv(x, y)) end)
    ell(t, U(bx + 3), U(20.2), 1.3 * k, 1.1 * k, function(x, y) return pick('bc', 0, dg(x, y)) end)
    wire(t, { { U(bx + 3.8), U(21.2) }, { U(bx + 4), U(22) } }, 'j', nil, TH(k, 0.6))              -- folha nasal
    wire(t, { { U(bx + 0.2), U(18.4) }, { U(bx + 2.2), U(19) } }, 'w', nil, TH(k, 0.5))            -- listras da cara
    wire(t, { { U(bx + 0.4), U(21) }, { U(bx + 1.8), U(21) } }, 'w', nil, TH(k, 0.5))
    wire(t, { { U(bx + 1), U(20) }, { U(bx + 2), U(20) } }, 'a', nil, TH(k, 0.4))                  -- olho fechado
    if k > 1 then
      wire(t, { { U(bx - 2.2), U(18.4) }, { U(bx - 1.4), U(17.8) } }, 'd')
      wire(t, { { U(bx - 3.4), U(22.6) }, { U(bx - 2), U(21.6) } }, 'm')
      wire(t, { { U(bx + 2.6), U(23.4) }, { U(bx + 2.2), U(22.2) } }, 'm')
    end
  end)
  if k == 1 then -- no mapa o corpo é desenhado pixel a pixel
    L.put(g, 16, 6, {
      '....jj.....',
      '...AnmA....',
      '..AonnmA...',
      '.AjonmniA..',
      '.AjocbniA..',
      'AjondcnmiA.',
      'AjoncdnmiA.',
      'AojndcnimA.',
      'AnojcbinmA.',
      'AonojinmnA.',
      '.AnonmnmA..',
      '.AcdcccbA..',
      'AcdcwwcbbA.',
      'AcdccaacbcA',
      'AbccwwcbcbA',
      '.AbcdcbaAjA',
      'AonAAAonAA.',
      'AoA...AonA.',
      'AnA....AnA.',
      '.A......A..',
    })
  end
  dot(g, U(3), U(22), k); dot(g, U(6.4), U(24.4), k, 'k'); dot(g, U(14), U(24.6), k)
  return g
end

-- ESPÍRITO (Shadekin): o morcego de pé, um braço virou laje de marquise com a lâmpada acesa, o outro desce até o chão.
-- A sombra é maior que ele, tem três olhos e três orelhas, os braços para cima, e uma das mãos já está sobre a cabeça dele.
local function espirito(k)
  local S = 36 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local dg = diag(p)
  local function sf(x, y) return pick('stu', y < U(14) and 0.7 or 0.2, dg(x, y)) end
  layer(g, function(t)
    cap(t, U(20.5), U(30.8), U(10), U(14), 2.2 * k, 3.8 * k, sf)
    ell(t, U(9.6), U(9.4), 2.9 * k, 3.1 * k, sf)
    for _, e in ipairs({ { 7.2, 7.6, 6.6, 3.2, 8.8, 6.6 }, { 8.8, 6.6, 9.6, 2.6, 10.6, 6.6 }, { 10.6, 6.6, 12.6, 3.4, 12.2, 7.8 } }) do
      polyf(t, pts({ { e[1], e[2] }, { e[3], e[4] }, { e[5], e[6] } }), sf)
    end
    -- braço de trás para cima, mão aberta
    cap(t, U(8.4), U(13.4), U(6.4), U(10.6), 1.2 * k, 0.8 * k, sf)
    local tp = hand(t, U(6.4), U(10.6), -104, 5.8 * k, 78, 4, { 'u', 't' }, sf, TH(k, 0.6), 0.25)
    -- braço da frente: passa por cima e desce sobre a cabeça do corpo
    cap(t, U(11.4), U(13.2), U(15.6), U(7), 1.2 * k, 0.8 * k, sf)
    local tp2 = hand(t, U(15.6), U(7), 22, 6.4 * k, 78, 4, { 'u', 't' }, sf, TH(k, 0.6), 0.25)
    rim(t, 'stu', 'R', false, TH(k, 0.6), k > 1 and 3 or nil)
    for _, q in ipairs(tp) do ell(t, q[1], q[2], 0.5 * k, 0.5 * k, 'P') end
    for _, q in ipairs(tp2) do ell(t, q[1], q[2], 0.5 * k, 0.5 * k, 'P') end
    for _, e in ipairs({ { 8.2, 8.8 }, { 10.6, 8.6 }, { 9.6, 10.8 } }) do
      if k > 1 then
        ell(t, U(e[1]), U(e[2]), 0.8 * k, 0.6 * k, 'R'); ell(t, U(e[1]), U(e[2]), 0.45 * k, 0.35 * k, 'W')
      else
        L.set(t, e[1], e[2], 'W'); L.set(t, e[1], e[2] + 1, 'R', 'stu')
      end
    end
  end)
  layer(g, function(t)
    local bx = 21.4
    -- pernas e pés
    for _, sg in ipairs({ -1, 1 }) do
      wire(t, { { U(bx + sg * 1.2), U(26) }, { U(bx + sg * 1.4), U(32.4) }, { U(bx + sg * 1.4 + 1.6), U(33) } }, 'i', 'j', TH(k, 0.6))
    end
    -- braço comprido, com um resto de membrana
    local vr = ver(p)
    polyf(t, pts({ { bx - 1.6, 16.6 }, { bx - 6, 23.6 }, { bx - 4.4, 30.6 }, { bx - 3, 28.4 }, { bx - 1.8, 31.6 }, { bx - 0.4, 29 }, { bx + 0.8, 32 }, { bx + 1.4, 26 } }), function(x, y)
      return pick('mno', 0.9 - (x - U(bx - 5)) / (6 * k) * 0.8, vr(x, y))
    end)
    wire(t, { { U(bx - 1.8), U(16) }, { U(bx - 5.8), U(23.6) }, { U(bx - 3.6), U(29.6) } }, 'i', 'j', TH(k, 0.7))
    for _, e in ipairs({ { -5.2, 32.8 }, { -3.6, 33 }, { -2.2, 32.6 } }) do
      wire(t, { { U(bx - 3.6), U(29.6) }, { U(bx + e[1]), U(e[2]) } }, 'j', 'i', TH(k, 0.5))
    end
    -- laje no lugar do outro braço
    local nz = noise(p, 7)
    polyf(t, pts({ { bx + 1.4, 14.6 }, { 32.4, 12.4 }, { 33.4, 13.4 }, { bx + 2.4, 15.8 } }), function(x, y) return pick('34', 0, nz(x, y)) end)
    polyf(t, pts({ { bx + 2.2, 15.8 }, { 33.4, 13.6 }, { 33.4, 16.2 }, { bx + 2.2, 18.4 } }), function(x, y) return pick('23', 0, nz(x, y)) end)
    wire(t, { { U(bx + 2.2), U(18.8) }, { U(33.4), U(16.6) } }, '1', '5', TH(k, 0.8))
    wire(t, { { U(25.6), U(19) }, { U(31.6), U(17.8) } }, 'T', nil, TH(k, 0.8))
    L.rect(t, floor(U(25)), floor(U(19)), floor(U(25)) + TH(k, 0.8) - 1, floor(U(19)) + TH(k, 0.8) - 1, 'V')
    L.rect(t, floor(U(32.2)), floor(U(17.6)), floor(U(32.2)) + TH(k, 0.8) - 1, floor(U(17.6)) + TH(k, 0.8) - 1, 'V')
    wire(t, { { U(33.2), U(14.6) }, { U(33.8), U(14.2) } }, 'r', 'q', TH(k, 0.6))
    wire(t, { { U(28.6), U(15.2) }, { U(28.8), U(17) } }, '5', nil, TH(k, 0.4), '23')
    wire(t, { { U(31), U(14.6) }, { U(31.2), U(16) } }, '5', nil, TH(k, 0.4), '23')
    if k > 1 then
      wire(t, { { U(26.4), U(15.6) }, { U(27), U(16.6) }, { U(26.6), U(17.6) } }, '5', nil, 1, '23')
      wire(t, { { U(29.4), U(18.8) }, { U(29.4), U(20.6) } }, '1', '5', 1)
    end
    -- tronco e cabeça
    local cv = chev(U(bx), p)
    ell(t, U(bx), U(21.2), 3.7 * k, 6.4 * k, function(x, y) return pick('abcd', lum(x, y, U(bx), U(21.2), 3.7 * k, 6.4 * k), cv(x, y)) end)
    if k == 1 then return end
    for _, e in ipairs({ { bx - 2, 11, bx - 2.6, 6.4, bx - 0.4, 10 }, { bx - 0.2, 10, bx + 0.4, 5.8, bx + 1.4, 10 }, { bx + 1.4, 10.4, bx + 3.2, 6.8, bx + 2.8, 11.2 } }) do
      polyf(t, pts({ { e[1], e[2] }, { e[3], e[4] }, { e[5], e[6] } }), function(x, y) return pick('no', 0, dg(x, y)) end)
    end
    ell(t, U(bx + 0.2), U(12.6), 2.9 * k, 2.7 * k, function(x, y) return pick('abcd', lum(x, y, U(bx), U(12.6), 2.9 * k, 2.7 * k), cv(x, y)) end)
    ell(t, U(bx + 3), U(13.4), 1.3 * k, 1.1 * k, function(x, y) return pick('bc', 0, dg(x, y)) end)
    wire(t, { { U(bx + 3.6), U(12.2) }, { U(bx + 3.8), U(11.2) } }, 'j', nil, TH(k, 0.6))
    wire(t, { { U(bx + 0.6), U(11.4) }, { U(bx + 2.6), U(12.4) } }, 'w', nil, TH(k, 0.5))
    wire(t, { { U(bx + 0.8), U(14.2) }, { U(bx + 2.2), U(14) } }, 'w', nil, TH(k, 0.5))
    wire(t, { { U(bx + 0.8), U(12.9) }, { U(bx + 2.2), U(13) } }, 'a', nil, TH(k, 0.5))            -- sem olhos: uma faixa escura
  end)
  if k == 1 then -- a cabeça no mapa, pixel a pixel: três orelhas, as listras, nenhum olho
    L.put(g, 18, 6, {
      '.A..A.A...',
      'AoAAoAoA..',
      'AonnoAnA..',
      'AbcdcbnAA.',
      'AcdcwwcbjA',
      'AcdcaacbcA',
      'AbccwwcbbA',
      '.AbcccbaA.',
      '..AbcbA...',
    })
  end
  dot(g, U(2), U(20), k); dot(g, U(5), U(26), k, 'k'); dot(g, U(13), U(4), k, 'k'); dot(g, U(28), U(22), k, 'k'); dot(g, U(30), U(25), k)
  return g
end

-- ENTIDADE MAIOR: a marquise inteira. Embaixo, pendurado, o corpo sem rosto, com três pares de braços que descem em
-- grade; em cima da laje, do lado errado da luz, a sombra em cata-vento de três asas, com o rosto que falta no corpo.
local function entidade(k)
  local S = 48 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local dg = diag(p)
  local cx, cy = 23.5, 14
  local function sf(x, y) return pick('stu', 0.9 - (y - U(4)) / (18 * k), dg(x, y)) end
  layer(g, function(t)
    for n2, ang in ipairs({ -100, 20, 140 }) do
      local a = rad(ang)
      hand(t, U(cx + cos(a) * 1.5), U(cy + sin(a) * 1.5), ang + 24, 10.4 * k, 62, 3, { 'u', 't' }, sf, TH(k, 0.5), 0.12)
    end
    ell(t, U(cx), U(cy), 3.4 * k, 3.4 * k, sf)
    cap(t, U(cx), U(cy), U(cx), U(23), 1.6 * k, 2.4 * k, sf)
    rim(t, 'stu', 'R', true, TH(k, 0.5), k > 1 and 4 or 2)
    -- olhos a mais, espalhados pelas asas
    for n2, ang in ipairs({ -100, 20, 140 }) do
      for m2, r2 in ipairs({ 5.4, 8.4 }) do
        local a = rad(ang + 24 + (m2 == 1 and -10 or 12))
        local ex, ey = U(cx + cos(a) * r2), U(cy + sin(a) * r2)
        if k > 1 then ell(t, ex, ey, 0.8 * k, 0.6 * k, 'P'); ell(t, ex, ey, 0.4 * k, 0.3 * k, 'W') else L.set(t, ex, ey, 'W'); L.set(t, ex + 1, ey, 'P', 'stuR') end
      end
    end
    -- o rosto: três olhos em triângulo e a folha nasal
    for i2 = 0, 2 do
      local a = rad(-90 + i2 * 120)
      local ex, ey = U(cx + cos(a) * 1.9), U(cy + sin(a) * 1.9)
      if k > 1 then ell(t, ex, ey, 0.9 * k, 0.7 * k, 'R'); ell(t, ex, ey, 0.5 * k, 0.4 * k, 'W') else L.set(t, ex, ey, 'W') end
    end
    wire(t, { { U(cx), U(cy - 0.4) }, { U(cx), U(cy + 0.8) } }, 'P', nil, TH(k, 0.6))
  end)
  -- a laje
  layer(g, function(t)
    local nz = noise(p, 11)
    polyf(t, pts({ { 6.4, 21.6 }, { 40.6, 21.6 }, { 41.6, 23 }, { 41, 27.4 }, { 6, 27.4 }, { 5.4, 24 } }), function(x, y)
      local v = y < U(22.6) and 0.95 or (y < U(25.6) and 0.5 or 0.05)
      return pick('1234', v, nz(x, y))
    end)
    for _, e in ipairs({ { 9, 23 }, { 14.6, 24 }, { 19, 23 }, { 28, 23.4 }, { 33.4, 23 }, { 38, 24 } }) do
      wire(t, { { U(e[1]), U(e[2]) }, { U(e[1] + 0.3), U(26) } }, '5', nil, TH(k, 0.4))
    end
    if k > 1 then
      wire(t, { { U(11), U(22) }, { U(12.4), U(23.6) }, { U(11.8), U(25) } }, '5')
      wire(t, { { U(30), U(22) }, { U(31), U(23) }, { U(30.4), U(24.6) }, { U(31.4), U(25.6) } }, '5')
      wire(t, { { U(22), U(24) }, { U(24), U(24.6) }, { U(26), U(24.2) } }, '5')
    end
    for _, e in ipairs({ { 8, 16 }, { 19, 28 }, { 31, 39 } }) do
      L.rect(t, floor(U(e[1])), floor(U(27.6)), floor(U(e[2])), floor(U(27.6)) + 2 * k - 1, 'T')
      L.rect(t, floor(U(e[1])), floor(U(27.6)) + 2 * k - TH(k, 0.6), floor(U(e[2])), floor(U(27.6)) + 2 * k - 1, 'V')
      for _, x in ipairs({ e[1] - 0.8, e[2] + 0.8 }) do
        L.rect(t, floor(U(x)), floor(U(27.6)), floor(U(x)) + TH(k, 0.7) - 1, floor(U(27.6)) + 2 * k - 1, '5')
      end
    end
    wire(t, { { U(5.4), U(25) }, { U(3.6), U(24.4) } }, 'r', 'q', TH(k, 0.6))
    wire(t, { { U(41.4), U(25.6) }, { U(43.6), U(26.4) } }, 'r', 'q', TH(k, 0.6))
    wire(t, { { U(41.6), U(23.4) }, { U(43), U(22.6) } }, 'r', 'q', TH(k, 0.6))
  end)
  -- o corpo pendurado
  layer(g, function(t)
    local vr = ver(p)
    for n2 = 3, 1, -1 do
      for _, sg in ipairs({ -1, 1 }) do
        local wx, wy = cx + sg * (2.6 + 4.4 * n2), 30.6 + (n2 % 2) * 0.8
        local tips = {}
        for f = 0, 2 do
          tips[f] = { wx + sg * (f - 1) * 1.7 + sg * 0.6, 46 - n2 * 2.4 - f * 1.2 + (f == 1 and 1.6 or 0) }
        end
        polyf(t, pts({ { wx - sg * 1.4, wy - 1 }, { cx + sg * 2, 30 + n2 * 0.9 }, { tips[0][1], tips[0][2] - 1 }, { (tips[0][1] + tips[1][1]) / 2, tips[1][2] - 3.4 }, { tips[1][1], tips[1][2] - 1 },
          { (tips[1][1] + tips[2][1]) / 2, tips[2][2] - 3 }, { tips[2][1], tips[2][2] - 1 } }), function(x, y)
          return pick('mno', 0.5 - sg * 0.3, vr(x, y))
        end)
        wire(t, { { U(cx + sg * 2.4), U(30 + n2 * 0.9) }, { U(wx), U(wy) } }, 'i', 'j', TH(k, 0.7))
        for f = 0, 2 do
          wire(t, { { U(wx), U(wy) }, { U(tips[f][1] - sg * 0.4), U((wy + tips[f][2]) / 2) }, { U(tips[f][1]), U(tips[f][2]) } }, 'i', 'j', TH(k, 0.5))
        end
      end
    end
    wire(t, { { U(cx - 0.8), U(27.8) }, { U(cx - 0.8), U(29.4) } }, 'j', nil, TH(k, 0.5))
    wire(t, { { U(cx + 0.8), U(27.8) }, { U(cx + 0.8), U(29.4) } }, 'j', nil, TH(k, 0.5))
    local cv = chev(U(cx), p)
    ell(t, U(cx), U(34), 3.2 * k, 5.6 * k, function(x, y) return pick('abcd', lum(x, y, U(cx), U(34), 3.2 * k, 5.6 * k), cv(x, y)) end)
    for _, sg in ipairs({ -1, 1 }) do
      polyf(t, pts({ { cx + sg * 2.4, 42 }, { cx + sg * 3.2, 45 }, { cx + sg * 0.6, 43.4 } }), function(x, y) return pick('no', 0, dg(x, y)) end)
    end
    ell(t, U(cx), U(40.8), 3 * k, 2.8 * k, function(x, y) return pick('abcd', lum(x, y, U(cx), U(40.8), 3 * k, 2.8 * k), cv(x, y)) end)
    -- sem rosto: só as listras, que se cruzam onde seriam os olhos
    wire(t, { { U(cx - 1.8), U(39.6) }, { U(cx + 1.8), U(41.8) } }, 'w', nil, TH(k, 0.5))
    wire(t, { { U(cx + 1.8), U(39.6) }, { U(cx - 1.8), U(41.8) } }, 'w', nil, TH(k, 0.5))
  end)
  -- a luz das lâmpadas cai nos braços pendurados
  for y = floor(U(29.6)), floor(U(32.4)) do for x = floor(U(8)), floor(U(39)) do
    local ux = (x - (k - 1) / 2) / k
    if ((ux >= 8 and ux <= 16) or (ux >= 19 and ux <= 28) or (ux >= 31 and ux <= 39)) and (x // p + y // p) % 2 == 0
      and ('mnoij'):find(g[y][x], 1, true) then g[y][x] = 'P' end
  end end
  for _, e in ipairs({ { 10, 30 }, { 13.6, 32.4 }, { 21.4, 30.2 }, { 26.4, 31.4 }, { 33.4, 30 }, { 37, 32.6 }, { 4, 12 }, { 42, 8 }, { 36, 18 } }) do
    dot(g, U(e[1]), U(e[2]), k, (e[1] * 10) % 3 < 1 and 'K' or 'k')
  end
  return g
end

-- ARQUÉTIPO: o vão. Três lajes em roda, cada uma apoiada em cima da seguinte (nenhuma fica embaixo), as lâmpadas viradas
-- para dentro; no meio não há corpo, só o vão, e dele saem três sombras em cata-vento, sem ninguém que as faça, que
-- passam por cima das lajes e acabam em mãos de osso. Do morcego sobram as mãos, três orelhas e os que dormem pendurados.
local function arquetipo(k)
  local S = 64 * k
  local g = L.grid(S, S)
  local p = PP(k)
  local U, pts = scale(k)
  local dg = diag(p)
  local cx, cy = 29.5, 30
  local function sf(x, y) return pick('stu', 0.5 + 0.5 * sin((x + y) / (9 * k)), dg(x, y)) end
  -- sombras: braço em espiral e mão
  local arms = {}
  local LEN = { 25, 22, 21 }
  for i2 = 0, 2 do
    arms[i2] = L.grid(S, S)
    local t = arms[i2]
    local a0 = -90 + i2 * 120 + 20
    local px, py, pa
    local spine = {}
    for r2 = 4, LEN[i2 + 1], 0.5 do
      local a = rad(a0 + (r2 - 4) * 3.1)
      local x, y = cx + cos(a) * r2, cy + sin(a) * r2 * 0.94
      ell(t, U(x), U(y), (4.2 - 2.2 * (r2 - 4) / 22) * k, (4.2 - 2.2 * (r2 - 4) / 22) * k, sf)
      spine[#spine + 1] = { U(x), U(y) }
      px, py, pa = x, y, a0 + (r2 - 4) * 3.1 + 55
    end
    local hx, hy = U(px), U(py)
    local tp = hand(t, hx, hy, pa, 10.5 * k, 104, 5, { '6', '7' }, sf, TH(k, 0.6), 0.35)
    rim(t, 'stu', 'R', true, TH(k, 0.6), k > 1 and 5 or 2)
    for _, q in ipairs(tp) do
      ell(t, q[1], q[2], 0.6 * k, 0.6 * k, 'P')
      ell(t, hx + (q[1] - hx) * 0.55, hy + (q[2] - hy) * 0.55, 0.6 * k, 0.6 * k, 'P')
    end
    L.outline(t, 'A', SOLIDB)
  end
  -- lajes
  local slabs = {}
  for i2 = 0, 2 do
    slabs[i2] = L.grid(S, S)
    local t = slabs[i2]
    local a = rad(-90 + i2 * 120 + 8)
    local nx, ny = cos(a), sin(a)
    local tx, ty = -ny, nx
    local nz = noise(p, 20 + i2)
    local mx, my = cx + nx * 13.5 + tx * 3, cy + ny * 13.5 + ty * 3
    local function q(s2, d) return { mx + tx * s2 + nx * d, my + ty * s2 + ny * d } end
    polyf(t, pts({ q(-16, -3.2), q(15, -3.2), q(16.4, -0.6), q(15.4, 3.6), q(-15, 3.6), q(-16.6, 0.4) }), function(x, y)
      local d = ((x - U(mx)) * nx + (y - U(my)) * ny) / k
      local v = d > 1.8 and 0.95 or (d > -1.6 and 0.5 or 0.05)
      return pick('1234', v, nz(x, y))
    end)
    for _, e in ipairs({ { -12, -4 }, { -1, 7 }, { 9, 13 } }) do
      for _, d in ipairs({ -3, -2.2 }) do
        wire(t, { { U(q(e[1], d)[1]), U(q(e[1], d)[2]) }, { U(q(e[2], d)[1]), U(q(e[2], d)[2]) } }, d < -2.6 and 'T' or 'V', nil, TH(k, 1))
      end
    end
    for _, e in ipairs({ -9, -3, 4, 11 }) do
      wire(t, { { U(q(e, -0.6)[1]), U(q(e, -0.6)[2]) }, { U(q(e + 0.6, 2.2)[1]), U(q(e + 0.6, 2.2)[2]) } }, '5', nil, TH(k, 0.4))
    end
    wire(t, { { U(q(16, 0.6)[1]), U(q(16, 0.6)[2]) }, { U(q(18.6, 1.4)[1]), U(q(18.6, 1.4)[2]) } }, 'r', 'q', TH(k, 0.6))
    wire(t, { { U(q(-16, 1)[1]), U(q(-16, 1)[2]) }, { U(q(-18.4, 0.2)[1]), U(q(-18.4, 0.2)[2]) } }, 'r', 'q', TH(k, 0.6))
    -- os que dormem pendurados
    for n2, e in ipairs({ -10, -2, 6, 12 }) do
      local b = q(e, 3.6)
      if ny > -0.2 or n2 % 2 == 0 then
        local len = 3.4 + ((n2 * 7 + i2 * 3) % 4) * 0.9
        cap(t, U(b[1]), U(b[2] + 0.6), U(b[1]), U(b[2] + len), 0.8 * k, 1.5 * k, function(x, y) return pick('87', 0, ver(p)(x, y)) end)
        wire(t, { { U(b[1] - 0.8), U(b[2] + len + 1.4) }, { U(b[1] - 1), U(b[2] + len + 2.6) } }, '8', nil, TH(k, 0.5))
        wire(t, { { U(b[1] + 0.8), U(b[2] + len + 1.4) }, { U(b[1] + 1), U(b[2] + len + 2.6) } }, '8', nil, TH(k, 0.5))
      end
    end
    L.outline(t, 'A', SOLIDB)
  end
  -- anel de sombra em volta do vão, três orelhas
  local ring = layer(g, function(t)
    ell(t, U(cx), U(cy), 8 * k, 9.4 * k, sf)
    for i2 = 0, 2 do
      local a = rad(-90 + i2 * 120 - 38)
      local ex, ey = cx + cos(a) * 7.4, cy + sin(a) * 8.6
      local ox, oy = -sin(a) * 2.4, cos(a) * 2.4
      polyf(t, pts({ { ex + ox, ey + oy }, { ex + cos(a) * 7.6, ey + sin(a) * 7.6 }, { ex - ox, ey - oy } }), function(x, y) return pick('876', 0.3, dg(x, y)) end)
    end
  end)
  for i2 = 0, 2 do blit(g, arms[i2]) end
  blit(g, slabs[0]); blit(g, slabs[1]); blit(g, slabs[2])
  -- a roda impossível: a laje 0 volta por cima da 2 na ponta em que se encontram
  do
    local a = rad(-90 + 8)
    local nx, ny = cos(a), sin(a)
    for y = 0, S - 1 do for x = 0, S - 1 do
      local s2 = ((x - U(cx + nx * 13.5)) * -ny + (y - U(cy + ny * 13.5)) * nx) / k
      if slabs[0][y][x] ~= '.' and s2 < -6 then g[y][x] = slabs[0][y][x] end
    end end
  end
  -- cada sombra passa por cima da laje de onde sai
  for i2 = 0, 2 do
    for y = 0, S - 1 do for x = 0, S - 1 do
      if arms[i2][y][x] ~= '.' and slabs[i2][y][x] ~= '.' then g[y][x] = arms[i2][y][x] end
    end end
  end
  -- o vão
  local void = {}
  for y = 0, S - 1 do for x = 0, S - 1 do
    local d = ((x - U(cx)) / (4.6 * k)) ^ 2 + ((y - U(cy)) / (7.4 * k)) ^ 2
    if d <= 1 then g[y][x] = '.'; void[#void + 1] = { x, y, d } end
  end end
  for y = 0, S - 1 do for x = 0, S - 1 do
    local d = ((x - U(cx)) / (4.6 * k)) ^ 2 + ((y - U(cy)) / (7.4 * k)) ^ 2
    if d > 1 and d <= ((4.6 * k + 1) / (4.6 * k)) ^ 2 * 1.08 and g[y][x] ~= '.' then g[y][x] = 'A' end
  end end
  local pk = TH(k, 1)
  for _, v in ipairs(void) do
    if v[3] > 0.4 then g[v[2]][v[1]] = 'X'
    elseif (v[1] // pk + v[2] // pk) % 2 == 0 and v[3] > 0.12 then g[v[2]][v[1]] = 'Y' end
  end
  for n2 = 1, 30 do
    local a = rad(n2 * 67)
    local r2 = 20 + (n2 * 13) % 9
    dot(g, U(cx + cos(a) * r2), U(cy + sin(a) * r2), k, n2 % 2 == 0 and 'K' or 'k')
  end
  return g
end

local function fit(src, size)
  local g = L.grid(size, size)
  blit(g, src, (size - src.w) // 2, (size - src.h) // 2)
  return g
end
local function out(stage, kind, g) C.save('shade', stage, kind, g, LEG, LIT, LOOSE) end
do -- as medidas saem numa linha só por sprite
  local raw = print
  print = function(sx) if tostring(sx):find('opacos') then raw((tostring(sx):gsub('^%s+', ''))) end end
end
out('fagulha', 'mapa', fagulhaMapa())
out('fagulha', 'retrato', fagulhaRetrato())
out('eco', 'mapa', eco(1))
out('eco', 'retrato', fit(eco(3), 96))
out('espirito', 'mapa', espirito(1))
out('espirito', 'retrato', fit(espirito(2.5), 96))
out('entidade', 'mapa', entidade(1))
out('entidade', 'retrato', entidade(2))
out('arquetipo', 'mapa', arquetipo(1))
out('arquetipo', 'retrato', arquetipo(2))
print('ok shade')
