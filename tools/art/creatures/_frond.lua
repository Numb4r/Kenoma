-- Kit da arte final da família Frond (Planta): Frondling (Eco), Thicketkin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar); aqui ficam a legenda, os emissivos e as formas dos conceitos aprovados
-- (tools/art/creatures/conceitos/frond/build.lua), agora com pose. Cada espécie dá draw(g, sg, k, o): o corpo em g
-- (emissivos ACESOS, sem contorno) e o esporo solto em sg; k é a escala (1 no mapa) e o é o quadro (ph fase do laço,
-- pose 'alert' | 'crouch', dy, lean, jump, portrait).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Planta: d, m, l). Bicho de chão: o tronco sobe e desce
-- (body_dy, aplicado no draw) e as raízes ficam no chão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local S = dofile(ART .. 'creatures/_soot.lua')               -- só as ajudas que servem a qualquer família
local C, L, F, R = K.C, K.L, S.F, S.R
local Fr = { L = L, C = C, F = F, R = R, hash = K.hash, seam = S.seam, tear = S.tear, spark = S.spark }
local floor, sqrt, cos, sin, rad = math.floor, math.sqrt, math.cos, math.sin, math.rad

local PLANT
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'plant' then PLANT = c end end
local VEU = '#9B7BFF'

Fr.LEG = {
  A = '#1A1424',
  a = '#2B3324', b = '#3D4A30', c = '#566440', d = '#748354', e = '#96A070', -- folha (verde de calçada, sem brilho)
  n = '#5E4628', N = '#7E6038', M = '#A07C48',                               -- folha seca
  q = '#4C3D2E', p = '#735D42', o = '#9A8262',                               -- raiz
  J = '#454449', j = '#63625F', i = '#85847F', I = '#A9A8A2',                 -- concreto da calçada
  k = '#2A2630',                                                              -- junta, fundo da rachadura, o vão apagado
  ['1'] = '#B9B4A6', ['2'] = '#928D80', ['3'] = '#6A665E', ['4'] = '#4A474A', -- pedra do fóssil (Arquétipo)
  r = '#22381F', u = '#2F4A2C',                                               -- nervura apagada (corpo)
  B = PLANT.d, D = PLANT.m, E = PLANT.l,                                      -- nervura acesa (glow)
  H = PLANT.m, G = PLANT.l,                                                   -- o broto do báculo (leds: pisca)
  T = PLANT.d, S = PLANT.m, s = PLANT.l,                                      -- esporo solto (só no glow)
  ['5'] = '#4B5049', ['8'] = '#5F5C6B', ['6'] = '#6B5850',                    -- costura do Véu apagada: folha, concreto, raiz
  X = VEU, ['9'] = VEU, ['7'] = VEU,                                          -- costura acesa (glow)
  Q = VEU, W = '#5A45A8', U = PLANT.m, Z = PLANT.l,                           -- o vão do Arquétipo (apagado: k)
  -- bases que o sombreado troca (não têm cor: se sobrar, o build acusa): f folha, g folha seca, h raiz, y concreto,
  -- z fóssil, m nervura
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
Fr.LIT = {
  B = { 'r', 'w' }, D = { 'u', 'w' }, E = { 'u', 'w' }, H = { 'r', 'l' }, G = { 'u', 'l' },
  X = { '5', 'w' }, ['9'] = { '8', 'w' }, ['7'] = { '6', 'w' },
  Q = { 'k', 'w' }, W = { 'k', 'w' }, U = { 'k', 'w' }, Z = { 'k', 'w' },
}
Fr.NOPULL = 'ATSs'
Fr.SOLID = ''                                                 -- o que puxa contorno (para as camadas do _r2.lua)
for ch in pairs(Fr.LEG) do if not Fr.NOPULL:find(ch, 1, true) then Fr.SOLID = Fr.SOLID .. ch end end
Fr.LEAF, Fr.DRY, Fr.ROOT, Fr.CONC, Fr.STONE = 'edcba', 'MNn', 'opq', 'IijJ', '1234'
-- cores do corpo que as variantes trocam (as apagadas e as emissivas ficam iguais em todas)
Fr.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'n', 'N', 'M', 'q', 'p', 'o', 'J', 'j', 'i', 'I', '1', '2', '3', '4' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): a nervura sobe um degrau da paleta.
function Fr.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'B' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'D'
    elseif c == 'D' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'E' end
  end end
