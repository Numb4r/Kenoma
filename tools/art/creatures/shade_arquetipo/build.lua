-- Arquétipo da família Shade (nome e pasta provisórios: shade_arquetipo), arte final a partir do conceito aprovado da
-- rodada 2: as asas sobre o casulo. Só aparece em evento e Incursão.
-- O morcego pendurado na própria sombra. Em cima, onde ficaria a marquise, está a sombra, de pé e de asa aberta, com
-- os olhos todos; embaixo, o casulo das asas fechadas é de laje e vergalhão, igual dos dois lados (simetria demais),
-- com as lâmpadas viradas para dentro e os que dormem pendurados nele. A cabeça, embaixo, é osso, com três orelhas
-- e nenhum rosto.
-- REGRAS QUEBRADAS: física, o peso pende de uma sombra, que fica acima da lâmpada e não é projetada por nada (o
-- casulo balança como pêndulo e ela não se mexe com ele); geometria, casulo dentro de casulo: o casulo não fecha, e
-- na fresta o mesmo casulo nasce do tamanho do de fora, encolhe e afunda sem parar.
-- Sem costura do Véu: o vão. No corpo ele é a fresta escura; o violeta vai só no glow (a borda e o xadrez que rareia
-- para o eixo), e os casulos de dentro acendem em violeta, depois na luz do tipo.
-- TRAÇO: a sombra não acompanha o corpo. O body_dy e o pêndulo movem só o casulo; as asas batem devagar, no ritmo
-- delas. No alerta as asas sobem e o vão abre; na antecipação elas descem em volta do casulo, que se recolhe.
-- Camadas: corpo; leds = os olhos da sombra; glow = a borda da sombra, as lâmpadas, o vão e a poeira solta.
-- Retrato: composição própria, um busto de 128 (escala 3): a sombra, os pés e a fresta, cortado num rasgo.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/shade_arquetipo/build.lua')
local Sh = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_shade.lua')
local L, R = Sh.L, Sh.R
local floor, ceil, abs, sin, cos, rad, max = math.floor, math.ceil, math.abs, math.sin, math.cos, math.rad, math.max

