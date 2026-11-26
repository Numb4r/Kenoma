-- Arquétipo da família Rust (nome e pasta provisórios: rust_arquetipo), arte final a partir do conceito aprovado
-- (rodada3/arquetipos.png). Só aparece em evento e Incursão.
-- O besouro em pé, alto, torto e sem cabeça. O casco é só a grade, e atrás das barras não há corpo: o vão. Um élitro
-- fechado, o outro aberto como folha de portão, e as barras de um continuam nas do outro. O pronoto ficou, com o
-- chifre dele; onde a cabeça encaixava, um colar vazio (também o vão).
-- REGRAS QUEBRADAS: física, nove patas finas de aço, seis de um lado e três do outro, saem de dentro do vão por
-- entre as barras e nenhuma toca o chão; geometria, a folha aberta e o casco fechado são a mesma grade.
-- Sem costura do Véu: o vão. No corpo ele é escuro (O); o violeta vai só no glow, em faixas atrás das barras, que
-- descem no passo delas.
-- Camadas: corpo; leds = nada (não tem cabeça nem olho); glow = o vão atrás da grade e no colar, os rebites acesos
-- e a limalha solta.
-- Animação (6 quadros, lenta): as faixas do vão descem atrás das barras, a folha aberta range, as nove patas mexem
-- cada uma no seu passo; o corpo inteiro paira. O vão segue as regras do K.run (_hum.lua).
-- Retrato: o besouro inteiro dentro da moldura, desenhado em 128 (escala 1,85, margem de 5 px), com o _retrato.lua.
-- As patas não têm contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rust_arquetipo/build.lua')
local Ru = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rust.lua')
local L, R = Ru.L, Ru.R
local floor, sqrt, abs, sin, cos, max, pi, rad = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.pi, math.rad
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Ru)
RT.install(Ru.LEG, Ru.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'Xx', set = 'OXx', depth = 2.4, star = { 'M', 'L' }, sky = 30 },
  light = { ramps = { { '09876', RT.tex.fur(1, 0.2, 0.1, 7) } }, lights = 'LMD', lw = 0.2, R = 5, blur = 0, rim = { 'M', 'D' }, rimR = 3 },
}