end

-- Ponto e direção ao longo de uma linha quebrada, t de 0 a 1.
function Fr.along(pts, t)
  local total, acc = 0, 0
  for i = 1, #pts - 1 do total = total + sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2) end
  local want = t * total
  for i = 1, #pts - 1 do
    local dx, dy = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
    local len = sqrt(dx * dx + dy * dy)
    if want <= acc + len or i == #pts - 1 then
      local f = len > 0 and (want - acc) / len or 0
      return pts[i][1] + dx * f, pts[i][2] + dy * f, math.deg(math.atan(dy, dx)), total
    end
    acc = acc + len
  end
end

-- Fronde de Charnia: lobos alternados (um lado, depois o outro: simetria de deslize, não de espelho), cada lobo com
-- a costura escura em volta. o = { n = lobos por lado, w = função(t) comprimento do lobo, ang, t0, t1, fat,
--   mat = função(i, lado) -> base, costura; wag = função(i) -> graus (o lobo abana); stem = false; r0, r1 }
-- Devolve os lobos: { x, y (no talo), x, y (a 72% do lobo), largura }.
function Fr.frond(P, pts, o)
  local n, t0, t1 = o.n, o.t0 or 0.05, o.t1 or 0.9
  local _, _, _, total = Fr.along(pts, 0)
  local step = total * (t1 - t0) / (2 * n)
  local lobes = {}
  for i = 0, 2 * n - 1 do
    local side = (i % 2 == 0) and -1 or 1
    local t = t0 + (t1 - t0) * (i + 0.5) / (2 * n)
    local x, y, da = Fr.along(pts, t)
    local la = da + side * ((o.ang or 54) + (o.wag and o.wag(i) or 0))
    local len = o.w(t)
    local wid = math.max(1.1, step * (o.fat or 2.1))
    local base, seam = 'f', 'a'
    if o.mat then base, seam = o.mat(i, side) end
    local cx, cy = x + cos(rad(la)) * len * 0.5, y + sin(rad(la)) * len * 0.5
    P:ell(cx, cy, len * 0.5 + 0.5, wid * 0.5 + 0.5, seam, nil, la)
    P:ell(cx, cy, len * 0.5, wid * 0.5, base, nil, la)
    if P.k > 1 and len * P.k > 9 then
      -- a segunda ordem do fractal: cada lobo repartido em lobinhos, em espinha
      local ux, uy = cos(rad(la)), sin(rad(la))
      local vx, vy = cos(rad(la + side * 62)), sin(rad(la + side * 62))
      for sgm = 1, floor(len * P.k / 4) do
        local f = sgm * 4 / (len * P.k)
        local bx, by = P:X(x + ux * len * f), P:Y(y + uy * len * f)
        L.line(P.g, bx - vx * wid * P.k * 0.5, by - vy * wid * P.k * 0.5, bx + vx * wid * P.k * 0.5, by + vy * wid * P.k * 0.5, seam, base)
      end
    end
    lobes[#lobes + 1] = { x, y, x + cos(rad(la)) * len * 0.72, y + sin(rad(la)) * len * 0.72, wid }
  end
  if o.stem ~= false then
    local th = P.k > 1 and 0.55 or 1                         -- no retrato o talo é fino: o fio de luz, não um cano
    P:limb(pts, (o.r0 or 0.5) * th, (o.r1 or 0.4) * th, 'm')
  end
  return lobes
end
-- Nervuras acesas: o talo (m) e, se pedido, o fio de cada lobo. A luz corre pelo talo: um ponto claro a cada per
-- pixels, que anda com ph.
function Fr.veins(g, P, lobes, mask, ph, per)
  for _, q in ipairs(lobes or {}) do
    L.line(g, P:X(q[1]), P:Y(q[2]), P:X(q[3]), P:Y(q[4]), 'B', mask)
  end
  per = per or 4
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == 'm' then g[y][x] = ((x + 2 * y + (ph or 0)) % per == 0) and 'E' or 'D' end
  end end
end
function Fr.shadeAll(g, k)
  local p = k > 1 and 2 or 1
  F.shade(g, 'f', Fr.LEAF, { p = p, ax = 1, ay = 0.4, zones = 3, within = 'f', jit = k > 1 and 2 or 0, jw = 2 })
  F.shade(g, 'g', Fr.DRY, { p = p, ax = 1, ay = 0.4, zones = 1, within = 'g' })
  F.shade(g, 'h', Fr.ROOT, { p = k > 1 and 3 or 2, ax = 0.3, ay = 1, zones = 1, within = 'h' })
  F.shade(g, 'y', Fr.CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 2, within = 'y', jit = 1, jw = 3 })
  F.shade(g, 'z', Fr.STONE, { p = p, ax = 1, ay = 0.4, zones = 2, within = 'z' })
