-- Kit da arte final da família Shade (Sombra): Umbrel (Eco), Shadekin (Espírito), Entidade Maior e Arquétipo.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar); aqui ficam a legenda, os emissivos e as ajudas de forma dos conceitos aprovados
-- (tools/art/creatures/conceitos/shade/build.lua), agora com pose. Cada espécie dá draw(g, sg, k, o): o corpo em g
-- (emissivos ACESOS; as camadas do _r2.lua já saem contornadas) e a faísca solta em sg; k é a escala (1 no mapa) e o
-- é o quadro (ph fase do laço, pose 'alert' | 'crouch', dy, lean, jump, portrait).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Sombra: d, m, l); o rosa do crepúsculo do conceito saiu.
-- TRAÇO DA FAMÍLIA: a sombra não acompanha o corpo. Ela é parte do sprite (matéria e, f, g, igual em toda variante),
-- o body_dy move só o corpo (ownDy) e a sombra fica, com outro ritmo; o código não desenha sombra no chão.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local C, L = K.C, K.L
local R = dofile(ART .. 'creatures/conceitos/_r2.lua')(C)
local Sh = { L = L, C = C, R = R, hash = K.hash }
local floor, sin, cos, rad = math.floor, math.sin, math.cos, math.rad

local SHADOW
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'shadow' then SHADOW = c end end
local VEU = '#9B7BFF'

