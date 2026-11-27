-- Duskwreath (sprig.ritual), arte final: a maritaca de pé no chão, grande e na frente, de olho fechado, parada como
-- ídolo (body_dy 0). As duas asas são ramos de casca com folhas secas serrilhadas em leque (4 atrás, 3 na frente) que
-- sobem por trás do corpo e NÃO se fecham: a abertura fica em cima da cabeça. O crepúsculo é luz solta nos cinco vãos
-- entre as folhas, sem disco; na abertura fica escuro. Azul na garganta, crisso vermelho, raminho em casca.
-- Camadas: corpo; leds = o ponto de cada forquilha e a ponta das nervuras (piscam); glow = as nervuras, a luz dos
-- vãos (solta, sem par), as duas costuras do Véu na pena.
-- Animação: aL/aR = graus somados aos ângulos do braço esquerdo e direito (ramo e folhas juntos) em volta de (18, 19);
-- positivo fecha a esquerda, negativo fecha a direita; em todo quadro aL <= +2 e aR >= -2 (a coroa nunca fecha).
-- Rodar: tools/art/rodar.sh tools/art/creatures/duskwreath/build.lua
local Sp = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_sprig.lua')
local L, H = Sp.L, Sp.H
local sin, cos, pi, floor, max, atan, sqrt, deg = math.sin, math.cos, math.pi, math.floor, math.max, math.atan, math.sqrt, math.deg
local CX, CY = 18, 19                                  -- o centro da coroa
local FX, FY = 19.6, 31                                -- onde o corpo inclina (os pés)

-- folhas: { braço (1 esquerdo, 2 direito), base, ponta, comprimento } (1 a 7)
local LEAF = {
  { 1, 9.1, 22.2, 3, 24.5 }, { 1, 8.8, 16.7, 2.5, 15 }, { 1, 11.6, 11.9, 7.3, 7.1 }, { 1, 16.7, 9.6, 16.7, 3.1 },
  { 2, 25.3, 12.9, 29.6, 8.1 }, { 2, 27.4, 17.4, 33.4, 17.2 }, { 2, 26.9, 22.2, 33, 24.5 },
}
local ARM = {                                          -- ramo: ombro (fixo) e depois os pontos que giram com o braço
  { { 16, 20.6 }, { 11, 22.4 }, { 9.1, 22.2 }, { 8.8, 16.7 }, { 11.6, 11.9 }, { 16.7, 9.6 } },
  { { 22.6, 20.4 }, { 26.9, 22.2 }, { 27.4, 17.4 }, { 25.3, 12.9 } },
}
local FORK = { { 1, 8.5, 19.5 }, { 1, 9.9, 14.1 }, { 1, 14, 10.4 }, { 2, 26.6, 15 }, { 2, 27.5, 19.8 } }
-- a luz dos vãos: { s por dentro, S por fora } (36 px), a 177, 211, 245, 335 e 5 graus
local GAP = {
  { { 6.5, 19.6 }, { 4.5, 19.7 } }, { { 8.1, 13.1 }, { 6.4, 12 } }, { { 13.1, 8.6 }, { 12.3, 6.8 } },
  { { 28.4, 14.1 }, { 30.2, 13.3 } }, { { 29.5, 20 }, { 31.4, 20.2 } },
}
local GANG = { 177, 211, 245, 335, 5 }

