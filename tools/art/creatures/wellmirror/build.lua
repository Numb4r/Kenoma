-- Wellmirror (rill.ritual), arte final: o cururu de ritual da família Rill, ligado a Zumvi (mares).
-- Na linguagem do Eco e do Espírito aprovados do Rill (conceitos/rill/build.lua, kit em _rill.lua): pele de barro
-- com verruga, barriga creme, concreto com a tinta amarela gasta; só o espelho tem cor, e a luz é a do tipo Água.
-- O QUE ELE TEM DE PRÓPRIO (e o Brookkin não): é o sapo do fundo do poço. Está sentado dentro de uma manilha de
-- concreto, de olho fechado, e o papo cheio é o espelho: um disco d'água em pé com a noite de lua cheia dentro (o
-- céu inteiro que ele vê lá de baixo). O dorso dele é pele; o espelho da família passou para o papo, que enche e
-- esvazia. A manilha transborda.
-- Costuras do Véu: duas, de 2 px (no dorso e na parede da manilha), só no glow.
-- Camadas: corpo; leds = as estrelas no espelho (piscam); glow = a borda do espelho, a lua, o rastro dela na água,
-- os fios que transbordam, as costuras e as gotas.
-- Bicho de chão: o sapo sobe e desce dentro da manilha (body_dy) e ela fica; na deriva a manilha ginga; na fuga,
-- salta com ela.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wellmirror/build.lua')
local Rl = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rill.lua')
local L, F = Rl.L, Rl.F
local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