Sh.LEG = {
  A = '#1A1424',
  a = '#3A2E2C', b = '#574639', c = '#7A654F', d = '#A08A6C', -- pelo pardo
  m = '#2B2230', n = '#40323F', o = '#5A4652',                -- membrana
  i = '#6B5560', j = '#927C80',                               -- osso do dedo, garra
  w = '#D8CDB8',                                              -- listras da cara
  ['1'] = '#45454E', ['2'] = '#63636B', ['3'] = '#87868A', ['4'] = '#ACA9A4', ['5'] = '#34343E', -- concreto e sujeira
  r = '#7A4630', q = '#A0623C',                               -- vergalhão
  ['6'] = '#C8C2B4', ['7'] = '#9A9488', ['8'] = '#6E6A66',    -- osso (Arquétipo)
  e = '#231E33', f = '#2F2942', g = '#3C3552',                -- sombra (matéria; não entra nas variantes)
  x = '#3A2A44', y = '#4C3A56', z = '#5E4A68',                -- luz do tipo apagada (borda e olhos da sombra)
  H = '#77737C', h = '#5E5A64',                               -- lâmpada da marquise apagada
  R = SHADOW.d, P = SHADOW.m, W = SHADOW.l,                   -- borda da sombra (glow)
  I = SHADOW.m, E = SHADOW.l,                                 -- olhos da sombra (leds: piscam)
  T = SHADOW.l, V = SHADOW.m,                                 -- lâmpada acesa (glow)
  K = SHADOW.d, S = SHADOW.m, s = SHADOW.l,                   -- faísca solta (só no glow)
  v = '#352E4C', ['9'] = '#5F5062', ['0'] = '#6C6A7C',        -- costura do Véu apagada: na sombra, no pelo, no concreto
  Z = VEU, X = VEU, Q = VEU,                                  -- costura acesa (glow)
  k = '#120D1C',                                              -- o vão apagado (mais escuro que o contorno)
  U = VEU, Y = '#5A45A8', M = SHADOW.m, N = SHADOW.l,         -- o vão do Arquétipo (glow)
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
Sh.LIT = {
  R = { 'x', 'w' }, P = { 'y', 'w' }, W = { 'z', 'w' }, I = { 'y', 'l' }, E = { 'z', 'l' },
  T = { 'H', 'w' }, V = { 'h', 'w' },
  Z = { 'v', 'w' }, X = { '9', 'w' }, Q = { '0', 'w' },
  U = { 'k', 'w' }, Y = { 'k', 'w' }, M = { 'k', 'w' }, N = { 'k', 'w' },
}
Sh.NOPULL = 'AKSs'
Sh.SHADE = 'efg'
-- cores do corpo que as variantes trocam (a sombra, as apagadas e as emissivas ficam iguais em todas)
Sh.BODY_KEYS = { 'a', 'b', 'c', 'd', 'm', 'n', 'o', 'i', 'j', 'w', '1', '2', '3', '4', '5', 'r', 'q', '6', '7', '8' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): a borda da sombra sobe um degrau da paleta.
function Sh.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'R' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'P'
    elseif c == 'P' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'W' end
  end end
end

-- Contexto do _r2.lua desenhando direto na grade g (unidades do mapa; dx, dy em pixels).
function Sh.ctx(g, k, dx, dy)
  local d = R.ctx(g.w, k, dx or 0, dy or 0)
  d.g = g
  return d
end
-- A matéria da sombra: mais clara acima de vtop (ou conforme light(u, v)).
function Sh.matter(d, light)
  if type(light) == 'number' then local vt = light; light = function(_, v) return v < vt and 0.7 or 0.2 end end
  return R.mat(Sh.SHADE, R.diag(d:pp()), light)
end
-- Mão de asa: n dedos em leque a partir de (x, y); mem pinta a membrana entre eles (borda em arco para dentro).
function Sh.hand(t, x, y, ang, len, spread, n, bone, mem, w, vary)
  local tips = {}
  for i = 0, n - 1 do
    local a = rad(ang + (i / (n - 1) - 0.5) * spread)
    local l = len * (1 - (vary or 0.2) * (0.5 + 0.5 * sin(i * 2.1 + 1)))
    tips[#tips + 1] = { x + cos(a) * l, y + sin(a) * l }
  end
  if mem then
    for i = 1, n - 1 do
      local a, b = tips[i], tips[i + 1]
      t:poly({ { x, y }, a, { x + ((a[1] + b[1]) / 2 - x) * 0.7, y + ((a[2] + b[2]) / 2 - y) * 0.7 }, b }, mem)
    end
  end
  for _, q in ipairs(tips) do t:wire({ { x, y }, q }, bone[1], bone[2], w) end
  return tips
end
-- Olho da sombra (leds): no mapa um pixel (dois quando wide), no retrato o aro e o miolo.
function Sh.eye(t, u, v, wide, mask)
  if t.k > 1 then
    t:ell(u, v, wide and 1.0 or 0.75, wide and 0.8 or 0.6, 'I'); t:ell(u, v, 0.45, 0.35, 'E')
  else
    L.set(t.g, t:X(u), t:Y(v), 'E')
    if wide then L.set(t.g, t:X(u), t:Y(v) + 1, 'I', mask or Sh.SHADE .. 'R') end
  end
end
-- Faísca solta em sg (só no glow), onde o corpo está vazio e longe da borda.
function Sh.spark(d, sg, u, v, ch)
  local n = d:th(0.6)
  local px, py = floor(d:X(u)), floor(d:Y(v))
  for j = 0, n - 1 do for i = 0, n - 1 do
    local x, y = px + i, py + j
    if x > 0 and y > 0 and x < sg.w - 1 and y < sg.h - 1 and L.get(d.g, x, y) == '.' then sg[y][x] = ch end
  end end
end
-- Poeira de crepúsculo: sobe e some. list = { { u, v, ch } }; NL = quadros do laço.
function Sh.dust(d, sg, list, ph, NL)
  for n, q in ipairs(list) do
    local r = (ph + n) % NL
    if r < NL - 1 then Sh.spark(d, sg, q[1], q[2] - r * 0.9, q[3] or (n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'K'))) end
  end
end
-- Recorte do busto: apaga o que passa de uma moldura rasgada a m px da borda (o corpo não encosta no quadro).
function Sh.tear(g, m)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local e = math.min(x, y, g.w - 1 - x, g.h - 1 - y)
    if e < m + (K.hash(x // 3, y // 3, 17) % 3) then g[y][x] = '.' end
  end end
end
-- Tapa com c os furos fechados dentro da forma (até max pixels cada): a pose abre frestas de 1 px entre as peças.
function Sh.fill(g, c, max)
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
end
-- Conta caracteres (para acertar o emissivo).
function Sh.count(g, chars)
  local n = 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do if chars:find(g[y][x], 1, true) then n = n + 1 end end end
  return n
end

function Sh.run(spec)
  spec.LEG = spec.LEG or Sh.LEG
  spec.LIT, spec.heat = Sh.LIT, Sh.heat
  spec.NOPULL = spec.NOPULL or Sh.NOPULL
  spec.BODY_KEYS = spec.BODY_KEYS or Sh.BODY_KEYS
  spec.DARK = spec.DARK or 'e'
  spec.ownDy, spec.ownLean = true, true
  -- silhueta escura do spawn: o K.run escurece tudo e contorna de novo; o contorno de fora das camadas sai antes,
  -- para a silhueta não crescer 1 px
  local draw = spec.draw
  spec.draw = function(g, sg, k, o)
    draw(g, sg, k, o)
    if not o.dark then return end
    local cut = {}
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] == 'A' and (L.get(g, x - 1, y) == '.' or L.get(g, x + 1, y) == '.' or L.get(g, x, y - 1) == '.' or L.get(g, x, y + 1) == '.') then
        cut[#cut + 1] = { x, y }
      end
    end end
    for _, q in ipairs(cut) do g[q[2]][q[1]] = '.' end
  end
  return K.run(spec)
end

return Sh
