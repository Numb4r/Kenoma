-- Arquétipo da família Clod (nome e pasta provisórios: clod_arquetipo), arte final a partir do conceito aprovado
-- (rodada3/arquetipos.png). Só aparece em evento e Incursão.
-- O tatu de perfil, partido no meio. Os dois escudos são osso e andam juntos, mas as três cintas que os uniam não
-- estão: no lugar delas, o vão, em ampulheta, e dentro dele as cintas se repetem, cada vez menores, sem chegar ao
-- fundo. As patas (demais) e as placas encolhem na direção do vão; a cabeça é um escudo pequeno demais, sem rosto, e
-- as garras são grandes demais.
-- REGRAS QUEBRADAS: física, as metades andam sem estar ligadas (cada uma sobe e desce no seu quadro) e o cascalho
-- cai de lado, para dentro do vão; geometria, as cintas não chegam ao fundo.
-- Sem costura do Véu: o vão. No corpo ele é escuro (O); o violeta vai só no glow (a borda, o pontilhado e a primeira
-- fileira de cintas de dentro), e as cintas mais fundas acendem na luz do tipo.
-- Camadas: corpo; leds = nada (não tem olho); glow = as juntas das placas perto do vão, o vão e o cascalho solto.
-- Animação (6 quadros, lenta): a metade de trás sobe e desce com o body_dy e a da frente um quadro depois; as cintas
-- de dentro afundam e o laço fecha; o cascalho cai dos dois lados para o vão. O vão segue as regras do K.run.
-- Retrato: o tatu inteiro dentro da moldura, desenhado em 128 (escala 1,85, margem de 5 px), com o _retrato.lua.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/clod_arquetipo/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_clod.lua')
local L, R = C.L, C.R
local floor, abs, min, max, sin, pi = math.floor, math.abs, math.min, math.max, math.sin, math.pi
local stone = C.stone
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(C)
RT.install(C.LEG, C.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'Xx', set = 'OXx', keep = 'UV', depth = 5, star = { 'U', 'V' }, sky = 80 },
  light = { ramps = { { '9876', RT.tex.stone(0.16) } }, lights = 'JYH', lw = 0.22, R = 6, blur = 0, rim = { 'J', 'H' }, rimR = 4 },
}

