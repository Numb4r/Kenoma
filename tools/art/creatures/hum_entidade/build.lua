-- Entidade Maior da família Hum (nome e pasta provisórios: hum_entidade), arte final a partir do conceito aprovado.
-- O poste é o corpo: o transformador abriu numa boca de pé, com dentes de aleta e olhos lá dentro; duas asas rasgadas
-- pendem como mortalha e a terceira sobe atrás da cruzeta (três, dois e dois olhos); olhos soltos no poste e cinco
-- antenas no lugar das pernas. Nenhuma cabeça. REGRA QUEBRADA: gravidade. Os fios da cruzeta caem para cima, em onda,
-- e a faísca das pontas sobe.
-- Costuras do Véu: duas, largas (3 px): uma cinta no poste, abaixo do transformador, e uma atravessando a asa direita.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/hum_entidade/build.lua')
local K = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_hum.lua')
local L = K.L
local floor, ceil, abs, sin = math.floor, math.ceil, math.abs, math.sin

local function draw(g, sg, k, o)
  local S = 48 * k
  local cx = S / 2 - 0.5
  local ph = (o.ph or 0) % 6
  local t = ph / 6 * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local sw = (alert or crouch) and 0 or sin(t)
  local th = math.max(1, floor(k + 0.5))
  local WP = { 'F', 'Q', 'P', 'G' }
  local function W(x, y, ang, len, wid, side)
    return { x = x, y = y, ang = ang, len = len * k, wid = wid * k, side = side, pal = WP, band = 2, rich = k > 1, torn = 3 * k }
  end
  local top = W(cx, 15 * k, -90 + (alert and 0 or 4 * sin(t + 1)), crouch and 10 or 12.5, 7, 1)
  K.wing(g, top)
  -- poste
  for y = floor(12 * k), floor(45 * k) - 1 do
    for x = ceil(cx - 1.5 * k), floor(cx + 1.5 * k) do
      local ch = x < cx - 0.5 * k and 'x' or 'w'
      if k > 1 and K.hash(x, y // 4, 5) % 4 == 0 then ch = ch == 'x' and 'w' or 'x' end
      if y >= 28 * k and y < 31 * k then ch = '9' end              -- costura do Véu: a cinta no poste
      L.set(g, x, y, ch)
    end
  end
  -- as duas asas de mortalha: balançam juntas, abrem no alerta, fecham na antecipação
  local spread = alert and 14 or (crouch and -10 or 0)
  local wl, wr = W(cx - 3 * k, 19 * k, 118 + spread + 3 * sw, 22, 9, 1), W(cx + 3 * k, 19 * k, 62 - spread + 3 * sw, 22, 9, -1)
  K.wing(g, wl); K.wing(g, wr)
  do -- costura do Véu atravessando a asa direita
    local x0, y0 = K.wpt(wr, 0.63, 0.0); local x1, y1 = K.wpt(wr, 0.66, 1.0)
    for d = 0, 3 * th - 1 do L.line(g, x0, y0 + d, x1, y1 + d, 'X', 'FQPG') end
  end
  local eyes = { { wl, 0.28, 2.4 }, { wl, 0.52, 1.5 }, { wl, 0.74, 1.5 }, { wr, 0.42, 3.0 }, { wr, 0.84, 1.5 },
    { top, 0.42, 1.5 }, { top, 0.74, 1.5 } }
  for _, e in ipairs(eyes) do
    K.veins(g, e[1], { { e[2], 0.6, e[2] - 0.06, 0.98 }, { e[2] + 0.04, 0.6, e[2] + 0.12, 0.98 } }, k > 1 and 2 or 1)
    if k > 1 then K.veins(g, e[1], { { e[2], 0.4, e[2] + 0.08, 0.06 }, { e[2] - 0.03, 0.75, e[2] - 0.16, 0.8 } }, 2) end
  end
  for n, e in ipairs(eyes) do
    local x, y = K.wpt(e[1], e[2], 0.5)
    K.E(g, x, y, e[3], k, n)
  end
  -- cruzeta, isoladores e os fios que caem para cima
  L.rect(g, floor(cx - 14 * k), floor(11 * k), ceil(cx + 14 * k), floor(13 * k) - 1, 'w')
  L.rect(g, floor(cx - 14 * k), floor(11 * k), ceil(cx + 14 * k), floor(11 * k) + ceil(k / 2) - 1, 'x')
  for n, ix in ipairs({ -13, -8, 8, 13 }) do
    local ex = cx + ix * k
    for r = 0, 3 * k - 1 do
      local hw = (floor(r / k) % 2 == 0) and 1.6 * k or 1 * k
      L.rect(g, ceil(ex - hw), floor(11 * k - 1 - r), floor(ex + hw), floor(11 * k - 1 - r), floor(r / k) % 2 == 0 and 'O' or 'o')
    end
    local topY = ({ 2.5, 5, 4, 2 })[n] * k
    local y, pts, step = 8 * k, {}, 0
    local amp = alert and 0 or 0.8 * k
    while y > topY do
      pts[#pts + 1] = { ex + (step > 0 and sin(step * 1.7 - t + n) * amp or 0), y }   -- a onda sobe pelo fio
      y = y - 2 * k; step = step + 1
    end
    local tip = { ex + (n % 2 == 0 and 1 or -1) * 0.8 * k * (alert and 0 or 1), topY }
    pts[#pts + 1] = tip
    K.wire(g, pts, 'k', 'm', k)
    -- a faísca da ponta sobe e some
    local rise = (ph + n * 2) % 6
    local sy = tip[2] - (1.5 + rise * 0.7) * k
    if rise == 0 and n % 2 == 1 then K.plus(sg, tip[1], sy - k, k)
    elseif rise < 5 then K.dot(sg, tip[1] + (rise % 2) * k, sy, k, rise % 2 == 0 and 's' or 'S') end
    K.dot(sg, tip[1] + (n % 2 == 1 and 2 or -2) * k, tip[2] + (1 - (ph % 3)) * k, k)
  end
  -- transformador, com a boca (respira; escancara no alerta)
  local mw = alert and 2.7 or (crouch and 1.3 or 1.9 + 0.35 * sw)
  local x0, x1 = ceil(cx - 4.5 * k), floor(cx + 4.5 * k)
  for y = floor(14 * k), floor(27 * k) - 1 do
    for x = x0, x1 do
      local col = floor((x - x0) / k)
      local ch = col % 2 == 0 and 'V' or 'U'
      if col == 1 then ch = 'W' elseif col >= 8 then ch = 'u' end
      if y < 15 * k then ch = col >= 8 and 'U' or 'W' end
      if floor(y / k) == 26 then ch = col == 1 and 'N' or 'n' end
      local tt = (y - 15.5 * k) / (10 * k)
      if tt > 0 and tt < 1 then
        local m = mw * k * sin(math.pi * tt) ^ 0.8
        local d = abs(x - cx)
        if d <= m then
          ch = 'z'
          if floor(y / k) % 2 == 0 and d > m - 1.1 * k and m > 1.2 * k then ch = (k > 1 and x > cx) and 'V' or 'W' end
        elseif k > 1 and d <= m + 1 then ch = 'u' end
      end
      L.set(g, x, y, ch)
    end
  end
  if k == 1 then
    K.led(g, cx - 0.5, 19, 1); K.led(g, cx + 0.5, 22, 1); K.led(g, cx - 0.5, 23, 1, 'I')
  else
    K.eye(g, cx + 0.5, 18.4 * k, 1.5); K.eye(g, cx - 0.5, 21.6 * k, 1.5); K.led(g, cx + 0.5, 24 * k, 1); K.led(g, cx - 1.5, 16.6 * k, 1)
  end
  -- olhos soltos no poste
  K.led(g, cx - 1 * k, 32.5 * k, k); K.led(g, cx + 0.5 * k, 35 * k, k, 'I'); K.led(g, cx - 0.5 * k, 37.5 * k, k)
  -- cinco antenas no lugar das pernas: o joelho de cada uma sobe e desce fora de fase
  for n, dx in ipairs({ -12, -7, 2, 8, 13 }) do
    local knee = (37.5 - abs(dx) * 0.12 + ((alert or crouch) and (crouch and 1 or -1) or 0.7 * sin(t + n * 1.3))) * k
    local leg = { { cx, 40 * k }, { cx + dx * 0.6 * k, knee }, { cx + dx * k, 44 * k } }
    -- no mapa a perna é um fio de 1 px, sem contorno; no retrato é a antena inteira, com barbas
    if k == 1 then K.wire(g, leg, 'b', 'b', 1) else K.feather(g, leg, k) end
  end
end

K.run {
  name = 'hum_entidade', stage = 'entidade', W = 48, PW = 96, LEG = K.LEG, draw = draw, DARK = 'n',
  BODY_KEYS = { 'F', 'Q', 'P', 'G', 'w', 'x', 'u', 'U', 'V', 'W', 'n', 'N', 'o', 'O', 'K', 'c', 'M', 'B', 'T' },
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- inclina a cruzeta e o transformador; as pernas (fio de 1 px) ficam no lugar para não soltar
  lean = function(y) return (y < 13 and 2) or (y < 27 and 1) or 0 end,
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 31 }, green = { 18, 13 }, water = { 20, 27 }, residential = { 20, 27 }, lit = { 20, 28 },
    sacred = { 20, 13 }, crimson = { 22, 32 },
  },
}
