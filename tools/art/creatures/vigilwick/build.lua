-- Vigilwick (wisp.ritual), arte final: a coruja-buraqueira de pé no montinho da toca, nas pernas compridas, de cabeça
-- chata e sem olhos. No rosto abriu um nicho ogival escuro com um toco de vela aceso (a luz do Espectral), e a cera
-- escorre pelo peito. Mesma silhueta do conceito (conceitos/rituais/vigilwick/build.lua), refeita no kit Wisp.
-- TRAÇO: a chama não sai da coluna x = 19 e a cabeça não se mexe no idle; quem respira é o tronco (body_dy). A chama
-- vai em glow e não pisca (a vela fica acesa); em leds fica só a luz que ela joga: o reflexo na borda de dentro do
-- nicho e o frio na boca da toca. Costuras do Véu: duas, de 2 px, só no glow.
-- Bicho de chão: o montinho é fixo (nem no salto); na deriva cabeça e nicho vão 1 px à frente e a chama fica atrás.
-- Rodar: tools/art/rodar.sh tools/art/creatures/vigilwick/build.lua
local Wi = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wisp.lua')
local L, F = Wi.L, Wi.F
local floor, ceil, abs, sqrt = math.floor, math.ceil, math.abs, math.sqrt

-- o nicho do mapa, pixel a pixel: { y, x, texto } (3 moldura à esquerda, 2 à direita, v o vão, 3 3 2 e 2 2 1 o toco)
local NICHE = {
  { 5, 19, 'e' }, { 6, 18, '3v2' }, { 7, 17, '3vvv2' }, { 8, 16, '3vvvvv2' }, { 9, 16, '3vvvvv2' },
  { 10, 15, '3vvvvvvv2' }, { 11, 15, '3vvvvvvv2' }, { 12, 15, '3vv332vv2' }, { 13, 15, '3vv221vv2' }, { 14, 15, '333222111' },
}
-- a chama do mapa, linhas { dx, ch } por y, na coluna 19; por fase do laço (ph1 ponta à direita, ph2 baixa e larga, ph3 à esquerda)
local function flameRows(ph)
  local r = {
    [7] = { { 0, 'B' } }, [8] = { { 0, 'D' } }, [9] = { { -1, 'D' }, { 0, 'E' }, { 1, 'D' } },
    [10] = { { -1, 'D' }, { 0, 'E' }, { 1, 'D' } }, [11] = { { -1, 'B' }, { 0, 'E' }, { 1, 'B' } },
  }
  if ph == 1 then r[7] = { { 1, 'B' } } elseif ph == 3 then r[7] = { { -1, 'B' } }
  elseif ph == 2 then r[7] = nil; r[8] = { { -1, 'B' }, { 0, 'D' }, { 1, 'B' } } end
  return r
end
local function ogive(u, v, cx, v0, v1, a, r)
  if v > v1 then return false end
  if v >= v0 then return abs(u - cx) <= a end
  return sqrt((u - (cx - a + r)) ^ 2 + (v - v0) ^ 2) <= r and sqrt((u - (cx + a - r)) ^ 2 + (v - v0) ^ 2) <= r
end

