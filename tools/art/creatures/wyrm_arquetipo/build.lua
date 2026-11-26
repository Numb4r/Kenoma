-- Arquétipo da família Wyrm (nome e pasta provisórios: wyrm_arquetipo), arte final a partir do conceito aprovado: o
-- eclipse, a espiral de escamas. Só aparece em evento e Incursão. No lugar do corpo, o vão; a armação é um anel de
-- doze escamas de asfalto em espiral; de dentro do vão, cinco mãos de teú agarram o anel; por fora, três caudas em
-- cata-vento, de cinza. Nenhuma cabeça.
-- REGRAS QUEBRADAS: geometria, as doze escamas do anel estão cada uma por cima da seguinte em toda a volta (não
-- existe a de baixo), e o anel gira sem sair do lugar; física, a coroa brilha em volta de um disco que não tapa nada
-- (eclipse sem sol nem lua) e as brasas soltas caem de fora para dentro do vão.
-- Sem costura do Véu: o vão. No corpo ele é escuro (z, mais escuro que o contorno); o violeta vai só no glow (a borda
-- junto do anel e das mãos e o xadrez), com a coroa na luz do tipo em volta do disco do meio, que fica apagado.
-- Movimento: o anel gira uma escama por laço (o laço fecha), as mãos abrem e fecham fora de fase, a coroa tremula, as
-- caudas respiram e as brasas caem para dentro. No alerta as mãos abrem e as caudas esticam; encolhem na antecipação.
-- Retrato: composição própria, um busto de 128 (escala 3): o vão com a coroa, as mãos e o lado direito do anel,
-- cortado num rasgo em volta.
-- Camadas: corpo; leds = nada (não tem olho); glow = o vão, a coroa, as juntas das escamas e as brasas.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wyrm_arquetipo/build.lua')
local W = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wyrm.lua')
local L = W.L
local floor, sqrt, abs, sin, cos, rad, max, pi = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.rad, math.max, math.pi
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(W)
RT.install(W.LEG, W.LIT)
-- o retrato nativo: o vão com fundo, asfalto com brita, cinza em escamas; a borda recortada pela brasa das juntas
local RETRATO = {
  vao = { seed = 'UY', set = 'zUY', keep = 'Vmd', depth = 12, star = { 'm', 'V' }, sky = 40 },
  light = { ramps = { { 'QPpg', RT.tex.pit(0.35, 6) }, { 'GFDB', RT.tex.scale(6, 0.3) }, { '4321' }, { 'Ee', RT.tex.pit(0.4) } },
    lights = 'JHRVmd', lw = 0.3, R = 8, rim = { 'J', 'R' } },
}

