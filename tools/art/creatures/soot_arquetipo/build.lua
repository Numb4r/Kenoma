-- Arquétipo da família Soot (nome e pasta provisórios: soot_arquetipo), arte final a partir do conceito aprovado da
-- rodada 2. Só aparece em evento e Incursão.
-- O saruê de perfil, grande demais, de boca aberta além do que a queixada deixa. Não tem olho (a órbita está vazia);
-- a boca é o vão, e dentro dela há outra queixada aberta, e outra dentro dessa, cada uma menor. O flanco é a tampa do
-- bueiro, com a brasa atrás das fendas; os filhotes no lombo são caveiras, cada uma menor, até o rabo, que dá voltas
-- demais e acaba numa bituca.
-- REGRAS QUEBRADAS: geometria, boca dentro de boca (as queixadas de dentro nascem da de fora e afundam sem parar);
-- física, o fogo dele tira luz em vez de dar: o pelo e o ferro escurecem quanto mais perto da brasa do peito.
-- Sem costura do Véu: o vão. No corpo ele é a boca escura; o violeta vai só no glow (a borda junto das queixadas e o
-- xadrez que rareia para o fundo), e as queixadas de dentro acendem em violeta, depois na luz do tipo.
-- Retrato: composição própria, um busto de 128 (escala 3): a cabeça sem olho, a boca e a brasa do peito, cortado num
-- rasgo à esquerda e embaixo.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/soot_arquetipo/build.lua')
local S = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_soot.lua')
local L, R = S.L, S.R
local min, sqrt, abs, cos, sin, rad, floor = math.min, math.sqrt, math.abs, math.cos, math.sin, math.rad, math.floor
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(S)
RT.install(S.LEG, S.LIT)
-- o retrato nativo: o vão com fundo, pelo em fios, ferro com poros; a brasa tira luz (sign -1) e a borda é recortada
-- pela luz que vem da boca
local RETRATO = {
  vao = { seed = 'QD', set = 'kQD', keep = 'UZ', depth = 13, star = { 'U', 'Z' }, sky = 60 },
  light = { ramps = { { 'ab4321', RT.tex.fur(1, 0.35, 0.26, 5) }, { 'JjiI', RT.tex.pit(0.35) }, { 'qpP' } },
    lights = 'REY', sign = -1, lw = 0.18, R = 16, rim = { 'E', 'R' }, rimLights = '!@UZ', rimR = 26 },
}

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t = fr * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dyp = o.dy or 0                                       -- o tronco sobe e desce; os pés ficam
  local fo = (o.jump and 0 or -dyp) / k                       -- o pé, no referencial do tronco
  local st = o.lean and ({ [0] = 1.2, 0.6, -0.6, -1.2, -0.6, 0.6 })[ph] or 0
  local d = R.ctx(g.w, k, o.ox or 0, (o.oy or 0) + dyp); d.g = g
  local p = o.bust and 1 or d:pp()
  local SOL = S.SOLID
  local grow = still and (alert and 1 or 0) or (0.5 - 0.5 * cos(t))
  local EX, EY = 33, 41                                       -- a brasa do peito
  local function dark(u, v) return min(1, sqrt((u - EX) ^ 2 + (v - EY) ^ 2) / 20) end
  local fur = R.mat('ab4321', R.noise(p, 3), dark)
  local HX, HY = 39, 29                                       -- a dobradiça da queixada
  local jo = rad(alert and 9 or (crouch and -14 or 2.5 * sin(t)))   -- a queixada respira; escancara no alerta
  local function rj(x, y)
    local dx, dy = x - HX, y - HY
    return { HX + dx * cos(jo) - dy * sin(jo), HY + dx * sin(jo) + dy * cos(jo) }
  end
  local lo = rj(53.6, 50.4)
  d:layer(function(q)                                         -- o rabo, com voltas demais, e a bituca
    local pts = {}
    for i = 0, 40 do
      local a = rad(200 + i * 26)
      local r = 1.2 + i * 0.14
      pts[#pts + 1] = { 9.6 + cos(a) * r, 40 + sin(a) * r }
    end
    pts[#pts + 1] = { 12, 36 }
    q:wire(pts, 'q', 'p', 1.1)
    q:ell(9.6, 40, 0.9, 0.9, (still or ph % 2 == 0) and 'B' or 'G')
  end, SOL)
  d:layer(function(q)                                         -- pernas de lá
    q:cap(18, 42, 16.6 - st, 52 + fo, 2.6, 1.6, R.mat('ab4', R.noise(p, 3), 0.3))
    q:cap(34, 44, 36 + st, 53 + fo, 2.2, 1.4, R.mat('ab4', R.noise(p, 3), 0.3))
  end, SOL)
  d:layer(function(q)
    q:ell(24, 34, 15.6, 11.6, fur)                            -- o lombo
    q:cap(34, 30, 40, 27, 7, 5.6, fur)                        -- pescoço e nuca
    -- a tampa do bueiro no flanco: ferro, fendas com a brasa atrás
    local gk = 1 + 0.15 * grow
    q:ell(22, 35, 7.6, 7.6, function(x, y, u, v)
      local r = sqrt((u - 22) ^ 2 + (v - 35) ^ 2)
      if r > 6.4 then return R.pick('JjiI', dark(u, v) * 0.8, R.noise(p, 5)(x, y)) end
      if (floor(u * 0.8 + 0.4)) % 2 == 0 and r < 6.3 then return r < 2.4 * gk and 'Y' or (r < 4.2 * gk and 'E' or 'R') end
      return R.pick('Jji', dark(u, v) * 0.7, R.ver(p)(x, y))
    end)
    -- os filhotes no lombo: caveiras, cada uma menor, até o rabo; balançam fora de fase
    for n, c in ipairs({ { 31, 22.4, 3 }, { 24.4, 21.6, 2.4 }, { 18.6, 22.6, 1.9 }, { 13.6, 25, 1.5 }, { 10, 28.4, 1.1 } }) do
      local cy = c[2] + (still and 0 or 0.5 * sin(t + n * 1.3))
      q:cap(c[1], cy, c[1] + c[3] * 1.5, cy + c[3] * 0.4, c[3], c[3] * 0.4, R.mat('321', R.noise(p, 7), 0.6))
      q:ell(c[1] - c[3] * 0.5, cy - c[3] * 0.9, c[3] * 0.5, c[3] * 0.6, 'p')
      if c[3] > 1.4 then q:ell(c[1] + c[3] * 0.3, cy - c[3] * 0.1, c[3] * 0.3, c[3] * 0.3, 'k') end
    end
    -- a cabeça: maxila em cima, mandíbula escancarada embaixo, sem olho; orelha pelada
    q:ell(38.6, 17.6, 2.6, 3.4, R.mat('qpP', R.ver(p), 0.5))
    q:poly({ { 36, 20 }, { 44, 18.6 }, { 59, 21.4 }, { 60.4, 24 }, { 58, 25.6 }, { HX, HY } },
      R.mat('4321', R.noise(p, 9), function(_, v) return 0.9 - (v - 18) / 10 end))
    q:poly({ { 35, 31 }, { HX, HY }, lo, rj(51.6, 53.4), rj(47.6, 53), { 35, 39 } },
      R.mat('4321', R.noise(p, 9), function(_, v) return 0.7 - (v - 30) / 30 end))
    q:ell(59.6, 22.6, 1.3, 1.2, 'q')
    q:ell(43.6, 21.6, 1.7, 1.3, 'k')                          -- a órbita, vazia
    for i = 0, 8 do                                           -- dentes: muitos
      local f = 0.2 + i * 0.09
      local ux, uy = HX + (58 - HX) * f, HY + (25.6 - HY) * f
      q:poly({ { ux - 0.7, uy }, { ux + 0.7, uy - 0.1 }, { ux + 0.2, uy + 2.2 - i * 0.08 } }, i % 3 == 0 and 'V' or 'W')
      local lx, ly = HX + (lo[1] - HX) * f, HY + (lo[2] - HY) * f
      q:poly({ { lx - 0.4, ly + 0.6 }, { lx + 0.6, ly - 0.6 }, { lx + 2, ly - 1.4 + i * 0.05 } }, i % 3 == 0 and 'V' or 'W')
    end
    -- patas de cá: mão que parece de gente
    for n, c in ipairs({ { 20, 43, 21, 53.4 }, { 31.6, 44.6, 30.6, 54 } }) do
      local fx, fy = c[3] + (n == 1 and st or -st), c[4] + fo
      q:cap(c[1], c[2], fx, fy, 2.7, 1.6, fur)
      for i = -2, 2 do q:wire({ { fx, fy }, { fx + i * 1.2 + 1, fy + 3.2 - abs(i) * 0.5 } }, 'p', 'q', 0.5) end
    end
    -- a brasa no peito, em rachaduras que crescem e encolhem
    for i = 0, 9 do
      local a = rad(i * 36 + 10)
      local len = 8 + (i % 3) + (still and 0 or ((i + ph) % 3 == 0 and 1.2 or 0))
      q:wire({ { EX, EY }, { EX + cos(a) * 2.6, EY + sin(a) * 2.6 }, { EX + cos(a + 0.4) * len, EY + sin(a + 0.4) * len } }, 'E', 'R', 0.5)
    end
    q:ell(EX, EY, 2.3 * gk, 2.3 * gk, 'Y')
  end, SOL)
  -- o vão: a boca. No corpo é a boca escura (k); a borda junto das queixadas e o xadrez acendem em violeta no glow
  local a0, a1 = math.atan(25.6 - HY, 58 - HX), math.atan(lo[2] - HY, lo[1] - HX)
  local mid, half = (a0 + a1) / 2, (a1 - a0) / 2
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local dx, dy = (x - d.ox - (k - 1) / 2) / k - HX, (y - d.oy - (k - 1) / 2) / k - HY
    local r, a = sqrt(dx * dx + dy * dy), math.atan(dy, dx)
    if r >= 2 and r <= 21 and a >= a0 + 0.1 and a <= a1 - 0.08 then
      local tt = abs(a - mid) / (half - 0.09) * (r > 17.6 and 0.6 or 1)
      local ch = 'k'
      if tt > 0.6 then ch = 'Q'
      elseif tt > 0.2 and (x // p + y // p) % 2 == 0 then ch = 'D'
      elseif tt > 0.12 and (x // p) % 2 == 0 and (y // p) % 2 == 0 then ch = 'D' end
      g[y][x] = ch
    end
  end end
  -- queixada dentro de queixada: cada uma nasce da de fora, encolhe e afunda; a de dentro some no fundo
  for lv = 0, 3 do
    local q = lv - 1 + (still and 0 or fr)
    if q > -0.99 then
      local f = 0.62 * 0.55 ^ q
      local bx, by = HX + 3.4 * (q + 1), HY + 2.6 * (q + 1)
      local ch = q < 0.5 and (o.bust and '!' or 'Q') or (q < 1.5 and 'U' or 'Z')
      for _, sd in ipairs({ -1, 1 }) do
        local a = mid + sd * half * 0.62
        d:wire({ { bx, by }, { bx + cos(a) * 15 * f, by + sin(a) * 15 * f } }, ch, nil, 0.5, 'kDQ')
        for i = 1, 3 do
          local tx, ty = bx + cos(a) * 15 * f * i / 3.4, by + sin(a) * 15 * f * i / 3.4
          d:wire({ { tx, ty }, { tx + cos(a - sd * 1.3) * 3.2 * f, ty + sin(a - sd * 1.3) * 3.2 * f } }, ch, nil, 0.5, 'kDQ')
        end
      end
    end
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  -- faíscas soltas: sobem e somem
  local sz = d:th(0.6)
  for n = 0, 17 do
    local r = (ph + n) % NL
    local x, y = floor(d:X(4 + (n * 23) % 56)), floor(d:Y(6 + (n * 11) % 9 + (n % 3 == 0 and 50 or 0) - r * 0.7))
    if r < NL - 1 then
      for j = 0, sz - 1 do for i = 0, sz - 1 do
        if L.get(g, x + i, y + j) == '.' and y + j < g.h - 1 then L.set(sg, x + i, y + j, n % 3 == 0 and 'T' or (n % 3 == 1 and 'S' or 's')) end
      end end
    end
  end
end

S.run {
  name = 'soot_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, ownDy = true, ownLean = true,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'QDUZ', fill = 'k', mid = 'D', edge = 'Q' },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- busto: a cabeça sem olho, a boca e a brasa, em escala 3
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust, o.ox, o.oy = true, -64, -30
    draw(g, sg, 3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 10, 31 }, green = { 16, 25 }, water = { 30, 30 }, residential = { 30, 29 }, lit = { 31, 31 },
    sacred = { 36, 11 }, crimson = { 11, 37 },
  },
}
