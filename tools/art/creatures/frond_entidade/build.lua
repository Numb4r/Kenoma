-- Entidade Maior da família Frond (nome e pasta provisórios: frond_entidade), arte final a partir do conceito
-- aprovado: a calçada inteira. Um disco de laje partido em três por uma rachadura em espiral (o desenho do
-- Tribrachidium), três frondes em cata-vento saindo da borda, sete raízes embaixo como pernas, nenhum rosto.
-- REGRA QUEBRADA: a rachadura não para na pedra. Os três braços da espiral continuam pelo ar, acesos, para além da
-- borda da laje, e a luz corre por eles para fora.
-- Costuras do Véu: duas, de 3 px: uma atravessa a laje de borda a borda (a pedra emendada) e uma corta os lobos de uma
-- fronde.
-- Camadas: corpo; leds = o broto na ponta de cada fronde (pisca); glow = a rachadura, as nervuras, as costuras, a
-- rachadura no ar e os esporos.
-- Bicho de chão: a laje sobe e desce (body_dy) e as raízes ficam; a espiral aperta e solta; as frondes balançam em
-- cata-vento; na deriva as raízes andam fora de fase.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/frond_entidade/build.lua')
local Fr = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_frond.lua')
local L, F = Fr.L, Fr.F
local floor, abs, sqrt, sin, cos, rad = math.floor, math.abs, math.sqrt, math.sin, math.cos, math.rad
local CONC = Fr.CONC

-- raízes: ângulo e raio do quadril na laje, depois joelhos e pé (no chão)
local ROOTS = {
  { 60, 8, { 31, 37 }, { 34.6, 40 }, { 33.6, 44.4 } }, { 80, 8, { 26.6, 38 }, { 28.4, 41.4 }, { 27, 44.6 } },
  { 100, 8, { 20.4, 38 }, { 18.6, 41.4 }, { 20, 44.6 } }, { 120, 8, { 16, 37 }, { 12.4, 40 }, { 13.4, 44.4 } },
  { 90, 8, { 23.5, 39 }, { 23.5, 41.4 }, { 23, 43.6 } }, { 140, 9, { 11, 34 }, { 7.6, 38 }, { 8.4, 42.6 } },
  { 40, 9, { 36, 34 }, { 39.4, 38 }, { 38.6, 42.6 } },
}