local function draw(g, sg, k, o)
  local rich = k > 1
  local NL = o.portrait and 4 or 8
  local ph = (o.ph or 0) % NL
  local t = ph / NL * 2 * pi
  local m = rich and 0.5 or 1
  local pose = o.pose
  local aL, aR, rs, lf, fan, crown, tl, sq, hy, ws = 0, 0, 1, 1, 0, 0, 0, 0, 0, 1
  if pose == 'alert' then aL, aR, rs, lf, fan, hy, ws = -6, 6, 10.5 / 9.5, 0.9, 6, 0.4, 0
  elseif pose == 'crouch' then rs, lf, sq, ws = 8 / 9.5, 0.8, 1, 0
  elseif pose == 'half' then rs, lf, ws = 8.5 / 9.5, 0.85, 0
  else
    aL = -1 + 3 * m * sin(t)
    aR = 1 - 3 * m * sin(t + 1.2)
    if o.dash then crown, tl = -10, 8 elseif o.lean then crown, tl = -6, 4 end
  end
  local br = (1 - cos(t)) / 2
  local cdx = o.cdx or 0                               -- a coroa recua para caber no quadro
  local function P(v) return v * k end
  local function pt(x, y)                              -- o corpo: inclina sobre os pés, que ficam
    x, y = Sp.H.spin(x, y, FX, FY, tl)
    return x * k, (y + sq) * k
  end
  local function hp(x, y) return pt(x, y - hy) end     -- a cabeça: sobe no alerta
  local function A(side, x, y)                         -- o braço: raio, giro do braço e da coroa, depois o corpo
    x, y = CX + (x - CX) * rs, CY + (y - CY) * rs
    x, y = Sp.H.spin(x, y, CX, CY, (side == 1 and aL or aR) + crown)
    x, y = pt(x, y)
    return x + cdx * k, y
  end
  local function E(f, x, y, rx, ry, ang, sh)
    local X, Y = f(x, y)
    H.ell(g, X, Y, P(rx), P(ry), ang + tl, sh)
  end

  -- o rabo (balança), os pés (ficam) e os ramos
  local ts = 4 * m * sin(t + 1.5) * ws
  do
    local x0, y0 = pt(17, 28.5)
    local x1, y1 = pt(H.spin(14.6, 33, 17, 28.5, ts))
    y1 = math.min(y1, 33 * k)                          -- a ponta não passa do chão do quadro
    H.tube(g, H.seg(x0, y0, x1, y1), function(u) return P(1.6 - 0.6 * u) end, function(x, y, u, dn, ds, r, l)
      return (floor(ds) % 2 == 0) and (l > 0 and '2' or '3') or (l > 0 and '3' or '4')
    end)
  end
  for side = 1, 2 do
    local pts = ARM[side]
    local n = #pts - 1
    local sx, sy = pt(pts[1][1], pts[1][2])
    local px, py = sx, sy
    for i = 2, #pts do
      local x, y = A(side, pts[i][1], pts[i][2])
      H.tube(g, H.seg(px, py, x, y), function(u) return P(1.1 - 0.4 * (i - 2 + u) / n) end, H.bark(H.BARK))
      px, py = x, y
    end
  end
  -- as folhas: as quatro de lá primeiro, as três de cá na frente; ímpares NEAR, pares DARK
  for n, q in ipairs(LEAF) do
    local ang0 = deg(atan(q[5] - q[3], q[4] - q[2]))
    local len = sqrt((q[4] - q[2]) ^ 2 + (q[5] - q[3]) ^ 2)
    local wig = 5 * m * ws * (n % 2 == 1 and 1 or -1) * sin(t)
    local x, y = A(q[1], q[2], q[3])
    local o2 = { x = x, y = y, ang = ang0 + (q[1] == 1 and aL or aR) + crown + tl + wig + (q[1] == 1 and -fan or fan),
      len = P(len * lf), wid = P(2.0), k = k, pal = n % 2 == 1 and H.NEAR or H.DARK, notch = n, vp = max(2, 1.5 * k) }
    if rich then o2.litv, o2.spots = 0.4, 3 end
    H.leaf(g, o2)
    if rich and (n == 2 or n == 6) then                -- mordidas no retrato
      local a = o2.ang * pi / 180
      local dx, dy = cos(a), sin(a)
      for _, b in ipairs({ { 0.55, 0.8 }, { 0.78, -0.8 } }) do
        L.disc(g, x + dx * o2.len * b[1] - dy * o2.wid * b[2], y + dy * o2.len * b[1] + dx * o2.wid * b[2], 0.8 * k, '.')
      end
    end
  end
  -- forquilhas (leds)
  for _, f in ipairs(FORK) do
    local x, y = A(f[1], f[2], f[3])
    local s = max(1, floor(k * 0.6 + 0.5))
    L.rect(g, floor(x), floor(y), floor(x) + s - 1, floor(y) + s - 1, 'L')
  end
  -- o corpo, a coberteira do ombro, a cabeça
  E(pt, 19, 23, 5.6, 7.4 + 0.35 * br * ws, 0, H.feather(H.BODY))
  E(pt, 16.6, 22.5, 2.6, 5, 0, H.feather({ '2', '3', '4', '4' }))
  for _, fx in ipairs({ 18.2, 21 }) do
    H.wire(g, { { P(fx), P(29.6) }, { P(fx), P(32.4) }, { P(fx + 2), P(32.4) } }, 'T', 'x', k * 0.8)
  end
  E(pt, 17.4, 29.6, 2.2, 1.1, 118, H.stripes('r', 'R'))
  E(hp, 20.5, 12.5, 4.4, 4.2, 0, H.feather(H.HEAD))
  E(hp, 22, 16.2, 2.1, 1.1, 0, H.stripes('u', 'U'))
  do
    local x, y = hp(24.2, 12.6)
    H.beak(g, x, y, 8 + tl, k, false)
    if rich then                                       -- o olho fechado: arco claro com 1 px de q embaixo
      local n = math.ceil(1.8 * k * 2)
      for _, c in ipairs({ { 'q', 1 }, { 'w', 0 } }) do
        for i = 0, n do
          local s = i / n
          local X, Y = hp(21.2 + 1.8 * s, 12.4 + 0.5 * sin(pi * s))
          L.set(g, X, Y + c[2], c[1])
        end
      end
    else
      for _, ex in ipairs({ 21.5, 22.5 }) do local X, Y = hp(ex, 12.5); L.set(g, X, Y, 'w') end
    end
  end
  if not o.dark then L.outline(g, 'A', H.SOLID) end
  H.fae(g)
  -- as duas costuras do Véu, só na pena
  for _, q in ipairs({ { pt, 21.6, 22.6, 22.4, 25.6 }, { hp, 16.8, 10.8, 17.6, 13.4 } }) do
    local x0, y0 = q[1](q[2], q[3])
    local x1, y1 = q[1](q[4], q[5])
    H.seamLine(g, x0, y0, x1, y1, rich and 3 or 2)
  end
  local src = g
  return src
