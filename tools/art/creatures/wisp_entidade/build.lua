-- Entidade Maior da família Wisp (nome e pasta provisórios: wisp_entidade), arte final a partir do conceito aprovado
-- da rodada 2: o velário de pé. O tronco é um feixe de velas derretidas umas nas outras; as asas abertas são duas
-- prateleiras de tocos de vela; em cima, a cara da coruja está de ponta-cabeça (bico para o alto, sobrancelha
-- embaixo) e sem olhos: as órbitas são ocas e delas descem os olhos de vela. Três pernas compridas de coruja, em
-- tripé, saem da toca, num monte de cera.
-- REGRA QUEBRADA: a chama queima para baixo e a cera pinga para cima. As chamas descem das órbitas e por baixo das
-- asas, e soltam fogo que cai; dos tocos, da cabeça e do monte sobem fios de cera.
-- Costuras do Véu: duas, largas: 3 px na raiz da asa esquerda e 2 px numa cinta no tronco de cera.
-- Camadas: corpo; leds = os dois olhos de vela que descem das órbitas (piscam); glow = as chamas dos tocos e da toca,
-- as costuras, o fogo que cai e o frio solto.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; as asas balançam em gangorra; cada chama cresce e
-- encolhe no seu passo; os fios de cera sobem e recolhem; na deriva o tripé anda fora de fase e a cara vai à frente.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wisp_entidade/build.lua')
local Wi = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wisp.lua')
local L, R = Wi.L, Wi.R
local floor, abs, max, sin, cos = math.floor, math.abs, math.max, math.sin, math.cos

