-- Staticroost (bit.ritual), arte final: o pombo dormindo no alto de uma placa, estufado, cabeça encolhida, olho fechado
-- em todo quadro. As penas do peito e do pescoço viram Estática (a luz do tipo Digital), mais densa para a frente, sem
-- contorno na frente; o chuvisco continua solto no ar. A faixa do dorso fica na mesma linha, 2 px fora (4 no alerta).
-- Mesma silhueta do conceito (conceitos/rituais/staticroost/build.lua), refeita no kit Bit (_bit.lua), sem cor nova.
-- A placa e os 8 LEDs ficam no lugar quando o tronco sobe; só no salto da fuga vai tudo junto.
-- Camadas: corpo; leds = os LEDs da placa; glow = a Estática, a emenda do glitch, as costuras e o chuvisco solto.
-- Rodar: tools/art/rodar.sh tools/art/creatures/staticroost/build.lua
local B = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_bit.lua')
local R = dofile(KENOMA_ART .. 'creatures/conceitos/rituais/_ritual.lua')
local L = B.L
local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
local pick, rnd = B.pick, B.rnd

local function lum(x, y, cx, cy, rx, ry) return 0.5 - 0.3 * (x - cx) / rx - 0.4 * (y - cy) / ry end
local function dseg(x, y, x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  local t = max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)))
  return sqrt((x - x0 - dx * t) ^ 2 + (y - y0 - dy * t) ^ 2)
end
-- a mistura da Estática: 4 P, 2 R, 2 Q, 2 O em cada 10
local function mix(x, y)
  local h = floor(rnd(x, y, 9) * 10)
  return h < 4 and 'P' or (h < 6 and 'R' or (h < 8 and 'Q' or 'O'))
end

