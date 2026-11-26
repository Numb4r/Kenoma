-- Kit da arte final da família Glare (Luz): Glimlet (Eco), Prismkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar). As formas são as dos conceitos aprovados (tools/art/creatures/conceitos/glare/build.lua):
-- cada peça é uma função do ponto (u, v) em unidades do mapa, por isso o retrato é desenhado no próprio tamanho, sem
-- ampliar nada. Cada espécie dá draw(g, sg, k, o): o corpo em g (emissivos ACESOS, sem contorno) e o brilho solto em sg.
-- LUZ: a base é a do tipo (tools/art/ui/types/palette.lua, Luz: H = d, J = m, Y = l) e o espectro do prisma vai por
-- cima dela (R rosa, L verde, B azul; o amarelo é o J), a única exceção multicolor (estilo-criaturas.md, "Cores
-- emissivas"). leds = a estrela de quatro pontas (I, K: o reflexo que pisca); glow = o resto.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local L = K.L
local G = { L = L, K = K, hash = K.hash }
local floor, sqrt, abs, sin, cos, rad, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.rad, math.max, math.min
local hash = K.hash

local LT
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'light' then LT = c end end
local VEU = '#9B7BFF'

G.LEG = {
  A = '#1A1424',
  a = '#7A9A8E', b = '#55766E', c = '#3A5755', d = '#273E42',  -- plumagem verde-petróleo
  e = '#46587A', f = '#313F5C', n = '#222B42',                 -- cabeça e cauda azul-escuras
  ['1'] = '#DCE6E8', ['2'] = '#A9BCC2', ['3'] = '#7C939C', ['4'] = '#586E7A', ['5'] = '#3C4E5C', -- vidro
  g = '#6FA08E', G = '#4A7A6C',                                -- o verde da borda do vidro
  M = '#C8CCD0', m = '#8E9298',                                -- cromado do farol
  z = '#C8CCD0', Z = '#8E9298',                                -- bico de agulha de vidro (sem contorno)
  o = '#1E1A26', W = '#F2F2F6',                                -- olho e o brilho dele
  t = '#9CC0D0', u = '#A8786A', v = '#2A3050',                 -- céus refletidos: dia, fim de tarde, noite
  ['6'] = '#D2D4D0', ['7'] = '#A6AAA8', ['8'] = '#7A7F80', ['9'] = '#555A5E', ['0'] = '#383C42', -- vidro cinza (Arquétipo)
  y = '#6A6650', j = '#5A5540', h = '#4A4230',                 -- reflexo apagado (corpo)
  r = '#5A4044', l = '#3E5440', q = '#38465E',                 -- cores do prisma apagadas
  Y = LT.l, J = LT.m, H = LT.d,                                -- reflexo e lente acesos (glow)
  I = LT.l, K = LT.m,                                          -- a estrela de quatro pontas (leds: pisca)
  R = '#F0A0A0', L = '#A8E0A0', B = '#8AB8F0',                 -- a luz separada pelo prisma (glow)
  S = LT.m, s = LT.l, E = '#F0A0A0', F = '#A8E0A0', D = '#8AB8F0', -- brilho solto (só no glow)
  x = '#8C9CB0', w = '#3F5A5E',                                -- costura do Véu apagada: no vidro, na pena
  X = VEU, V = VEU,                                            -- costura acesa (glow)
  O = '#120D1C',                                               -- o vão apagado (mais escuro que o contorno)
  U = VEU, T = '#5A45A8', C = LT.l,                            -- o vão do Arquétipo (glow)
}
G.LIT = {
  Y = { 'y', 'w' }, J = { 'j', 'w' }, H = { 'h', 'w' }, R = { 'r', 'w' }, L = { 'l', 'w' }, B = { 'q', 'w' },
  I = { 'y', 'l' }, K = { 'j', 'l' }, X = { 'x', 'w' }, V = { 'w', 'w' },
  U = { 'O', 'w' }, T = { 'O', 'w' }, C = { 'O', 'w' },
}
G.NOPULL = 'ASsEFDzZ'                                         -- o bico de agulha não tem contorno
G.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'f', 'n', '1', '2', '3', '4', '5', 'g', 'G', 'M', 'm', 'z', 'Z', 't', 'u', 'v',
  '6', '7', '8', '9', '0' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): o reflexo sobe um degrau da paleta.
function G.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'H' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'J'
    elseif c == 'J' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'Y' end
  end end
end

-- f(u, v, x, y) devolve a cor do pixel (ou nil); (u, v) em unidades do mapa.
function G.paint(g, k, ox, oy, f)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = f((x + 0.5 - ox) / k, (y + 0.5 - oy) / k, x, y)
      if c then g[y][x] = c end
    end
  end
