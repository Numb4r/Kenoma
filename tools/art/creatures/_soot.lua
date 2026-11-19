-- Kit da arte final da família Soot (Fogo): Sootling (Eco), Cinderkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar); aqui ficam a legenda, os emissivos e as formas dos conceitos aprovados
-- (tools/art/creatures/conceitos/soot/build.lua), agora com pose. Cada espécie dá draw(g, sg, k, o): o corpo em g
-- (emissivos ACESOS, sem contorno) e a faísca solta em sg; k é a escala (1 no mapa) e o é o quadro (ph fase do laço,
-- pose 'alert' | 'crouch', dy, lean, jump, portrait).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Fogo: d, m, l), sem o laranja da Essência.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local C, L = K.C, K.L
local F = dofile(ART .. 'creatures/conceitos/soot/_forma.lua')(C)
local R = dofile(ART .. 'creatures/conceitos/_r2.lua')(C)
local S = { L = L, C = C, F = F, R = R, hash = K.hash }
local floor, ceil, sqrt, abs, cos, sin, rad = math.floor, math.ceil, math.sqrt, math.abs, math.cos, math.sin, math.rad

local FIRE
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'fire' then FIRE = c end end
local VEU = '#9B7BFF'

S.LEG = {
  A = '#1A1424',
  a = '#2A2529', b = '#3B3539', c = '#514B4E', d = '#6E6866', e = '#8A8480', -- pelo de fuligem (e: ponta grisalha)
  v = '#6A6462', w = '#8E877F', W = '#B5ADA1', V = '#D2CBBE',                 -- cara branca suja, dente
  q = '#5A4044', p = '#8A6460', P = '#B08880',                                -- pele nua (orelha, rabo, mão, focinho)
  k = '#241A2A', K = '#3A2C3C',                                               -- olho, boca
  J = '#2A2C33', j = '#41444D', i = '#5F636C', I = '#858A92',                 -- ferro fundido
  n = '#5E4636', N = '#7C5B40',                                               -- ferrugem
  h = '#A39C90', H = '#CFC8BA',                                               -- cinza e papel da bituca
  o = '#8C6238', O = '#B88648',                                               -- filtro
  m = '#4A4753', M = '#6A6775', l = '#A39C90',                                -- fumaça e bigode (sem contorno)
  ['1'] = '#B9B3A6', ['2'] = '#8F8A80', ['3'] = '#66625E', ['4'] = '#46434A', -- osso e cinza (Arquétipo)
  r = '#4A1F1A', u = '#6E2E1E',                                               -- brasa apagada (corpo)
  R = FIRE.d, E = FIRE.m, Y = FIRE.l,                                         -- brasa acesa (glow)
  B = FIRE.m, G = FIRE.l,                                                     -- bituca e olho de brasa (leds: piscam)
  T = FIRE.d, S = FIRE.m, s = FIRE.l,                                         -- faísca solta (só no glow)
  ['5'] = '#473F4C', ['8'] = '#44455A', ['6'] = '#A49CA6',                    -- costura do Véu apagada: pelo, ferro, cara
  X = VEU, ['9'] = VEU, ['7'] = VEU,                                          -- costura acesa (glow)
  Q = VEU, D = '#5A45A8', U = FIRE.m, Z = FIRE.l,                             -- o vão do Arquétipo (apagado: a boca)
  -- bases que o sombreado troca (não têm cor: se sobrar, o build acusa): f pelo, g pelo de trás, t pele, x cara,
  -- y ferro, z osso
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
S.LIT = {
  R = { 'r', 'w' }, E = { 'r', 'w' }, Y = { 'u', 'w' }, B = { 'r', 'l' }, G = { 'u', 'l' },
  X = { '5', 'w' }, ['9'] = { '8', 'w' }, ['7'] = { '6', 'w' },
  Q = { 'k', 'w' }, D = { 'k', 'w' }, U = { 'k', 'w' }, Z = { 'k', 'w' },
}
S.NOPULL = 'AmMlTSs'
S.SOLID = ''                                                  -- o que puxa contorno (para as camadas do _r2.lua)
for ch in pairs(S.LEG) do if not S.NOPULL:find(ch, 1, true) then S.SOLID = S.SOLID .. ch end end
S.FUR, S.FACE, S.SKIN, S.IRON = 'edcba', 'VWwv', 'Ppq', 'IijJ'
-- cores do corpo que as variantes trocam (as apagadas e as emissivas ficam iguais em todas)
S.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'v', 'w', 'W', 'V', 'q', 'p', 'P', 'J', 'j', 'i', 'I', 'n', 'N', 'h', 'H',
  'o', 'O', 'm', 'M', '1', '2', '3', '4' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): a brasa sobe um degrau da paleta.
