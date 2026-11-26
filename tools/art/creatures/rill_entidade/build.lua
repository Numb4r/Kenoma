-- Entidade Maior da família Rill (nome e pasta provisórios: rill_entidade), arte final a partir do conceito aprovado
-- da rodada 3, com o ajuste do dono. De frente (exceção aceita: estilo-criaturas.md, "Ângulo").
-- AJUSTE DO DONO (o bloco lia como caixote ou máquina): é o sapo agachado, feito de concreto de meio-fio. Cabeça larga
-- e chata, torta, com os calombos dos olhos saltados em cima (de pele); dorso e barriga redondos, de concreto; pernas
-- de trás dobradas e braços da frente plantados, de pele. A boca de lobo é a boca: uma fenda de lado a lado, a verga
-- com a tinta amarela gasta, a grade como dentes, a soleira molhada, e água escura escorrendo pela barriga até a poça.
-- O terceiro olho está fora do lugar, no joelho direito, com a pupila em pé. Nada de caixa simétrica.
-- REGRA QUEBRADA: a chuva sobe; e a poça de baixo reflete três olhos em fila, que no corpo não estão assim.
-- Costura do Véu: uma, larga, no flanco esquerdo, só no glow.
-- Camadas: corpo; leds = os três olhos e os reflexos deles na poça (piscam); glow = a água atrás da grade, o brilho
-- dos fios e da poça, a costura e as gotas que sobem.
-- Animação (6 quadros, lenta): os olhos piscam um de cada vez, a água escorre (as faixas descem), a barriga respira,
-- os joelhos mexem (o olho do joelho vai junto). No alerta os três olhos abrem e a água engrossa; na antecipação fecham.
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
  local puff = still and 0 or 0.4 * sin(t6)
  local sol = o.dark and '' or SOL
  -- concreto de meio-fio: quatro degraus, poros, luz de cima à esquerda
  local function conc(lx, ly, rx, ry, seed)
    local lm, nz = R.lum(lx, ly, rx, ry), R.noise(p, seed or 4)
    return function(x, y, u, v)
      if R.hash(x, y, 17) > 0.955 then return 'J' end
      return R.pick('JjiI', lm(u, v), nz(x, y))
    end
  end
  local function eye(t, ex, ey, r, shut, rot)
    if shut then ceye(t, ex, ey, r * 0.85, false, true) return end
    t:ell(ex, ey, r, r * 0.85, 'H'); t:ell(ex, ey - r * 0.3, r * 0.88, r * 0.4, 'Z', 'H')
    if rot then t:ell(ex, ey, r * 0.27, r * 0.7, 'k') else t:ell(ex, ey, r * 0.77, r * 0.27, 'k') end
  end
  local function blink(n) return crouch or (not still and floor(ph * 6 / NL) == n * 2 - 1) end
  local KX, KY = cx + 19.6, 26.4 - knee
  d:layer(function(t)                                               -- pernas de trás dobradas, o joelho para cima
    for _, s in ipairs({ -1, 1 }) do
      local kx, ky = cx + s * 19.6, 26.4 - knee * s
      t:cap(cx + s * 13, 37, kx, ky, 3.8, 2.7, hide('abcd', p, cx + s * 17, 32, 5, 6))
      t:cap(kx, ky, cx + s * 18.6, 41.4, 2, 1.3, hide('abcd', p, cx + s * 19, 35, 3, 8))
      for i = -1, 1 do t:wire({ { cx + s * 18.6, 41.4 }, { cx + s * (19.4 + i * 2.1), 44.6 } }, 'c', 'd', 0.6) end
    end
    -- o terceiro olho, fora do lugar: no joelho direito, com a pupila em pé
    eye(t, KX - 0.6, KY + 0.6, 2.3, blink(3), true)
  end, sol)
  d:layer(function(t)
    -- a poça de água escura embaixo: reflete três olhos em fila, que no corpo não estão assim
    t:ell(cx, 43, 16, 2.5, function(x, y, u, v)
      local m = (x + flow * 2 + (y // 2) * 3) % 5
      if y % 2 == 0 then return m < 3 and 'B' or (m == 3 and 'D' or 'n') end
      return 'k'
    end)
    for i = -1, 1 do t:ell(cx + i * 5.4, 43, 1.4, 0.6, 'H') end
    -- o dorso e a barriga: redondo, de concreto, com a junta do meio-fio
    t:ell(cx + 0.5, 32.4, 16.4 + puff, 10.6, function(x, y, u, v)
      if abs(u - (cx + 7.4) - 0.8 * sin(v * 0.5)) < 0.45 and v > 30 then return 'J' end
      return conc(cx, 31, 16.4, 12, 6)(x, y, u, v)
    end)
    t:suture({ { cx - 13.4, 29.6 }, { cx - 14.8, 33.6 }, { cx - 12.4, 38.4 } }, '9', 1.4, k > 1 and 3 or nil, Rl.CONC)   -- a costura
  end, sol)
  -- a cabeça: larga e chata, torta (o lado esquerdo cai); a boca de lobo é a boca
  local function my(u) return 25.2 - (u - cx) * 0.045 end
  local function hh(u) local a = abs(u - cx) / 13.4; return a < 1 and 3.1 * (1 - a * a) ^ 0.35 or -1 end
  d:layer(function(t)
    t:ell(cx, 20.4, 17.6, 9.6, function(x, y, u, v)
      local m, h = my(u), hh(u)
      local a = abs(u - cx)
      if h > 0 and abs(v - m) < h then                              -- a fenda: a grade são os dentes, a água escura atrás
        if v - m < -h + 0.8 then return 'J' end
        local n = floor((u - cx + 15) / 2.4)
        local f = ((u - cx + 15) / 2.4) % 1
        if f < 0.42 then
          if n % 2 == 0 then return v < m - 0.4 and 'I' or 'i' end   -- a barra inteira
          if v < m + 0.3 then return 'I' end                         -- a barra quebrada: só o toco de cima
        end
        if v > m + h - 2.1 then return ((x + y + flow) % 3 == 0) and 'D' or 'B' end   -- a água atrás da grade, com brilho
        return (y % 2 == 0 and (x + y) % 7 == 0) and 'r' or 'k'
      end
      if h > 0 and v >= m + h and v < m + h + 1.2 then return (x + flow) % 3 == 0 and 'B' or 'i' end   -- a soleira, molhada
      if v < m - (h > 0 and h or 0) and v > m - (h > 0 and h or 0) - 2.3 and a < 15.4 then       -- a verga: a tinta amarela gasta
        return (R.hash(x // (2 * p), 0, 7) > 0.38) and R.pick('pP', 0, R.chk(p)(x, y)) or R.pick('iI', 0, R.noise(p, 4)(x, y))
      end
      if abs(u - (cx + 10.6) - sin(v * 0.7)) < 0.42 and v > 13.4 and v < 19.6 then return 'J' end   -- trinca
      return conc(cx, 19, 17.6, 9.6)(x, y, u, v)
    end)
    -- os calombos dos olhos, saltados em cima; o esquerdo é maior e mais baixo
    for n, q in ipairs({ { cx - 8.8, 12.2, 4.3 }, { cx + 8.4, 10.8, 3.7 } }) do
      t:ell(q[1], q[2], q[3], q[3] * 0.94, hide('bcde', p, q[1], q[2], q[3], q[3]))
      eye(t, q[1] + (n == 1 and 0.3 or -0.3), q[2] + 0.4, q[3] * 0.72, blink(n), false)
    end
  end, sol)
  d:layer(function(t)                                               -- a água escura escorre da boca, pela barriga, até a poça
    -- quatro fios desiguais; só os dois do meio chegam à poça, e cada um serpenteia no seu passo
    for n, q in ipairs({ { -5.8, 1.4, 37 }, { -1.4, 2.6, 42.4 }, { 3.2, 1.4, 42.4 }, { 6.4, 0.9, 34.6 } }) do
      local u0 = cx + q[1]
      local v0 = my(u0) + hh(u0) - 0.6
      t:rect(u0 - 2.5, v0, u0 + 2.5, q[3], function(x, y, u, v)
        local w = q[2] * fat / 2 * (1 - 0.45 * (v - v0) / (42.4 - v0))
        if abs(u - u0 - 0.7 * sin(v * 0.55 + n * 2)) > w then return nil end
        if (y + flow * 2 + n) % 3 == 0 and (x + n) % 2 == 0 then return 'B' end                 -- um brilho de 1 px
        return (y + flow + n) % 2 == 0 and 'n' or 'k'
      end)
    end
  end, false)
  d:layer(function(t)                                               -- os braços da frente, plantados dos lados da água
    for _, s in ipairs({ -1, 1 }) do
      t:cap(cx + s * 10.6, 31, cx + s * 9.4, 40.8, 1.9, 1.3, hide('bcde', p, cx + s * 10, 35, 3, 6))
      for i = -1, 1 do t:wire({ { cx + s * 9.4, 40.8 }, { cx + s * (9.4 + i * 1.9) - s * 0.8, 43.8 } }, 'd', 'c', 0.5) end
    end
  end, sol)
  F.prune(g, '', 'rill_entidade')
  -- a chuva sobe
  Rl.drops(d, sg, { { 4, 19 }, { 7.6, 9 }, { 40.6, 8 }, { 43.6, 18 }, { 23, 4 }, { 15, 5 }, { 32.6, 5 }, { 2.6, 12 }, { 45, 11 }, { 28, 3 },
    { 19, 8 }, { 36.6, 9 }, { 11, 6 }, { 44, 22 }, { 3, 24 }, { 26, 7 },
    { 9.6, 5 }, { 38, 6 }, { 1.6, 17 }, { 20.6, 5 }, { 45.6, 15 }, { 30, 7 } }, ph, NL, true)
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
    -- na testa, entre os calombos dos olhos (acima da verga)
    urban = { 21, 14 }, green = { 18, 15 }, water = { 20, 13 }, residential = { 20, 14 }, lit = { 20, 15 },
    sacred = { 20, 4 }, crimson = { 22, 13 },
  },
}