end

-- a luz dos vãos: solta, só onde o corpo está vazio (depois do Sp.place)
local function gaps(g, sg, k, o, ph, NL)
  local pose = o.pose
  local rs = pose == 'crouch' and 8 / 9.5 or (pose == 'half' and 8.5 / 9.5 or (pose == 'alert' and 10.5 / 9.5 or 1))
  local crown, tl = 0, 0
  if not pose then if o.dash then crown, tl = -10, 8 elseif o.lean then crown, tl = -6, 4 end end
  local base = max(1, floor(k * 0.6 + 0.5))
  local sweep
  if not pose and not o.dash then
    if o.portrait then sweep = ({ 1, 2, 4, 5 })[ph + 1] else sweep = ph <= 4 and ph + 1 or nil end
  end
  local function lite(x, y, n, ch)
    x, y = x * k, y * k
    for j = 0, n - 1 do for i = 0, n - 1 do
      local px, py = floor(x + 0.5) + i, floor(y + 0.5) + j
      if L.get(g, px, py) == '.' then L.set(sg, px, py, ch) end
    end end
  end
  for i = 1, 5 do
    local on = not (o.lean and not o.dash and i > 3)
    if on then
      local function T(q)
        local x, y = CX + (q[1] - CX) * rs, CY + (q[2] - CY) * rs
        x, y = H.spin(x, y, CX, CY, crown)
        x, y = H.spin(x, y, FX, FY, tl)
        if o.dash then x = x - 2 end
        x = x + (o.cdx or 0)
        return x, y
      end
      local n = pose == 'alert' and (o.glow or 1) or base
      local x, y = T(GAP[i][1]); lite(x, y, n, 's')
      x, y = T(GAP[i][2]); lite(x, y, n, 'S')
      if sweep == i or (o.lean and not o.dash and i <= 3 and ph == i - 1) then
        local a = math.rad(GANG[i])
        x, y = T({ CX + cos(a) * 15.5, CY + sin(a) * 15.5 }); lite(x, y, base, 's')
      end
    end
  end
end

local function full(g, sg, k, o)
  local NL = o.portrait and 4 or 8
  local ph = (o.ph or 0) % NL
  o.cdx = o.pose == 'alert' and 0 or (o.dash and -2 or (o.lean and -1 or 0))
  local src = draw(g, sg, k, o)
  local s = L.grid(g.w, g.h)
  Sp.place(g, sg, src, { k = k, ph = ph % 4, NL = 4, piv = 33, dark = o.dark })
  gaps(g, sg, k, o, ph, NL)
end

Sp.run {
  name = 'duskwreath', stage = 'espirito', W = 36, PW = 96, draw = full,
  nloop = 8, dy = { 0, 0, 0, 0, 0, 0, 0, 0 }, fps = { idle = 6, drift = 6 }, fleeDy = { 0, 0, -1, -1, -1, -1 },
  over = {
    alert = function(_, os) for i = 1, #os do os[i].glow = i end return os end,
    flee = function(_, os) for i = 2, #os do os[i].dash = true end return os end,
    spawn = function(_, os) os[5].pose = 'half'; return os end,
  },
  -- o retrato é o mesmo desenho feito em 96, com a textura no pixel
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    full(g, sg, 96 / 36, o)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 18, 4 }, crimson = { 19, 9 }, green = { 13, 16 }, lit = { 15, 19 },
    water = { 14, 22 }, residential = { 13, 25 }, urban = { 16, 26 },
  },
}
