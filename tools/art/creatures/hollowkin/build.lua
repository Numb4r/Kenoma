-- Hollowkin (wisp.spirit), arte final: o Espírito da família Wisp, a partir do conceito aprovado. O manto de penas da
-- coruja ficou de pé e vazio.
-- ELEMENTO ERRADO (o que o Eco não tem): a vela tomou o corpo por dentro. Não há coruja dentro das penas: o peito é
-- uma fenda oca e, no lugar dele, queima uma vela inteira, que ilumina a borda da fenda por dentro. Do bicho sobram o
-- bico no escuro do capuz e os olhos de vela, agora três (dois do mesmo lado). Um ombro derreteu em cera, sobra uma
-- perna só, e no lugar da outra escorre cera.
-- Costuras do Véu: duas, de 2 px (o lado de penas do manto e o ombro de cera), só no glow.
-- Camadas: corpo; leds = os três olhos de vela (piscam, cada chama no seu passo); glow = a vela do peito, a luz dela
-- na borda da fenda, as costuras e o frio solto.
-- Bicho de chão: o manto sobe e desce (body_dy) e a perna e a coluna de cera ficam; a barra em farrapos balança; na
-- deriva o capuz vai à frente e ela anda na perna só; na fuga, salta. No alerta a fenda abre e as chamas crescem.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/hollowkin/build.lua')
local Wi = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wisp.lua')
local L, F = Wi.L, Wi.F
local floor, abs, max = math.floor, math.abs, math.max

-- o manto: { x, y, lado da barra (a ponta balança) }
local CLOAK = { { 14.6, 2.4 }, { 18, 3 }, { 21, 4.6 }, { 22.6, 8 }, { 21.6, 11.8 }, { 26.4, 14.6 }, { 27.2, 22 }, { 26.6, 29.6 },
  { 25, 31.4, 1 }, { 23.4, 29.4 }, { 21.8, 31.6, -1 }, { 20, 29.6 }, { 18.4, 31.2, 1 }, { 16.6, 29.4 }, { 15, 31.6, -1 }, { 13.2, 29.6 },
  { 11.6, 31.4, 1 }, { 10, 29.4 }, { 8.4, 30.6, -1 }, { 7.8, 22 }, { 8.6, 14.6 }, { 13.4, 11.8 }, { 12.4, 8 }, { 13.4, 4.6 } }
local MELT = { { 20.4, 4.4 }, { 22.6, 8 }, { 22.4, 11.6 }, { 26.4, 14.6 }, { 27, 20.4 }, { 25.8, 17.6 }, { 24.8, 22.4 }, { 23.6, 16.6 },
  { 22.6, 19.4 }, { 21.8, 13 }, { 20.8, 10 } }

