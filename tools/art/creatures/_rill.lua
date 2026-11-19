-- Kit da arte final da família Rill (Água). Por enquanto só o Wellmirror (rill.ritual) usa: o Rillet, o Brookkin,
-- a Entidade Maior e o Arquétipo entram aqui quando a família for para a arte final.
-- A saída é a do _hum.lua (K.run: seis animações em três tiras, <especie>.json, variantes, retrato, folha e a régua
-- impressa ao gravar); aqui ficam a legenda, os emissivos e a pele dos conceitos aprovados
-- (tools/art/creatures/conceitos/rill/build.lua). Cada espécie dá draw(g, sg, k, o): o corpo em g (emissivos ACESOS,
-- sem contorno) e a gota solta em sg; k é a escala (1 no mapa) e o é o quadro (ph fase do laço, pose 'alert' |
-- 'crouch', dy, lean, jump, portrait).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Água: d, m, l), no lugar dos azuis e do branco do conceito.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local K = dofile(ART .. 'creatures/_hum.lua')
local S = dofile(ART .. 'creatures/_soot.lua')               -- só as ajudas que servem a qualquer família
local C, L, F, R = K.C, K.L, S.F, S.R
local Rl = { L = L, C = C, F = F, R = R, hash = K.hash, seam = S.seam, tear = S.tear }
local floor = math.floor

local WATER
for _, c in ipairs(dofile(ART .. 'ui/types/palette.lua')) do if c.id == 'water' then WATER = c end end
local VEU = '#9B7BFF'

Rl.LEG = {
  A = '#1A1424',
  a = '#2E2A22', b = '#453E30', c = '#5F553F', d = '#7D7052', e = '#9A8C68', -- pele de cururu (barro, água de poça)
  v = '#6A634F', w = '#8A8168', W = '#B0A685', V = '#CFC6A6',                 -- barriga creme
  o = '#8A6A2A', O = '#B8923A', k = '#241A2A',                                -- íris, pupila, fundo do poço
  J = '#454449', j = '#63625F', i = '#85847F', I = '#A9A8A2',                 -- concreto
  p = '#8C7836', P = '#B59A45',                                               -- tinta amarela gasta
  n = '#2F3038', N = '#44454F',                                               -- asfalto molhado
  r = '#1B2638', q = '#243449', u = '#30455E',                                -- espelho apagado (corpo)
  B = WATER.d, D = WATER.m, E = WATER.l,                                      -- o céu no espelho (glow)
  H = WATER.m, Z = WATER.l,                                                   -- estrela (leds: pisca)
  M = WATER.l, L = WATER.m,                                                   -- a lua e o rastro dela (glow)
  m = '#93A5BD', l = '#5C7696',                                               -- a lua e o rastro apagados: de dia o papo não é um disco escuro
  F = WATER.m, G = WATER.l,                                                   -- o luar na borda da cabeça (glow; apagado: pele e pálpebra)
  T = WATER.d, S = WATER.m, s = WATER.l,                                      -- gota solta (só no glow)
  ['5'] = '#5E586A', ['8'] = '#5F5C6B',                                       -- costura do Véu apagada: pele, concreto
  X = VEU, ['9'] = VEU,                                                       -- costura acesa (glow)
  -- bases que o sombreado troca (não têm cor: se sobrar, o build acusa): f pele, h perna, x barriga, y concreto
}
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
Rl.LIT = {
  B = { 'r', 'w' }, D = { 'q', 'w' }, E = { 'u', 'w' }, H = { 'q', 'l' }, Z = { 'u', 'l' },
  M = { 'm', 'w' }, L = { 'l', 'w' }, F = { 'e', 'w' }, G = { 'W', 'w' },
  X = { '5', 'w' }, ['9'] = { '8', 'w' },
}
Rl.NOPULL = 'ATSs'
Rl.SKIN, Rl.BELLY, Rl.CONC = 'edcba', 'VWwv', 'IijJ'
-- cores do corpo que as variantes trocam (as apagadas e as emissivas ficam iguais em todas)
Rl.BODY_KEYS = { 'a', 'b', 'c', 'd', 'e', 'v', 'w', 'W', 'V', 'o', 'O', 'J', 'j', 'i', 'I', 'p', 'P', 'n', 'N' }

-- O brilho que cresce (alerta, fuga, o pulso do retrato): o espelho sobe um degrau da paleta.
function Rl.heat(g, lv)
  if lv == 0 then return end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c == 'B' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'D'
    elseif c == 'D' and lv == 2 and (x + y) % 2 == 0 then g[y][x] = 'E' end
  end end
end

-- Pele: hachura e verrugas (um ponto claro com a sombra embaixo). A do conceito.
function Rl.skin(g, k, src, ramp, o)
  o = o or {}
  ramp = ramp or Rl.SKIN
  o.p = o.p or (k > 1 and 2 or 1); o.ax = o.ax or 0.5; o.ay = o.ay or 1
  o.zones = o.zones or (#ramp - 2)
  if k > 1 then o.jit = 3; o.jw = 2 end
  local hit = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do if g[y][x] == src then hit[#hit + 1] = { x, y } end end end
  F.shade(g, src, ramp, o)
  local w = k > 1 and 2 or 1
  for _, q in ipairs(hit) do
    local x, y = q[1], q[2]
    if F.rnd(x // w, y // w, o.seed or 3) > (o.warts or 0.9) and (x // w + y // w) % 2 == 0 then
      g[y][x] = (w == 1 or y % w == 0) and ramp:sub(1, 1) or ramp:sub(#ramp - 1, #ramp - 1)
    end
  end
end
function Rl.toes(P, x, y, n, len, c, dx, dy)
  for t = 0, n - 1 do
    P:limb({ { x, y }, { x + (dx or 1) * len * (0.55 + t * 0.25) + (dy and (t - 1) * 0.9 or 0), y + (dy or 0) * len + 0.4 - t * 0.4 } },
      0.42, 0.35, c)
  end
end
-- Gota solta em sg (só no glow), onde o corpo de P.g está vazio; a cauda fica para trás do movimento.
function Rl.drop(P, sg, x, y, up)
  local n = math.max(1, floor(P.k * 0.6 + 0.5))
  local px, py = floor(P:X(x)), floor(P:Y(y))
  local d = up and 1 or -1
  for i, ch in ipairs({ 's', 'S', 'T' }) do
    for jy = 0, n - 1 do for jx = 0, n - 1 do
      local xx, yy = px + jx, py + (i - 1) * d * n + jy
      if L.get(P.g, xx, yy) == '.' then L.set(sg, xx, yy, ch) end
    end end
  end
end

function Rl.run(spec)
  spec.LEG = spec.LEG or Rl.LEG
  spec.LIT, spec.NOPULL, spec.heat = Rl.LIT, Rl.NOPULL, Rl.heat
  spec.BODY_KEYS = spec.BODY_KEYS or Rl.BODY_KEYS
  spec.DARK = spec.DARK or 'a'
  spec.ownDy = true
  return K.run(spec)
end

return Rl
