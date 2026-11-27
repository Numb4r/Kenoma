-- Cratercoil (wyrm.ritual), arte final: o teú atarracado saindo até o peito de um buraco chato no asfalto, as mãos
-- fincadas na borda, a cabeça rombuda de olho fechado e a língua bífida para fora (conceito revisão 4:
-- conceitos/rituais/cratercoil/build.lua). O altar é o próprio buraco: fixo, nunca anda nem salta; a fuga é mergulhar.
-- TRAÇO: três divisas rosa de 1 px sobre as faixas pretas e brancas, acendendo de baixo para cima a partir da frincha
-- de brasa na beira do buraco. Crânio escuro sem faixas, mandíbula clara; as faixas começam na nuca.
-- Camadas: corpo; leds = só a língua; glow = divisas, frincha da boca, frincha do buraco, início das rachaduras,
-- costuras e fagulhas.
-- As rachaduras e os riscos de garra são planos, sem contorno: entram depois do contorno (L.outline embrulhado).
-- Rodar: tools/art/rodar.sh tools/art/creatures/cratercoil/build.lua
local W = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wyrm.lua')
local R = dofile(KENOMA_ART .. 'creatures/conceitos/rituais/_ritual.lua')   -- só a caneta (R.pen) e o hash
local L = W.L
local floor, abs, sqrt, rad, cos, sin, max, min = math.floor, math.abs, math.sqrt, math.rad, math.cos, math.sin, math.max, math.min
local DARK = W.DARK
local SC = '1234cCw'                                                         -- o que é pele (corte, divisas)

local CR = { { 8, 29.6, 2, 30.4 }, { 28, 29.6, 34, 30.6 }, { 10.4, 31.2, 5, 32.8 }, { 26, 31.4, 31.6, 32.8 }, { 15, 32.2, 11.2, 33 } }
local CLAWS = { { 6.5, 4.2, 28.4 }, { 6.5, 5.2, 29.4 }, { 6.5, 6.8, 29.8 }, { 29.5, 31.8, 28.4 }, { 29.5, 30.8, 29.4 }, { 29.5, 29.2, 29.8 } }
local SPARKS = { { 30.4, 3.4, 's' }, { 33, 8, 'S' }, { 23, 3, 'S' }, { 4, 16, 's' }, { 32, 17, 'S' }, { 2.6, 22, 's' }, { 33.6, 22, 'S' }, { 12, 11, 's' } }
local RAISE = { R = 'J', J = 'H' }

-- rachaduras e riscos: só no vazio, depois do contorno (K.run chama L.outline; g.over roda logo em seguida)
local outline = L.outline
function L.outline(g, ...)
  outline(g, ...)
  if g.over then g.over(g) end
end