-- O papo: disco d'água com a noite dentro. Borda acesa, céu escuro em hachura, lua cheia, o rastro dela na água.
local function moon(g, P, cx, cy, r, ph)
  local k = P.k
  local pk = math.max(1, floor(k / 2 + 0.5))
  local X0, Y0, R = P:X(cx), P:Y(cy), r * k
  local mx, my, mr = X0 - R * 0.2, Y0 - R * 0.28, math.max(1.5, R * 0.36)
  local rim = math.max(1, 0.8 * k)
  for y = floor(Y0 - R - 1), ceil(Y0 + R + 1) do for x = floor(X0 - R - 1), ceil(X0 + R + 1) do
    local d = sqrt((x - X0) ^ 2 + (y - Y0) ^ 2)
    if d <= R then
      local ch
      local v = (y - Y0) / R
      if R - d < rim then ch = (x + y + ph) % 4 == 0 and 'D' or 'B'
      elseif sqrt((x - mx) ^ 2 + (y - my) ^ 2) <= mr then ch = F.rnd(x // pk, y // pk, 7) > 0.8 and 'D' or 'E'
      elseif v > 0.3 then                                    -- a água: o rastro da lua, em linhas
        local row = floor((y - Y0) / pk)
        ch = (row % 2 == 0 and abs(x - mx - ((row + ph) % 4 < 2 and pk or 0)) < R * (0.62 - v * 0.42)) and 'D'
          or ((x // pk) % 3 == 0 and 'q' or 'r')
      elseif v > 0.3 - 1.01 * pk / R then ch = 'u'           -- a linha d'água
      else ch = ((x + y) // pk) % 2 == 0 and 'r' or 'q' end
      L.set(g, x, y, ch)
    end
  end end
end

local function draw(g, sg, k, o)
  local off = k > 1 and 1 or 0
  local P = F.pen(g, k, off, off)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local f = o.jump and (o.dy or 0) / k or 0                  -- a manilha
  local b = (o.dy or 0) / k + (alert and -1 or (crouch and 2 or 0))   -- o sapo
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0     -- a manilha ginga
  local lx = o.lean and 1 or 0
  local sw = (alert or crouch) and 0 or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local hb = b + (alert and -0.6 or 0)
  local rs = alert and 6 or (crouch and 3.4 or 5 + sw * 0.6) -- o papo enche e esvazia
  local RY = 25.6 + f
  -- a manilha: a borda de trás e o fundo do poço
  P:ell(16, RY - 0.4, 11.4, 2.3, 'y')
  P:ell(16, RY - 0.2, 9.8, 1.4, 'k')
  -- o sapo
  P:ell(14 + lx * 0.5, 20.4 + b, 7.8, 6.8, 'f', nil, -15)
  P:ell(11.6 + lx * 0.3, 23 + b, 5.4, 5, 'f')
  P:ell(21 + lx, 12.6 + hb, 5.6, 4.1, 'f', nil, -18)
  P:ell(25.4 + lx, 11.4 + hb, 3.0, 2.4, 'f', nil, -18)
  P:ell(20 + lx, 8.6 + hb, 2.7, 2.2, 'f')                    -- o calombo do olho
  P:ell(20.6 + lx, 16.4 + hb, 4.4, 2.6, 'x')                 -- a garganta
  P:ell(23.8 + lx, 13.6 + hb, 3.8, 1.1, 'x', nil, -18)       -- o beiço de baixo
  P:ell(17.4 + lx * 0.5, 22.6 + b, 3.6, 3.4, 'x')
  P:limb({ { 23 + lx, 20 + b }, { 25.2, RY - 0.6 }, { 25, RY + 1.6 } }, 1.2, 0.9, 'h')   -- o braço de trás
  -- a parede da manilha, por cima do sapo
  P:poly({ { 4.6 + st * 0.2, RY }, { 27.4 + st * 0.2, RY }, { 27.4 - st * 0.5, 31.8 + f }, { 4.6 - st * 0.5, 31.8 + f } }, 'y')
  P:ell(16 - st * 0.5, 31.8 + f, 11.4, 1.8, 'y')
  -- o braço da frente, pendurado na borda
  P:limb({ { 16.4 + lx * 0.5, 21.6 + b }, { 18.6, RY - 0.4 }, { 18.2, RY + 2 } }, 1.6, 1.1, 'h')
  Rl.toes(P, 18.2, RY + 2, 3, 2.4, 'h', 0, 1)
  Rl.toes(P, 25, RY + 1.6, k > 1 and 3 or 2, 2, 'h', 0, 1)
  Rl.skin(g, k, 'f', Rl.SKIN, { within = 'fxh' })
  Rl.skin(g, k, 'h', 'edcb', { within = 'h', seed = 5, zones = 2 })
  F.shade(g, 'x', Rl.BELLY, { p = k > 1 and 3 or 2, ax = 1, ay = 0.3, zones = 3, within = 'x', jit = k > 1 and 2 or 0 })
  F.shade(g, 'y', Rl.CONC, { p = k > 1 and 3 or 2, ax = 1, ay = 0, zones = 3, within = 'y', jit = k > 1 and 2 or 1, jw = 3 })
  -- o lábio da manilha (claro, com a sombra embaixo), a tinta amarela gasta na quina, uma trinca, e a água que
  -- transborda (dois fios)
  for x = 4, 28, 1 / k do
    for d = 0, 1.2, 1 / k do P:px(x, RY + d, (floor(x * k / 2) % 3 == 0) and 'i' or 'I', Rl.CONC) end
    P:px(x - st * 0.1, RY + 1.9, 'J', Rl.CONC)
  end
  for x = 5, 27, 1 / k do
    if F.rnd(floor(x * k), 2, 6) > 0.45 then P:px(x + st * 0.2, RY + 0.2, floor(x) % 3 == 0 and 'p' or 'P', Rl.CONC) end
  end
  P:limb({ { 12.6, RY + 1 }, { 13.4, RY + 3.4 }, { 12.8, RY + 5.6 } }, 0.3, 0.3, 'J', Rl.CONC)
  for n, x0 in ipairs({ 7.6, 22 }) do
    local len = floor((5.4 + n) * k)
    for s = 0, len do
      for wd = 0, math.max(0, floor(k * 0.6 + 0.5) - 1) do
        L.set(g, P:X(x0) + wd, P:Y(RY + 0.8) + s, ((s // math.max(1, floor(k))) + ph + n) % 3 == 0 and 'E' or 'D', Rl.CONC .. 'pP')
      end
    end
  end
  -- o papo: o espelho com a lua
  local sx, sy = 24 + lx, 19.6 + hb * 0.6 + b * 0.4 - (rs - 5) * 0.4
  moon(g, P, sx, sy, rs, ph)
  for n, q in ipairs({ { 2.4, -2.6 }, { 3.2, 0.2 }, { -0.4, -3.9 }, { -3.4, 0.6 } }) do
    if n <= 2 or k > 1 or alert then P:px(sx + q[1] * rs / 5, sy + q[2] * rs / 5, n % 2 == 0 and 'H' or 'Z', 'rq') end
  end
  -- a glândula, o olho fechado, a boca, a narina
  P:ell(15.6 + lx, 11.8 + hb, 2.9, 1.3, 'e', Rl.SKIN, -14); P:ell(15.6 + lx, 12.3 + hb, 2.7, 0.8, 'd', 'e', -14)
  P:ell(20.2 + lx, 8.6 + hb, 1.7, 1.1, 'W', Rl.SKIN)         -- a pálpebra, clara, e a fresta
  P:ell(20.2 + lx, 8.2 + hb, 1.7, 0.7, 'V', 'W')
  P:limb({ { 18.6 + lx, 9.5 + hb }, { 20.4 + lx, 9.8 + hb }, { 22 + lx, 9.2 + hb } }, 0.3, 0.3, 'a', Rl.SKIN .. Rl.BELLY)
  P:limb({ { 17.6 + lx, 14.8 + hb }, { 22.6 + lx, 13.9 + hb }, { 27.6 + lx, 12 + hb } }, 0.3, 0.3, 'a', Rl.SKIN .. Rl.BELLY)
  P:px(27 + lx, 9.9 + hb, 'a', Rl.SKIN)
  -- costuras do Véu: duas, de 2 px
  local w = math.max(1, floor(2 * k + 0.5))
  Rl.seam(P, { { 8.6 + lx * 0.3, 17 + b }, { 10.2 + lx * 0.3, 23.6 + b } }, w, 'X', Rl.SKIN, k > 1 and 2 or nil)
  Rl.seam(P, { { 15.4, RY + 1.6 }, { 16.2, 32.6 + f } }, w, '9', Rl.CONC, k > 1 and 2 or nil)
  F.prune(g, '', 'wellmirror')
  -- gotas: caem do papo e da borda
  for n, q in ipairs({ { 30.6, 22 }, { 29, 27 }, { 2.4, 27 }, { 31.6, 30 } }) do
    local r = (ph + n) % 4
    if r < 3 then Rl.drop(P, sg, q[1], q[2] + f + r * 1.2, false) end
  end
end

Rl.run {
  name = 'wellmirror', stage = 'espirito', W = 36, PW = 96, draw = draw, ownLean = true,
  fleeDy = { 1, 0, -1, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,6 vezes num quadro de 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.6, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 9, 19 }, green = { 7, 15 }, water = { 9, 17 }, residential = { 9, 15 }, lit = { 9, 18 },
    sacred = { 16, 3 }, crimson = { 13, 19 },
  },
}