function S.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'R' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'E'
    elseif c == 'E' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'Y' end
  end end
end

-- Brasa: miolo claro e rachaduras que se espalham. mask: onde pode queimar. grow (0..1): o miolo pulsa.
function S.ember(g, cx, cy, r, seed, mask, arms, grow)
  arms = arms or 5
  for n = 1, arms do
    local a = (n / arms) * 6.283 + F.rnd(n, seed, 3) * 1.2
    local x, y = cx, cy
    local len = r * (1.1 + F.rnd(n, seed, 5) * 0.9)
    for s = 0, floor(len) do
      a = a + (F.rnd(n, s, seed) - 0.5) * 1.1
      x, y = x + cos(a), y + sin(a)
      L.set(g, x, y, s > len * 0.6 and 'R' or 'E', mask)
    end
  end
  local rc = r * (1 + 0.18 * (grow or 0))
  for y = floor(cy - rc), ceil(cy + rc) do for x = floor(cx - rc), ceil(cx + rc) do
    local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    if d <= rc * 0.5 then L.set(g, x, y, 'Y', mask)
    elseif d <= rc * 0.95 and F.rnd(x, y, seed) > 0.2 then L.set(g, x, y, 'E', mask) end
  end end
end

function S.furShade(g, k, src, ramp, o)
  o = o or {}
  o.p = o.p or (k > 1 and 2 or 1); o.ax = o.ax or 0.5; o.ay = o.ay or 1
  if k > 1 then o.jit = o.jit or 2; o.jw = o.jw or 3 end
  F.shade(g, src, ramp, o)
end
function S.skinShade(g, k, src)
  F.shade(g, src or 't', S.SKIN, { p = k > 1 and 3 or 2, ax = 1, ay = 1, zones = 2, within = src or 't' })
end
function S.ironShade(g, k, src, o)
  o = o or {}
  o.p = o.p or (k > 1 and 3 or 2); o.ax = o.ax or 1; o.ay = o.ay or 0; o.zones = o.zones or 3
  F.shade(g, src or 'y', S.IRON, o)
end
function S.faceShade(g, k, zones)
  F.shade(g, 'x', S.FACE, { p = k > 1 and 3 or 2, ax = 1, ay = 0.4, zones = zones or 3, within = 'x', jit = k > 1 and 2 or 0 })
end

-- Bituca na ponta de um rabo: cinza e brasa (leds: a ponta pisca). (x, y) é a ponta, em unidades do mapa.
function S.buttTip(P, k, x, y, dx, dy, hot)
  P:disc(x - dx * 0.9, y - dy * 0.9, 0.85, 'h', 'Ppqt')
  if k > 1 then P:disc(x - dx * 1.2, y - dy * 1.2, 0.8, 'H', 'Ppqth') end
  P:disc(x, y, 0.75, hot and 'G' or 'B', 'PpqthH')
  P:disc(x + dx * 0.25, y + dy * 0.25, k > 1 and 0.4 or 0.1, 'G', 'B')
end

-- Cabeça de gambá no referencial próprio: u para a frente (focinho), v para baixo; ang gira, sc escala.
-- o = { open = boca aberta (1 = normal; mais abre mais), ear = n, bone = caveira, flip = -1 espelha v }
function S.head(P, k, x, y, ang, sc, o)
  o = o or {}
  local fl = o.flip or 1
  local ca, sa = cos(rad(ang)), sin(rad(ang))
  local function T(u, v) u, v = u * sc, v * sc * fl; return { x + u * ca - v * sa, y + u * sa + v * ca } end
  local function poly(pts, c, mask)
    local q = {}
    for n, p in ipairs(pts) do q[n] = T(p[1], p[2]) end
    P:poly(q, c, mask)
  end
  local base = o.bone and 'z' or 'x'
  if not o.bone then
    for n = 1, (o.ear or 1) do
      local e = T(-1.6 + (n - 1) * 1.9, -3.5 + (n - 1) * 0.3)
      P:ell(e[1], e[2], 1.8 * sc, 2.0 * sc, 'q'); P:ell(e[1] + 0.2 * sc, e[2] + 0.3 * sc, 0.9 * sc, 1.1 * sc, 'p')
    end
  end
  P:ell(x, y, 3.2 * sc, 3.0 * sc, base, nil, ang)
  poly({ { 0.2, -2.6 }, { 3.6, -1.2 }, { 6.6, 0.5 }, { 6.5, 1.3 }, { 0, 1.5 } }, base)
  if o.open then
    local op = type(o.open) == 'number' and o.open or 1
    poly({ { 0.4, 1.4 }, { 6.3, 1.3 }, { 5.8, 3.3 + 1.5 * op }, { 0, 2.8 } }, 'k')
    if not o.bone then local th = T(1.4, 2.3); P:disc(th[1], th[2], 0.9 * sc, 'E', 'k') end
    poly({ { -1.2, 2.6 }, { 5.9, 3.2 + 1.5 * op }, { 5.4, 4.2 + 1.5 * op }, { -1.6, 4.0 } }, base)
    for u = 1.6, 5.8, (k > 1 and 0.9 or 1.4) do
      local t = T(u, 1.8); P:px(t[1], t[2], 'V')
      t = T(u - 0.5, 2.3 + (u + 0.7) / 7.1 * (0.6 + 1.5 * op)); P:px(t[1], t[2], 'V')
    end
  end
  return T
