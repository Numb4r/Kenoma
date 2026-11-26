-- Entidade Maior da família Rill (nome e pasta provisórios: rill_entidade), arte final a partir do conceito aprovado
-- da rodada 3, com o ajuste do dono. De frente (exceção aceita: estilo-criaturas.md, "Ângulo").
-- AJUSTE DO DONO: não é mais o Espírito maior. O corpo é o próprio meio-fio com a boca de lobo: um bloco de concreto
-- (a face de cima, a quina com a tinta amarela gasta, a verga, a grade, a soleira). Os três olhos de cururu ficam
-- sobre a grade, e da boca escorre água escura, que empoça embaixo. O sapo se lê só pelos olhos e pelas patas: as
-- duas pernas de trás dobradas, uma de cada lado do bloco, e as duas mãos que saem da boca e agarram a soleira.
-- REGRA QUEBRADA: a poça de cima do bloco reflete os três olhos, que estão do outro lado do corpo; e a chuva sobe.
-- Costura do Véu: uma, larga, na face do bloco, só no glow.
-- Camadas: corpo; leds = as nuvens da poça de cima (piscam); glow = o céu da poça, o brilho da água atrás da grade e
-- da que escorre, a costura e as gotas que sobem.
-- Animação (6 quadros, lenta): os olhos piscam um de cada vez e o do meio gira a pupila, a água escorre (as faixas
-- descem), o céu anda na poça, os joelhos mexem. No alerta os três olhos abrem e a água engrossa; na antecipação fecham.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rill_entidade/build.lua')
local Rl = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rill.lua')
local L, R, F = Rl.L, Rl.R, Rl.F
local floor, abs, sin, pi = math.floor, math.abs, math.sin, math.pi
local hide, ceye = Rl.hide, Rl.ceye