end
-- Costura do Véu atravessada num lobo (q, de Fr.frond), a f do comprimento dele.
function Fr.lobeSeam(P, q, w, f, step)
  local dx, dy = q[3] - q[1], q[4] - q[2]
  local len = sqrt(dx * dx + dy * dy)
  local mx, my = q[1] + dx * (f or 0.6), q[2] + dy * (f or 0.6)
  local nx, ny = -dy / len * (q[5] * 0.5 + 0.1), dx / len * (q[5] * 0.5 + 0.1)
  S.seam(P, { { mx - nx, my - ny }, { mx + nx, my + ny } }, w, 'X', Fr.LEAF, step)
end
-- Esporos soltos (só no glow): sobem e somem. list = { { x, y } }; NL = quadros do laço.
function Fr.spores(P, sg, list, ph, NL)
  for n, q in ipairs(list) do
    local r = (ph + n) % NL
    if r < NL - 1 then S.spark(P, sg, q[1], q[2] - r * 0.9, n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'T')) end
  end
end
-- Tira do corpo o que não está ligado à peça principal (um pixel de lobo que a pose soltou) e, se c for dado, tapa
-- com c os furos fechados dentro da forma (até max pixels cada: o vazio grande entre as raízes fica).
function Fr.clean(g, tag, c, max)
  F.prune(g, '', tag)
  if not c then return g end
  local seen = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == '.' and not seen[y * g.w + x] then
      local st, hole, open = { { x, y } }, {}, false
      seen[y * g.w + x] = true
      while #st > 0 do
        local q = table.remove(st)
        hole[#hole + 1] = q
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local nx, ny = q[1] + d[1], q[2] + d[2]
          if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h then open = true
          elseif g[ny][nx] == '.' and not seen[ny * g.w + nx] then seen[ny * g.w + nx] = true; st[#st + 1] = { nx, ny } end
        end
      end
      if not open and #hole <= (max or 4) then for _, q in ipairs(hole) do g[q[2]][q[1]] = c end end
    end
  end end
  return g
end

function Fr.run(spec)
  spec.LEG = spec.LEG or Fr.LEG
  spec.LIT, spec.NOPULL, spec.heat = Fr.LIT, Fr.NOPULL, Fr.heat
  spec.BODY_KEYS = spec.BODY_KEYS or Fr.BODY_KEYS
  spec.DARK = spec.DARK or 'a'
  spec.ownDy = true
  return K.run(spec)
end

return Fr
