-- Arquétipo da família Sprig (nome e pasta provisórios: sprig_arquetipo), arte final a partir do conceito aprovado
-- (rodada3/arquetipos.png; a forma está no _sprig.lua, com pose). Só aparece em evento e Incursão.
-- Seis maritacas cinza, sem olho, de tamanhos diferentes, gritando para a frente e para os lados; os pescoços saem de
-- um mesmo anel de pena. Dentro do anel está o vão, com as cabeças repetidas para dentro. Asas de folha morta
-- varridas para trás, dois rabos com o crisso ainda vermelho.
-- REGRAS QUEBRADAS: geometria, os pescoços saem de um corpo que não está lá; física, as asas são só nervura da
-- metade para a ponta e ele paira.
-- Sem costura do Véu: o vão. No corpo ele é escuro (0); o violeta vai só no glow (a borda, o pontilhado e os aros das
-- cabeças de dentro).
-- Camadas: corpo; leds = a ponta das nervuras (pisca; não tem olho); glow = as nervuras, as gargantas que gritam, o
-- vão e o pólen solto.
-- Animação (6 quadros, lenta): paira; as seis cabeças e os pescoços se mexem cada um na sua fase (balançam no anel,
-- esticam e encolhem, viram para onde gritam, abrem e fecham o bico), as asas e os rabos também. O vão é vivo em
-- outro ritmo: os lóbulos da borda giram, as cabeças de dentro afundam e voltam duas vezes por laço, o pontilhado
-- corre. O resto do vão segue as regras do K.run (_hum.lua): a máscara atrasa um quadro, no nascer ela se fecha
-- sobre o vão, na fuga o vão engole o resto.
-- Retrato: o bando inteiro dentro da moldura, desenhado em 128 (escala 1,85, margem de 5 px), com o _retrato.lua.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/sprig_arquetipo/build.lua')
local Sp = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_sprig.lua')
local L = Sp.L
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Sp)
RT.install(Sp.LEG, Sp.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'XV', set = '0XV', depth = 6, star = { 'W', 'L' }, sky = 25 },
  light = { ramps = { { 'GEDB', RT.tex.fur(1, 0.4, 0.14, 4) } }, lights = 'WLO', lw = 0.2, R = 6, blur = 0, rim = { 'W', 'O' }, rimR = 3 },
}
local CX, CY = 34, 32.6

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local still = o.pose == 'alert' or o.pose == 'crouch'
  -- as seis cabeças e os pescoços se mexem fora de fase (balançam no anel, esticam, viram e abrem o bico), as asas
  -- e os rabos também; o vão ondula e as cabeças de dentro afundam no passo dele. No alerta tudo para, esticado e
  -- de bico aberto; na antecipação os pescoços encolhem e os bicos fecham.
  local t6 = ph / NL * 2 * math.pi
  local a = { t = t6, amp = o.bust and 0.6 or 1, flap = 6 * math.sin(t6), inner = o.bust and '!' or nil }
  if o.pose == 'alert' then a = { amp = 0, flap = 8, reach = 1.2, gape = 1 }
  elseif o.pose == 'crouch' then a = { amp = 0, flap = -10, reach = -2.4, gape = 0 } end
  local src = Sp.C.arquetipo(k, g.w, ox, oy, a)
  -- o vão: o que o conceito deixava vazado vira o fundo escuro; o pontilhado corre
  for y = 0, src.h - 1 do for x = 0, src.w - 1 do
    local u, v = (x - ox - (k - 1) / 2) / k, (y - oy - (k - 1) / 2) / k
    if (u - CX) ^ 2 + ((v - CY) * 1.1) ^ 2 < 9.6 ^ 2 then
      if src[y][x] == '.' then src[y][x] = '0'
      elseif src[y][x] == 'V' and not still and not o.bust and (x + y * 2 + ph) % 3 == 0 then src[y][x] = '0' end
    end
  end end
  if o.bust then RT.finish(src, o, RETRATO) end
  Sp.place(g, sg, src, { k = k, ph = ph, NL = NL, dark = o.dark, sway = o.lean and math.max(1, k * 0.6) or nil, piv = 60,
    squash = o.pose == 'crouch' and 1 or nil, hot = (not still and ph % 3 == 1) and 1 or 0 })
end

Sp.run {
  name = 'sprig_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, DARK = 'G',
  BODY_KEYS = { 'B', 'D', 'E', 'G', '6', '7', 'u', 'U', 'r', 'R', 'k', 'K', 'q' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'XV', fill = '0', mid = 'V', edge = 'X' },
  -- o bando inteiro, em 128: escala 1,85, margem de 5 px
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.85, o, 3.4, 4.8)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 30, 22 }, green = { 27, 24 }, water = { 29, 21 }, residential = { 29, 22 }, lit = { 29, 23 },
    sacred = { 30, 12 }, crimson = { 24, 34 },
  },
}