local NOPULL = 'AKSs678'                                      -- contorno seletivo: osso e os que dormem ficam sem
local SOL = ''
for ch in pairs(Sh.LEG) do if not NOPULL:find(ch, 1, true) then SOL = SOL .. ch end end
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Sh)
RT.install(Sh.LEG, Sh.LIT)
-- o retrato nativo: o vão com fundo, laje com poros, osso com trincas, a sombra em trama; a borda recortada pelas
-- lâmpadas viradas para dentro
local RETRATO = {
  vao = { seed = 'UY', set = 'kUY', keep = 'MN', depth = 9, star = { 'M', 'N' }, sky = 70 },
  light = { ramps = { { '51234', RT.tex.pit(0.3) }, { '876', RT.tex.stone(0.3) }, { 'efg', RT.tex.weave(0.22) }, { 'mno' } },
    lights = 'TV', lw = 0.3, R = 9, rim = { 'P', 'R' } },
}
local cx = 31.5
local HALF = { { cx, 19.5 }, { 27, 20 }, { 22.5, 25 }, { 20.3, 34 }, { 21.5, 44 }, { 25, 51 }, { cx, 53 } }

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local tt = fr * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dy = o.dy or 0
  local sdy = (o.jump and dy < 0) and ceil(dy / 2) or 0
  local ox, oy = o.ox or 0, o.oy or 0
  -- a sombra: as asas batem devagar (a ponta mais que a raiz)
  local wf = alert and -2.4 or (crouch and 3 or (o.lean and 1.8 or 1.2) * sin(tt))
  local function W(x, y) return { x, y + wf * max(0, 24 - x) / 20 } end
  local ds = Sh.ctx(g, k, ox, oy + sdy)
  local sf = Sh.matter(ds, function(_, v) return 0.9 - (v - 3) / 22 end)
  ds:layer(function(t)
    t:poly({ { cx, 7 }, { 24, 8 }, W(14, 5), W(4, 9), W(3, 16), W(6, 13.5), W(8, 21), W(11, 15.5), W(14.5, 23), W(17.5, 16.5),
      W(21.5, 22), { 24, 17 }, { cx, 19 } }, sf)
    t:ell(cx, 9, 4, 4.2, sf)
    t:poly({ { cx - 3.4, 7 }, { cx - 4.6, 3.2 }, { cx - 1.4, 5.4 } }, sf)
    t:poly({ { cx - 1.3, 5.8 }, { cx, 2.8 }, { cx + 1.3, 5.8 } }, sf)
    for _, e in ipairs({ { 3.4, 15.6 }, { 8, 20.4 }, { 14.5, 22.4 } }) do t:wire({ W(14, 6), W(e[1], e[2]) }, '7', '6', 0.5) end
    t:wire({ { 24, 8.6 }, W(21.5, 21.4) }, '7', '6', 0.5)
    t:mirror(cx)
    t:rim(Sh.SHADE, 'R', true, 0.5, k > 1 and 5 or nil)
    for n, e in ipairs({ { 8.6, 11 }, { 15.6, 12 }, { 19.6, 15.4 }, { 12, 16.4 }, { 23, 11.4 }, { cx - 1.7, 8.4 }, { cx, 11 } }) do
      local q = W(e[1], e[2])
      for s = 0, 1 do
        local ex = s == 0 and q[1] or 2 * cx - q[1]
        if k > 1 then t:ell(ex, q[2], alert and 1 or 0.75, 0.55, 'I'); t:ell(ex, q[2], 0.4, 0.3, 'E')
        else
          L.set(t.g, t:X(ex), t:Y(q[2]), 'E')
          if alert or (n + s + ph) % 3 == 0 then L.set(t.g, t:X(ex), t:Y(q[2]) + 1, 'I', 'efgR') end
        end
      end
    end
  end, SOL)
  -- o casulo, numa grade própria (depois ele pende); na antecipação se recolhe para dentro das asas
  local d = R.ctx(g.w, k, ox, oy + dy - (crouch and 2 * k or 0))
  local p = o.bust and 1 or d:pp()
  d:layer(function(t)
    t:poly(HALF, R.mat('5123', R.noise(p, 21), function(u, v) return 0.15 + 0.8 * (cx - u) / 11 - (v - 20) / 90 end))
    for _, e in ipairs({ { 23.4, 27, 31 }, { 25.6, 33, 39 }, { 22.6, 40, 44 }, { 27.6, 24, 27 } }) do
      t:wire({ { e[1], e[2] }, { e[1] + 0.3, e[3] } }, '5', nil, 0.4, '123')
    end
    t:wire({ { 27.4, 20.6 }, { 23, 27 }, { 21.6, 38 }, { 25.6, 50 } }, 'r', 'q', 0.6)
    t:wire({ { 29.4, 21 }, { 27, 32 }, { 27.6, 47 } }, 'r', 'q', 0.6)
    t:wire({ { cx - 6.4, 27 }, { cx - 6.4, 43 } }, 'T', nil, 0.9)                     -- a lâmpada, virada para a fresta
    t:wire({ { cx - 6.4, 26 }, { cx - 6.4, 26.4 } }, 'V', nil, 0.9)
    t:wire({ { cx - 6.4, 43.6 }, { cx - 6.4, 44 } }, 'V', nil, 0.9)
    t:wire({ { cx - 1.6, 17 }, { cx - 1.6, 20.4 } }, '7', nil, 0.6)                   -- o pé agarrado na sombra
    for n, e in ipairs({ { 22.6, 26 }, { 20.8, 36 }, { 22.4, 45 } }) do               -- os que dormem pendurados no casulo
      local len = 3 + (n % 2) * 1.2
      t:cap(e[1] - 1, e[2], e[1] - 1.6, e[2] + len, 0.8, 1.4, R.mat('87', R.ver(p), 0))
      t:wire({ { e[1] - 2.2, e[2] + len + 1.4 }, { e[1] - 2.6, e[2] + len + 2.6 } }, '8', nil, 0.5)
    end
    t:mirror(cx)
    if not still and ph % 3 == 2 then                         -- uma das lâmpadas falha
      for y = 0, t.S - 1 do for x = ceil(t:X(cx)), t.S - 1 do if t.g[y][x] == 'T' then t.g[y][x] = 'V' end end end
    end
  end, SOL)
  d:layer(function(t)                                         -- a cabeça: osso, três orelhas, nenhum rosto
    for _, e in ipairs({ { cx - 3.6, 56.6, cx - 5.6, 60.6, cx - 1.6, 58 }, { cx - 1.3, 58, cx, 61.4, cx + 1.3, 58 } }) do
      t:poly({ { e[1], e[2] }, { e[3], e[4] }, { e[5], e[6] } }, R.mat('n87', R.diag(p), 0.5))
    end
    t:ell(cx, 54.8, 4.6, 3.8, R.mat('876', R.chev(t:X(cx), p), R.lum(cx, 54.8, 4.6, 3.8)))
    t:wire({ { cx - 2.8, 53.4 }, { cx, 56 } }, 'w', nil, 0.5)
    t:mirror(cx)
  end)
  -- o vão: a fresta do casulo. No corpo é escura (k); a borda e o xadrez acendem em violeta no glow
  local vs = alert and 1.3 or (crouch and 0.6 or 1 + 0.08 * sin(tt))
  for y = 0, d.S - 1 do for x = 0, d.S - 1 do
    local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
    local q = (v - 35.5) / 13
    if abs(q) < 1 then
      local t = abs(u - cx) / (4.4 * vs * (1 - q * q) ^ 0.8)
      if t <= 1 then
        local ch = 'k'
        if t > 0.7 then ch = 'U'
        elseif t > 0.3 and (x // p + y // p) % 2 == 0 then ch = 'Y'
        elseif t > 0.12 and (x // p) % 2 == 0 and (y // p) % 2 == 0 then ch = 'Y' end
        d.g[y][x] = ch
      end
    end
  end end
  -- o mesmo casulo, para dentro: cada um nasce do tamanho do de fora, encolhe e afunda no eixo
  for lv = 0, 3 do
    local q = lv - 1 + (still and 0 or fr)
    local s = 0.62 * 0.45 ^ q
    local ch = q < 0.5 and (o.bust and '!' or 'U') or (q < 1.5 and 'M' or 'N')
    local pts = {}
    for i = 1, #HALF do pts[#pts + 1] = { cx + (HALF[i][1] - cx) * s * 0.62, 36 + (HALF[i][2] - 36) * s } end
    for i = #HALF, 1, -1 do pts[#pts + 1] = { cx - (HALF[i][1] - cx) * s * 0.62, 36 + (HALF[i][2] - 36) * s } end
    pts[#pts + 1] = pts[1]
    d:wire(pts, ch, nil, 0.5, 'kY')
  end
  -- o casulo pende da sombra como pêndulo (ela não): cada linha desliza conforme a distância dos pés
  local A = still and 0 or 1.4 * sin(tt)
  if o.lean then A = -1.8 + 0.6 * sin(tt) end
  for y = 0, g.h - 1 do
    local v = (y - d.oy - (k - 1) / 2) / k
    local dx = floor(A * k * max(0, v - 19) / 36 + 0.5)
    for x = 0, g.w - 1 do
      local c = d.g[y][x]
      if c ~= '.' then L.set(g, x + dx, y, c) end
    end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- poeira de crepúsculo em volta: sobe e some
  for n = 1, 26 do
    local a = rad(n * 67)
    local r = (ph + n) % NL
    if r < NL - 1 then
      Sh.spark(ds, sg, cx + cos(a) * (15 + (n * 13) % 9) * 1.5, 34 + sin(a) * (17 + (n * 7) % 9) - r * 0.8, n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'K'))
    end
  end
end

Sh.run {
  name = 'shade_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, NOPULL = NOPULL,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'UYMN', fill = 'k', mid = 'Y', edge = 'U' },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- busto: a sombra, os pés e a fresta, em escala 3
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust, o.ox, o.oy = true, -32, -8
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 22, 36 }, green = { 26, 50 }, water = { 35, 27 }, residential = { 35, 38 }, lit = { 28, 53 },
    sacred = { 21, 42 }, crimson = { 23, 27 },
  },
}