local function draw(g, sg, k, o)
  local ox, oy = o.ox or 0, o.oy or 0
  local P = R.pen(g, k, ox, oy)
  local ph = (o.ph or (o.portrait and o.portrait - 1) or 0) % 4
  local alert, crouch, flee = o.pose == 'alert', o.pose == 'crouch', o.flee
  local still = alert or crouch
  local p = k > 1 and 2 or 1
  local hot = o.hot or 0
  local bob = (o.portrait and ({ 0, -1, 0, 1 })[o.portrait] or (o.dy or 0)) / k        -- pescoço e cabeça
  local ex = alert and -1.5 or (crouch and (flee and 0.5 or 1) or 0)
  local hy = bob + ex
  local hx = (o.lean and not flee) and 1 or 0
  local delta = alert and -8 or 0
  local tS = flee and 2 * bob or 0                                                  -- o tronco baixo desce mais
  local pulse = still and -1 or ph
  local function chk(x, y) return (x // p + y // p) % 2 end
  local function darkc(x, y, l) return DARK[(l > 0.35 and 1 or l > -0.2 and 2 or 3) + chk(x, y)] end
  local function X(u) return u * k + ox - 0.5 end
  local function Y(v) return v * k + oy - 0.5 end
  local function norm(u, v) return ((u - 18) / 10) ^ 2 + ((v - 28.5) / 3.2) ^ 2 end
  -- elipse sombreada (u, v em unidades do mapa); sh(x, y, uu, vv, l)
  local function ellsh(Q, cx, cy, rx, ry, a, sh)
    local ca, sa, rm = cos(rad(a)), sin(rad(a)), max(rx, ry)
    Q:fill(cx - rm, cy - rm, cx + rm, cy + rm, nil, nil, function(u, v, x, y)
      local dx, dy = u - cx, v - cy
      local uu, vv = (dx * ca + dy * sa) / rx, (-dx * sa + dy * ca) / ry
      if uu * uu + vv * vv <= 1 then return sh(x, y, uu, vv, -(dy * 0.8 + dx * 0.5) / rm) end
    end)
  end

  -- 1. o buraco, a parede de trás e a terra sob o corte
  P:ell(18, 28.5, 10, 3.2, 'z')
  local wall = {}
  P:fill(7, 24, 29, 30, nil, 'z', function(u, v, x, y)
    if v < 28.5 and norm(u, v) > 0.45 then
      wall[y * g.w + x] = true
      if k > 1 and R.hash(x, y, 5) % 11 == 0 then return R.hash(x, y, 6) % 2 == 0 and 'p' or 'g' end   -- brita (retrato)
      return R.hash(x, y, 9) % 3 == 0 and 'Q' or 'P'
    end
  end)
  for key in pairs(wall) do
    local x, y = key % g.w, key // g.w
    for j = 1, p do
      if g[y + j] and g[y + j][x] == 'z' and not wall[(y + j) * g.w + x] then g[y + j][x] = R.hash(x, y + j, 3) % 3 > 0 and 'e' or 'E' else break end
    end
  end

  -- 2. tronco e pescoço (faixas 2 e 2 inclinadas, ancoradas no corpo), cortados pela beira da frente
  local function sShift(v)
    local f = max(0, min(1, (16 - v) / 4))
    return hy * f + tS * (1 - f)
  end
  local function band(x, y, t, dn, ds, r, l)
    local u, v = (x + 0.5 - ox) / k, (y + 0.5 - oy) / k
    v = v - sShift(v)
    if floor((v + (u - 17) * 0.35) / 2) % 2 == 0 then
      return chk(x, y) == 0 and (l > 0.35 and 'w' or 'c') or 'C'
    end
    return darkc(x, y, l)
  end
  W.tube(g, W.spline({ { X(18), Y(29 + tS) }, { X(16.5), Y(22 + tS) }, { X(17.5), Y(16 + bob) } }),
    W.prof({ { 0, 4.2 }, { 1, 3.6 } }, k), band)
  W.tube(g, W.seg(X(17.5), Y(16 + bob), X(20 + hx), Y(11.5 + hy)), W.prof({ { 0, 3.6 }, { 1, 3.2 } }, k), band)
  P:fill(8, 24, 28, 45, nil, nil, function(u, v, x, y)
    if v > 29.6 and SC:find(g[y][x], 1, true) then return norm(u, v) <= 1 and 'z' or '.' end
  end)
  -- a frincha de brasa na beira do buraco (sobe um degrau na fase 0; na fuga fica em H)
  local hole = flee and 'H' or (pulse == 0 and 'J' or 'R')
  P:fill(10, 28, 26, 33, nil, 'z', function(u, v) if v >= 29.6 and v < 30.6 and abs(u - 18) < 5 then return hole end end)
  -- as três divisas (cima J, meio R, baixo J), uma por fase de baixo para cima
  for i, a in ipairs({ 15.5, 19, 22.5 }) do
    local ch = i == 2 and 'R' or 'J'
    if pulse == 4 - i then ch = RAISE[ch] end
    P:fill(13, 12, 22, 36, nil, SC, function(u, v)
      local d = abs(u - 17)
      if d < 3 and abs(v - (a + tS + 0.9 * d)) < 0.4 then return ch end
    end)
  end

  -- 3. a cabeça (num quadro à parte, para a boca e o olho só pegarem nela), girada no alerta
  local hd = L.grid(g.w, g.h)
  local HP = R.pen(hd, k, ox, oy)
  local ca, sa = cos(rad(delta)), sin(rad(delta))
  local function hp(u, v)
    local dx, dy = u - 20, v - 11.5
    return { 20 + hx + dx * ca - dy * sa, 11.5 + hy + dx * sa + dy * ca }
  end
  local j = hp(21, 11.2)
  ellsh(HP, j[1], j[2], 2.6, 2.4, 0, function(x, y, uu, vv, l)
    return l > 0.2 and (chk(x, y) == 0 and 'w' or 'c') or (chk(x, y) == 0 and 'c' or 'C')
  end)
  local s = hp(23.5, 9.5)
  ellsh(HP, s[1], s[2], 5, 3.1, -12 + delta, function(x, y, uu, vv, l)
    if vv < -0.5 then return '1' end
    return DARK[(l > 0.2 and 1 or l > -0.3 and 2 or 3) + chk(x, y)]
  end)
  local function seg(a, b, r0, r1, ch, mask) HP:limb({ hp(a[1], a[2]), hp(b[1], b[2]) }, r0, r1, ch, mask) end
  local before = {}
  for y = 0, hd.h - 1 do before[y] = {}; for x = 0, hd.w - 1 do before[y][x] = hd[y][x] end end
  seg({ 23, 7.8 }, { 24.8, 7.4 }, 0.5, 0.5, '4', '1234')                                 -- o olho fechado
  for y = 1, hd.h - 1 do for x = 0, hd.w - 1 do
    if hd[y][x] == '4' and before[y][x] ~= '4' and ('234'):find(hd[y - 1][x], 1, true) then hd[y - 1][x] = '1' end
  end end
  seg({ 22.5, 10.8 }, { 28, 9.4 }, 0.45, 0.45, 'R', '1234wcC')                           -- a frincha da boca
  seg({ 22.5, 10.8 }, { 24.2, 10.4 }, 0.5, 0.5, 'J', 'R')
  if k > 1 then
    seg({ 27.2, 8.7 }, { 27.6, 8.8 }, 0.2, 0.2, '4', '1234')                             -- narina
    seg({ 23.6, 7.2 }, { 24, 7.9 }, 0.2, 0.2, 'k', '1234'); seg({ 25.4, 6.3 }, { 25.8, 7 }, 0.2, 0.2, 'k', '1234')
  end
  for y = 0, hd.h - 1 do for x = 0, hd.w - 1 do if hd[y][x] ~= '.' then g[y][x] = hd[y][x] end end end
  -- a língua (leds): haste M, forquilhas T; no retrato ela varre
  local tl
  if flee then tl = o.flee == 1 and 0 or (o.flee == 2 and 1 or 0.6)
  else tl = alert and 1 or (crouch and 0 or ({ [0] = 1, 0.6, 0, 0.6 })[ph]) end
  if tl > 0.01 then
    local sw = o.portrait and ({ 0, -0.8, 0, 0.8 })[o.portrait] or 0
    local r0, s1 = hp(28, 9.4), hp(28 + 2.5 * tl, 9.4 + 0.8 * tl + sw)
    P:limb({ r0, s1 }, 0.45, 0.45, 'M')
    P:limb({ s1, { s1[1] + 1.5 * tl * ca, s1[2] - 1.0 * tl + sw * 0.5 } }, 0.4, 0.4, 'T')
    P:limb({ s1, { s1[1] + 1.5 * tl * ca, s1[2] + 1.2 * tl + sw * 0.5 } }, 0.4, 0.4, 'T')
  end

  -- 4. os braços fincados na borda (parados), as mãos e três garras por mão
  if not (flee and o.flee >= 3) then
    local function armSh(x, y, t, dn, ds, r, l)
      if l > 0.8 then return '1' end
      if R.hash(x, y, 4) % 7 == 0 then return 'c' end
      return darkc(x, y, l - 0.35)
    end
    for _, a in ipairs({ { 14, 21, 5.5, 22, 6.5, 27 }, { 20, 21, 30.5, 22, 29.5, 27 } }) do
      W.tube(g, W.seg(X(a[1]), Y(a[2]), X(a[3]), Y(a[4])), W.prof({ { 0, 2.0 }, { 1, 1.75 } }, k), armSh)
      W.tube(g, W.seg(X(a[3]), Y(a[4]), X(a[5]), Y(a[6])), W.prof({ { 0, 1.75 }, { 1, 1.5 } }, k), armSh)
    end
    for _, hu in ipairs({ 6.5, 29.5 }) do
      ellsh(P, hu, 27.6, 1.8, 1, 0, function(x, y, uu, vv, l) return darkc(x, y, l) end)
    end
    for _, c in ipairs(CLAWS) do
      P:limb({ { c[1], 27.8 }, { c[2], c[3] } }, 0.45, 0.45, 'K')
      for dy = 0, p - 1 do for dx = 0, p - 1 do
        local x, y = floor(c[2] * k + ox) + dx, floor(c[3] * k + oy) + dy
        if g[y] and g[y][x] == 'K' then g[y][x] = 'k' end
      end end
      if k > 1 then P:limb({ { c[1], 28.3 }, { c[1] + (c[2] - c[1]) * 0.3, 28.3 + (c[3] - 28.3) * 0.3 } }, 0.3, 0.3, 'e', 'K') end
    end
  end

  -- 5. costuras do Véu (só glow): duas passadas, Z na escama e 9 na faixa clara
  local function seam(a, b)
    local r = k > 1 and 0.8 or 1.0
    for _, m in ipairs({ { 'Z', '1234' }, { '9', 'cCw' } }) do
      P:limb({ a, b }, r, r, m[1], m[2])
      if k > 1 then
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local n = sqrt(dx * dx + dy * dy)
        for _, t in ipairs({ 0.25, 0.75 }) do
          local cx, cy = a[1] + dx * t, a[2] + dy * t
          local nx, ny = -dy / n * (r + 1.2), dx / n * (r + 1.2)
          P:limb({ { cx - nx, cy - ny }, { cx + nx, cy + ny } }, 0.2, 0.2, m[1], m[2])
        end
      end
    end
  end
  local h1, h2 = hp(19.4, 11.2), hp(20.6, 13.6)
  seam(h1, h2)
  seam({ 25, 19.7 }, { 25.2, 23.4 })

  -- 6. rachaduras (brasa em 34%, 50%, 66% do comprimento) e riscos de garra, planos, depois do contorno
  local pct = ({ [0] = 0.34, 0.5, 0.66 })[hot] or 0.34
  g.over = function(gg)
    local function put(x, y, ch)
      if x > 0 and y > 0 and x < gg.w - 1 and y < gg.h - 1 and gg[y][x] == '.' then gg[y][x] = ch end
    end
    for ci, c in ipairs(CR) do
      for i = 0, 40 do
        local f = i / 40
        local x, y = floor((c[1] + (c[3] - c[1]) * f) * k + ox), floor((c[2] + (c[4] - c[2]) * f) * k + oy)
        local ch = f < pct and 'R' or ((k > 1 and ci == 2 and f > 0.55 and f < 0.75) and 'o' or 'Q')
        for dy = 0, p - 1 do for dx = 0, p - 1 do put(x + dx, y + dy, ch) end end
      end
    end
    if flee and o.flee >= 3 then
      for _, c in ipairs(CLAWS) do
        local dx, dy = c[1] - c[2], 27.8 - c[3]
        local n = sqrt(dx * dx + dy * dy)
        for s2 = 0, 1 do
          local x = floor((c[2] + dx / n * s2 / k) * k + ox)
          local y = floor((c[3] + dy / n * s2 / k) * k + oy)
          for yy = 0, p - 1 do for xx = 0, p - 1 do put(x + xx, y + yy, 'Q') end end
        end
      end
    end
  end

  -- 7. fagulhas (na deriva só as de trás)
  local list = SPARKS
  if o.lean and not flee then
    list = {}
    for _, q in ipairs(SPARKS) do if q[1] < 18 then list[#list + 1] = q end end
  end
  W.dust(g, sg, list, ph, 4, k, ox, oy)
end

W.run {
  name = 'cratercoil', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 2, 4, 6, 8 },
  over = {
    alert = function(_, os)
      return { { pose = 'alert' }, { pose = 'alert', hot = 1 }, { pose = 'alert', hot = 2, sparks = { { 21, 2, 's' }, { 25, 1, 'S' } } } }
    end,
    flee = function(_, os)
      for i, f in ipairs(os) do f.flee = i; f.sparks = nil end
      return os
    end,
  },
  -- o retrato é o mesmo draw a 2,5x, deslocado (3, 3)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    o.ox, o.oy = 3, 3
    draw(g, sg, 2.5, o)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 20, 1 }, residential = { 20, 5 }, water = { 15, 6 }, crimson = { 19, 7 },
    urban = { 17, 11 }, green = { 13, 12 }, lit = { 15, 12 },
  },
}
