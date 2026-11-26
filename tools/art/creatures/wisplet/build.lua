-- Wisplet (wisp.eco), arte final: o Eco da família Wisp, a partir do conceito aprovado. A coruja-buraqueira de pé nas
-- pernas compridas, numa poça de névoa, em proporção natural. O errado é pouco: no lugar de cada olho há uma chama de
-- vela que sobe além da cabeça, e embaixo de cada uma escorre uma lágrima de cera.
-- Costuras do Véu: três, de 1 px (asa, barriga, alto da cabeça), só no glow; apagadas ficam quase na cor da pena.
-- Camadas: corpo; leds = os dois olhos de vela (piscam); glow = as costuras e o frio solto.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; na deriva ela anda; na fuga, salta. No alerta estica
-- o pescoço e as chamas crescem; encolhida, afunda a cabeça e as chamas baixam (a reverência da buraqueira).
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wisplet/build.lua')
local Wi = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wisp.lua')
local L, F = Wi.L, Wi.F
local floor = math.floor

-- O mapa é desenhado pixel a pixel (a coruja é estreita): { coluna, texto } por linha, sem o contorno.
local HEAD = { { 12, 'cdFHdcFH' }, { 11, 'beeGHeeGHb' }, { 11, 'bccFGclFGb' }, { 11, 'acda3dla3b' }, { 11, 'abee2efeea' } } -- linha 6
local BODY = { { 10, 'abcbdcdcdcb' }, { 10, 'abebcededec' }, { 10, 'acbabcbcbcb' }, { 10, 'abebdededec' }, { 10, 'acbabcbcbcb' },
  { 10, 'abebdededc' }, { 11, 'ababcbcbb' }, { 11, 'abdededc' }, { 11, 'abcd.cd' } }                                    -- linha 11
local MIST = { { 9, 'nopomonpoonm' }, { 7, 'mnoponmnopononom' }, { 5, 'mnmnonopononmnmnm' }, { 11, 'mnmn' } }           -- linha 22
-- a ponta da chama acima da cabeça, três linhas, por fase: reta, inclina para a frente, baixa e larga, inclina para trás
local TIP = { [0] = { { 1, 'F' }, { 1, 'G' }, { 1, 'G' } }, { { 2, 'F' }, { 1, 'G' }, { 1, 'H' } }, { false, { 1, 'F' }, { 0, 'FG' } },
  { { 0, 'F' }, { 1, 'G' }, { 1, 'G' } } }
local SEAMS = { { 11, 13 }, { 11, 14 }, { 12, 15 }, { 12, 16 }, { 17, 12 }, { 18, 13 }, { 18, 14 }, { 19, 15 } }        -- no tronco
local function rows(g, list, x, y)
  for j, r in ipairs(list) do L.put(g, r[1] + x, y + j - 1, { r[2] }) end
end
local function rot(s, n) n = n % #s; return s:sub(n + 1) .. s:sub(1, n) end