local WING = { { 2.6, 17.4 }, { 21.4, 14.2 }, { 22, 16.6 }, { 18.4, 20.6 }, { 14.6, 19.4 }, { 11, 22.6 }, { 7.4, 21 }, { 3.6, 25 } }
local LEGS = { { -1, 14.6, 35, 12.4, 41.4 }, { 0, 24.6, 36, 23.6, 41.6 }, { 1, 33, 35, 35, 41.6 } }

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t = ph / NL * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k                                   -- o tronco
  local f = o.jump and b or 0                                 -- os pés e o monte
  local d = R.ctx(g.w, k); d.g = g
  local p = d:pp()
  local SOL = (not o.dark) and Wi.SOLID                       -- false: a silhueta do spawn não tem contorno de dentro
  local LEGSOL = SOL and (SOL:gsub('[fl]', ''))
  local cx = 23.5
  local lx = o.lean and 1 or 0                                -- na deriva só a cara e o alto do tronco vão à frente
  local hx = 0
  local rl = alert and -1.6 or (crouch and 1.8 or 1.2 * sin(t))   -- a gangorra das asas
  local rr = alert and -1.6 or (crouch and 1.8 or -1.2 * sin(t))
  local gain = alert and 1.3 or (crouch and 0.6 or 1)
  local function wob(n, a) return still and 0 or a * sin(t + n * 1.3) end
  local function wy(s, x, y) return y + b + (s < 0 and rl or rr) * (abs(x - cx) - 2.6) / 19 end
  local function fl(u, v, len, w, chars) Wi.flame(g, d:X(u), d:Y(v), 90, len * k, w * k, chars) end
  -- o monte de cera com a toca
  d:layer(function(q)
    q:poly({ { 12, 44.6 + f }, { 15, 40.6 + f }, { 21, 39.4 + f }, { 28, 39.6 + f }, { 33, 41 + f }, { 35.6, 44.6 + f } },
      R.mat('123', R.ver(p), function(u) return 0.9 - (u - 12) / 26 end))
    q:ell(cx + 0.4, 42.6 + f, 3.4, 1.7, 'k')
  end, SOL)
  -- as três pernas (finas: sem contorno)
  d:layer(function(q)
    for n, c in ipairs(LEGS) do
      local sx = o.lean and 1.2 * sin(t + n * 2.1) or 0
      local up = o.lean and max(0, cos(t + n * 2.1)) * 0.8 or 0
      local fx, fy = c[4] + sx, c[5] + f - up
      q:wire({ { cx + c[1] * 1.6, 29 + b }, { c[2] + sx * 0.5, c[3] + (b + f) / 2 }, { fx, fy } }, 'f', 'l', 1)
      for _, dx in ipairs({ -1.6, 0, 1.6 }) do q:wire({ { fx, fy }, { fx + dx, fy + 1.8 } }, 'l', nil, 0.5) end
    end
  end, LEGSOL)
  -- o tronco de cera e as asas abertas: duas prateleiras de velas
  local FL, DRIP = {}, {}
  d:layer(function(q)
    q:cap(cx + lx * 0.5, 18 + b, cx, 29.4 + b, 3.6, 2.4, R.mat('123', R.ver(p), function(u) return 0.85 - (u - (cx - 3.6)) / 7.2 end))
    for _, s in ipairs({ -1, 1 }) do
      local pts = {}
      for i, w in ipairs(WING) do pts[i] = { cx + s * w[1] + hx, wy(s, cx + s * w[1], w[2]) } end
      local fe = Wi.feather('abcd', p, 7, 0.1)
      q:poly(pts, function(x, y, _, v) return fe(x, y, 0.85 - (v - 14 - b) / 10 - (s > 0 and 0.15 or 0)) end)
      for i = 1, 4 do                                         -- tocos de vela em cima da asa
        local x = cx + s * (4.4 + i * 3.7)
        local top = wy(s, x, 17.4 - (abs(x - cx) - 2.6) * 0.17)
        q:rect(x + hx - 0.9, top - 3.6 + (i % 2), x + hx + 0.9, top, R.mat('123', R.ver(p), s > 0 and 0.3 or 0.7))
        q:wire({ { x + hx, top - 4.2 + (i % 2) }, { x + hx, top - 3.8 + (i % 2) } }, 'k', nil, 0.5)
        FL[#FL + 1] = { x + hx, top + 2 }
        if i == 3 or i == 4 then DRIP[#DRIP + 1] = { x + hx + (i == 3 and s * 0.9 or 0), top - 3, top - 8 + i } end
      end
    end
  end, SOL)
  -- costuras do Véu: duas, largas
  Wi.seam(d, { { cx - 7.4 + hx, wy(-1, cx - 7.4, 16.2) }, { cx - 5.4 + hx, wy(-1, cx - 5.4, 22.8) } }, floor(3 * k + 0.5), 'X', Wi.FEATHER, k > 1 and 2.4 or nil)
  Wi.seam(d, { { cx - 4, 24 + b }, { cx + 4, 25.2 + b } }, floor(2 * k + 0.5), '9', Wi.WAX, k > 1 and 2 or nil)
  -- a cara, de ponta-cabeça
  local fx, fy = cx + lx, 12 + b
  d:layer(function(q)
    local fe = Wi.feather('abcd', p, 3, 0.14)
    q:ell(fx, fy, 6.2, 5.2, function(x, y, _, v) return fe(x, y, 0.5 + (v - fy) / 12) end)
    q:wire({ { fx - 5, fy + 1.6 }, { fx - 1.6, fy + 3.6 }, { fx, fy + 2.6 }, { fx + 1.6, fy + 3.6 }, { fx + 5, fy + 1.6 } }, 'e', nil, 0.6)   -- a sobrancelha, embaixo
    q:poly({ { fx - 1.1, fy - 1.4 }, { fx, fy - 4.6 }, { fx + 1.1, fy - 1.4 } }, R.mat('fl', R.ver(p), 0))                                   -- o bico, para o alto
    q:ell(fx - 3, fy + 0.4, 1.5, 1.4, 'k'); q:ell(fx + 3, fy + 0.4, 1.5, 1.4, 'k')
  end, SOL)
  -- a cera pinga para cima: os fios sobem e recolhem
  local ups = { { fx - 4, fy - 2.8, fy - 8.6 }, { fx + 2.6, fy - 3.4, fy - 7.8 }, { 15, 42.2 + f, 36.4 + f }, { 33, 42.6 + f, 37.4 + f } }
  for _, q in ipairs(DRIP) do ups[#ups + 1] = q end
  for n, q in ipairs(ups) do
    d:wire({ { q[1], q[2] }, { q[1], q[3] + 0.9 + wob(n * 1.7, 0.9) } }, 'i', 'j', 0.5)
  end
  -- as chamas descem: das órbitas (os olhos), por baixo das asas (a vela queima através dela) e três dentro da toca
  local e1, e2 = 10 * gain + wob(0, 1.4), 13 * gain - wob(0, 1.4)
  fl(fx - 3, fy + 0.6, e1, 2.6, 'FGH'); fl(fx + 3, fy + 0.6, e2, 2.6, 'FGH')
  for n, q in ipairs(FL) do fl(q[1], q[2], (4.8 + (n % 2) * 1.4) * gain + wob(n, 1.2), 1.7, 'BDE') end
  for n, dx in ipairs({ -1.8, 0.2, 2 }) do fl(cx + dx, 42 + f, 2.6 + wob(n * 2, 0.5), 1.4, 'BDE') end
  -- o fogo que cai dos olhos e o frio solto, que também desce
  if not still then
    Wi.dot(g, sg, d:X(fx - 3), d:Y(fy + 1.6 + e1 + (ph % 3) * 1.2), k, 's')
    Wi.dot(g, sg, d:X(fx + 3), d:Y(fy + 1.6 + e2 + ((ph + 1) % 3) * 1.2), k, 'S')
  end
  for n, e in ipairs({ { 6, 28 }, { 4, 34 }, { 41, 26 }, { 43.6, 33 }, { 9, 10 }, { 39, 7 }, { 12.6, 3 }, { 34, 3.6 }, { 6.6, 20 }, { 42, 17 } }) do
    local r = (ph + n) % NL
    if r < NL - 1 then Wi.dot(g, sg, d:X(e[1]), d:Y(e[2] + r * 0.9), k, n % 3 == 0 and 's' or (n % 3 == 1 and 'S' or 'T')) end
  end
end

Wi.run {
  name = 'wisp_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, NOPULL = Wi.NOPULL .. 'fl',
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 48 ampliado 2 vezes, com a textura mais fina e os pontos nas costuras
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 26 }, green = { 18, 21 }, water = { 20, 17 }, residential = { 20, 19 }, lit = { 20, 28 },
    sacred = { 20, 6 }, crimson = { 22, 20 },
  },
}