local function draw(g, sg, k, o)
  local X, Y, pts = Wi.scale(k, o.ox, o.oy)
  local ox, oy = o.ox or 0, o.oy or 0
  local P = F.pen(g, k, ox, oy)
  local p = Wi.pp(k)
  Wi.flat = o.dark
  local ph = (o.ph or (o.portrait and o.portrait - 1) or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local hot = o.hot or 0
  local b = crouch and 1 or (alert and -1 or (o.dy or 0) / k)     -- o tronco
  local f = o.jump and b or 0                                      -- os pés (só saem do chão no salto)
  local hy = alert and -1 or (crouch and 1 or (o.jump and b or 0)) -- a cabeça e o nicho (parados no idle)
  local hx = o.lean and 1 or 0
  local fy = o.jump and (b < 0 and ceil(b / 2) or 0) or hy         -- a chama: atrasada na fuga, como o Sol Negro
  local fnoise = Wi.noise(p, 4)

  -- o montinho da toca, com a boca escura (fixo)
  Wi.layer(g, function(t)
    local function dirt(x, y)
      if y >= Y(33) - 0.01 then return 'r' end
      local h = Wi.hash(floor(x / p), floor(y / p), 4)
      return h < 0.16 and '5' or (h < 0.42 and 't' or 'u')
    end
    Wi.ell(t, X(18.5), Y(32.4), 11.5 * k, 1.6 * k, dirt)
    Wi.ell(t, X(18), Y(31.6), 6 * k, 1.4 * k, dirt)
    Wi.ell(t, X(25.6), Y(32.3), 2.6 * k, 0.9 * k, 'v')
    if k > 1 then
      for _, q in ipairs({ { 11.4, 32.2, 'u' }, { 15.8, 32.8, 't' }, { 19.4, 32.6, 'u' }, { 22, 32.8, 't' } }) do
        Wi.ell(t, X(q[1]), Y(q[2]), 0.5 * k, 0.35 * k, q[3], 'u5tr')
      end
    end
  end)
  -- as pernas compridas: a perna estica, os pés ficam
  Wi.layer(g, function(t)
    for _, lg in ipairs({ { 15.8, 15.2 }, { 20.2, 20.8 } }) do
      Wi.wire(t, { { X(lg[1]), Y(24 + b) }, { X(lg[2]), Y(30.6 + f) } }, 'l', 'f', Wi.th(k, 0.7))
      Wi.wire(t, { { X(lg[2] - 1.0), Y(30.8 + f) }, { X(lg[2] + 1.0), Y(30.8 + f) } }, 'l', nil, Wi.th(k, 0.5))
    end
  end, '')                                                         -- sem contorno de dentro: o de fora é o do quadro
  -- o tronco e o rabo
  Wi.layer(g, function(t)
    Wi.poly(t, pts({ { 12.6, 21 }, { 9.4, 26.4 }, { 13.4, 25.4 } }, 0, b), function(x, y)
      return Wi.hash(floor(x / p), floor(y / p), 6) > 0.5 and 'b' or 'a'
    end)
    local fe = Wi.feather('abcd', p, 3)
    local cx, cy, rx, ry = X(17.6), Y(19.6 + b), 5.6 * k, 6.2 * k
    Wi.ell(t, cx, cy, rx, ry, function(x, y)
      local v = y - Y(b) + abs(x - X(17.5)) * 0.25
      if v % (2 * k) >= 2 * k - p then return (floor(x / p) + floor(v / (2 * k))) % 3 == 0 and 'b' or 'a' end
      return fe(x, y, Wi.lum(x, y, cx, cy, rx, ry))
    end)
  end)
  -- a asa fechada
  Wi.layer(g, function(t)
    local fe = Wi.feather('abc', p, 3)
    local cx, cy, rx, ry = X(13.6), Y(20 + b), 2.8 * k, 5.4 * k
    Wi.ell(t, cx, cy, rx, ry, function(x, y) return fe(x, y, Wi.lum(x, y, cx, cy, rx, ry)) end)
    if k > 1 then Wi.wire(t, { { X(16.2), Y(16 + b) }, { X(16.6), Y(20.4 + b) }, { X(15.6), Y(25 + b) } }, 'a', nil, Wi.th(k, 0.4), 'abcde') end
  end, k == 1 and '' or nil)                                      -- no mapa a asa não leva contorno (a régua)
  -- a cabeça (parada no idle), o nicho e a cera
  Wi.layer(g, function(t)
    local fe = Wi.feather('abcd', p, 5)
    local cx, cy, rx, ry = X(18.6 + hx), Y(9.8 + hy), 6.6 * k, 5.6 * k
    Wi.ell(t, cx, cy, rx, ry, function(x, y) return fe(x, y, Wi.lum(x, y, cx, cy, rx, ry)) end)
    Wi.wire(t, { { X(13.6 + hx), Y(7.4 + hy) }, { X(15.4 + hx), Y(6.2 + hy) } }, 'e', nil, Wi.th(k, 0.5), 'abcd')
    Wi.wire(t, { { X(22.8 + hx), Y(6.2 + hy) }, { X(24 + hx), Y(7.4 + hy) } }, 'e', nil, Wi.th(k, 0.5), 'abcd')
    -- o nicho: moldura, vão, toco
    local refl = {}                                               -- os pixels de moldura que tocam o vão
    if k == 1 then
      for _, r in ipairs(NICHE) do
        local y = r[1] + hy
        for i = 1, #r[3] do
          local c = r[3]:sub(i, i)
          local x = r[2] + hx + i - 1
          L.set(t, x, y, c)
          if r[1] >= 6 and r[1] <= 13 and (c == '3' or c == '2') and (i == 1 or i == #r[3]) then refl[#refl + 1] = { x, y, r[1] } end
        end
      end
    else
      local function fill(fn)
        for y = 0, t.h - 1 do for x = 0, t.w - 1 do
          local ch = fn((x - ox - (k - 1) / 2) / k - hx, (y - oy - (k - 1) / 2) / k - hy, x, y)
          if ch then L.set(t, x, y, ch) end
        end end
      end
      fill(function(u, v) if ogive(u, v, 19, 10.8, 14.6, 4.0, 6.4) then return u < 19 and '3' or '2' end end)
      fill(function(u, v) if ogive(u, v, 19, 10.8, 13.9, 3.0, 5.4) then return 'v' end end)
      Wi.poly(t, pts({ { 17.8, 12 }, { 20.4, 12 }, { 20.4, 13.9 }, { 17.8, 13.9 } }, hx, hy), Wi.wax(p, X(17.8 + hx), 2.6 * k), 'v')
      for y = 0, t.h - 1 do for x = 0, t.w - 1 do             -- o filete de cera escura por dentro
        local c = t[y][x]
        if (c == '3' or c == '2') and (L.get(t, x + 1, y) == 'v' or L.get(t, x - 1, y) == 'v' or L.get(t, x, y - 1) == 'v') then
          local v = (y - oy - (k - 1) / 2) / k - hy
          if v < 13.9 then t[y][x] = '1' end
          if v >= 6 and v <= 13 then refl[#refl + 1] = { x, y, v } end
        end
      end end
    end
    -- a chama: coluna 19, só dentro do vão
    if k == 1 then
      local rows = flameRows(ph)
      if alert then rows[6] = { { 0, 'B' } } end
      if crouch then
        rows = { [9] = { { 0, 'D' } }, [10] = { { -1, 'D' }, { 0, 'E' }, { 1, 'D' } }, [11] = { { -1, 'B' }, { 0, 'E' }, { 1, 'B' } } }
      elseif o.lean then
        rows[7] = nil; rows[9] = { { 0, 'E' }, { 1, 'D' } }            -- fica 1 px atrás, sem tocar a moldura
        if o.jump then rows[8] = nil end                                -- na fuga a chama é curta
      end
      for y, list in pairs(rows) do
        for _, c in ipairs(list) do L.set(t, 19 + c[1], y + fy, c[2], 'v') end
      end
    else
      local ang = ({ [0] = -90, -82, -90, -98 })[ph]
      local len, w = 5.6 + (alert and 0.8 or 0) + (ph == 2 and -1.2 or 0), ph == 2 and 3.0 or 2.6
      if crouch then len, w, ang = 2.4, 2.4, -90 end
      if o.jump then len = len - 1.6 end
      Wi.flame(t, X(19.1), Y(11.8 + fy), ang, len * k, w * k, 'BDE', 'v')
      Wi.wire(t, { { X(19.1), Y(12.4 + hy) }, { X(19.1), Y(11.7 + hy) } }, 'k', nil, Wi.th(k, 0.4), 'vBDE')
    end
    -- o reflexo da chama na borda de dentro (leds): por fase, ou a borda toda no alerta
    if not crouch then
      for _, q in ipairs(refl) do
        if alert or Wi.hash(floor(q[1] / p), floor(q[2] / p), ph + 20) > 0.18 then L.set(t, q[1], q[2], 'F') end
      end
    end
    -- a gota de cera no parapeito (só no retrato) e o bico
    if k > 1 then Wi.ell(t, X(20.9 + hx), Y(15 + hy), 0.35 * k, 0.5 * k, '3') end
    local bx = X(19.2 + hx)
    Wi.poly(t, pts({ { 18, 15 }, { 20.4, 15 }, { 19.2, 16.8 } }, hx, hy), function(x) return x < bx and 'l' or 'f' end)
  end, '')                                                         -- a cabeça sem contorno de dentro (o de fora é o do quadro)
  -- a cera que escorre fica sem contorno (o peito já é o fundo dela)
    Wi.cap(g, X(18 + hx), Y(14.4 + hy), X(17.4), Y(19.6 + b), 0.6 * k, 0.5 * k, '3')
    Wi.cap(g, X(20.2 + hx), Y(14.6 + hy), X(20.8), Y(17.6 + b), 0.5 * k, 0.5 * k, '2')
  -- costuras do Véu: duas, de 2 px, só no glow
  local w = k > 1 and 4 or 2
  Wi.seam(P, { { 20.8, 19.6 + b }, { 21.8, 23 + b } }, w, 'X', Wi.FEATHER, k > 1 and 2 or nil)
  Wi.seam(P, { { 12.8, 17.4 + b }, { 13.2, 21 + b } }, w, 'X', Wi.FEATHER, k > 1 and 2 or nil)
  -- o frio da toca (leds): sem reflexo agachada, mais na deriva, toda a boca no alerta
  if not crouch then
    local cells = {}
    for y = floor(Y(30.8)), ceil(Y(33.6)) do for x = floor(X(22.4)), ceil(X(29)) do
      if L.get(g, x, y) == 'v' then cells[#cells + 1] = { x, y, Wi.hash(x, y, ph * 7 + 3) } end
    end end
    table.sort(cells, function(a, c) return a[3] < c[3] end)
    local n = alert and #cells or floor(#cells * (o.lean and 0.4 or 0.3) + 0.5)
    for i = 1, n do L.set(g, cells[i][1], cells[i][2], (alert or i % 2 == 0) and 'G' or 'F') end
  end
  -- alerta quente: dois pontos de frio soltos acima do ápice do nicho; fuga: um T onde a chama estava
  if alert and hot == 2 then
    L.set(sg, floor(X(19)), floor(Y(1.6)), 's'); L.set(sg, floor(X(20)), floor(Y(0.4)), 's')
  end
  if o.jump and k == 1 then L.set(sg, 19, 8, 'T') end
  local motes = { { 7, 9 }, { 29, 7 }, { 28, 19 }, { 6, 22 }, { 30, 27 }, { 10, 5 } }
  if o.lean then motes = { { 7, 9 }, { 6, 22 }, { 10, 5 }, { 4, 15 } } end    -- só atrás
  Wi.motes(g, sg, X, Y, k, motes, ph, 4)
end

Wi.run {
  name = 'vigilwick', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho do mapa ampliado 2,5 vezes, com detalhe (pavio, gota de cera, filete do nicho)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    o.ox, o.oy = 3, 3
    draw(g, sg, 2.5, o)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 15, 1 }, residential = { 8, 13 }, urban = { 9, 22 }, green = { 10, 27 },
    lit = { 24, 17 }, crimson = { 22, 21 }, water = { 23, 25 },
  },
}