local function draw(g, sg, kk, o, ox0, oy0)
  ox0, oy0 = ox0 or 0, oy0 or 0
  local k = kk
  local ph = (o.ph or (o.portrait and o.portrait - 1) or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local hot = alert and (o.hot or 0) or 0
  local dy = o.dy or 0
  local all = o.jump and dy or 0                                -- no salto vai tudo, placa e pés
  local by = dy - all
  local ox, oy = ox0, oy0 + all
  local function X(u) return u * k + (k - 1) / 2 + ox end
  local function Y(v) return v * k + (k - 1) / 2 + oy + by end
  local function F(v) return v * k + (k - 1) / 2 + oy end       -- o chão não sobe
  local function U(x) return (x - (k - 1) / 2 - ox) / k end
  local function V(y) return (y - (k - 1) / 2 - oy - by) / k end
  local ck = B.plume(k)
  -- a cabeça: 0,6 px à frente na deriva, 1 px no alerta (sem subir), recua 0,6 agachada
  local hdx = (o.lean and 0.6 or 0) + (alert and 1 or 0) - (crouch and 0.6 or 0)
  local bk = o.lean and 0.5 or 0                                -- o bico desce na deriva
  local b0, b1 = { 26.6 + hdx, 13.2 + bk }, { 28.4 + hdx, 15.4 + bk }
  if alert then b0, b1 = { 26.6 + hdx, 13.6 }, { 28.8 + hdx, 13.8 } end   -- bico na horizontal
  local tear = o.jump and floor(2 * k + 0.5) or 0
  local gl = alert and -4 or -2

  B.layer(g, function(t)
    -- a placa, com a rampa 4321 (claro em cima)
    local y0, y1 = F(30.6), F(33.7)
    B.polyf(t, { { X(5), F(30.6) }, { X(31), F(30.6) }, { X(31), F(33.7) }, { X(5), F(33.7) } }, function(_, y)
      local i = min(3, floor((y + 0.5 - y0) / (y1 - y0) * (k > 1 and 4 or 3.4)))
      return ('4321'):sub(i + 1, i + 1)
    end)
    local lw = k > 1 and 3 or 1
    for u = 7.5, 28.6, 3 do
      for i = 0, lw - 1 do L.set(t, floor(X(u)) + i - (lw - 1) // 2, floor(F(32.2) + 0.5), 'G') end
    end
    -- a cauda, rígida
    B.polyf(t, { { X(2.6), Y(21.5) }, { X(9), Y(18.6) }, { X(10), Y(25.6) }, { X(3), Y(25.6) } }, function(x, y)
      return x < X(5) and pick('fa', 0, ck(x, y)) or pick('ab', 0, ck(x, y))
    end)
    -- os pés ficam no chão e esticam quando o tronco sobe
    for _, lx in ipairs({ 15, 20 }) do
      B.wire(t, { { X(lx), Y(26.4) }, { X(lx), F(30.4) } }, 'j', 'i', B.th(k, 0.6))
      B.wire(t, { { X(lx - 0.8), F(30.2) }, { X(lx + 1.4), F(30.2) } }, 'j', nil, B.th(k, 0.45))
    end
    -- o corpo estufado e a asa fechada com as duas barras
    local cx, cy, rx, ry = X(17), Y(21.5), 10 * k, 7.6 * k
    B.ell(t, cx, cy, rx, ry, function(x, y) return pick('abcd', lum(x, y, cx, cy, rx, ry), ck(x, y)) end)
    local wx, wy, wrx, wry = X(13.4), Y(21), 7 * k, 4.8 * k
    B.ell(t, wx, wy, wrx, wry, function(x, y)
      local u, v = U(x), V(y)
      if dseg(u, v, 11, 23.6, 15, 18) < 0.5 or dseg(u, v, 14.6, 24.6, 18.6, 19) < 0.5 then return pick('fa', 0, ck(x, y)) end
      return pick('cde', lum(x, y, wx, wy, wrx, wry), ck(x, y))
    end)
    -- a cabeça encolhida, o furta-cor do pescoço, o bico e a cera
    local hx, hy, hrx, hry = X(23.5 + hdx), Y(12.6), 3.8 * k, 3.6 * k
    B.ell(t, hx, hy, hrx, hry, function(x, y) return pick('bcde', lum(x, y, hx, hy, hrx, hry), ck(x, y)) end)
    B.ell(t, X(22.4 + hdx * 0.5), Y(15.8), 3.6 * k, 1.8 * k, 'N', 'abcdef')
    B.cap(t, X(b0[1]), Y(b0[2]), X(b1[1]), Y(b1[2]), 0.8 * k, 0.5 * k, 'q')
    B.ell(t, X(26.3 + hdx), Y(12.6), 0.8 * k, 0.7 * k, 'h')
    B.wire(t, { { X(23.6 + hdx), Y(12) }, { X(25.4 + hdx), Y(12) } }, 'f', nil, k > 1 and 2 or 1)   -- olho fechado
    -- as duas costuras do Véu, só no glow, longe da Estática
    local w, st = k > 1 and 2 or 1, k > 1 and 4 or nil
    local S1 = { { X(8.6), Y(20.4) }, { X(9.6), Y(23.4) } }
    local S2 = { { X(12), Y(26.6) }, { X(15.4), Y(27.6) } }
    B.seam(t, S1, w, st); B.seam(t, S2, w, st)
    if k == 1 then   -- 2 px de largura no mapa
      B.seam(t, { { S1[1][1], S1[1][2] + 1 }, { S1[2][1], S1[2][2] + 1 } }, 1)
      B.seam(t, { { S2[1][1], S2[1][2] + 1 }, { S2[2][1], S2[2][2] + 1 } }, 1)
    end
    -- o glitch: a faixa do dorso anda fora do lugar; ponta de trás N, emenda da frente acesa
    local P = R.pen(t, k, ox + (k - 1) / 2, oy + by + (k - 1) / 2)
    R.glitch(P, 15, 17, 1, 14.5, gl)
    for y = floor(Y(15) - (k - 1) / 2), floor(Y(17) - (k - 1) / 2) - 1 do
      for x = 0, t.w - 1 do if t[y][x] ~= '.' then t[y][x] = 'N'; break end end
    end
    local sx, sy = floor(X(15.6)), floor(Y(16))
    for i = 0, (k > 1 and 2 or 0) do
      L.set(t, sx + i, sy, 'P', 'abcdefN'); L.set(t, sx + i, sy - 1, 'R', 'abcdefN')
    end
    -- o peito e o pescoço se desfazem em Estática, mais densa para a frente
    local add = 0.15 * hot
    for y = floor(Y(13)), floor(Y(29)) do
      for x = floor(X(18)), floor(X(30)) do
        if x >= 0 and x < t.w and y >= 0 and y < t.h and ('abcdefN'):find(t[y][x], 1, true) then
          local u, v = U(x), V(y)
          local p = (u - 19.4) / 6.2 - (v < 15.4 and 0.3 or 0) + add
          if rnd(x, y, 5 + ph) < 0.95 * p then t[y][x] = mix(x, y) end
        end
      end
    end
  end, o.dark and '' or nil)
  -- o contorno da frente se desfaz: 60% dos A, só trocados (a silhueta fica numa peça)
  for y = floor(Y(13)), floor(Y(29)) do
    for x = floor(X(23)), floor(X(30)) do
      if x >= 0 and x < g.w and y >= 0 and y < g.h and g[y][x] == 'A' and rnd(x, y, 7 + ph) < 0.6 then g[y][x] = mix(x, y) end
    end
  end
  -- fuga: o corpo sai em fatias, trocando de lado a cada quadro
  if o.jump then
    local sgn = ph % 2 == 0 and 1 or -1
    B.tear(g, Y(19), Y(20.99), tear * sgn, false)
    B.tear(g, Y(23), Y(24.99), -tear * sgn, false)
  end
  -- o chuvisco solto, só no glow e só onde o corpo está vazio
  local function rain(u0, u1, y0, y1, dens, shift)
    for y = floor(Y(y0)), floor(Y(y1)) do
      for x = floor(X(u0)), floor(X(u1)) do
        if x > 0 and y > 0 and x < g.w - 1 and y < g.h - 1 and g[y][x] == '.' and sg[y][x] == '.' then
          local u = U(x)
          if rnd(x - shift, y, 12) < dens(u) then sg[y][x] = ({ 'p', 'y', 't' })[floor(rnd(x, y, 3) * 3) + 1] end
        end
      end
    end
  end
  if o.jump then
    rain(2, 10, 15, 29, function(u) return 0.28 * (u - 2) / 8 end, -floor(ph * k + 0.5))
  else
    local ex = o.lean and 34 or 33.5
    rain(26, ex, 14, 29, function(u) return 0.2 * (1 - (u - 26) / (ex - 26 + 0.0)) end, floor(ph * k + 0.5))
  end
end

B.run {
  name = 'staticroost', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fps = { idle = 6, drift = 6 },
  NOPULL = B.NOPULL .. 'PQRO',   -- a Estática que roeu o contorno não puxa contorno novo
  over = {
    alert = function(_, os) for _, f in ipairs(os) do f.sparks = nil end return os end,
    flee = function(_, os)
      for i = 1, #os do os[i].sparks = nil; if i > 1 then os[i].jump = true end end
      return os
    end,
  },
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.5, o, 3, 3)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 20, 4 }, residential = { 9, 11 }, urban = { 15, 15 }, lit = { 7, 18 }, water = { 12, 19 },
    green = { 8, 23 }, crimson = { 3, 21 },
  },
}