local function draw(g, sg, k, o)
  local P = F.pen(g, k, 0, 0)
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t = ph / NL * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k + (crouch and 1 or 0)            -- a laje
  local f = o.jump and (o.dy or 0) / k or 0                  -- as raízes
  local rot = (still and 0 or 3 * sin(t)) - (o.lean and 5 or 0) + (alert and 4 or (crouch and -6 or 0))
  local tw = 7 + (alert and 1.6 or (crouch and -1.2 or 0.9 * sin(t)))   -- a espiral aperta e solta
  local cx, cy, R = 23.5, 23.6 + b, 9.6
  local function pol(a, r) return { cx + cos(rad(a)) * r, cy + sin(rad(a)) * r } end
  for n, r in ipairs(ROOTS) do
    local s = o.lean and 1.1 * sin(t + n * 2.1) or 0          -- o passo, fora de fase
    local up = o.lean and math.max(0, cos(t + n * 2.1)) * 0.8 or 0
    local m = (b + f) / 2
    P:limb({ pol(r[1], r[2]), { r[3][1], r[3][2] + m }, { r[4][1] + s * 0.5, r[4][2] + f - up * 0.5 }, { r[5][1] + s, r[5][2] + f - up } },
      1.5, 0.55, 'h')
  end
  -- três frondes em cata-vento: a raiz de cada uma fica na laje, a ponta balança
  local all, tips, fronds = {}, {}, {}
  for n = 0, 2 do
    local a = -100 + n * 120
    local st = {}
    for j, q in ipairs({ { 0, R - 2 }, { 16, R + 2.6 }, { 34, R + 5 }, { 54, R + 6.4 }, { 72, R + 6.4 } }) do
      st[j] = pol(a + q[1] + rot * (j - 1) / 4, q[2])
    end
    local lb = Fr.frond(P, st, { n = 6, t0 = 0.1, t1 = 0.97, ang = 56, r0 = 1.0, r1 = 0.5,
      w = function(u) return (1.8 + 3.4 * sin(3.14 * (0.12 + 0.8 * u))) * (alert and 1.08 or 1) end,
      wag = function(i) return still and 0 or 4 * sin(t + i * 0.8 + n * 2.1) end,
      mat = function(i) local m = (i + n) % 4; if m == 1 then return 'y', 'J' elseif m == 3 then return 'g', 'n' end return 'f', 'a' end })
    for _, q in ipairs(lb) do all[#all + 1] = q end
    tips[#tips + 1] = st[#st]
    fronds[#fronds + 1] = lb
  end
  -- o disco de laje e a rachadura em espiral
  local X0, Y0 = P:X(cx), P:Y(cy)
  local air = {}
  for y = 0, S - 1 do for x = 0, S - 1 do
    local dx, dy = (x - X0) / k, (y - Y0) / k
    local d = sqrt(dx * dx + dy * dy)
    local an = math.deg(math.atan(dy, dx))
    local edge = R + (F.rnd(floor((an + 180) / 12), 1, 4) - 0.5) * 1.6
    local best = 99                                           -- o braço da espiral mais perto
    for n = 0, 2 do
      local diff = ((an - (-100 + n * 120 + d * tw) + 180) % 360) - 180
      best = math.min(best, abs(diff) * d * 0.01745)
    end
    local wcr = d < 2 and 1.4 or (0.9 - d * 0.03)
    if d <= edge then
      if best < wcr * 0.5 + 0.2 then g[y][x] = (best < 0.35) and 'E' or 'D'
      else
        local sector = floor(((an + 100 - d * 7) % 360) / 120)
        local tile = (floor((dx * cos(sector) + dy * sin(sector)) / 3) + floor((-dx * sin(sector) + dy * cos(sector)) / 3)) % 2
        local lt = (-dx - dy) / (R * 1.414)
        local idx = (lt > 0.25 and 0 or lt > -0.3 and 1 or 2) + tile
        g[y][x] = CONC:sub(math.min(4, idx + 1), math.min(4, idx + 1))
      end
    elseif d <= edge + 10 and best < 0.75 and y >= 2 * k and y < S - 2 * k and x >= k and x < S - k then
      air[#air + 1] = { x, y, d - edge }
    end
  end end
  -- a espessura da laje, embaixo
  for y = S - 2, 0, -1 do for x = 0, S - 1 do
    if CONC:find(g[y][x], 1, true) or g[y][x] == 'D' or g[y][x] == 'E' then
      for s = 1, floor(1.6 * k) do
        local c = L.get(g, x, y + s)
        if y + s < S and (c == '.' or c == 'h') then g[y + s][x] = (x // k) % 3 == 0 and 'k' or 'J' else break end
      end
    end
  end end
  Fr.shadeAll(g, k)
  Fr.veins(g, P, k > 1 and all or nil, Fr.LEAF .. Fr.DRY, ph, NL == 6 and 6 or 4)
  -- costuras do Véu: duas, largas
  local w = math.max(1, floor(3 * k + 0.5))
  Fr.seam(P, { { cx - 8.6, cy - 4.6 }, { cx - 3.6, cy + 8.6 } }, w, '9', CONC, k > 1 and 2.4 or nil)
  local lb = fronds[2]
  Fr.seam(P, { { lb[4][3], lb[4][4] }, { lb[9][3], lb[9][4] } }, w, 'X', Fr.LEAF, k > 1 and 2.4 or nil)
  -- o broto na ponta de cada fronde
  for _, q in ipairs(tips) do
    if k > 1 then P:disc(q[1], q[2], 0.5, 'H', 'DEBm') end
    P:px(q[1], q[2], 'G')
  end
  Fr.clean(g, 'frond_entidade', 'a', 4 * k * k)
  -- a rachadura continua pelo ar (solta, só no glow): a luz corre para fora
  local per = NL / 2
  for _, q in ipairs(air) do
    if g[q[2]][q[1]] == '.' and (still or (q[3] * 1.5 - ph) % per < per * 0.72) then
      sg[q[2]][q[1]] = q[3] < 3.4 and 's' or (q[3] < 7 and 'S' or 'T')
    end
  end
  Fr.spores(P, sg, { { 5, 8 }, { 43, 14 }, { 40, 44 }, { 4.6, 30 }, { 24, 4.6 } }, ph, NL)
end

Fr.run {
  name = 'frond_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, DARK = 'J', ownLean = true,
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 48 ampliado 2 vezes, com os lobinhos e o fio de cada lobo
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 19 }, green = { 18, 15 }, water = { 20, 23 }, residential = { 20, 21 }, lit = { 20, 26 },
    sacred = { 20, 11 }, crimson = { 15, 21 },
  },
}
