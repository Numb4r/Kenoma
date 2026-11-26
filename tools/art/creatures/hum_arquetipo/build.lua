-- Arquétipo da família Hum (nome e pasta provisórios: hum_arquetipo), arte final a partir do conceito aprovado: a
-- régua dos Arquétipos. Só aparece em evento e Incursão.
-- No lugar do corpo, uma boca redonda de armação de letreiro com doze dentes, e dentro dela um túnel de armações com
-- o olho de LED no fim e outros descendo em espiral. Três asas de cinza de tamanhos diferentes (três, um e dois
-- olhos), sete antenas sem cabeça em volta da gola de pelo. A armação está partida embaixo e o vão escorre para fora.
-- REGRA QUEBRADA: o dentro é maior que o fora. O túnel afunda mais do que o corpo tem de fundo, e o raio não cai do
-- céu: sai de dentro dela, pelo vão que escorre.
-- Sem costura do Véu: o vão. Ele fica quase preto no corpo (z, mais escuro que o contorno, com as faixas de fundo do
-- túnel) e o violeta do Véu vai só no glow: um aro tracejado depois das pontas dos dentes e o miolo do que escorre.
-- Animação: os dentes giram um dente por laço, o letreiro da armação corre, os olhos descem a espiral para o fundo,
-- as asas respiram fora de fase, o raio muda de caminho a cada quadro.
-- Retrato: composição própria, um busto de 128. A boca ocupa o quadro (escala 2,5), com a quarta armação do túnel; as
-- asas e as antenas entram cortadas num rasgo em volta, e o raio sai pelo pé do quadro.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/hum_arquetipo/build.lua')
local K = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_hum.lua')
local L = K.L
local floor, ceil, abs, sqrt, sin, cos, rad = math.floor, math.ceil, math.abs, math.sqrt, math.sin, math.cos, math.rad
local hash = K.hash
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(K)
RT.install(K.LEG, K.LIT)
-- o retrato nativo: o túnel afunda do violeta ao quase preto (t: a distância ao fim do túnel, posta no draw), com
-- LEDs perdidos lá no fundo; asa de cinza com poros, pelo em fios, aço riscado; a borda recortada pelos veios.
-- Sem rasgo: as asas já entram cortadas num círculo por dentro da moldura.
local RETRATO = {
  margin = false,
  vao = { seed = 'Z0', set = 'z0', keep = 'Z', star = { 'H', 'I' }, sky = 50 },
  light = { ramps = { { '4321', RT.tex.pit(0.22) }, { 'CDR', RT.tex.fur(1, 0.5, 0.25, 4) }, { 'uUVW', RT.tex.pit(0.2, 9) } },
    lights = 'JY', lw = 0.3, R = 8, blur = 1, rim = { 'Y', 'J' }, rimR = 4, rimVao = false },
}

local WINGS = { -- { ângulo, comprimento, olhos { u, raio, t } }
  { -78, 18, { { 0.42, 2.4, 0.5 }, { 0.66, 1.5, 0.5 }, { 0.85, 1.5, 0.5 } } },
  { 42, 18, { { 0.55, 3.0, 0.5 } } },
  { 162, 17, { { 0.48, 1.5, 0.5 }, { 0.74, 2.4, 0.5 } } },
}
local BUST = { -- no busto as asas entram cortadas: os olhos ficam perto da raiz
  { -78, 18, { { 0.27, 2.4, 0.5 }, { 0.48, 1.5, 0.5 }, { 0.63, 1.5, 0.5 } } },
  { 42, 18, { { 0.42, 3.0, 0.5 } } },
  { 162, 17, { { 0.36, 1.5, 0.5 }, { 0.56, 2.4, 0.5 } } },
}

