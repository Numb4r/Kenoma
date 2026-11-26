-- Kit da arte final da família Rust (Metal): Rustling (Eco), Gratekin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run). As formas são as dos conceitos aprovados (tools/art/creatures/conceitos/rust/build.lua),
-- agora com pose. O Eco e o Espírito são funções do ponto (u, v) em unidades do mapa (o retrato é desenhado no próprio
-- tamanho); a Entidade e o Arquétipo usam as formas do _r2.lua, com textura no pixel (pp = 1 abaixo de escala 2,5).
-- LUZ: só a do tipo (tools/art/ui/types/palette.lua, Metal: D = d, M = m, L = l), no lugar do azul-aço dos conceitos.
-- leds = o miolo da luz atrás da grade (I: pisca); glow = o resto da luz dos vãos, a costura, o vão e a limalha solta.
-- Bicho de chão: o tronco sobe e desce (o.dy) e as patas ficam; só no salto da fuga (o.jump) sai tudo do chão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local L = K.L
local R = dofile(ART .. 'creatures/conceitos/_r2.lua')(K.C)
local Ru = { L = L, K = K, R = R, hash = K.hash }
local floor, sqrt, abs, sin, cos, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.min
local hash = K.hash

local MT
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'metal' then MT = c end end
local VEU = '#9B7BFF'

Ru.LEG = {
  A = '#1A1424',
  ['1'] = '#2E2B33', ['2'] = '#44404A', ['3'] = '#5E5A66', ['4'] = '#858290', ['5'] = '#AEB0BC', -- ferro e aço
  r = '#5A3324', R = '#874A2E', q = '#B06A3C', Q = '#D09458',  -- ferrugem
  g = '#3F5248', G = '#5F7868',                                -- resto de tinta verde de portão
  z = '#2D2A3C',                                               -- o escuro de dentro da grade
  b = '#8A7440', B = '#B89A58',                                -- latão do cadeado
  o = '#201A26', W = '#E6E6EE',                                -- olho e o brilho dele
  e = '#B06A3C', E = '#874A2E', m = '#C2C5CB', n = '#4C4E58',  -- perna fina, sem contorno (ferrugem; cinza no Arquétipo)
  ['6'] = '#C2C5CB', ['7'] = '#9A9DA6', ['8'] = '#70737D', ['9'] = '#4C4E58', ['0'] = '#33343D', -- cinza de aço (Arquétipo)
  l = '#2C2D36', j = '#272830', d = '#22232B',                 -- vãos apagados (corpo)
  L = MT.l, M = MT.m, D = MT.d,                                -- a luz atrás da grade (glow)
  I = MT.l,                                                    -- o miolo dela (leds: pisca)
  S = MT.m, s = MT.l,                                          -- limalha solta (só no glow)
  v = '#4A4658', Z = VEU,                                      -- costura do Véu apagada e acesa (glow)
  O = '#120D1C',                                               -- o vão apagado (mais escuro que o contorno)
  X = VEU, x = '#5A45A8',                                      -- o vão do Arquétipo (glow)
}
Ru.LIT = {
  L = { 'l', 'w' }, M = { 'j', 'w' }, D = { 'd', 'w' }, I = { 'l', 'l' }, Z = { 'v', 'w' },
  X = { 'O', 'w' }, x = { 'O', 'w' },
}
Ru.NOPULL = 'AeEmnSs'
Ru.SOLID = ''
for ch in pairs(Ru.LEG) do if not Ru.NOPULL:find(ch, 1, true) then Ru.SOLID = Ru.SOLID .. ch end end
Ru.BODY_KEYS = { '1', '2', '3', '4', '5', 'r', 'R', 'q', 'Q', 'g', 'G', 'b', 'B', 'e', 'E', 'm', 'n', '6', '7', '8', '9', '0' }

function Ru.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'D' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'M'
    elseif c == 'M' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'L' end
  end end
end

