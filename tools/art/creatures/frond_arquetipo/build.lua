-- Arquétipo da família Frond (nome e pasta provisórios: frond_arquetipo), arte final a partir do conceito aprovado da
-- rodada 2. Só aparece em evento e Incursão.
-- A fronde de pé, de pedra, grande demais. Está errada de três jeitos: os lobos se espelham (a Charnia nunca se
-- espelha), crescem para a ponta em vez de afinar, e o báculo abriu em dois, um para cada lado. O talo não existe: no
-- lugar dele, o vão, de cima a baixo, e dentro dele a mesma fronde se repete, menor, e outra dentro dela. Embaixo, o
-- disco de fixação é um caco de calçada em cima de raízes finas demais para o peso.
-- REGRAS QUEBRADAS: geometria, a fronde inteira dentro do próprio talo (as de dentro nascem do tamanho da de fora,
-- encolhem e afundam sem parar); física, mais pesada em cima do que as raízes aguentam, e não tomba: o corpo todo
-- pende de um lado para o outro sobre cinco fios de raiz que tremem.
-- Sem costura do Véu: o vão. No corpo ele é a fenda escura; o violeta vai só no glow (a borda e o xadrez que rareia
-- para o eixo), e as frondes de dentro acendem em violeta, depois na luz do tipo.
-- Camadas: corpo; leds = o broto na ponta de cada nervura (pisca); glow = as nervuras, os báculos, o vão e os esporos.
-- Retrato: composição própria, um busto de 128 (escala 3): os dois báculos, os lobos de cima e o vão, cortado num
-- rasgo embaixo.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/frond_arquetipo/build.lua')
local Fr = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_frond.lua')
local L, R = Fr.L, Fr.R
local abs, sin, cos, rad, floor = math.abs, math.sin, math.cos, math.rad, math.floor
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Fr)
RT.install(Fr.LEG, Fr.LIT)
-- o retrato nativo: o vão com fundo, pedra com poros e trincas, folha seca em fios; a borda recortada pela nervura
local RETRATO = {
  vao = { seed = 'QW', set = 'kQW', keep = 'UZ', depth = 5, star = { 'U', 'Z' }, sky = 75 },
  light = { ramps = { { '4321', RT.tex.stone(0.3) }, { 'nNM', RT.tex.fur(1, -0.45, 0.3, 5) }, { 'abcde', RT.tex.fur(1, -0.45, 0.25, 4) },
      { 'JjiI', RT.tex.pit(0.35) }, { 'qpo' } },
    lights = 'BDEHG', lw = 0.28, R = 7, rim = { 'D', 'B' } },
}

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t = fr * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dyp = o.dy or 0                                       -- o corpo sobe e desce; as raízes ficam
  local ox, oy = o.ox or 0, o.oy or 0
  local SOL = Fr.SOLID
  local cx = 31.5
  local d = R.ctx(g.w, k, ox, oy + dyp)                       -- o corpo, numa grade própria (depois ele pende)
  local p = o.bust and 1 or d:pp()
  local lift = alert and -1.4 or (crouch and 1.6 or 0)        -- os lobos erguem no alerta e caem encolhidos
  local curl = alert and 26 or (crouch and 33 or 30 + 1.5 * sin(t))   -- os báculos enrolam e soltam
  local buds = {}
  d:layer(function(q)
    for i = 0, 6 do                                           -- os lobos, de baixo para cima, crescendo
      local y0, len, w = 46.6 - i * 4.5, 6.5 + i * 1.5, 2.4 + i * 0.16
      local ex = cx - 2 - len * 0.92
      local ey = y0 - len * 0.42 + lift * (0.4 + i * 0.1) + (still and 0 or 0.7 * sin(t + i * 0.9))
      q:cap(cx - 2.4, y0, (cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.4, w * 0.8, w, function(x, y, u, v)
        local s = ((u - cx) * 0.92 + (v - y0) * -0.42)
        if floor(s * 1.1) % 3 == 0 then return v > y0 - len * 0.2 and '4' or '3' end   -- os lobinhos
        return R.pick(i == 5 and 'nnNM' or '4321', 0.75 - (v - (y0 - len * 0.45)) / (w * 2.4), R.noise(p, 3 + i)(x, y))
      end)
      q:cap((cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.4, ex, ey, w, 0.5, function(x, y, u, v)
        local s = ((u - cx) * 0.92 + (v - y0) * -0.42)
        if floor(s * 1.1) % 3 == 0 then return i == 6 and ((x + y) % 2 == 0 and 'b' or 'c') or (i == 4 and ((x + y) % 2 == 0 and 'J' or 'j') or '3') end
        return R.pick(i == 5 and 'nnNM' or '4321', 0.8 - (v - ey) / (w * 2.2), R.noise(p, 3 + i)(x, y))
      end)
      q:wire({ { cx - 3.4, y0 - 0.4 }, { (cx - 2 + ex) / 2, (y0 + ey) / 2 - 0.6 }, { ex + 1.6, ey + 0.4 } }, 'D',
        (i + ph) % 2 == 0 and 'E' or 'B', 0.5)                -- a nervura acesa: a luz troca de lobo a cada quadro
      buds[#buds + 1] = { ex + 1.6, ey + 0.4 }
    end
    -- o báculo, um de cada lado
    local pts = {}
    for n = 0, 15 do
      local a = rad(20 - n * curl)
      local r = 6.6 - n * 0.36
      pts[#pts + 1] = { cx - 9.6 + cos(a) * r, 10.6 + sin(a) * r * 0.86 }
    end
    table.insert(pts, 1, { cx - 2.6, 17.6 })
    q:wire(pts, 'p', 'o', 1.5)
    q:wire(pts, 'D', 'E', 0.5)
    for _, b in ipairs(buds) do q:wire({ b, b }, 'G', nil, 0.5) end
    -- o disco de fixação: um caco de calçada, com a junta acesa
    q:poly({ { cx - 9, 49.6 }, { cx, 48.6 }, { cx, 53.6 }, { cx - 7.6, 53 } }, R.mat('JjiI', R.noise(p, 5), function(_, v) return 0.9 - (v - 48.6) / 5 end))
    q:wire({ { cx - 6, 49.6 }, { cx - 4.4, 51.4 }, { cx - 5, 53 } }, 'B', 'D', 0.5)
    q:mirror(cx)
  end, SOL)
  -- o vão: a fenda no lugar do talo. No corpo é escura (k); a borda e o xadrez acendem em violeta no glow
  local function slit(u, v)
    local q = (v - 32.6) / 18
    if abs(q) >= 1 then return nil end
    local tt = abs(u - cx) / (3 * (1 - q * q) ^ 0.6 + 0.01)
    return tt <= 1 and tt or nil
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local tt = slit((x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k)
    if tt then
      local ch = 'k'
      if tt > 0.62 then ch = 'Q'
      elseif tt > 0.3 and (x // p + y // p) % 2 == 0 then ch = 'W'
      elseif tt > 0.12 and (x // p) % 2 == 0 and (y // p) % 2 == 0 then ch = 'W' end
      d.g[y][x] = ch
    end
  end end
  -- a mesma fronde, para dentro: cada uma nasce do tamanho da de fora, encolhe e afunda no eixo
  for lv = 0, 3 do
    local q = lv - 1 + (still and 0 or fr)
    local f = 0.5 * 0.52 ^ q
    local ch = q < 0.5 and (o.bust and '!' or 'Q') or (q < 1.5 and 'U' or 'Z')
    for i = 0, 6 do
      local y0, len = 32.6 + (46.6 - i * 4.5 - 32.6) * f, (6.5 + i * 1.5) * f * 0.42
      for _, sd in ipairs({ -1, 1 }) do
        d:wire({ { cx, y0 }, { cx + sd * len, y0 - len * 0.6 } }, ch, nil, 0.5, 'kQW')
      end
    end
  end
  for _, y in ipairs({ 20.6, 30.6, 40.6 }) do                 -- três lobinhos de pedra ainda atravessam o vão
    d:wire({ { cx - 3.6, y }, { cx, y + 1.2 }, { cx + 3.6, y } }, '3', '2', 0.5)
  end
  -- as raízes: finas demais; os joelhos tremem
  local dr = R.ctx(g.w, k, ox, oy + (o.jump and dyp or 0)); dr.g = g
  dr:layer(function(q)
    local top = 52 + (o.jump and 0 or dyp / k)
    for i = -2, 2 do
      local kn = still and 0 or 0.5 * sin(2 * t + i * 1.7)
      local st = o.lean and 1.1 * sin(t + i * 1.3) or 0
      q:wire({ { cx + i * 2.4, top }, { cx + i * 4.6 + kn + st * 0.5, 56 }, { cx + i * 5.2 + (i % 2) + st, 60.4 } }, 'p', 'q', 0.7)
    end
  end, SOL)
  -- o corpo pende sobre as raízes (e não tomba): cada linha desliza conforme a altura acima do caco
  local A = still and 0 or 1.5 * sin(t)
  if o.lean then A = -1.6 + 0.8 * sin(t) end
  for y = 0, g.h - 1 do
    local v = (y - d.oy - (k - 1) / 2) / k
    local dx = floor(A * k * math.max(0, 52 - v) / 46 + 0.5)
    for x = 0, g.w - 1 do
      local c = d.g[y][x]
      if c ~= '.' then L.set(g, x + dx, y, c) end
    end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- esporos soltos: sobem e somem
  local sz = d:th(0.6)
  for n = 0, 21 do
    local r = (ph + n) % NL
    local x, y = floor(d:X(3 + (n * 31) % 59)), floor(d:Y(3 + (n * 17) % 58 - r * 0.7))
    if r < NL - 1 then
      for j = 0, sz - 1 do for i = 0, sz - 1 do
        if L.get(g, x + i, y + j) == '.' and y + j > 0 and y + j < g.h - 1 and x + i > 0 and x + i < g.w - 1 then
          L.set(sg, x + i, y + j, n % 3 == 0 and 'T' or (n % 3 == 1 and 'S' or 's'))
        end
      end end
    end
  end
end

Fr.run {
  name = 'frond_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, DARK = '4', ownLean = true,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'QWUZ', fill = 'k', mid = 'W', edge = 'Q' },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- busto: os dois báculos, os lobos de cima e o vão, em escala 3
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust, o.ox, o.oy = true, -31, -8
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 29, 43 }, green = { 26, 49 }, water = { 28, 23 }, residential = { 28, 33 }, lit = { 28, 38 },
    sacred = { 28, 5 }, crimson = { 30, 28 },
  },
}
