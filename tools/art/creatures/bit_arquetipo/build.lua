-- Arquétipo da família Bit (nome e pasta provisórios: bit_arquetipo), arte final a partir do conceito aprovado. Só
-- aparece em evento e Incursão.
-- O pombo de perfil, grande demais e fora de registro. O corpo está em fatias, cada uma num lugar, e nada as segura;
-- a cabeça está em três lugares do mesmo balanço ao mesmo tempo (a ave, a varredura, só a matriz); pernas e caudas a
-- mais. No peito a imagem não fecha: o vão é um recorte aberto para a frente, e dentro dele está o mesmo pombo
-- inteiro, menor, e outro dentro dele.
-- REGRAS QUEBRADAS: física, as fatias ficam fora do lugar sem nada que as segure; geometria, o pombo inteiro dentro
-- do próprio peito (os de dentro nascem do tamanho do de fora, encolhem e afundam sem parar).
-- Sem costura do Véu: o vão. No corpo ele é escuro (O); o violeta vai só no glow (a borda do recorte, o pontilhado e
-- o primeiro pombo de dentro), e os pombos mais fundos acendem na luz do tipo.
-- Camadas: corpo; leds = os subpixels do pescoço da ave (piscam); glow = a cabeça de matriz, a franja das fatias, o
-- vão com os pombos de dentro e o pixel solto.
-- Animação (6 quadros, lenta): as fatias respiram cada uma no seu passo, as três cabeças balançam uma depois da
-- outra, os pombos de dentro afundam e o laço fecha. O vão segue as regras do K.run (_hum.lua).
-- Retrato: o pombo inteiro dentro da moldura, desenhado em 128 (escala 1,8, margem de 6 px), com o _retrato.lua.
-- Pés e pernas sem contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/bit_arquetipo/build.lua')
local B = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_bit.lua')
local L = B.L
local floor, max, abs, sin, cos, rad, pi = math.floor, math.max, math.abs, math.sin, math.cos, math.rad, math.pi
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(B)
RT.install(B.LEG, B.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'XY', set = 'OXY', keep = 'UV', depth = 6, star = { 'U', 'V' }, sky = 15 },
  light = { ramps = { { 'abcde' } }, lights = 'GPQR', lw = 0.2, R = 6, blur = 0, rim = { 'P', 'Q' }, rimR = 4 },
}

local TEARS = { { 9, 13, -4 }, { 15, 19, 4 }, { 23, 27, -4 }, { 42.5, 46.6, 5, true }, { 47, 51, -3, true } }
local BOB = { [0] = 0, -0.5, -0.9, -0.5, 0, 0 }
local A1, A2 = { 30.1, 26.6 }, { 38.1, 32 }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t6 = fr * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = (o.dy or 0) - all + (crouch and k or 0)
  oy = oy + all
  local s = 1.9 * k
  local function Y(v) return v * k + (k - 1) / 2 + oy end
  local function bob(n) return still and 0 or BOB[floor((ph - n) % NL * 6 / NL)] end
  B.layer(g, function(t)
    B.pigeon(t, s, 2.5 * k + ox, 6 * k + oy, { by = by, roll = still and 0 or ph, tails = { 0, 1.6, 3 }, legs = { 10.4, 12.8, 15.4, 17.6 },
      step = o.lean and { sin(t6), sin(t6 + 1.6), sin(t6 + 3.1), sin(t6 + 4.7) } or nil,
      heads = { { 21.4, 12.6, 25.6, 7.6, 'led', bob(0) }, { 20, 12, 21.6, 3.8, 'scan', bob(1) }, { 18.4, 12, 17.6, 7.4, nil, bob(2) } } })
  end, o.dark and '' or nil)
  -- as fatias: cada uma respira no seu passo
  local amp = alert and 1.25 or (crouch and 0.4 or nil)
  for n, q in ipairs(TEARS) do
    local f = amp or (0.75 + 0.25 * sin(t6 + n * 1.7))
    local lift = q[4] and 0 or by                                -- as fatias das pernas ficam no chão
    B.tear(g, Y(q[1]) + lift, Y(q[2]) + lift, floor(q[3] * k * f + 0.5))
  end
  -- o vão: um recorte no peito, aberto para a frente
  local function inside(x, y)
    local u, v = (x - ox - (k - 1) / 2) / k, (y - oy - by - (k - 1) / 2) / k
    if u < 28.5 or v < 28.5 or v > 41.5 then return nil end
    return max(abs(v - 35) / 6.5, 1 - (u - 28.5) / 4)
  end
  for y = 0, S - 1 do for x = 0, S - 1 do
    local tt = inside(x, y)
    if tt and g[y][x] ~= '.' then
      g[y][x] = tt > 0.86 and 'X' or ((x % 2 == 0 and y % 2 == 0) and 'Y' or 'O')
    end
  end end
  -- o mesmo pombo, para dentro: cada um nasce do tamanho do de fora, encolhe e afunda
  for lv = 0, 2 do
    local q = lv - 1 + (still and 0 or fr)
    local sc = 0.56 * (0.26 / 0.56) ^ q
    local t = L.grid(S, S)
    B.pigeon(t, sc * k, (A1[1] + (A2[1] - A1[1]) * q) * k + ox, (A1[2] + (A2[2] - A1[2]) * q) * k + oy + by)
    local ch = q < 0.5 and (o.bust and '!' or 'X') or (q < 1.5 and 'U' or 'V')
    for y = 1, S - 2 do for x = 1, S - 2 do
      if t[y][x] ~= '.' and inside(x, y) and (g[y][x] == 'O' or g[y][x] == 'Y') then
        if t[y][x - 1] == '.' or t[y][x + 1] == '.' or t[y - 1][x] == '.' or t[y + 1][x] == '.' then g[y][x] = ch end
      end
    end end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  local n = max(1, floor(k * 0.6 + 0.5))
  for i = 1, 24 do                                                -- pixels soltos em volta: piscam
    if (i + ph) % 3 ~= 0 then
      local a = rad(i * 67)
      local x, y = floor((31 + cos(a) * (27 + (i * 5) % 4)) * k + ox), floor((33 + sin(a) * (24 + (i * 7) % 6)) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < S - 1 and y + dy < S - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = ({ 'p', 'y', 't' })[i % 3 + 1]
        end
      end end
    end
  end
end

B.run {
  name = 'bit_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, NOPULL = B.NOPULL .. 'ij', DARK = '2',
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'XYUV', fill = 'O', mid = 'Y', edge = 'X' },
  -- o pombo inteiro, em 128: escala 1,8, margem de 6 px
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.8, o, 6.4, 5.4)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 14, 34 }, green = { 10, 37 }, water = { 12, 31 }, residential = { 12, 33 }, lit = { 12, 36 },
    sacred = { 34, 2 }, crimson = { 20, 30 },
  },
}