function Ru.vor(x, y, s, seed)
  local gx, gy = floor(x / s), floor(y / s)
  local b1, b2, id = 1e9, 1e9, 0
  for j = -1, 1 do
    for i = -1, 1 do
      local h = hash(gx + i, gy + j, seed)
      local px = (gx + i + 0.2 + 0.6 * ((h & 255) / 255)) * s
      local py = (gy + j + 0.2 + 0.6 * (((h >> 8) & 255) / 255)) * s
      local d = (x - px) ^ 2 + (y - py) ^ 2
      if d < b1 then b2 = b1; b1 = d; id = h elseif d < b2 then b2 = d end
    end
  end
  return id, sqrt(b2) - sqrt(b1)
end
Ru.RUSTP = { 'QqRr', 'qRr1', '4321', 'QqRr', 'Gg21', 'qRr1' }
Ru.IRONP = { '5432', '4321', 'qRr1', '4321', '5432', 'Gg21' }
Ru.ASH = { '6789', '7890', '6789', '5432', '7890', '4321', 'qRr1' }
-- Barra de ferro: d = distância assinada ao eixo, w = meia largura, sh = sombra do lugar (-1 luz, +1 sombra).
-- No retrato a barra tem aresta clara, miolo e aresta escura; a ferrugem vem em manchas.
function Ru.iron(d, w, x, y, sh, k, pal)
  local p = pal or Ru.RUSTP
  local id = Ru.vor(x, y, k > 1 and 4.5 or 6, 17)
  local s = p[(id >> 16) % #p + 1]
  local i = 2
  if w * k >= 1.2 then
    if d < -w * 0.3 then i = 1 elseif d > w * 0.3 then i = 3 end
  end
  if sh < -0.35 then i = i - 1 elseif sh > 0.35 then i = i + 1 end
  if k > 1 and hash(x, y, 31) % 13 == 0 then i = i + 1 end
  i = max(1, min(4, i))
  return s:sub(i, i)
end
local iron = Ru.iron
function Ru.paint(g, k, ox, oy, f)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = f((x + 0.5 - ox) / k, (y + 0.5 - oy) / k, x, y)
      if c then g[y][x] = c end
    end
  end
end
function Ru.caps(u, v, list)
  for _, s in ipairs(list) do
    local dx, dy = s[3] - s[1], s[4] - s[2]
    local t = max(0, min(1, ((u - s[1]) * dx + (v - s[2]) * dy) / (dx * dx + dy * dy)))
    local px, py = s[1] + dx * t, s[2] + dy * t
    if sqrt((u - px) ^ 2 + (v - py) ^ 2) <= s[5] + (s[6] - s[5]) * t then
      if s[9] and floor(t * s[9]) % 2 == 1 then return s[8] end
      return ((u - px) + (v - py) < 0) and s[7] or s[8]
    end
  end
end
-- Perna em segmentos a partir de pontos; r = raio; a, b = cores; ribs = anéis por segmento.
function Ru.leg(list, pts, r, a, b, ribs)
  for n = 1, #pts - 1 do
    list[#list + 1] = { pts[n][1], pts[n][2], pts[n + 1][1], pts[n + 1][2], r, n == #pts - 1 and r * 0.7 or r, a, b, ribs }
  end
end
-- Ponta de lança de portão: haste, colar e losango, a partir de (px, py) na direção (dx, dy).
function Ru.spear(u, v, px, py, dx, dy, len, w, c1, c2, c3)
  local a = (u - px) * dx + (v - py) * dy
  local b = -(u - px) * dy + (v - py) * dx
  if a >= 0 and a <= len and abs(b) < w then return b < 0 and c1 or c2 end
  if a > len - 0.7 and a < len and abs(b) < w + 0.6 then return c3 end
  local tl = w * 3.4 + 1
  if abs(a - len - tl / 2) / (tl / 2) + abs(b) / (w + 0.9) <= 1 then return b < 0 and c1 or c2 end
end
function Ru.prune(g)
  local id, sizes, n = {}, {}, 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local k0 = y * g.w + x
    if g[y][x] ~= '.' and not id[k0] then
      n = n + 1
      local stack, size = { k0 }, 0
      id[k0] = n
      while #stack > 0 do
        local q = table.remove(stack)
        size = size + 1
        local qx, qy = q % g.w, q // g.w
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = qx + dx, qy + dy
          if nx >= 0 and ny >= 0 and nx < g.w and ny < g.h and g[ny][nx] ~= '.' and not id[ny * g.w + nx] then
            id[ny * g.w + nx] = n; stack[#stack + 1] = ny * g.w + nx
          end
        end end
      end
      sizes[n] = size
    end
  end end
  local best = 1
  for i = 2, n do if sizes[i] > sizes[best] then best = i end end
  for k0, i in pairs(id) do if i ~= best then g[k0 // g.w][k0 % g.w] = '.' end end
end
-- Patas finas sem contorno: entram só no vazio, a 1 px ou mais da borda, e o que ficar solto sai.
function Ru.behind(g, k, ox, oy, list)
  Ru.paint(g, k, ox, oy, function(u, v, x, y)
    if g[y][x] == '.' and x > 0 and y > 0 and x < g.w - 1 and y < g.h - 1 then return Ru.caps(u, v, list) end
  end)
  Ru.prune(g)
end
-- Chapa de ferro (pronoto): tons pelo lugar, manchas de ferrugem.
function Ru.plate(x, y, sh, k)
  local id = Ru.vor(x, y, 2.6 * k, 23)
  if (id >> 16) % 3 == 0 then return sh < -0.3 and 'q' or (sh < 0.35 and 'R' or 'r') end
  return sh < -0.5 and '4' or (sh < -0.05 and '3' or (sh < 0.45 and '2' or '1'))
end
-- Olho de parafuso: cabeça de aço com a fenda.
function Ru.screw(u, v, ex, ey, r, k, ang)
  local d = sqrt((u - ex) ^ 2 + (v - ey) ^ 2)
  if d > r then return end
  local b = -(u - ex) * sin(ang) + (v - ey) * cos(ang)
  if k > 1 and abs(b) < r * 0.24 then return '1' end
  if k == 1 and u > ex and v > ey then return '3' end
  return (u - ex) + (v - ey) < 0 and '5' or '4'
end
-- Casco de grade num élitro em elipse: barras a cada 3 px do mapa, uma travessa e a moldura; atrás, a luz (o miolo
-- I pisca) ou o escuro de dentro. glow: tamanho da luz.
function Ru.elytra(u, v, x, y, k, cx, cy, rx, ry, glow)
  local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
  if e > 1 then return end
  local bw = 0.5
  local hh = ry * sqrt(max(0.02, 1 - ((u - cx) / rx) ^ 2))
  local lat = (v - cy) / hh
  local sh = lat * 0.8 + (u - cx) / rx * 0.25
  local rim = (1 - sqrt(e)) * min(rx, ry)
  if rim < 2 * bw then return iron(rim - bw, bw, x, y, sh, k) end
  local dd = ((u - cx + 91.5 - lat * 0.5) % 3) - 1.5
  if abs(dd) < bw then return iron(dd, bw, x, y, sh, k) end
  dd = (lat + 0.08) * hh
  if abs(dd) < bw then return iron(dd, bw, x, y, sh, k) end
  local gl = ((u - cx - 0.6) / (rx * 0.64 * glow)) ^ 2 + ((lat - 0.05) / (0.8 * glow)) ^ 2
  if gl < 0.07 then return 'I' elseif gl < 0.3 then return 'M' elseif gl < 0.62 then return 'D' end
  return 'z'
end
-- Costura do Véu num ponto: verdade a menos de w da linha a-b; step: pontos atravessados (retrato).
function Ru.seam(u, v, a, b, w, step)
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local len = sqrt(dx * dx + dy * dy)
  local t = max(0, min(len, ((u - a[1]) * dx + (v - a[2]) * dy) / len))
  if sqrt((u - a[1] - dx * t / len) ^ 2 + (v - a[2] - dy * t / len) ^ 2) < w then return true end
  if step then
    local tt = ((u - a[1]) * dx + (v - a[2]) * dy) / len
    local dn = abs((u - a[1]) * -dy + (v - a[2]) * dx) / len
    if tt > 0 and tt < len and dn < w + 0.8 and abs((tt % step) - step / 2) < 0.2 then return true end
  end
end
-- Limalha solta em sg (só no glow), onde o corpo está vazio: sobe e some. list = { { u, v, ch } }.
function Ru.dust(g, sg, k, ox, oy, list, ph, NL)
  local n = max(1, floor(k * 0.6 + 0.5))
  for i, d in ipairs(list) do
    local r = (ph + i) % NL
    if r < NL - 1 then
      local x, y = floor(d[1] * k + ox), floor((d[2] - r * 0.8) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = d[3] or (i % 3 == 0 and 's' or 'S')
        end
      end end
    end
  end
end
-- Para as formas do _r2.lua: losango de lança e folha de portão em perspectiva. O é o pé da dobradiça, A vai até a
-- ponta, B sobe; nb barras, lanças em cima; glow: até onde a luz chega atrás das barras (0 = vão vazio).
function Ru.diamond(t, x, y, w, h, fn) t:poly({ { x - w, y }, { x, y - h * 0.62 }, { x + w, y }, { x, y + h * 0.38 } }, fn) end
function Ru.gateLeaf(t, k, O, A, B, nb, glow, pal)
  local det = A[1] * B[2] - A[2] * B[1]
  local la, lb = sqrt(A[1] ^ 2 + A[2] ^ 2), sqrt(B[1] ^ 2 + B[2] ^ 2)
  local pw = t:pp()
  for i = 1, (glow > 0 and nb - 1 or 0) do
    local s = (i + 0.16) / nb
    local bx, by = O[1] + A[1] * s + B[1], O[2] + A[2] * s + B[2]
    t:wire({ { bx, by }, { bx + B[1] / lb * 1.6, by + B[2] / lb * 1.6 } }, '3', '4', 0.5)
    Ru.diamond(t, bx + B[1] / lb * 2.8, by + B[2] / lb * 2.8, 1, 3, R.mat(pal and '987' or '234', R.ver(pw), 0.5))
  end
  t:poly({ O, { O[1] + A[1], O[2] + A[2] }, { O[1] + A[1] + B[1], O[2] + A[2] + B[2] }, { O[1] + B[1], O[2] + B[2] } }, function(x, y, u, v)
    local s = ((u - O[1]) * B[2] - (v - O[2]) * B[1]) / det
    local tt = (A[1] * (v - O[2]) - A[2] * (u - O[1])) / det
    local sh = (0.5 - tt) * 0.8 + (s - 0.5) * 0.5
    local ds, dt = min(s, 1 - s) * la, min(tt, 1 - tt) * lb
    if ds < 1 or dt < 1 then return iron(min(ds, dt) - 0.5, 0.5, x, y, sh, k, pal) end
    local f = (s * nb) % 1
    if f < 0.34 then return iron((f - 0.17) * la / nb, 0.5, x, y, sh, k, pal) end
    if abs(tt - 0.45) < 0.6 / lb then return iron(0, 0.5, x, y, sh + 0.3, k, pal) end
    if s > glow then return nil end
    return s < glow * 0.4 and 'M' or 'D'
  end)
end

function Ru.run(spec)
  spec.LEG = spec.LEG or Ru.LEG
  spec.LIT, spec.heat = Ru.LIT, Ru.heat
  spec.NOPULL = spec.NOPULL or Ru.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or Ru.BODY_KEYS
  spec.DARK = spec.DARK or '1'
  spec.ownDy, spec.ownLean = true, true
  if not spec.over then
    spec.over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end }
  end
  return K.run(spec)
end

return Ru
