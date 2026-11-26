-- Arquétipo da família Glare (nome e pasta provisórios: glare_arquetipo), arte final a partir do conceito aprovado da
-- rodada 3. Só aparece em evento e Incursão.
-- A silhueta do beija-flor do Eco, pairando, do tamanho do quadro, feita de cacos grandes de vitrine cinza que não se
-- tocam. A cabeça não tem olho, e só ela e a cauda guardam a cor. No lugar do coração os cacos não fecham: o vão.
-- REGRAS QUEBRADAS: física, os cacos não se tocam e guardam a forma (as frestas abrem e fecham e a ave não desmonta);
-- geometria, o reflexo atravessa todos os cacos em linha reta, como se fossem um vidro só, e a ponta do bico, que
-- aponta para fora, aparece dentro do vão.
-- Sem costura do Véu: o vão. No corpo ele é escuro (O, mais escuro que o contorno); o violeta vai só no glow (o aro,
-- o xadrez e as frestas em volta dele, que abrem para o vão).
-- LUZ: a do tipo (o reflexo, a estrela) com o espectro do prisma por cima: o fio de cada caco pega uma cor (dourado,
-- rosa, verde, azul), e as lascas soltas também (o Glare multicolor da arte final).
-- Camadas: corpo; leds = a estrela de quatro pontas na asa (pisca); glow = o reflexo, os fios dos cacos, o vão, a
-- ponta do bico lá dentro e as lascas soltas.
-- Animação (6 quadros, lenta): a asa sobe e desce devagar, as frestas respiram, o reflexo corre pelos cacos e fecha o
-- laço, a ponta do bico entra e sai do vão duas vezes por laço. O vão segue as regras do K.run (_hum.lua).
-- Retrato: a ave inteira dentro da moldura, desenhada em 128 (escala 1,95, centrada, com margem), com o acabamento do
-- _retrato.lua: vidro em degraus com risco fino, o fio dos cacos na luz, o vão com fundo.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/glare_arquetipo/build.lua')
local G = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_glare.lua')
local L, hash = G.L, G.hash
local floor, sqrt, abs, sin, cos, pi = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.pi
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(G)
RT.install(G.LEG, G.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'UT', set = 'OUT', keep = 'C', depth = 7, star = { 'J', 'Y' }, sky = 30 },
  light = { ramps = { { '9876', RT.tex.fur(1, -1, 0.12, 9) }, { 'nfe' } }, lights = 'YJHRLBIK', lw = 0.22, R = 5, blur = 0,
    rim = { 'J', 'H' }, rimR = 3 },
}

local SC, BX, BY = 2.3, 1.5, 1.5
local VX, VY = BX + 17.2 * SC, BY + 13.6 * SC
local RIM = { 'H', 'R', 'L', 'B' }

-- Cacos: células de Voronoi em unidades do mapa (o retrato tem os mesmos cacos). Devolve o id e a distância à fresta.
local function vor(u, v, s, seed)
  local gx, gy = floor(u / s), floor(v / s)
  local b1, b2, id = 1e9, 1e9, 0
  for j = -1, 1 do for i = -1, 1 do
    local h = hash(gx + i, gy + j, seed)
    local px = (gx + i + 0.15 + 0.7 * ((h & 255) / 255)) * s
    local py = (gy + j + 0.15 + 0.7 * (((h >> 8) & 255) / 255)) * s
    local dd = (u - px) ^ 2 + (v - py) ^ 2
    if dd < b1 then b2 = b1; b1 = dd; id = h elseif dd < b2 then b2 = dd end
  end end
  return id, sqrt(b2) - sqrt(b1)