local CX, CY, RX, RY = 25, 40.5, 12.6, 20
local cr, sr = cos(rad(12)), sin(rad(12))
local ASH3 = { '6789', '7890', '6789', '5432', '7890', '4321', 'qRr1', 'Gg09' }
local LEGS = { { -34, { { 46, 28.6 }, { 50, 34.4 }, { 52.6, 33.4 } } }, { -17, { { 48, 35 }, { 51, 41.4 }, { 54, 41 } } },
  { -2, { { 49.6, 42 }, { 51.4, 48.4 }, { 54.4, 48.4 } } }, { 13, { { 49, 48.6 }, { 49.6, 54.6 }, { 52.6, 55 } } },
  { 30, { { 46, 54 }, { 45.4, 59.4 }, { 48.4, 60.4 } } }, { 50, { { 40.6, 58 }, { 39, 60 }, { 41.6, 61 } } },
  { 165, { { 6.6, 47.6 }, { 5, 53.6 }, { 2.6, 53 } } }, { 142, { { 8, 55 }, { 8.6, 60 }, { 6, 60.6 } } },
  { 118, { { 13.6, 59.4 }, { 15.6, 60.8 }, { 13.4, 61 } } } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t6 = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local d = R.ctx(S, k, ox, oy + math.min(0, o.dy or 0)); d.g = g
  local p = d:pp()
  local sol = o.dark and '' or Ru.SOLID
  local roll = still and 0 or ph
  local swing = alert and 1.5 or (crouch and -1.5 or (still and 0 or sin(t6)))
  local function iron(d0, w, x, y, sh, kk)                          -- aço fosco: hachura de dois tons
    return Ru.iron(d0, w, x, y, sh + (((x + y) // p) % 3 == 0 and 0.5 or 0), kk, ASH3)
  end
  local function rim(th, f)                                         -- ponto da borda do casco
    local a, b = RX * cos(th) * f, RY * sin(th) * f
    return CX + a * cr - b * sr, CY + a * sr + b * cr
  end
  d:layer(function(t)                                               -- a folha aberta, do lado de lá
    Ru.gateLeaf(t, k, { 17.6, 31 }, { -12 - swing * 0.5, -4.6 + swing }, { 3.4, -17 }, 4, 0.001, ASH3)
  end, sol)
  d:layer(function(t)
    t:cap(29.6, 22.6, 35, 17, 3.6, 3.4, function(x, y, u, v) return iron(0, 1, x, y, (u - 32) * 0.2, k) end)   -- a cintura
    t:cap(40.6, 9.6, 47.4, 6, 1.4, 1, function(x, y, u, v) return iron(0, 1, x, y, (v - 8) * 0.4, k) end)      -- o chifre do pronoto
    t:cap(47.4, 6, 51, 8.6, 1, 0.4, function(x, y) return iron(0, 1, x, y, 0.3, k) end)
    t:ell(37.6, 13.6, 7.6, 6, function(x, y, u, v)                                                            -- o pronoto
      local sh = (v - 13.6) / 6 * 0.85 + (u - 37.6) / 7.6 * 0.3
      if abs(((u - 37.6) / 7.6) ^ 2 + ((v - 13.6) / 6) ^ 2 - 0.55) < 0.07 then return sh < 0 and '6' or '8' end
      return iron(0, 1, x, y, sh, k)
    end)
    t:rect(0, 0, 63, 63, function(x, y, u, v)                       -- o casco: só barras, e o vão atrás
      local a = (u - CX) * cr + (v - CY) * sr
      local b = -(u - CX) * sr + (v - CY) * cr
      local e = (a / RX) ^ 2 + (b / RY) ^ 2
      if e > 1 then return nil end
      local hw = RX * sqrt(max(0.02, 1 - (b / RY) ^ 2))
      local lon = a / hw
      local sh = lon * 0.6 + b / RY * 0.5
      if (1 - sqrt(e)) * RX < 1.5 then return iron(0, 1, x, y, sh, k) end
      for _, s in ipairs({ -0.66, -0.33, 0, 0.33, 0.66 }) do
        local dd = (lon - s) * hw
        if abs(dd) < 0.75 then
          if abs(b + 7) < 0.9 or abs(b - 6) < 0.9 then return 'L' end                -- o rebite, aceso
          local i = (dd < 0 and 1 or 3) + (sh > 0.2 and 1 or 0)                      -- barra de aço limpo: aresta clara, aresta escura
          return ('6789'):sub(i, i)
        end
      end
      if abs(b + 7) < 0.7 or abs(b - 6) < 0.7 then return y % 2 == 0 and '8' or '9' end
      local r = sqrt((lon * 0.8) ^ 2 + (b / RY) ^ 2)                -- atrás das barras: o vão, em faixas que descem
      if (y - roll) % 3 == 0 then return 'O' end
      return r < 0.36 and 'X' or 'x'
    end)
  end, sol)
  -- o colar vazio, onde a cabeça encaixava
  for y = 0, S - 1 do for x = 0, S - 1 do
    local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
    local t = sqrt(((u - 44.4) / 2.7) ^ 2 + ((v - 16.6) / 3.3) ^ 2)
    if t <= 1 then g[y][x] = t > 0.6 and 'X' or ((x + y) % 2 == 0 and 'x' or 'O') end
  end end
  if o.bust then
    -- o fundo do vão é um só atrás de todas as barras: violeta junto da moldura, quase preto no meio do casco
    RETRATO.vao.t = function(x, y)
      local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
      local a0 = (u - CX) * cr + (v - CY) * sr
      local b0 = -(u - CX) * sr + (v - CY) * cr
      local e = sqrt((a0 / RX) ^ 2 + (b0 / RY) ^ 2)
      if e > 1 then e = sqrt(((u - 44.4) / 2.7) ^ 2 + ((v - 16.6) / 3.3) ^ 2) end   -- o colar
      return math.max(0, math.min(1, (1 - e) * 1.8))
    end
    RT.finish(g, o, RETRATO)
  end
  -- as patas saem do vão, por entre as barras; nenhuma toca o chão
  local legs = {}
  for n, q in ipairs(LEGS) do
    local w = still and 0 or 0.8 * sin(t6 + n * 1.7)
    local x0, y0 = rim(rad(q[1]), 0.93)
    local pts = { { x0, y0 } }
    for i, e in ipairs(q[2]) do pts[#pts + 1] = { e[1], e[2] + (i > 1 and w or w * 0.5) } end
    Ru.leg(legs, pts, 0.55, 'm', 'n', 4)
    local e = pts[#pts]                                             -- a garra
    legs[#legs + 1] = { e[1], e[2], e[1] + 1.4, e[2] - 1.5, 0.4, 0.3, 'm', 'n' }
  end
  Ru.behind(g, k, d.ox, d.oy, legs)
  local n1 = max(1, floor(k * 0.6 + 0.5))
  for n = 0, 15 do
    if (n + ph) % 3 ~= 0 then
      local a = n * 2.4
      local x, y = floor((30 + cos(a) * (26 + (n * 7) % 5)) * k + ox), floor((32 + sin(a) * (27 + (n * 5) % 4)) * k + oy)
      for dy = 0, n1 - 1 do for dx = 0, n1 - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < S - 1 and y + dy < S - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = n % 3 == 0 and 's' or 'S'
        end
      end end
    end
  end
end

Ru.run {
  name = 'rust_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, DARK = '0',
  BODY_KEYS = { '6', '7', '8', '9', '0', '5', '4', '3', '2', '1', 'q', 'R', 'r', 'G', 'g', 'm', 'n' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'Xx', fill = 'O', mid = 'x', edge = 'X' },
  -- o besouro inteiro, em 128: escala 1,85, margem de 5 px
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.85, o, 4.8, 4.8)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 33, 10 }, green = { 30, 12 }, water = { 32, 9 }, residential = { 32, 11 }, lit = { 32, 12 },
    sacred = { 33, 1 }, crimson = { 36, 10 },
  },
}
