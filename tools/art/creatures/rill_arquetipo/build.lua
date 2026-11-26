-- Arquétipo da família Rill (nome e pasta provisórios: rill_arquetipo), arte final a partir do conceito aprovado
-- (rodada3/arquetipos.png). Só aparece em evento e Incursão. De frente (exceção aceita: estilo-criaturas.md, "Ângulo").
-- O sapo de frente, com a boca aberta do tamanho do corpo. A boca é a poça: uma lâmina d'água em pé, que não escorre,
-- e o que ela reflete é um céu que não é o daqui (o vão): duas luas e a linha de uma cidade de ponta-cabeça. A pele
-- está do avesso: fibra em vez de verruga, cova em vez de calombo, as veias por fora, acesas. Não tem olho: no lugar
-- dos calombos, dois buracos. Braços a mais de um lado só.
-- REGRAS QUEBRADAS: física, a poça está em pé e não escorre, e a água cai para cima; geometria, a poça é mais larga
-- que a cabeça que a segura (passa do contorno de um lado).
-- Sem costura do Véu: o vão. No corpo ele é escuro (z); o violeta vai só no glow (a borda da poça, o pontilhado e a
-- cidade), e as luas acendem na luz do tipo.
-- Camadas: corpo; leds = nada (não tem olho); glow = as veias, o vão com as luas e a cidade, e as gotas que sobem.
-- Animação (6 quadros, lenta): o corpo respira, as luas atravessam a poça cada uma no seu passo, a cidade corre de
-- lado, os braços a mais mexem, as gotas sobem. O vão segue as regras do K.run (_hum.lua).
-- Retrato: o sapo inteiro dentro da moldura, desenhado em 128 (escala 1,85, margem de 5 px), com o _retrato.lua.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rill_arquetipo/build.lua')
local Rl = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rill.lua')
local L, R, F = Rl.L, Rl.R, Rl.F
local floor, sqrt, abs, sin, pi = math.floor, math.sqrt, math.abs, math.sin, math.pi
local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(Rl)
RT.install(Rl.LEG, Rl.LIT)
local RETRATO = {
  margin = false,
  vao = { seed = 'UY', set = 'zUY', keep = 'Ct', depth = 9, star = { 't', 'C' }, sky = 8 },
  light = { ramps = { { '4321', RT.tex.fur(1, 0.7, 0.12, 5) }, { 'vwWV' } }, lights = 'BD', lw = 0.2, R = 6, blur = 0, rim = { 'D', 'B' }, rimR = 4 },
}

