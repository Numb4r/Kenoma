-- Entidade Maior da família Soot (nome e pasta provisórios: soot_entidade), arte final a partir do conceito aprovado:
-- o saruê enrolado na própria brasa. A tampa do bueiro é o corpo; três pescoços de gambá saem dela em cata-vento, sem
-- olhos, só a boca aberta com os dentes; os seis olhos ficaram na tampa, em volta da brasa (piscam um de cada vez);
-- três rabos entre os pescoços, cada um com a bituca na ponta.
-- REGRA QUEBRADA: o fogo dela pende. A chama escorre para baixo, da brasa pela tampa, das pontas dos rabos e das
-- bocas, como baba: cresce, pinga e recomeça.
-- Costuras do Véu: duas, de 3 px: uma atravessa a tampa (o ferro soldado de volta) e uma dá a volta num pescoço.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/soot_entidade/build.lua')
local S = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_soot.lua')
local L, F = S.L, S.F
local floor, ceil, abs, sqrt, sin, cos, rad = math.floor, math.ceil, math.abs, math.sqrt, math.sin, math.cos, math.rad
local IRON = S.IRON

local function draw(g, sg, k, o)
  local P = F.pen(g, k, 0, 0)
  local ph = (o.ph or 0) % (o.portrait and 4 or 6)
  local t = ph / (o.portrait and 4 or 6) * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local rot = (still and 0 or 4 * sin(t)) + (o.lean and 8 or 0)   -- o cata-vento balança; na deriva, tomba para a frente
  local ext = alert and 1 or (crouch and -2 or 0)                   -- pescoços e rabos esticam no alerta e encolhem
  local grow = still and (alert and 1 or 0) or (0.5 - 0.5 * cos(t))
  local cx, cy = 23.5, 24.2
  local function pol(a, r) return { cx + cos(rad(a + rot)) * r, cy + sin(rad(a + rot)) * r } end
  local drips, heads = {}, {}
  for n = 0, 2 do
    local a = -100 + n * 120
    P:limb({ pol(a + 62, 9.5), pol(a + 72, 13 + ext * 0.5), pol(a + 86, 16.6 + ext), pol(a + 102, 18.8 + ext), pol(a + 116, 19.2 + ext) },
      1.5, 0.85, 't')
    drips[#drips + 1] = pol(a + 116, 19.2 + ext)
  end
  for n = 0, 2 do
    local a = -100 + n * 120
    P:limb({ pol(a, 8.5), pol(a + 14, 12.5 + ext * 0.5), pol(a + 28, 14.4 + ext) }, 2.6, 2.1, 'f')
    local h = pol(a + 40, 15.6 + ext)
    local open = alert and 1.8 or (crouch and 0.4 or 1 + 0.5 * sin(t + n * 2.1))   -- as bocas abrem fora de fase
    heads[#heads + 1] = S.head(P, k, h[1], h[2], a + rot + 40 + 74, 1.0, { open = open, ear = 1 })
    drips[#drips + 1] = heads[#heads](5, 2.1 + 1.5 * open)
  end
  -- tampa
  local R = 10.4
  local X0, Y0, RR = P:X(cx), P:Y(cy), R * k
  for y = floor(Y0 - RR), ceil(Y0 + RR) do for x = floor(X0 - RR), ceil(X0 + RR) do
    local dx, dy = x - X0, y - Y0
    local d = sqrt(dx * dx + dy * dy) / k
    if d <= R then
      local an = math.atan(dy, dx)
      local lt = (-dx - dy) / (RR * 1.414)                 -- 1 do lado da luz
      local idx = lt > 0.35 and 0 or lt > -0.25 and 1 or 2
      local seg = (floor((an + 3.1416) / 6.2832 * 12) + floor(d / 2.1)) % 2
      local ch
      if d > R - 1.1 then ch = IRON:sub(math.min(4, idx + 2), math.min(4, idx + 2))
      elseif abs(d - 4.2) < 0.5 then ch = 'R'
      elseif abs(d - 8.2) < 0.4 then ch = seg == 0 and 'R' or 'J'
      else ch = IRON:sub(math.min(4, idx + 1 + seg), math.min(4, idx + 1 + seg)) end
      if d < R - 1.1 and d > 5 and F.rnd(floor(x / k), floor(y / k), 4) > 0.94 then ch = seg == 0 and 'N' or 'n' end
      g[y][x] = ch
    end
  end end
  S.furShade(g, k, 'f', 'dcba', { zones = 2, within = 'f', bias = 0.1 })
  S.faceShade(g, k, 2)
  S.skinShade(g, k)
  for _, T in ipairs(heads) do S.headFinish(P, k, T, 1.0, {}) end
  -- costuras do Véu: uma atravessa a tampa, a outra dá a volta num pescoço
  local w = math.max(1, floor(3 * k + 0.5))
  S.seam(P, { { cx - 9.6, cy - 3.6 }, { cx - 4.8, cy + 9 } }, w, '9', IRON .. 'nNR', k > 1 and 2.4 or nil)
  S.seam(P, { pol(20 + 14, 9.6), pol(20 + 14, 15.4) }, w, 'X', S.FUR, k > 1 and 2.4 or nil)
  -- os olhos na tampa: piscam um de cada vez
  for n = 0, 5 do
    local e = { cx + cos(rad(n * 60 + 35)) * 6.4, cy + sin(rad(n * 60 + 35)) * 6.4 }
    P:ell(e[1], e[2], 2.0, 1.4, 'J')
    if still or n ~= ph then
      if k > 1 then P:ell(e[1], e[2], 1.25, 0.85, 'V'); P:disc(e[1], e[2], 0.55, 'k'); P:px(e[1], e[2], 'B')
      else P:px(e[1] - 1, e[2], 'V'); P:px(e[1] + 1, e[2], 'V'); P:px(e[1], e[2], 'B') end
    end
  end
  -- a brasa no furo do meio e a chama que escorre pela tampa
  S.ember(g, X0, Y0, 3.3 * k, 31, IRON .. 'nNR', 0, grow)
  for n = 0, 2 do
    local x = cx - 1.6 + n * 1.6
    local len = (6 + F.rnd(n, 3, 3) * 2.4) * (still and 1 or 0.8 + 0.2 * sin(t - n * 2))
    for s = 0, len * k do
      local tt = s / (len * k)
      for wdt = 0, (k > 1 and 1 or 0) do
        L.set(g, P:X(x + sin(tt * 4 + n) * 0.5) + wdt, P:Y(cy + 2) + s, tt < 0.35 and 'Y' or tt < 0.75 and 'E' or 'R', IRON .. 'nNR')
      end
    end
  end
  for n = 1, 3 do S.buttTip(P, k, drips[n][1], drips[n][2], 0, 0.2, (ph + n) % 3 == 0) end
  -- o fogo pende das pontas dos rabos e das bocas (solto, só no glow): cresce, pinga e recomeça
  local NL = o.portrait and 4 or 6
  for n, q in ipairs(drips) do
    local r = still and NL - 2 or (ph + n * 2) % NL
    local len = ((n <= 3 and 5 or 3.4) + F.rnd(n, 1, 6) * 2) * (0.45 + 0.55 * math.min(1, r / (NL - 2)))
    for s = 1, floor(len * k) do
      local tt = s / (len * k)
      for wdt = 0, (k > 1 and (tt < 0.5 and 1 or 0) or 0) do
        local x = floor(P:X(q[1]) + wdt + sin(tt * 5 + n) * 0.8 + 0.5 - (o.lean and tt * 2 * k or 0))
        local y = floor(P:Y(q[2] + 0.8) + s + 0.5)
        if y <= g.h - 2 and L.get(g, x, y) == '.' then L.set(sg, x, y, tt < 0.3 and 's' or tt < 0.7 and 'S' or 'T') end
      end
    end
    if r >= NL - 2 and q[2] + len + 3 < 46 then S.spark(P, sg, q[1] + (n % 2 == 0 and 0.6 or -0.6), q[2] + len + 2 + (r - NL + 2) * 1.2, 'T') end
  end
end

S.run {
  name = 'soot_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, DARK = 'J', ownLean = true,
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 0, 0, 0, -1, -1, -1 },
  -- o retrato é o desenho de 48 ampliado 2 vezes, com o olho inteiro em cada olho da tampa
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 14 }, green = { 18, 13 }, water = { 20, 28 }, residential = { 20, 29 }, lit = { 20, 30 },
    sacred = { 20, 12 }, crimson = { 14, 23 },
  },
}
