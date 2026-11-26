-- Arquétipo da família Wisp (nome e pasta provisórios: wisp_arquetipo), arte final a partir do conceito aprovado: a
-- procissão. Só aparece em evento e Incursão.
-- Três mantos vazios em roda, cada um entrando pelo capuz do seguinte; no meio, o disco de penas de cinza de uma cara
-- que não tem olhos nem bico: no lugar deles, o vão. Nove tocos de vela cravados na borda do vão, com a chama virada
-- para dentro, fazem dele um olho de vela só (o traço da família, e ele funciona como olho). Três pernas penduradas
-- que não tocam nada, tiras de mortalha acesas na ponta, e uma roda de chamas soltas em volta.
-- REGRAS QUEBRADAS: geometria, o manto é um pano só, sem lado de dentro (cada manto entra pelo capuz do seguinte e o
-- último entra no primeiro); física, não existe "para cima": toda chama, em qualquer ponto do quadro, aponta para o vão.
-- Sem costura do Véu: o vão. No corpo ele é escuro (v, mais escuro que o contorno); o violeta vai só no glow: o aro
-- junto das chamas e o xadrez que rareia para o fundo.
-- Camadas: corpo; leds = as nove chamas do olho (piscam); glow = as chamas dos capuzes e das tiras, o violeta do vão
-- e a roda de chamas soltas.
-- Animação: a procissão anda (os três capuzes dão um terço de volta por laço, e o laço fecha); o disco e os tocos
-- giram devagar, a roda de chamas gira ao contrário, o aro do vão respira, as tiras e as pernas balançam fora de fase.
-- Ela não toca o chão: o body_dy é o corpo inteiro, e só desce (em cima não há folga com os capuzes girando).
-- Retrato: composição própria, um busto de 128 (escala 3): o olho de vela ocupa o quadro, com os capuzes, as pernas e
-- as tiras entrando cortados num rasgo em volta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wisp_arquetipo/build.lua')
local Wi = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wisp.lua')
local L = Wi.L
local floor, ceil, sqrt, min, max, sin, cos, rad = math.floor, math.ceil, math.sqrt, math.min, math.max, math.sin, math.cos, math.rad
local pick = Wi.pick

local STRIPS = { { 152, 17 }, { 134, 24 }, { 116, 14 }, { 98, 27 }, { 82, 19 }, { 64, 25 }, { 46, 15 }, { 28, 21 } }
local LEGS = { { -5.4, 10.6, 21 }, { 0, 12, 28 }, { 5.4, 10.6, 23 } }
local NOCLAW = Wi.SOLID:gsub('[67]', '')
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Wi)
RT.install(Wi.LEG, Wi.LIT)
-- o retrato nativo: o vão com fundo, pano em trama, pena de cinza em fios, cera lisa; a borda recortada pelas chamas
local RETRATO = {
  vao = { seed = 'QW', set = 'vQW', keep = 'FGH', depth = 13, star = { 'D', 'E' }, sky = 20 },
  light = { ramps = { { 'rtu', RT.tex.weave(0.2) }, { '876', RT.tex.fur(1, 0.6, 0.28, 5) }, { '123' }, { 'fl' } },
    lights = 'BDEFGH', lw = 0.32, R = 9, blur = 1, rim = { 'D', 'B' } },
}