end

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t = fr * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local wn = alert and 6 or (crouch and -30 or -6 + 6 * sin(t))
  if o.lean then wn = wn - 10 end
  local gap = alert and 0.8 or (crouch and 0.3 or 0.5 + 0.2 * sin(t + 1))
  local VR = alert and 6 or (crouch and 4.4 or 5.4)
  local slide = still and 0 or 15 * fr
  local tip = still and 0 or 0.7 * sin(2 * t)                    -- a ponta do bico, no passo dela
  local bird = G.bird(1, { wn = wn, wf = wn - 4, tail = o.lean and 1 or (still and 0 or 0.4 * sin(t)) })
  G.paint(g, k, ox, oy, function(u, v, x, y)
    local bu, bv = (u - BX) / SC, (v - BY) / SC
    local c = bird(bu, bv)
    if not c then return end
    if c == 'z' or c == 'Z' then return c end
    if ('efnoW'):find(c, 1, true) then                           -- cabeça (sem olho) e cauda
      if c == 'o' or c == 'W' then c = 'f' end
      return ((x + y) % 3 == 0) and (c == 'e' and 'f' or 'n') or c
    end
    local wu, wv = G.unrot(bu, bv, 15.4, 12.8, wn)
    local su, sv = abs(wu - 6.4) * SC, abs(wv - 6.4) * SC        -- a estrela de quatro pontas, presa na asa
    if su < 1.1 and sv < 1.1 then return 'I' end
    if (su < 0.6 and sv < 4.6) or (sv < 0.6 and su < 4.6) then return 'K' end
    local fu, fv = G.unrot(bu, bv, 16.6, 11.4, wn - 4)
    local base = G.inpoly(wu, wv, G.WN) and 1 or (G.inpoly(fu, fv, G.WF) and 3 or 2)
    local id, e = vor(u, v, 9.5, 5)
    if e < gap then return '0' end                               -- a fresta entre dois cacos
    local q = (u + v - 37 - slide) % 15                          -- o reflexo, reto por cima de todos os cacos
    if q < 1.5 or q > 14.9 then return base == 3 and 'J' or 'Y' elseif q > 3.2 and q < 4.2 and base ~= 3 then return 'J' end
    local rim = (id >> 3) % 4
    if e < gap + 0.8 and rim < 2 then return RIM[(id >> 9) % 4 + 1] end   -- o fio do caco pega a luz, cada um numa cor
    if e < gap + 0.8 and rim == 2 then return (x + y) % 3 == 0 and 'g' or 'G' end   -- o verde da espessura do vidro
    local tone = base + (id >> 5) % 2
    local dither
    if (id >> 7) % 2 == 0 then dither = (x - y) % 4 == 0 else dither = (x + y) % 3 == 0 end
    tone = tone + (dither and 1 or 0)
    return ('67890'):sub(tone, tone)
  end)
  G.prune(g)
  -- o vão no lugar do coração; as frestas em volta dele abrem para ele
  G.paint(g, k, ox, oy, function(u, v, x, y)
    local tt = sqrt((u - VX) ^ 2 + (v - VY) ^ 2) / VR
    if tt <= 1 then
      if tt > 0.8 then return 'U' end
      if G.dseg(u, v, VX + 3.6 - tip, VY - 2.6 + tip * 0.7, VX + 0.4 - tip, VY - 0.2 + tip * 0.7) < 0.45 then return 'C' end
      return ((x + y) % 2 == 0 and tt > 0.34) and 'T' or 'O'
    elseif tt <= 2.1 and g[y][x] == '0' then return 'T' end
  end)
  if o.bust then RT.finish(g, o, RETRATO) end
  -- lascas soltas em volta, nas cores do prisma: piscam
  local n = math.max(1, floor(k * 0.6 + 0.5))
  for i = 1, 14 do
    if (i + ph) % 3 ~= 0 then
      local a = i * 2.39996
      local r = 24 + (i * 7) % 6
      local x, y = floor((32 + cos(a) * r) * k + ox), floor((32 + sin(a) * r * 0.95) * k + oy)
      for dy = 0, n - 1 do for dx = 0, n - 1 do
        if x + dx > 0 and y + dy > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
          sg[y + dy][x + dx] = ({ 'S', 'E', 's', 'F', 'D' })[i % 5 + 1]
        end
      end end
    end
  end
end

G.run {
  name = 'glare_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, ownLean = true, DARK = '0',
  BODY_KEYS = { '6', '7', '8', '9', '0', 'e', 'f', 'n', 'g', 'G', 'z', 'Z' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'UT', fill = 'O', mid = 'T', edge = 'U', extra = 'C' },
  -- a ave inteira, em 128: escala 1,95, centrada, com pelo menos 8 px de margem
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.95, o, 1.6, 0.2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 28, 40 }, green = { 24, 42 }, water = { 26, 36 }, residential = { 26, 38 }, lit = { 26, 41 },
    sacred = { 40, 14 }, crimson = { 30, 44 },
  },
}