local function draw(g, sg, k, o)
  local S = 64 * k
  local cx, cy = S / 2 - 0.5, 31 * k
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t = fr * 2 * math.pi
  local alert, crouch, bust = o.pose == 'alert', o.pose == 'crouch', o.bust
  local still = alert or crouch
  local th = math.max(1, floor(k + 0.5))
  local WA = { '1', '2', '3', '4' }
  local drag = o.lean and 7 or 0            -- deriva: as asas ficam para trás e o túnel aponta para a frente
  local seed = 0
  for n, d in ipairs(bust and BUST or WINGS) do
    local wob = still and 0 or sin(t + n * 2.1)
    local a = rad(d[1])
    local w = { x = cx + cos(a) * 10 * k, y = cy + sin(a) * 10 * k, ang = d[1] + 2 * wob - drag,
      len = d[2] * k * (alert and 1.06 or (crouch and 0.84 or 1)) * (1 + 0.03 * wob), wid = 11 * k, side = 1,
      pal = WA, band = 2, rich = k > 1, torn = n == 2 and 3 * k or nil }
    if bust then
      w.clip = function(_, _, x, y)
        local tat = floor((math.deg(math.atan(y - cy, x - cx)) % 360) / 6) % 2
        return sqrt((x - cx) ^ 2 + (y - cy) ^ 2) < 58 - tat * 3
      end
    end
    K.wing(g, w)
    for _, e in ipairs(d[3]) do
      K.veins(g, w, { { e[1], 0.5, 0.05, 0.5 }, { e[1], 0.6, e[1] + 0.1, 0.98 } }, k > 1 and 2 or 1)
      if k > 1 then K.veins(g, w, { { e[1], 0.4, e[1] + 0.08, 0.06 }, { e[1] - 0.03, 0.75, e[1] - 0.16, 0.85 } }, 2) end
    end
    for _, e in ipairs(d[3]) do
      local x, y = K.wpt(w, e[1], e[3])
      seed = seed + 1
      K.E(g, x, y, e[2], k, seed + 20)
    end
  end
  -- antenas onde não devia haver nenhuma
  for n, d in ipairs({ { -12, 9 }, { 12, 6 }, { 122, 9 }, { 140, 7 }, { 215, 8 }, { 236, 10 }, { 255, 6 } }) do
    local a = rad(d[1] - drag * 0.5)
    local curl = (n % 2 == 0 and 0.35 or -0.3) + (still and 0 or 0.08 * sin(t + n))
    local r0, r1 = 13 * k, (14 + d[2]) * k * (crouch and 0.85 or 1)
    if bust then r1 = math.min(r1, 22 * k) end
    K.feather(g, { { cx + cos(a) * r0, cy + sin(a) * r0 }, { cx + cos(a) * (r0 + r1) / 2, cy + sin(a) * (r0 + r1) / 2 },
      { cx + cos(a + curl) * r1, cy + sin(a + curl) * r1 } }, k, '.BTb')
  end
  -- gola de pelo, armação, vão, dentes e o túnel
  local px = o.lean and 1 or 0
  local c2x, c2y = cx + (1.5 + px) * k, cy + 1 * k
  local c3x, c3y = cx + (2.6 + 2 * px) * k, cy + 1.7 * k
  local c4x, c4y = cx + (3.3 + 2.5 * px) * k, cy + 2.2 * k
  local NT = 12
  local t0 = alert and 8.6 or 7.6            -- onde começam os dentes: no alerta a boca abre
  local bw = math.max(2, th)                 -- largura das faixas de fundo do vão
  local chase = floor(fr * 12 + 0.5)
  for y = 0, S - 1 do
    for x = 0, S - 1 do
      local dx, dy = x - cx, y - cy
      local r = sqrt(dx * dx + dy * dy)
      if r < 16 * k then
        local deg = math.deg(math.atan(dy, dx)) % 360
        local tn = deg / 360
        local gap = deg > 92 and deg < 118
        local lit = deg > 170 and deg < 310          -- o lado da luz
        local ch
        if r >= 13 * k then
          if r < (14.2 + (hash(floor(tn * 24), 3, 1) % 3) * 0.6) * k then
            local row = floor((r + tn * 72 * k) / k)
            ch = row % 2 == 0 and 'C' or 'D'
            if ch == 'D' and lit and row % 4 == 1 then ch = 'R' end
          end
        elseif r >= 11 * k then
          if gap then ch = 'z' else
            ch = r >= 12.2 * k and (lit and 'W' or 'V') or (lit and 'V' or 'U')
            if k > 1 and (tn * 24) % 1 < 0.1 then ch = 'u' end
            -- o letreiro: os trechos acesos correm pela armação
            if abs(r - 12 * k) < 0.5 * k and hash((floor(tn * 12) + chase) % 12, 1, 2) % 4 ~= 0 then
              ch = (tn * 36) % 1 < 0.2 and 'Y' or 'J'
            end
          end
        else
          local r3 = sqrt((x - c3x) ^ 2 + (y - c3y) ^ 2)
          ch = floor(r3 / bw + 0.5) % 2 == 0 and 'z' or '0'
          local phi = (tn * NT + fr + 0.5) % 1 - 0.5
          if r >= t0 * k and not gap and abs(phi) < 0.44 * (r - t0 * k) / ((11 - t0) * k) then ch = phi < 0 and 'W' or 'V' end
          -- o violeta do vão: um aro tracejado logo depois das pontas dos dentes, girando ao contrário
          if r >= (t0 - 0.9) * k and r < (t0 - 0.1) * k and floor(tn * 16 - fr * 2 + 100) % 2 == 0 then ch = 'Z' end
          local r2 = sqrt((x - c2x) ^ 2 + (y - c2y) ^ 2)
          local t2 = (math.deg(math.atan(y - c2y, x - c2x)) % 360) / 360
          if r2 >= 6 * k and r2 < 7 * k then
            ch = 'U'
            if hash(floor(t2 * 7), 4, 4) % 3 == 0 then ch = 'J' elseif k > 1 and (t2 * 14) % 1 < 0.15 then ch = 'u' end
          elseif k > 1 and r2 >= 4.8 * k and r2 < 6 * k and abs((t2 * 9 - fr) % 1 - 0.5) < 0.22 * (r2 - 4.8 * k) / (1.2 * k) then
            ch = 'V'
          end
          if k > 1 and r3 >= 3.7 * k and r3 < 4.2 * k then ch = 'u' end
          if k > 2 then
            local r4 = sqrt((x - c4x) ^ 2 + (y - c4y) ^ 2)
            if r4 >= 2.7 * k and r4 < 3.0 * k then ch = 'U' end
          end
        end
        if ch then g[y][x] = ch end
      end
    end
  end
  -- o vão escorre pela armação partida (pinga), com o miolo violeta
  local gx, gy = cx + cos(rad(105)) * 12.5 * k, cy + sin(rad(105)) * 12.5 * k
  local sl = (6 + (still and 0 or (sin(t - 1) > 0.3 and 1 or 0))) * k
  for tt = 0, sl do
    local hw = 1.8 * k * (1 - tt / sl) + 0.4
    L.rect(g, ceil(gx - hw), floor(gy + tt), floor(gx + hw), floor(gy + tt), 'z')
  end
  L.rect(g, floor(gx + 0.5), floor(gy - 1 * k), floor(gx + 0.5) + th - 1, floor(gy + sl - 2 * k), 'Z', 'z0')
  -- olhos no vão: o do fundo é o maior; os outros descem a espiral e somem nele
  K.E(g, c3x + 0.5, c3y, 2.4, k, 3)
  for n = 0, 5 do
    local q = n + fr
    local a, rr = rad(q * 137.5 + 200), (9.4 - q * 0.9) * k
    local ex, ey = cx + cos(a) * rr, cy + sin(a) * rr
    if k > 1 and q > 1.2 then K.eye(g, ex, ey, 1.5)
    else L.rect(g, floor(ex + 0.5), floor(ey + 0.5), floor(ex + 0.5) + th - 1, floor(ey + 0.5) + th - 1, q > 4 and 'I' or 'H', 'z0Z') end
  end
  if bust then
    RETRATO.vao.t = function(x, y) return math.max(0.5, math.min(1, 1.5 - sqrt((x - c3x) ^ 2 + (y - c3y) ^ 2) / (11 * k))) end
    RT.finish(g, o, RETRATO)
  end
  -- o raio sai do vão que escorre e não acaba no quadro; muda de caminho a cada quadro
  local by = gy + sl
  local segs = (not alert and ph % 3 == 2) and 2 or 4
  local pts = { { gx, by + 1 } }
  for i = 1, segs do
    local jx = (i % 2 == 0 and 1.6 or -1.8) + ((hash(i, alert and 9 or ph, 21) % 5) - 2) * 0.5
    pts[#pts + 1] = { gx + (jx - (o.lean and i * 0.9 or 0)) * k, by + i * 3 * k }
  end
  K.wire(sg, pts, 'S', 's', k, '.')
  if k > 1 then
    for n, p in ipairs(pts) do pts[n] = { p[1] + th, p[2] } end
    K.wire(sg, pts, 'S', 'S', 1, '.')
  end
  local dots = { { -5, 8 }, { 5, 11 }, { 6, 3 }, { -7, 3 }, { 3, 6 } }
  for i, d in ipairs(dots) do
    if (i + ph) % 2 == 0 or alert then K.dot(sg, gx + d[1] * k, by + d[2] * k, k, i % 2 == 0 and 's' or 'S') end
  end
  K.dot(sg, cx + 24 * k, cy + 23 * k, k, 's'); K.dot(sg, cx + 26 * k, cy + (20 + ph % 2) * k, k); K.dot(sg, cx + 22 * k, cy + 26 * k, k)
end

K.run {
  name = 'hum_arquetipo', stage = 'arquetipo', W = 64, PW = 128, LEG = K.LEG, draw = draw, DARK = 'C',
  BODY_KEYS = { '1', '2', '3', '4', 'B', 'T', 'C', 'D', 'R', 'u', 'U', 'V', 'W' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 }, ownLean = true,
  vao = { lit = 'Z0', fill = 'z', mid = '0', edge = 'Z' },
  -- busto: a boca em escala 2,5, centrada um pouco acima do meio; o que passa do quadro (o raio) é cortado
  portrait = function(o)
    local g, sg = L.grid(160, 160), L.grid(160, 160)
    o.bust = true
    draw(g, sg, 2.5, o)
    return g, sg, -16, -15
  end,
  acc = {
    urban = { 29, 16 }, green = { 26, 14 }, water = { 28, 16 }, residential = { 28, 15 }, lit = { 28, 16 },
    sacred = { 28, 14 }, crimson = { 18, 29 },
  },
}