end
function G.caps(u, v, list)
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
function G.dseg(u, v, x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  local t = max(0, min(1, ((u - x0) * dx + (v - y0) * dy) / (dx * dx + dy * dy)))
  return sqrt((u - x0 - dx * t) ^ 2 + (v - y0 - dy * t) ^ 2)
end
function G.inpoly(u, v, p)
  local c, j = false, #p
  for i = 1, #p do
    local a, b = p[i], p[j]
    if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end
    j = i
  end
  return c
end
-- (u, v) no referencial de uma peça girada deg graus em volta de (cx, cy).
function G.unrot(u, v, cx, cy, deg)
  local a = rad(-deg)
  local dx, dy = u - cx, v - cy
  return cx + dx * cos(a) - dy * sin(a), cy + dx * sin(a) + dy * cos(a)
end
-- Só a peça maior fica (diagonal conta): o bico sem contorno não pode soltar.
function G.prune(g)
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

-- Vidro: polígono com borda própria, tons em faixas na diagonal e o reflexo (duas faixas claras em "/").
-- o = { pal = 'claro meio escuro', edge = cor da borda, ew = largura da borda, c = onde passa o reflexo (u + v),
--       m, len = centro e meio comprimento do reflexo em (u - v), ph = fase das faixas, fn = function(u, v) extra }.
function G.glass(u, v, k, pts, o)
  if not G.inpoly(u, v, pts) then return end
  local de = 1e9
  for i = 1, #pts do
    local a, b = pts[i], pts[i % #pts + 1]
    de = min(de, G.dseg(u, v, a[1], a[2], b[1], b[2]))
  end
  if de < (o.ew or 0.55) then return o.edge or 'G' end
  if o.fn then
    local c = o.fn(u, v)
    if c then return c end
  end
  if o.c and de > 0.8 and abs(u - v - o.m) < o.len then
    local q = u + v - o.c
    if abs(q) < (k > 1 and 0.4 or 0.55) then return 'Y' elseif abs(q - 1.9) < (k > 1 and 0.25 or 0.5) then return 'J' end
  end
  local band = floor((u + v) * (k > 1 and 0.9 or 1.4) + (o.ph or 0)) % 3
  local i = (u + v - (o.c or (u + v))) < 0 and 1 or 2
  if band == 0 then i = i + 1 end
  return o.pal:sub(i, i)
end
-- A estrela de quatro pontas (o reflexo que pisca, leds), só sobre o corpo.
function G.star(u, v, sx, sy, len)
  local du, dv = abs(u - sx), abs(v - sy)
  if du < 0.5 and dv < 0.5 then return 'I' end
  local hw = 0.5 - 0.3 * max(du, dv) / len                      -- os braços afinam para a ponta (no mapa dá 1 px)
  if (du < hw and dv < len) or (dv < hw and du < len) then return 'K' end
end
-- Lente de farol: miolo claro, anéis e o aro cromado. pulse desloca os anéis.
function G.lens(u, v, cx, cy, r, ring, k, pulse)
  local d = sqrt((u - cx) ^ 2 + (v - cy) ^ 2)
  if d > r + ring then return end
  if d > r then return ((u - cx) + (v - cy) < 0) and 'M' or 'm' end
  if d < r * 0.3 then return 'Y' end
  if k > 1 and r > 3 and abs((u - cx) % 1.5 - 0.75) < 0.2 then return 'H' end
  return floor(d * (r > 3 and 1 or 1.6) - (pulse or 0)) % 2 == 0 and 'J' or 'H'
end
-- Costura do Véu: ch onde (u, v) está a menos de w da linha quebrada pts; step: pontos atravessados (retrato).
function G.seam(u, v, pts, w, step)
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    if G.dseg(u, v, a[1], a[2], b[1], b[2]) < w then return true end
    if step then
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local len = sqrt(dx * dx + dy * dy)
      local t = ((u - a[1]) * dx + (v - a[2]) * dy) / len
      local dn = abs((u - a[1]) * -dy + (v - a[2]) * dx) / len
      if t > 0 and t < len and dn < w + 0.9 and abs((t % step) - step / 2) < 0.22 then return true end
    end
  end
end
-- Brilho solto em sg (só no glow), onde o corpo está vazio: sobe e some. list = { { u, v, ch } }.
function G.dust(g, sg, k, ox, oy, list, ph, NL)
  local n = max(1, floor(k * 0.5 + 0.5))
  for i, d in ipairs(list) do
    local r = (ph + i) % NL
    if r < NL - 1 then
      local x, y = floor(d[1] * k + ox), floor((d[2] - r * 0.8) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = d[3] or (i % 2 == 0 and 's' or 'S')
        end
      end end
    end
  end
end

-- O beija-flor-tesoura do Eco, como função do ponto. p = { wn, wf = giro das asas (graus, negativo desce), tail =
-- balanço da cauda, rc = quanto o reflexo andou na asa, crouch }. Devolve a cor (ou nil).
local AX, AY = 0.766, -0.643
G.WN = { { 15.4, 12.8 }, { 13.2, 14.8 }, { 2.6, 6.4 }, { 3.6, 3.4 }, { 9.6, 4.6 } }
G.WF = { { 16.6, 11.4 }, { 14.6, 12.6 }, { 9.4, 3.4 }, { 12.4, 2.6 }, { 16.4, 6 } }
function G.bird(k, p)
  p = p or {}
  local tx = p.tail or 0
  local TAIL = { { 9.6, 18.4, 3.6 + tx, 23.4, 1.35, 0.4, 'e', 'n' }, { 10.2, 19.2, 6.8 + tx * 0.6, 25, 1.25, 0.4, 'f', 'n' } }
  local BILL = { { 20.6, 10.3, 25.6, 9.3, 0.55, 0.45, 'z', 'Z' } }
  local rc = p.rc or 0
  return function(u, v)
    local d = sqrt((u - 18.4) ^ 2 + (v - 10.2) ^ 2)
    if d <= 2.7 then
      if k > 1 and (u - 19.2) ^ 2 + (v - 9.8) ^ 2 < 0.06 then return 'W' end
      if (u - 19.5) ^ 2 + (v - 10.1) ^ 2 < 0.4 then return 'o' end
      if p.seams and G.seam(u, v, { { 16.4, 9 }, { 18, 8 } }, k > 1 and 0.3 or 0.5, k > 1 and 1.2 or nil) then return 'V' end
      local sh = (u - 18.4) * 0.5 + (v - 10.2)
      return sh < -1.2 and 'e' or (sh < 1 and 'f' or 'n')
    end
    local wu, wv = G.unrot(u, v, 15.4, 12.8, p.wn or 0)
    local c = G.glass(wu, wv, k, G.WN, { pal = '123', edge = '4', c = 16.4 + rc, m = 2, len = k > 1 and 2.2 or 2.8, fn = p.seams and function(a, b)
      if G.seam(a, b, { { 9.4, 7.4 }, { 12.6, 10.4 } }, k > 1 and 0.3 or 0.5, k > 1 and 1.2 or nil) then return 'X' end
    end or nil })
    if c then return G.star(wu, wv, 6.6, 6.2, 1.6) or c end
    -- papo: lente de farol
    local gd = ((u - 17.5) / 1.8) ^ 2 + ((v - 13.3) / 1.6) ^ 2
    if gd <= 1 then
      if gd >= 0.55 and k > 1 and (floor(u * k) + floor(v * k)) % 3 ~= 0 then return 'h' end   -- o aro da lente, em grão
      return gd < 0.14 and 'Y' or (gd < 0.55 and 'J' or 'H')
    end
    local du, dv = u - 13, v - 15.5
    local la, lb = du * AX + dv * AY, -du * AY + dv * AX
    if (la / 5.6) ^ 2 + (lb / 3.3) ^ 2 <= 1 then
      if p.seams and G.seam(la, lb, { { -2.6, -1.4 }, { 0.6, 1.6 } }, k > 1 and 0.3 or 0.5, k > 1 and 1.2 or nil) then return 'V' end
      local i = lb < -0.9 and 1 or (lb < 1.3 and 2 or 3)
      if (la * 1.1 + (floor(lb * 1.3) % 2) * 0.5) % 1 < 0.34 then i = i + 1 end
      return ('abcd'):sub(i, i)
    end
    c = G.caps(u, v, TAIL)
    if c then return c end
    wu, wv = G.unrot(u, v, 16.6, 11.4, p.wf or 0)
    c = G.glass(wu, wv, k, G.WF, { pal = '345', edge = '5', c = 20.5 + rc, m = 5, len = k > 1 and 1.6 or 2.6 })
    if c then return c end
    return G.caps(u, v, BILL)
  end
end

function G.run(spec)
  spec.LEG = spec.LEG or G.LEG
  spec.LIT, spec.heat = G.LIT, G.heat
  spec.NOPULL = spec.NOPULL or G.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or G.BODY_KEYS
  spec.DARK = spec.DARK or 'n'
  return K.run(spec)
end

return G