end
-- eyes = { { u, v, miolo } }: o miolo de brasa vai em leds (pisca).
function S.headFinish(P, k, T, sc, o)
  o = o or {}
  if not o.bone then
    local nz = T(6.3, 0.8); P:disc(nz[1], nz[2], 0.6 * sc, 'P')
  end
  for _, e in ipairs(o.eyes or {}) do
    local q = T(e[1], e[2])
    P:ell(q[1], q[2], 1.2 * sc, 0.95 * sc, 'v', S.FACE)
    P:disc(q[1], q[2], k > 1 and 0.8 * sc or 0.5, 'k')
    if e[3] then P:px(q[1], q[2], e[3]) end
  end
end

-- Perna: do quadril (que sobe com o tronco) ao pé (que fica no chão); sx é o passo.
function S.leg(P, hx, hy, kx, ky, fx, fy, r0, r1, c, sx)
  P:limb({ { hx, hy }, { kx + (sx or 0) * 0.5, ky }, { fx + (sx or 0), fy } }, r0, r1, c)
end
function S.paw(P, k, x, y, c, r)
  P:limb({ { x - 0.3, y }, { x + 1.4, y } }, r or 0.5, r or 0.5, c)
  if k > 1 then
    for f = 0, 3 do L.line(P.g, P:X(x + 0.3 + f * 0.35), P:Y(y) - 1, P:X(x + 1 + f * 0.5), P:Y(y) + 2, c) end
  end
end

-- Faísca solta em sg (só no glow), onde o corpo de P.g está vazio.
function S.spark(P, sg, x, y, ch)
  local n = math.max(1, floor(P.k * 0.6 + 0.5))
  local px, py = floor(P:X(x)), floor(P:Y(y))
  for j = 0, n - 1 do for i = 0, n - 1 do
    if L.get(P.g, px + i, py + j) == '.' then L.set(sg, px + i, py + j, ch) end
  end end
end

-- Costura do Véu: linha de w px (ch aceso, com o par apagado na legenda), só por cima de mask (o material), nunca no
-- vazio. step (unidades do mapa): pontos atravessados, para o retrato.
function S.seam(P, pts, w, ch, mask, step)
  local g = P.g
  for i = 1, #pts - 1 do
    local x0, y0, x1, y1 = P:X(pts[i][1]), P:Y(pts[i][2]), P:X(pts[i + 1][1]), P:Y(pts[i + 1][2])
    local steep = abs(y1 - y0) > abs(x1 - x0)
    for d = 0, w - 1 do
      local off = d - (w - 1) / 2
      L.line(g, x0 + (steep and off or 0), y0 + (steep and 0 or off), x1 + (steep and off or 0), y1 + (steep and 0 or off), ch, mask)
    end
    if step then
      local len = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
      local nx, ny = -(y1 - y0) / len, (x1 - x0) / len
      for s = step * P.k / 2, len, step * P.k do
        local x, y = x0 + (x1 - x0) * s / len, y0 + (y1 - y0) * s / len
        L.line(g, x - nx * (w + 1), y - ny * (w + 1), x + nx * (w + 1), y + ny * (w + 1), ch, mask)
      end
    end
  end
end

-- Recorte do busto: apaga o que passa de uma moldura rasgada a m px da borda (o corpo não encosta no quadro).
function S.tear(g, m)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local e = math.min(x, y, g.w - 1 - x, g.h - 1 - y)
    if e < m + (K.hash(x // 3, y // 3, 17) % 3) then g[y][x] = '.' end
  end end
end

function S.run(spec)
  spec.LEG = spec.LEG or S.LEG
  spec.LIT, spec.NOPULL, spec.heat = S.LIT, S.NOPULL, S.heat
  spec.BODY_KEYS = spec.BODY_KEYS or S.BODY_KEYS
  spec.DARK = spec.DARK or 'a'
  return K.run(spec)
end

return S