local function draw(g, sg, k, o)
  local X, Y = Wi.scale(k, o.ox, o.oy)
  local P = F.pen(g, k, o.ox or 0, o.oy or 0)
  local p = Wi.pp(k)
  Wi.flat = o.dark
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k                                   -- o manto
  local f = o.jump and b or 0                                 -- a perna, a cera e a névoa
  local hd = alert and -0.6 or (crouch and 1.4 or 0)          -- o capuz
  local hx = o.lean and 0.8 or 0
  local st = o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[ph] or 0
  local sw = still and 0 or ({ [0] = 0, 0.7, 0, -0.7 })[ph]   -- a barra
  local SW = { [0] = 0, 7, 0, -7 }
  local fl = alert and 1.4 or (crouch and -1.2 or ({ [0] = 0, 0.4, 0.8, 0.3 })[ph])
  local op = alert and 0.6 or 0                               -- a fenda abre
  -- o manto cabe 1 px mais baixo no alto (2 px livres em cima) e igual na barra
  local function V(v) return v + 1 - (v - 2.4) / 29.2 + b end
  local function hood(x, y)                                   -- acima dos ombros o capuz baixa, sobe e vai à frente
    if y < 12 then local t = (12 - y) / 9.6; return x + hx * t, y + hd * t end
    return x, y
  end
  local function T(list)
    local q = {}
    for i, a in ipairs(list) do
      local x, y = hood(a[1], a[2])
      q[i] = { X(x + (a[3] or 0) * sw), Y(V(y)) }
    end
    return q
  end
  local function H(x, y) x, y = hood(x, y); return X(x), Y(V(y)) end
  Wi.layer(g, function(t)
    Wi.mist(t, X(8.6), Y(31.2 + f), 5.4 * k, 2 * k, 4, p); Wi.mist(t, X(27), Y(31.4 + f), 5 * k, 1.9 * k, 5, p)
  end)
  Wi.layer(g, function(t)
    Wi.wire(t, { { X(14.4), Y(V(28)) }, { X(14.2 + st), Y(32.4 + f) } }, 'l', 'f', Wi.th(k, 0.7))
    for _, q in ipairs({ { -1.6, 0.6 }, { 0.2, 0.8 }, { 1.7, 0.5 } }) do
      Wi.wire(t, { { X(14.2 + st), Y(32.4 + f) }, { X(14.2 + st + q[1]), Y(32.4 + f + q[2]) } }, 'l', nil, Wi.th(k, 0.5))
    end
    Wi.cap(t, X(21.2), Y(V(28)), X(21.4), Y(32.2 + f), 1.2 * k, 0.7 * k, Wi.wax(p, X(20), 3 * k))
    Wi.ell(t, X(21.5), Y(32.8 + f), 1 * k, 0.8 * k, '2')
  end)
  Wi.layer(g, function(t)
    local fe = Wi.feather('abcd', p, 3)
    local y0 = b * k
    Wi.poly(t, T(CLOAK), function(x, y)
      -- fileiras de penas: a ponta de cada uma é escura
      local v = y - y0 + abs(x - X(17.5)) * 0.25
      if v % (2 * k) >= 2 * k - p then return (floor(x / p) + floor(v / (2 * k))) % 3 == 0 and 'b' or 'a' end
      return fe(x, y, 0.85 - (x - X(8)) / (19 * k) * 0.75)
    end)
    Wi.poly(t, T(MELT), Wi.wax(p, X(20), 7 * k))              -- o ombro que derreteu
    -- o oco do capuz e a fenda do peito, com a vela no lugar do corpo
    local ox, oy = H(18.2, 8.2)
    Wi.ell(t, ox, oy, 3.3 * k, 3.5 * k, 'k')
    Wi.poly(t, T({ { 17.6, 13.4 }, { 20.2 + op, 21 }, { 20.6 + op, 29 }, { 18.4, 30.6 }, { 16.6, 29 }, { 14.8 - op, 29 }, { 15 - op, 21 } }), 'k')
    -- a luz da vela na borda de dentro
    local add = {}
    for y = floor(Y(V(13))), g.h - 1 do for x = 0, g.w - 1 do
      if t[y][x] == 'k' then
        for _, q in ipairs({ 1, -1 }) do
          local c = L.get(t, x + q, y)
          if c ~= 'k' and c ~= '.' and Wi.hash(x // p, floor(y - y0) // p, 8) > (k > 1 and 0.2 or (alert and 0.3 or 0.55)) then add[#add + 1] = { x, y } end
        end
      end
    end end
    for _, q in ipairs(add) do t[q[2]][q[1]] = 'B' end
    -- bico no escuro
    local bx, by = H(18.3, 9.8)
    Wi.poly(t, { { bx - 0.7 * k, by }, { bx + 0.7 * k, by }, { bx, by + 2.4 * k } }, function(x) return x < bx and 'l' or 'f' end)
    -- a vela de dentro
    Wi.cap(t, X(17.7), Y(V(24.6)), X(17.7), Y(V(28.2)), 1.3 * k, 1.5 * k, Wi.wax(p, X(16.2), 3 * k))
    Wi.wire(t, { { X(17.7), Y(V(23.6)) }, { X(17.7), Y(V(22.6)) } }, 'k', nil, Wi.th(k, 0.4))
    Wi.cap(t, X(16.5), Y(V(25)), X(16.4), Y(V(26.6)), 0.45 * k, 0.3 * k, '3')
    Wi.flame(t, X(17.7), Y(V(22.8)), -90 + (still and 0 or SW[ph]), (6.4 + fl) * k, 2.8 * k, 'BDE')
    -- três olhos de vela, dois do mesmo lado
    for n, e in ipairs({ { 16.4, 9.2, -92, 3.4 }, { 17.4, 6.8, -88, 2.8 }, { 20.4, 8.8, -86, 3.4 } }) do
      local ex, ey = H(e[1], e[2])
      Wi.flame(t, ex, ey, e[3] + (still and 0 or SW[(ph + n) % 4]), (e[4] + fl * 0.5) * k, 1.6 * k, 'FGH')
    end
    if k > 1 then
      Wi.wire(t, { { X(10), Y(V(15)) }, { X(9.2), Y(V(22)) }, { X(9.6), Y(V(28.4)) } }, 'a')
      Wi.wire(t, { { X(13), Y(V(12.4)) }, { X(12.6), Y(V(20)) } }, 'a')
    end
  end)
  Wi.layer(g, function(t) Wi.mist(t, X(17.6), Y(32.6 + f), 4 * k, 1.2 * k, 6, p) end)
  -- costuras do Véu: duas, de 2 px
  local w = k > 1 and 4 or 2
  Wi.seam(P, { { 10, V(15.6) }, { 12.2, V(25.4) } }, w, 'X', Wi.FEATHER, k > 1 and 2 or nil)
  Wi.seam(P, { { 22.4, V(12.4) }, { 25.8, V(18) } }, w, '9', Wi.WAX, k > 1 and 2 or nil)
  Wi.motes(g, sg, X, Y, k, { { 4, 12 }, { 30, 9 }, { 31, 22 }, { 5, 24 }, { 26, 4 }, { 10, 6 } }, ph, 4)
end

Wi.run {
  name = 'hollowkin', stage = 'espirito', W = 36, PW = 96, draw = draw, fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho do mapa ampliado 2,5 vezes, com detalhe (dobras do manto, pontos nas costuras)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    o.ox, o.oy = 3, 3
    draw(g, sg, 2.5, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 8, 24 }, green = { 10, 27 }, water = { 13, 11 }, residential = { 9, 13 }, lit = { 8, 19 },
    sacred = { 14, 3 }, crimson = { 23, 22 },
  },
}