local SOL = ''
for ch in pairs(Rl.LEG) do if not Rl.NOPULL:find(ch, 1, true) then SOL = SOL .. ch end end
local cx = 23.5

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t6 = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local d = R.ctx(g.w, k, ox, oy + math.min(0, o.dy or 0)); d.g = g   -- o bloco não afunda no chão
  local p = d:pp()
  local flow = still and 0 or ph
  local knee = still and 0 or 0.6 * sin(t6)
  local fat = alert and 1.4 or 1
  d:layer(function(t)                                               -- pernas de trás dobradas, o joelho para cima
    for _, s in ipairs({ -1, 1 }) do
      local kx, ky = cx + s * 19.6, 26.4 - knee * s
      t:cap(cx + s * 13, 37, kx, ky, 3.8, 2.7, hide('abcd', p, cx + s * 17, 32, 5, 6))
      t:cap(kx, ky, cx + s * 18.6, 41.4, 2, 1.3, hide('abcd', p, cx + s * 19, 35, 3, 8))
      for i = -1, 1 do t:wire({ { cx + s * 18.6, 41.4 }, { cx + s * (19.4 + i * 2.1), 44.6 } }, 'c', 'd', 0.6) end
    end
  end, o.dark and '' or SOL)
  d:layer(function(t)
    -- a poça de água escura embaixo
    t:ell(cx, 42.6, 15.6, 2.6, function(x, y, u, v) return (y % 2 == 0 and (x + flow * 2) % 11 == 0) and 'u' or (y % 2 == 0 and 'n' or 'k') end)
    -- o bloco: a face de cima, com a poça que reflete os olhos
    t:poly({ { 12.4, 9 }, { 34.6, 9 }, { 38.6, 16.6 }, { 8.4, 16.6 } }, R.mat('jiI', R.noise(p, 4), function(u, v) return 0.9 - abs(u - cx) / 30 end))
    t:ell(cx, 12.9, 12, 3.2, 'r'); t:ell(cx, 12.8, 11.2, 2.7, Rl.sky(12.8, 2.7, flow))
    for i = -1, 1 do t:ell(cx + i * 4.6, 13.2, 0.8, 0.5, i == 0 and 'k' or 'O') end
    -- a face da frente
    t:rect(8.4, 16.8, 38.6, 40, function(x, y, u, v)
      local a = abs(u - cx)
      if v < 19 then                                                -- a quina, com a tinta amarela gasta
        return (R.hash(x // (2 * p), 0, 7) > 0.4) and R.pick('pP', 0, R.chk(p)(x, y)) or R.pick('iI', 0, R.noise(p, 4)(x, y))
      end
      if v >= 23.6 and v < 34 and a < 12.6 then                       -- a boca de lobo: grade e água atrás
        if a > 11.8 or v < 24.2 then return 'J' end
        if (floor(u * 2 + 0.5) % 6) == 0 then return v < 25.6 and 'j' or 'J' end
        if v > 30 then return ((y + flow) % 3 == 0) and 'r' or 'k' end
        return (y % 2 == 0 and (x + y) % 7 == 0) and 'r' or 'k'
      end
      if v >= 34 and v < 35.4 and a < 13.2 then return (x + flow) % 4 == 0 and 'n' or 'i' end   -- a soleira, molhada
      if abs(u - 33 - sin(v * 0.6)) < 0.4 and v > 19.6 and v < 23 then return 'J' end           -- trinca na verga
      return R.pick('Jji', 0.85 - (v - 19) / 26 - a / 60, R.noise(p, 4)(x, y))
    end)
    -- a água escura escorre da boca pela frente do bloco
    for n, q in ipairs({ { -9, 1.5 }, { -1.5, 2.3 }, { 6.5, 1.3 }, { 11, 0.9 } }) do
      t:rect(cx + q[1] - q[2] * fat / 2, 35.4, cx + q[1] + q[2] * fat / 2, 41, function(x, y, u, v)
        if (y + flow * 2 + n) % 7 == 0 and (x + n) % 3 == 0 then return 'u' end                 -- um brilho de 1 px
        return (y + flow + n) % 2 == 0 and 'n' or 'k'
      end)
    end
    t:suture({ { 11.4, 20.6 }, { 9.8, 25.6 }, { 11, 30.6 }, { 10, 33.6 } }, '9', 1.5, k > 1 and 3 or nil, Rl.CONC)   -- a costura
    -- os olhos, sobre a grade: o calombo de pele e o olho; piscam um de cada vez
    for i = -1, 1 do
      local ex, ey = cx + i * 9, 26.8 - (i == 0 and 0.6 or 0)
      local shut = crouch or (not still and floor(ph * 6 / NL) == (i + 2) * 2 - 1)
      t:ell(ex, ey - 0.9, 3.4, 3.0, hide('bcde', p, ex, ey - 1, 3.1, 2.7))
      if shut then ceye(t, ex, ey, 2.2, false, true) else
        t:ell(ex, ey, 2.6, 2.2, 'H'); t:ell(ex, ey - 0.8, 2.3, 1.0, 'Z', 'H')
        if i == 0 and (still or ph % 2 == 0) then t:ell(ex, ey, 0.7, 1.8, 'k') else t:ell(ex, ey, 2.0, 0.7, 'k') end
      end
    end
  end, o.dark and '' or SOL)
  d:layer(function(t)                                               -- as mãos saem da boca e agarram a soleira
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 5.4, 32.4, cx + s * 6.2, 36.4, 1.5, 1.2, hide('bcde', p, cx + s * 6, 34, 3, 4))
      for i = -1, 1 do t:wire({ { cx + s * 6.2, 36.4 }, { cx + s * (6.6 + i * 1.9), 39 } }, 'd', 'c', 0.5) end
    end
  end, o.dark and '' or SOL)
  F.prune(g, '', 'rill_entidade')
  -- a chuva sobe
  Rl.drops(d, sg, { { 4, 19 }, { 7.6, 9 }, { 40.6, 8 }, { 43.6, 18 }, { 23, 6 }, { 15, 5 }, { 32.6, 5 }, { 2.6, 12 }, { 45, 11 }, { 28, 4 } }, ph, NL, true)
end

Rl.run {
  name = 'rill_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, ownLean = true, DARK = 'J',
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o, 0, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 30, 20 }, green = { 27, 20 }, water = { 29, 19 }, residential = { 29, 20 }, lit = { 29, 20 },
    sacred = { 19, 6 }, crimson = { 34, 19 },
  },
}