local function draw(g, sg, k, o)
  local X, Y = Wi.scale(k, o.ox, o.oy)
  local p = o.bust and 1 or Wi.pp(k)
  local ck = Wi.chk(p)
  Wi.flat = o.dark
  local NL = o.portrait and 4 or 8
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t = fr * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local cx, cy = 31.5, 27 + (o.dy or 0) / k
  local x0, y0 = X(cx), Y(cy)
  local turn = still and 0 or fr
  local spin = o.portrait and 0 or turn * 120                 -- a procissão anda
  local rr = crouch and 16.2 or 17.5
  local fg = alert and 1.4 or (crouch and 0.7 or 1)
  local function cloth(x, y)
    local an = math.atan(y - y0, x - x0) - rad(spin)
    local st = floor(an / (math.pi / 26) + (y - y0) / (3 * k)) % 2 == 0
    if k > 1 and not st then st = (x + y) % 2 == 0 end          -- no retrato, a trama do pano
    return pick('rtu', 0.5 - 0.3 * (x - x0) / (20 * k) - 0.3 * (y - y0) / (20 * k), st)
  end
  local function toC(x, y) return math.deg(math.atan(cy - y, cx - x)) end
  -- tiras da mortalha, penduradas do anel, com a ponta acesa
  Wi.layer(g, function(q)
    for n, s in ipairs(STRIPS) do
      local a = rad(s[1])
      local sx, sy = cx + cos(a) * rr, cy + sin(a) * rr
      local ey = min(cy + 31, sy + s[2])
      local ex = sx + ((n % 3) - 1) * 1.4 + (still and 0 or 0.9 * sin(t + n * 1.9)) - (o.lean and 2 or 0)   -- na deriva ficam para trás
      Wi.cap(q, X(sx), Y(sy), X(ex), Y(ey), 2 * k, 0.8 * k, function(x, y) return pick('rtu', 0.3, floor((y + x * 0.3) / p) % 2 == 0) end)
      Wi.flame(q, X(ex), Y(ey), toC(ex, ey), 4 * fg * k, 2 * k, 'BDE')
    end
  end)
  -- o anel de pano e os três capuzes
  Wi.layer(g, function(q)
    for an = 0, 359, 2 do
      local a = rad(an)
      local r2 = 2.5 + 0.7 * sin(rad((an - spin) * 3 + 40))
      Wi.ell(q, X(cx + cos(a) * rr), Y(cy + sin(a) * rr), r2 * k, r2 * k, cloth)
    end
    for i = 0, 2 do
      local a = rad(-90 + i * 120 - 14 + spin)
      local hx, hy = cx + cos(a) * (rr + 0.5), cy + sin(a) * (rr + 0.5)
      local tx, ty = -sin(a), cos(a)
      -- capuz: bojo e bico para trás
      Wi.ell(q, X(hx), Y(hy), 6.2 * k, 6.2 * k, cloth)
      Wi.poly(q, { { X(hx - tx * 3 + cos(a) * 5.4), Y(hy - ty * 3 + sin(a) * 5.4) }, { X(hx - tx * 11 + cos(a) * 4), Y(hy - ty * 11 + sin(a) * 4) },
        { X(hx - tx * 5 - cos(a) * 3.6), Y(hy - ty * 5 - sin(a) * 3.6) } }, cloth)
      -- a boca do capuz, virada para o seguinte, e o manto de trás entrando por ela
      Wi.ell(q, X(hx + tx * 2.4), Y(hy + ty * 2.4), 3.8 * k, 4.4 * k, 'k')
      Wi.cap(q, X(hx + tx * 7.4), Y(hy + ty * 7.4), X(hx + tx * 2), Y(hy + ty * 2), 2.4 * k, 0.5 * k, cloth)
      Wi.flame(q, X(hx + tx - cos(a) * 1.4), Y(hy + ty - sin(a) * 1.4), toC(hx, hy), 5 * fg * k, 2.4 * k, 'BDE')
    end
  end)
  -- pernas penduradas (as garras ficam sem contorno)
  Wi.layer(g, function(q)
    for n, c in ipairs(LEGS) do
      local sx = (still and 0 or 0.7 * sin(t + n * 2.1)) - (o.lean and 1.4 or 0)
      local ex, ey = cx + c[1] * 1.1 + sx, cy + c[3]
      Wi.wire(q, { { X(cx + c[1]), Y(cy + c[2]) }, { X(cx + c[1] * 1.15 + sx * 0.5), Y((cy + c[2] + ey) / 2) }, { X(ex), Y(ey) } }, 'l', 'f', Wi.th(k, 0.8))
      for _, d in ipairs({ { -1.8, 1.4 }, { 0, 2 }, { 1.8, 1.4 } }) do
        Wi.wire(q, { { X(ex), Y(ey) }, { X(ex + d[1]), Y(ey + d[2]) }, { X(ex + d[1] * 0.7), Y(ey + d[2] + 1) } }, '6', '7', Wi.th(k, 0.5))
      end
    end
  end, NOCLAW)
  -- o disco de penas de cinza em volta do vão
  Wi.layer(g, function(q)
    for y = max(0, floor(y0 - 14 * k)), min(g.h - 1, ceil(y0 + 14 * k)) do
      for x = max(0, floor(x0 - 14 * k)), min(g.w - 1, ceil(x0 + 14 * k)) do
        local rx, ry = (x - x0) / k, (y - y0) / k
        local r2 = sqrt(rx * rx + ry * ry)
        local st = floor((math.atan(ry, rx) - turn * math.pi / 11) / (math.pi / 22)) % 2 == 0
        if r2 >= 6.4 and r2 <= 12.4 + (st and 0.9 or 0) then
          local tone = st
          if k > 1 and not st then tone = (x + floor(r2 * k / 2)) % 2 == 0 end   -- no retrato, as barbas da pena
          local ch = pick('876', 0.75 - (r2 - 6.4) / 6.4 * 0.6 + 0.2 * Wi.lum(x, y, x0, y0, 13 * k, 13 * k), tone)
          if r2 > 9 and r2 < 10 and not st then ch = '8' end
          q[y][x] = ch
        end
      end
    end
    -- o olho de vela: tocos presos na borda do vão, a chama virada para dentro
    for n = 0, 8 do
      local a = n * 40 + 12 + turn * 40
      local ca, sa = cos(rad(a)), sin(rad(a))
      Wi.cap(q, X(cx + ca * 9.6), Y(cy + sa * 9.6), X(cx + ca * 7.4), Y(cy + sa * 7.4), 1.1 * k, 0.9 * k, function(x, y) return pick('123', n % 2, ck(x, y)) end)
      Wi.flame(q, X(cx + ca * 7.4), Y(cy + sa * 7.4), a + 180, ((o.bust and 4.3 or 3.5) * fg + (still and 0 or 0.5 * sin(t + n * 2.4))) * k, 1.8 * k, 'FGH')
    end
  end)
  -- o vão: escuro no corpo; o aro e o xadrez acendem em violeta no glow
  local th = Wi.th(k, 1)
  local edge = (o.bust and 2.8 or 3.3) + (still and (alert and -0.6 or 0.6) or 0.5 * sin(t))
  for y = max(0, floor(y0 - 8 * k)), min(g.h - 1, ceil(y0 + 8 * k)) do
    for x = max(0, floor(x0 - 8 * k)), min(g.w - 1, ceil(x0 + 8 * k)) do
      local r2 = sqrt((x - x0) ^ 2 + (y - y0) ^ 2) / k
      local c = g[y][x]
      if r2 < 6.4 then
        if not ('FGH'):find(c, 1, true) then
          local ch = 'v'
          if r2 > edge then ch = 'Q' elseif r2 > 1 and (x // th + y // th + ph) % 2 == 0 then ch = 'W' end
          g[y][x] = ch
        end
      elseif r2 < 6.4 + 1 / k and c ~= '.' and not ('123FGH'):find(c, 1, true) and not o.dark then g[y][x] = 'A' end
    end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- a roda de chamas soltas (só no glow), todas viradas para o vão; gira ao contrário da procissão
  for n = 0, 20 do
    local a = rad(n * 360 / 21 + 8 - turn * 360 / 7)
    local r2 = 26 + (n % 3) * 1.6
    local x, y = cx + cos(a) * r2, cy + sin(a) * r2 * 0.92
    if o.bust or (y < cy + 34 and y > 3 and x > 3 and x < 60) then
      Wi.flame(sg, X(x), Y(y), toC(x, y), 5 * fg * k, 2.5 * k, 'TSs')
    end
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' then sg[y][x] = '.' end
  end end
end

Wi.run {
  name = 'wisp_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, DARK = 'r', NOPULL = Wi.NOPULL .. '67',
  nloop = 8, dy = { 0, 0, 1, 1, 1, 1, 0, 0 }, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, 0, 0, 0 },
  vao = { lit = 'QW', fill = 'v', mid = 'W', edge = 'Q', extra = 'FGH' },
  -- busto: o olho de vela em escala 3, um pouco acima do meio
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust, o.ox, o.oy = true, -31.5, -22
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 29, 34 }, green = { 26, 16 }, water = { 18, 27 }, residential = { 37, 24 }, lit = { 28, 36 },
    sacred = { 28, 13 }, crimson = { 20, 22 },
  },
}