local GX = 30.5
local LEGS = { 11.5, 21, 40, 50 }
local DYN = { [0] = 0, 0, -1, -1, -1, 0 }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t6 = fr * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local d = R.ctx(S, k, ox, oy + (o.jump and (o.dy or 0) or 0)); d.g = g
  local p = d:pp()
  local function plates(x, y, u, v)
    local near = 1 - min(1, abs(u - GX) / 16)                       -- perto do vão: placa menor, junta acesa
    local sh = (v - 30) / 16
    local s = (3.6 - 2 * near) * k
    local _, e = C.vor(x, y, s, 13)
    if v > 41.4 then return R.pick('098', 0.3, R.ver(p)(x, y)) end   -- a barra de escudos da borda
    if e < 0.3 * k then return near > 0.2 and (near > (alert and 0.5 or 0.62) and 'Y' or 'J') or (sh > 0.3 and '0' or '9') end
    return stone(x, y, s, 13, sh > 0.45 and C.BONED or C.BONE, nil, 0, k)
  end
  local function st(n) return o.lean and 0.9 * sin(t6 + n * 1.6) or 0 end
  d:layer(function(t)                                               -- patas do lado de lá
    for n, x in ipairs(LEGS) do t:cap(x + 3, 43, x + 3.4 - st(n), 48.6, 1.5, 1.1, R.mat('098', R.hor(p), 0.3)) end
  end, o.dark and '' or C.SOLID)
  d:layer(function(t)
    t:cap(7.6, 40.6, 1.6, 48, 1.7, 0.5, R.mat('098', R.hor(p), 0.5))  -- rabo
    t:ell(30, 44, 25, 23.5, plates)                                 -- a carapaça inteira; o vão é aberto depois
    for y = 0, S - 1 do for x = 0, S - 1 do                         -- corta a barriga reta
      if (y - t.oy - (k - 1) / 2) / k > 43.6 then t.g[y][x] = '.' end
    end end
    t:rect(7, 43.6, 53, 44.4, R.mat('f5', R.ver(p), 0))
    -- a cabeça: um escudo pequeno demais, sem rosto, duas orelhas
    t:ell(56.4, 33.8, 1, 2.4, '8'); t:ell(54.2, 33.6, 1, 2.4, '7')
    t:cap(54.6, 38.6, 60.8, 44.6, 2.9, 0.9, function(x, y, u, v)
      if u > 60.2 then return '0' end
      if v > 40.2 + (u - 54.6) * 0.75 then return R.pick('987', 0.4, R.noise(p, 4)(x, y)) end
      return stone(x, y, 1.5 * k, 11, C.BONE, '0', 0.25 * k, k)
    end)
    for n, x in ipairs(LEGS) do                                     -- patas de cá, com garras de cavar grandes demais
      local sx = st(n)
      t:cap(x, 44, x + 0.5 + sx, 49, 2, 1.5, R.mat('987', R.hor(p), 0.5))
      for c = -1, 1 do
        t:cap(x + 0.5 + sx + c * 1.3, 49.4, x + 2.6 + sx + c * 2.2, 55.4, 0.9, 0.3, R.mat('DC', R.ver(p), 0))
      end
    end
  end, o.dark and '' or C.SOLID)
  -- o vão entre os escudos, em ampulheta
  local wide = alert and 1.25 or (crouch and 0.7 or 1)
  local function gap(u, v)
    if v < 19.6 or v > 43.6 then return nil end
    local w = (3.6 + 4.4 * abs((v - 33) / 13) ^ 1.6) * wide
    local t = abs(u - GX) / w
    return t <= 1 and t or nil
  end
  for y = 0, S - 1 do for x = 0, S - 1 do
    local t = gap((x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k)
    if t and g[y][x] ~= '.' then
      g[y][x] = t > 0.66 and 'X' or ((t > 0.25 and (x + y) % 2 == 0) and 'x' or 'O')
    end
  end end
  -- as cintas que faltam: repetidas para dentro, cada vez menores; afundam sem chegar ao fundo
  for lv = 0, 3 do
    local q = lv - 1 + (still and 0 or fr)
    local f = 0.62 * 0.56 ^ q
    local ch = q < 0.5 and (o.bust and '!' or 'X') or (q < 1.5 and 'U' or 'V')
    for n = -1, 1 do
      local y = 33 + n * 8 * f
      d:wire({ { GX - 3.4 * f, y - 1.2 * f }, { GX, y + 1.4 * f }, { GX + 3.4 * f, y - 1.2 * f } }, ch, nil, 0.5, 'Ox')
    end
  end
  for _, y in ipairs({ 21.6, 32, 42.6 }) do                        -- três fios de osso, o que sobrou delas
    local w = 3.9 + 4.4 * abs((y - 33) / 13) ^ 1.6
    d:wire({ { GX - w - 1, y }, { GX - w * 0.4, y + 1.6 }, { GX + w * 0.4, y + 1.6 }, { GX + w + 1, y } }, '7', '6', 0.5)
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- as metades andam sem estar ligadas: a de trás sobe com o body_dy, a da frente um quadro depois
  if not o.jump and not still then
    local idx = floor(ph * 6 / NL)
    local dl, dr = DYN[idx], DYN[(idx - 1) % 6]
    if o.portrait then dl, dr = (o.dy or 0), ({ [0] = -1, 0, -1, -2 })[ph] end
    local xs = floor(d:X(GX))
    local out = L.grid(S, S)
    for y = 0, S - 1 do for x = 0, S - 1 do
      if g[y][x] ~= '.' then L.set(out, x, y + (x < xs and dl or dr), g[y][x]) end
    end end
    for y = 0, S - 1 do for x = 0, S - 1 do g[y][x] = out[y][x] end end
  end
  -- o cascalho cai de lado, para dentro do vão
  local n1 = max(1, floor(k * 0.6 + 0.5))
  for n = 0, 21 do
    local s = n % 2 == 0 and -1 or 1
    local r = 7 + C.rnd(n, 5, 8) * 24 - ((ph + n) % NL) * 1.4
    local v = 3 + C.rnd(n, 7, 8) * 14 + r * 0.12
    if r > 5 then
      local x, y = floor((GX + s * r) * k + ox), floor(v * k + oy)
      for dy = 0, n1 - 1 do for dx = 0, n1 - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < S - 1 and y + dy < S - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = n % 3 == 0 and 's' or 'S'
        end
      end end
    end
  end
end

C.run {
  name = 'clod_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, DARK = '0',
  BODY_KEYS = { '6', '7', '8', '9', '0', '1', '2', '3', '4', '5', 'f', 'C', 'D' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'XxUV', fill = 'O', mid = 'x', edge = 'X' },
  -- o tatu inteiro, em 128: escala 1,85, margem de 5 px
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.85, o, 4.8, -4)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 12, 30 }, green = { 9, 33 }, water = { 11, 28 }, residential = { 11, 29 }, lit = { 11, 32 },
    sacred = { 12, 16 }, crimson = { 15, 30 },
  },
}