local function drawMap(g, sg, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = o.dy or 0
  local f = o.jump and b or 0
  local hy = b + (alert and -1 or (crouch and 1 or 0))
  local hx = o.lean and 1 or 0
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0
  local mp = still and 0 or ph                               -- a névoa escorre
  rows(g, { { MIST[1][1], rot(MIST[1][2], mp) }, { MIST[2][1], rot(MIST[2][2], 2 * mp) }, { MIST[3][1], rot(MIST[3][2], 17 - mp) }, MIST[4] }, 0, 22 + f)
  for n, lx in ipairs({ 14, 17 }) do
    local sx = n == 1 and st or -st
    L.line(g, lx, 20 + b, lx + sx, 23 + f, 'l')
    L.set(g, lx + sx, 22 + f, 'f'); L.set(g, lx + sx + 1, 23 + f, 'f')
  end
  rows(g, BODY, 0, 11 + b)
  if alert then rows(g, { { 11, 'bcdcdcdcb' } }, hx, 10 + b) end   -- o pescoço esticado
  rows(g, HEAD, hx, 6 + hy)
  for n, c in ipairs({ 14 + hx, 18 + hx }) do
    local pat = TIP[(ph + n - 1) % 4]
    if alert then pat = { { 1, 'G' }, { 1, 'G' }, { 1, 'H' } }; L.set(g, c + 1, 2 + hy, 'F')
    elseif crouch then pat = { false, false, { 1, 'F' } } end
    for j = 1, 3 do if pat[j] then L.put(g, c + pat[j][1], 2 + hy + j, { pat[j][2] }) end end
  end
  local function seam(x, y) if Wi.FEATHER:find(L.get(g, x, y), 1, true) then g[y][x] = 'X' end end
  for _, q in ipairs(SEAMS) do seam(q[1], q[2] + b) end
  seam(12 + hx, 7 + hy); seam(13 + hx, 6 + hy)
  local function id(v) return v end
  Wi.motes(g, sg, id, id, 1, { { 23, 9 }, { 4, 16 }, { 24, 19 }, { 22, 4 }, { 5, 10 } }, ph, 4)
end

local function draw(g, sg, k, o)
  if k == 1 then return drawMap(g, sg, o) end
  local X, Y, pts = Wi.scale(k, o.ox, 0)
  local P = F.pen(g, k, o.ox or 0, 0)
  local p = 1                                                 -- textura no pixel do retrato (a régua mede a ampliação)
  local ck = Wi.chk(p)
  Wi.flat = o.dark
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k                                   -- o tronco
  local f = o.jump and b or 0                                 -- os pés e a poça (só saem do chão no salto da fuga)
  local hb = b + (alert and -0.8 or (crouch and 1.2 or 0))    -- a cabeça
  local hx = o.lean and 0.8 or 0
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0      -- o passo
  local SW = { [0] = 0, 6, 0, -6 }
  local fl = alert and 1.2 or (crouch and -1.6 or ({ [0] = 0, 0.5, 0.9, 0.4 })[ph])
  local pick, lum = Wi.pick, Wi.lum
  Wi.layer(g, function(t)
    Wi.mist(t, X(8), Y(23.2 + f), 6 * k, 2.6 * k, 1, p); Wi.mist(t, X(19), Y(23.4 + f), 5.4 * k, 2.4 * k, 2, p)
  end)
  Wi.layer(g, function(t)
    local fe = Wi.feather('abcd', p, 2)
    Wi.poly(t, pts({ { 8.8, 16.6 }, { 7.4, 21.6 }, { 10.4, 20.6 }, { 11.2, 17.4 } }, 0, b), function(x, y) return pick('ab', 0, ck(x, y)) end)
    for n, lx in ipairs({ 12.2, 15.4 }) do
      local sx = (n == 1 and st or -st) * 0.9
      Wi.wire(t, { { X(lx), Y(20 + b) }, { X(lx + sx), Y(24 + f) } }, 'l', 'f', Wi.th(k, 0.6))
      for _, q in ipairs({ { -1.3, 0.7 }, { 0.3, 1 }, { 1.8, 0.6 } }) do
        Wi.wire(t, { { X(lx + sx), Y(24 + f) }, { X(lx + sx + q[1]), Y(24 + f + q[2]) } }, 'l', nil, Wi.th(k, 0.4))
      end
    end
    -- corpo: barriga creme barrada de pardo
    Wi.ell(t, X(13.6), Y(15.6 + b), 5.2 * k, 5.8 * k, function(x, y)
      local band = floor((y - Y(b) + (x - X(13.6)) * 0.2) / (1.4 * k)) % 2 == 0
      if band then return pick('de', 0, ck(x, y)) end
      return pick('abc', lum(x, y, X(13.6), Y(15.6 + b), 5.2 * k, 5.8 * k), ck(x, y))
    end)
    -- asa fechada, do lado das costas
    Wi.ell(t, X(10.2), Y(15.8 + b), 2.7 * k, 5.4 * k, function(x, y) return fe(x, y, lum(x, y, X(10.2), Y(15.8 + b), 2.7 * k, 5.4 * k)) end)
    Wi.wire(t, { { X(11.8), Y(11.6 + b) }, { X(12.8), Y(16 + b) }, { X(12), Y(20.4 + b) } }, 'a', nil, Wi.th(k, 0.4))
    for _, lx in ipairs({ 12.2, 15.3 }) do
      Wi.ell(t, X(lx), Y(20.2 + b), 1.5 * k, 1.3 * k, function(x, y) return pick('cd', 0, ck(x, y)) end)
    end
    -- cabeça chata, sem tufos, virada um pouco para a direita
    local cx, cy = 13.8 + hx, 9.4 + hb
    Wi.ell(t, X(cx), Y(cy), 5.1 * k, 3.7 * k, function(x, y) return fe(x, y, lum(x, y, X(cx), Y(cy), 5.1 * k, 3.7 * k)) end)
    Wi.wire(t, pts({ { -3.6, -0.6 }, { -1.6, -1.7 }, { 0.4, -0.5 } }, cx, cy), 'e', nil, Wi.th(k, 0.6))
    Wi.wire(t, pts({ { 1.4, -0.5 }, { 3.2, -1.7 }, { 4.8, -0.6 } }, cx, cy), 'e', nil, Wi.th(k, 0.6))
    Wi.wire(t, pts({ { -3.2, 2.6 }, { 0.4, 3.3 }, { 4, 2.6 } }, cx, cy), 'e', nil, Wi.th(k, 0.6))
    Wi.ell(t, X(cx - 1.4), Y(cy + 0.6), 1.4 * k, 1.2 * k, 'a'); Wi.ell(t, X(cx + 3), Y(cy + 0.6), 1.4 * k, 1.2 * k, 'a')
    Wi.poly(t, pts({ { 0.3, 0.3 }, { 1.6, 0.3 }, { 1.1, 2.6 } }, cx, cy), function(x) return x < X(cx + 0.9) and 'l' or 'f' end)
    -- lágrimas de cera
    Wi.cap(t, X(cx - 1), Y(cy + 1.6), X(cx - 0.8), Y(cy + 3.4), 0.45 * k, 0.3 * k, '3'); Wi.ell(t, X(cx - 0.8), Y(cy + 3.6), 0.5 * k, 0.6 * k, '2')
    Wi.cap(t, X(cx + 3.4), Y(cy + 1.6), X(cx + 3.4), Y(cy + 2.5), 0.45 * k, 0.3 * k, '3')
    -- os olhos de vela: cada chama treme no seu passo
    Wi.flame(t, X(cx - 1.4), Y(cy + 0.9), -86 + (still and 0 or SW[ph]), (6.6 + fl) * k, 1.9 * k, 'FGH')
    Wi.flame(t, X(cx + 3), Y(cy + 0.9), -82 + (still and 0 or SW[(ph + 1) % 4]), (6.2 + fl) * k, 1.9 * k, 'FGH')
  end)
  Wi.layer(g, function(t) Wi.mist(t, X(13.6), Y(24.3 + f), 5.4 * k, 1.5 * k, 3, p) end)
  -- costuras do Véu: três, finas
  local cx, cy = 13.8 + hx, 9.4 + hb
  for _, q in ipairs({ { 9, 12.8 + b, 11, 18.2 + b }, { 14.4, 13.4 + b, 17, 18 + b }, { cx - 3.4, cy - 2, cx + 0.2, cy - 2.9 } }) do
    Wi.seam(P, { { q[1], q[2] }, { q[3], q[4] } }, 1, 'X', Wi.FEATHER, k > 1 and 1.3 or nil)
  end
  Wi.motes(g, sg, X, Y, k, { { 23, 9 }, { 4, 16 }, { 24, 19 }, { 22, 4 }, { 5, 10 } }, ph, 4)
end

Wi.run {
  name = 'wisplet', stage = 'eco', W = 28, PW = 96, draw = draw,
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho do mapa ampliado 3,3 vezes, com detalhe (pontos nas costuras, o barrado da barriga)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    o.ox = 3
    draw(g, sg, 3.3, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 12, 14 }, green = { 9, 16 }, water = { 11, 11 }, residential = { 11, 10 }, lit = { 11, 17 },
    sacred = { 12, 5 }, crimson = { 10, 12 },
  },
}