local SOL = ''
for ch in pairs(Rl.LEG) do if not Rl.NOPULL:find(ch, 1, true) then SOL = SOL .. ch end end
local cx = 32.5
local MX, MY, MRX, MRY = cx - 5.4, 31.4, 19.6, 7.4

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local t6 = fr * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local d = R.ctx(g.w, k, ox, oy + math.min(0, o.dy or 0)); d.g = g
  local p = d:pp()
  local sol = o.dark and '' or SOL
  local puff = still and 0 or 0.5 * sin(t6)
  local function wig(n) return still and 0 or 0.8 * sin(t6 + n * 1.8) end
  local function flesh(pal, fx, lx, ly, rx, ry)                     -- fibra em espinha, com covas
    local lm, fib = R.lum(lx, ly, rx, ry), R.chev(d:X(fx), 2 * p)
    return function(x, y, u, v)
      if R.hash(x // p, y // p, 11) > 0.93 and (x // p + y // p) % 2 == 0 then return 'a' end
      return R.pick(pal, lm(u, v), fib(x, y))
    end
  end
  local function hand(t, x, y, sp, len)
    for i = -1, 1 do t:wire({ { x, y }, { x + i * sp, y + len - abs(i) * 0.6 } }, '2', '3', 0.6) end
  end
  d:layer(function(t)                                               -- pernas de trás, o joelho para cima
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 15, 47, cx + s * 24, 36 - s, 5, 3.4, flesh('4321', cx + s * 20, cx + s * 19, 41, 8, 9))
      t:cap(cx + s * 24, 36 - s, cx + s * 22, 55, 2.5, 1.5, flesh('4321', cx + s * 23, cx + s * 23, 45, 4, 10))
      hand(t, cx + s * 22, 55, 2.6, 5 + (s < 0 and 1 or 0))
    end
  end, sol)
  d:layer(function(t)                                               -- o queixo e o corpo
    t:cap(cx + 16.6, 21, cx + 17.6, 42, 3.4, 4.4, flesh('b321', cx + 17, cx + 17, 32, 4, 12))   -- o canto da boca, que segura a cabeça
    t:ell(cx, 44.6, 19.6 + puff * 0.6, 11.6 + puff * 0.4, flesh('4321', cx, cx, 44, 19.6, 11.6))
    t:ell(cx - 1, 37.6, 17, 4.6, R.mat('vwWV', R.noise(p, 6), R.lum(cx, 38, 17, 5)))             -- o beiço de baixo, forro da boca
    t:wire({ { cx - 13, 44 }, { cx - 8, 48 }, { cx - 9, 53 } }, 'B', 'D', 0.5); t:wire({ { cx - 8, 48 }, { cx - 2, 50 } }, 'B', 'D', 0.5)
    t:wire({ { cx + 14, 43 }, { cx + 9, 47.6 }, { cx + 11, 53 } }, 'B', 'D', 0.5); t:wire({ { cx + 9, 47.6 }, { cx + 3, 46.4 } }, 'B', 'D', 0.5)
  end, sol)
  d:layer(function(t)                                               -- o alto da cabeça, virado para trás
    t:ell(cx + 1, 19.4, 16.6, 8.6, flesh('4321', cx + 1, cx + 1, 19, 16.6, 8.6))
    t:ell(cx - 8, 12, 4.2, 3.8, flesh('c21', cx - 8, cx - 8, 12, 4.2, 3.8)); t:ell(cx + 10.6, 13, 3.6, 3.2, flesh('c21', cx + 10.6, cx + 10.6, 13, 3.6, 3.2))
    t:ell(cx - 8, 12.2, 2.9, 2.5, 'd'); t:ell(cx + 10.6, 13.2, 2.4, 2.1, 'd')
    t:ell(cx - 8, 12.4, 2.3, 1.9, 'k'); t:ell(cx + 10.6, 13.4, 1.9, 1.6, 'k')                    -- os buracos dos olhos
    t:ell(cx - 0.6, 25.4, 15, 3.4, R.mat('vwWV', R.noise(p, 6), R.lum(cx, 25, 15, 4)))           -- o beiço de cima
    t:wire({ { cx - 4, 12.6 }, { cx - 1, 16.4 }, { cx - 5, 20.6 } }, 'B', 'D', 0.5); t:wire({ { cx - 1, 16.4 }, { cx + 5, 18 }, { cx + 6.6, 22 } }, 'B', 'D', 0.5)
  end, sol)
  d:layer(function(t)                                               -- braços: um de um lado, três do outro
    for n, q in ipairs({ { -10, 52, -12.6, 57.6 }, { 6, 53.6, 5, 58.4 }, { 10.6, 52.6, 12, 58 }, { 15, 50.6, 18, 56.4 } }) do
      local w = n > 1 and wig(n) or 0
      t:cap(cx + q[1], q[2], cx + q[3] + w, q[4], 1.7, 1.1, flesh('c21', cx + q[1], cx + q[1], q[2] + 2, 3, 5))
      hand(t, cx + q[3] + w, q[4], 1.9, 3.4)
    end
  end, sol)
  -- a boca: a poça em pé. Mais larga que a cabeça, sai do contorno do lado esquerdo
  local grow = alert and 1.08 or (crouch and 0.9 or 1)
  local function mouth(u, v)
    local t = sqrt(((u - MX) / (MRX * grow)) ^ 2 + ((v - MY) / (MRY * grow)) ^ 2)
    return t <= 1 and t or nil
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local t = mouth((x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k)
    if t then g[y][x] = t > 0.86 and 'U' or ((t > 0.15 and (x + y) % 2 == 0) and 'Y' or 'z') end
  end end
  -- o céu de lá: duas luas, cada uma no seu passo, e a linha de uma cidade de ponta-cabeça, que corre
  local drift = still and { 0, 0 } or { 3 * sin(t6), -2 * sin(2 * t6) }
  for n, q in ipairs({ { MX - 9, MY - 1.6, 2.2 }, { MX + 7, MY + 0.6, 1.3 } }) do
    local mx = q[1] + drift[n]
    for y = floor(d:Y(q[2] - q[3])), floor(d:Y(q[2] + q[3])) do for x = floor(d:X(mx - q[3])), floor(d:X(mx + q[3])) do
      local u, v = (x - d.ox - (k - 1) / 2) / k, (y - d.oy - (k - 1) / 2) / k
      local r = sqrt((u - mx) ^ 2 + (v - q[2]) ^ 2)
      if r <= q[3] and sqrt((u - mx - q[3] * 0.5) ^ 2 + (v - q[2] + q[3] * 0.3) ^ 2) > q[3] * 0.8 and ('zY'):find(L.get(g, x, y), 1, true) then g[y][x] = 'C' end
    end end
  end
  local roll = still and 0 or floor(fr * 12 + 0.5)
  for i = 0, 11 do
    local h = 1 + R.hash((i + roll) % 12, 3, 9) * 2.6
    d:wire({ { MX - 4 + i * 1.4, MY - MRY * 0.78 }, { MX - 4 + i * 1.4, MY - MRY * 0.78 + h } }, o.bust and '!' or 'U', nil, 0.5, 'zY')
  end
  if o.bust then RT.finish(g, o, RETRATO) end
  F.prune(g, '', 'rill_arquetipo')
  local list = {}                                                  -- a água da poça cai para cima
  for n = 0, 9 do
    local x = cx + ((n * 37) % 54) - 27
    list[#list + 1] = { x, (abs(x - cx - 1) < 18 and 4 or 16) + (n * 7) % 4 }
  end
  Rl.drops(d, sg, list, ph, NL, true)
end

Rl.run {
  name = 'rill_arquetipo', stage = 'arquetipo', W = 64, PW = 128, draw = draw, ownLean = true, DARK = '4',
  BODY_KEYS = { '1', '2', '3', '4', 'a', 'b', 'c', 'd', 'v', 'w', 'W', 'V' },
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  vao = { lit = 'UYCt', fill = 'z', mid = 'Y', edge = 'U' },
  -- o sapo inteiro, em 128: escala 1,85, margem de 5 px
  portrait = function(o)
    local g, sg = L.grid(128, 128), L.grid(128, 128)
    o.bust = true
    draw(g, sg, 1.85, o, 4.8, 3)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 30, 42 }, green = { 27, 45 }, water = { 29, 41 }, residential = { 29, 43 }, lit = { 29, 44 },
    sacred = { 29, 4 }, crimson = { 33, 42 },
  },
}