local function draw(g, sg, k, o)
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local tt = fr * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local p = (k > 1 and not o.bust) and 2 or 1
  local function P(v) return v * k end
  local cx, cy = P(32) - 0.5 + (o.ox or 0), P(33) + (o.oy or 0) + (o.dy or 0)
  local rot = (still and 0 or fr) * 30                       -- uma escama por laço
  local lite, dark = W.asphalt(true), W.asphalt(false)
  -- caudas: respiram; na deriva ficam para trás
  local ext = alert and 2 or (crouch and -3.5 or (still and 0 or 0.8 * sin(tt)))
  for i = 0, 2 do
    local a0 = 35 + i * 120 - (o.lean and 12 or 0)
    local function tail(t)
      local a = rad(a0 + (120 + ext * 3) * t)
      local r = P(16.5 + (11.5 + ext) * t)
      return cx + cos(a) * r, cy + sin(a) * r
    end
    W.tube(g, tail, W.prof({ { 0, 3.4 }, { 0.6, 1.8 }, { 1, 0.5 } }, k), W.skin({ p = p, band = 5 * k, pal = W.ASHY, tw = ph + i,
      ember = function(t, dn) return t > 0.08 and t < 0.6 and abs(dn) < 0.45 end }))
  end
  -- o anel de escamas
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      local dx, dy = x - cx, y - cy
      local d = sqrt(dx * dx + dy * dy) / k
      local ang = math.deg(math.atan(dy, dx)) % 360
      local wob = 0.7 * sin(rad(ang * 5))
      if d >= 12.4 and d <= 19.4 + wob then
        local a = (ang - rot - 9 * sin((d - 12.4) / 7 * pi)) % 360
        local f = (a % 30) / 30
        local ch
        if f < 0.13 then ch = (d > 14 and d < 17.5) and 'H' or 'J'
        elseif f < 0.18 then ch = 'R'
        elseif f < 0.3 then ch = (x + y) % 2 == 0 and 'Q' or '4'
        elseif f < 0.62 then ch = dark(x, y)
        elseif f < 0.9 then ch = lite(x, y)
        else ch = (x + y) % 2 == 0 and 'g' or 'D' end
        if d < 13.1 then ch = (x + y) % 2 == 0 and 'E' or 'e' end
        g[y][x] = ch
      end
    end
  end
  -- as mãos que saem do vão: abrem e fecham fora de fase
  local reach = alert and 14.4 or (crouch and 12.6 or 13.6)
  for n, q in ipairs({ { 20, 1 }, { 95, 0.85 }, { 150, 1.1 }, { 215, 0.9 }, { 290, 1.05 } }) do
    local a = rad(q[1])
    local sp = q[2] * (alert and 1.35 or (crouch and 0.55 or 1 + 0.25 * sin(tt + n * 1.9)))
    for _, da in ipairs({ -13, -4, 5, 14 }) do
      local b = rad(q[1] + da * sp)
      W.tube(g, W.seg(cx + cos(a) * P(7.2), cy + sin(a) * P(7.2), cx + cos(b) * P(reach), cy + sin(b) * P(reach)),
        function(t) return max(0.6, P(0.95 - 0.3 * t)) end,
        function(_, _, t, _, ds) return t > 0.72 and 'k' or t > 0.6 and 'K' or (floor(ds / max(1, k * 0.8)) % 2 == 0 and '3' or '2') end)
    end
    W.ell(g, cx + cos(a) * P(7.6), cy + sin(a) * P(7.6), P(1.9), P(1.6), q[1], function(x, y) return (x + y) % 2 == 0 and '3' or '4' end)
  end
  -- o vão: contorno por dentro (mãos e anel), depois o disco escuro com o violeta e a coroa por cima (só glow)
  local function inside(x, y) return sqrt((x - cx) ^ 2 + (y - cy) ^ 2) < P(12.6) end
  local add = {}
  for y = 1, S - 2 do for x = 1, S - 2 do
    if g[y][x] == '.' and inside(x, y) then
      for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local q = g[y + dd[2]][x + dd[1]]
        if q ~= '.' and q ~= 'A' then add[#add + 1] = { x, y }; break end
      end
    end
  end end
  for _, q in ipairs(add) do g[q[2]][q[1]] = 'A' end
  for y = 1, S - 2 do for x = 1, S - 2 do
    if g[y][x] == '.' and inside(x, y) then
      local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2) / k
      local ch = 'z'
      if g[y][x - 1] == 'A' or g[y][x + 1] == 'A' or g[y - 1][x] == 'A' or g[y + 1][x] == 'A' then ch = 'U'
      elseif d > 6.6 and (x // p + y // p) % 2 == 0 then ch = 'Y' end
      g[y][x] = ch
    end
  end end
  for n = 0, 35 do                                            -- a coroa, em volta do disco apagado: tremula
    local a = rad(n * 10 + 3)
    local len = P(1.8 + (W.hash(n, 3 + (still and 0 or ph), 7) % 4) * 0.8 + (alert and 0.8 or 0))
    for s = 0, floor(len) do
      local r = P(6.4) - s
      local ch = s == 0 and 'V' or (s < len * 0.6 and 'm' or 'd')
      local n2 = max(1, floor(k * 0.6 + 0.5))
      for j = 0, n2 - 1 do for i = 0, n2 - 1 do L.set(g, cx + cos(a) * r + i, cy + sin(a) * r + j, ch, 'zY') end end
    end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- brasas que caem de fora para dentro
  for n = 0, 11 do
    local a = rad(n * 30 + 17)
    local r = P(21 + (W.hash(n, 9, 2) % 3) + 4.5 * (1 - (((still and 0 or fr) + (n % 3) / 3) % 1)))
    W.spark(g, sg, cx + cos(a) * r, cy + sin(a) * r, k, 's')
    W.spark(g, sg, cx + cos(a) * (r + P(1.4)), cy + sin(a) * (r + P(1.4)), k, 'S')
    W.spark(g, sg, cx + cos(a) * (r + P(2.8)), cy + sin(a) * (r + P(2.8)), k, 'N')
  end
end

W.run {
  name = 'wyrm_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'UY', fill = 'z', mid = 'Y', edge = 'U', extra = 'Vmd' },
  -- busto: o vão com a coroa, as mãos e o lado direito do anel, em escala 3
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust, o.ox, o.oy = true, -50, -20
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 29, 15 }, green = { 26, 50 }, water = { 15, 30 }, residential = { 42, 29 }, lit = { 28, 51 },
    sacred = { 28, 14 }, crimson = { 14, 31 },
  },
}
