-- Stormlamp (hum.ritual), arte final: a mariposa do Hum pousada, vista de cima, de asas fechadas em delta, parada como
-- ídolo. O tórax é um globo de lâmpada de rua (aro de cobre, dois isoladores de porcelana) com um raio dentro, e a
-- ponta de baixo do raio cai sempre no mesmo pixel. Os dois ocelos ficam de pálpebra baixa em todo quadro.
-- Mesma silhueta do conceito (conceitos/rituais/stormlamp/build.lua), refeita na linguagem do kit Hum (_hum.lua).
-- Rodar: tools/art/rodar.sh tools/art/creatures/stormlamp/build.lua
local K = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_hum.lua')
local R = dofile(KENOMA_ART .. 'creatures/conceitos/rituais/_ritual.lua')
local L = K.L
local floor, sqrt, atan, cos, sin, rad = math.floor, math.sqrt, math.atan, math.cos, math.sin, math.rad

local LEG = {}
for c, hex in pairs(K.LEG) do LEG[c] = hex end
LEG.L = '#B8901C'; LEG.r = '#FFEE9A'; LEG.a = '#FFD23A'; LEG.l = '#2B2836'
local LIT = {}
for c, e in pairs(K.LIT) do LIT[c] = e end
LIT.L = { 'l', 'w' }; LIT.r = { 'j', 'l' }; LIT.a = { 'j', 'l' }

local WING = 'EFGP'
-- Formas do raio; a ponta de baixo é fixa em (18,4; 20,4).
local TIP = { 18.4, 20.4 }
local BOLT = {
  [0] = { { 16.5, 13.8 }, { 19, 15.8 }, { 17, 17.4 } },
  { { 19.6, 13.8 }, { 17.2, 15.6 }, { 19.2, 17.6 } },
  { { 18, 13.4 }, { 19.4, 15.4 }, { 17, 17.6 } },
  { { 15.6, 14.6 }, { 18.6, 16 }, { 17.4, 18 } },
}
local HALO = { [0] = 3, 3.8, 4.4 }
local IDLE_HALO = { [0] = 3, 3.2, 3.4, 3.2 }
local ANT_OSC = { [0] = 0, 0.5, 0, -0.5 }

local function draw(g, sg, k, o)
  local P = R.pen(g, k)
  local cx = 18 * k - 0.5
  local ph = (o.ph or 0) % 4
  local crouch, alert = o.pose == 'crouch', o.pose == 'alert'
  local open = alert and 1.5 or (o.fly and 1.9 or 0)       -- ponta da asa para fora (o quadro de 36 tem 1 px de folga)
  local nar = crouch and 1 or 0                             -- delta mais estreito de cada lado
  local function yc(y) return crouch and (y - (y > 26 and math.min(1, (y - 26) / 8) or 0)) or y end
  local function mir(pts)
    local o2 = {}
    for i, p in ipairs(pts) do o2[i] = { 36 - p[1], p[2] } end
    return o2
  end
  local function u2p(x, y) return x * k - 0.5, y * k - 0.5 end

  -- asas de trás: armação em listras de 2 px
  local fan = o.fly and 2 or 0
  local back = { { 16, yc(25) }, { 9 - fan, yc(30) }, { 12.5 - fan * 0.6, yc(33.6) }, { 17, yc(29) } }
  for _, pts in ipairs({ back, mir(back) }) do
    P:fill(0, 0, 36, 36, 'Q', nil, function(u, v, x, y)
      if R.inpoly(u, v, pts) then return ((x + y) // 2) % 2 == 0 and 'Q' or 'P' end
    end)
  end
  -- abdômen
  local ay, ary = yc(28) - (crouch and 0.4 or 0), crouch and 5 or 5.6
  K.fur(g, cx, (ay - ary) * k, (ay + ary) * k - 1, function(y)
    local d = ((y + 0.5) / k - ay) / ary
    return math.abs(d) <= 1 and 2.6 * k * sqrt(1 - d * d) or -1
  end, k)
  -- asas da frente: delta com pó em faixas, no clip
  local fw = { { 17.4, 10 }, { 3.5 - open + nar, yc(26.5) }, { 8.5 - open * 0.6 + nar, yc(30.5) }, { 17.4, yc(24) } }
  local wings = { [-1] = fw, [1] = mir(fw) }
  for _, sd in ipairs({ -1, 1 }) do
    local pts = wings[sd]
    local rx, ry = pts[1][1], pts[1][2]
    local tx, ty = pts[2][1], pts[2][2]
    local dist = sqrt((tx - rx) ^ 2 + (ty - ry) ^ 2)
    local ox, oy = u2p(rx, ry)
    K.wing(g, { x = ox, y = oy, ang = math.deg(atan(ty - ry, tx - rx)), len = dist * 1.3 * k, wid = dist * 0.8 * k,
      side = sd, pal = { 'E', 'F', 'G', 'P' }, band = k > 1 and 3 or 2, rich = k > 1,
      clip = function(_, _, x, y) return R.inpoly((x + 0.5) / k, (y + 0.5) / k, pts) end })
  end
  -- antenas
  local lift = alert and 1 or 0
  local ao = (o.fly or crouch) and 0 or ANT_OSC[o.portrait and (ph - 1) % 4 or ph]
  for _, sd in ipairs({ -1, 1 }) do
    local pts
    if crouch then
      pts = { { 16.6, 6.6 }, { 14.2, 6.4 }, { 11.8, 7.8 } }
    else
      pts = { { 16.6, 6.6 }, { 13, 4.6 - lift }, { 9.5, 4.3 - lift + ao } }
    end
    local q = {}
    for i, p in ipairs(pts) do
      local x = sd < 0 and p[1] or 36 - p[1]
      local px, py = u2p(x, p[2])
      q[i] = { px, py }
    end
    K.feather(g, q, k)
  end
  -- cabeça
  K.fur(g, cx, (8.2 - 2.4) * k, (8.2 + 2.4) * k - 1, function(y)
    local d = ((y + 0.5) / k - 8.2) / 2.4
    return math.abs(d) <= 1 and 2.8 * k * sqrt(1 - d * d) or -1
  end, k)
  -- isoladores de porcelana
  for _, cy in ipairs({ 11.2, 22.8 }) do
    P:fill(18 - 1.7, cy - 1.2, 18 + 1.7, cy + 1.2, 'O', nil, function(u, v, x, y)
      if ((u - 18) / 1.7) ^ 2 + ((v - cy) / 1.2) ^ 2 <= 1 then
        if k > 1 then return y % 2 == 0 and 'O' or 'o' end
        return v < cy and 'O' or 'o'
      end
    end)
  end
  -- aro de cobre em três degraus, luz em cima à esquerda
  P:ring(18, 17, 4.4, 6, '&')
  local gx, gy = 18 * k - 0.5, 17 * k - 0.5
  local function lightAt(x, y)
    local dx, dy = x - gx, y - gy
    local r = sqrt(dx * dx + dy * dy)
    return -(dx + dy) * 0.7071 / math.max(r, 0.01)
  end
  for y = floor(gy - 6 * k) - 1, floor(gy + 6 * k) + 1 do
    for x = floor(gx - 6 * k) - 1, floor(gx + 6 * k) + 1 do
      if L.get(g, x, y) == '&' then
        local s = lightAt(x, y)
        g[y][x] = s > 0.4 and 'M' or (s > -0.3 and 'c' or 'K')
      end
    end
  end
  if k > 1 then
    for a = 0, 315, 45 do
      local x = floor(gx + 5.2 * k * cos(rad(a)) + 0.5)
      local y = floor(gy + 5.2 * k * sin(rad(a)) + 0.5)
      L.set(g, x, y, lightAt(x, y) > 0.1 and 'K' or 'M', 'McK')
      L.set(g, x + 1, y + 1, 'K', 'cM')
    end
  end
  -- o dentro do globo: vão, halo, raio, ponto ciano
  P:ell(18, 17, 4.4, 4.4, 'z')
  local rh
  if alert or o.portrait then rh = HALO[o.hot or 0] else rh = IDLE_HALO[ph] end
  P:ell(18, 17, rh, rh, 'L', 'z')
  local pts = {}
  for i, p in ipairs(BOLT[alert and 0 or ph]) do pts[i] = p end
  local shape = {}
  for _, p in ipairs(pts) do shape[#shape + 1] = p end
  shape[#shape + 1] = TIP
  P:limb(shape, 0.75, 0.75, 'a', 'zL')
  local branches = {}
  if ph == 2 and not alert then branches[1] = { { 17, 17.6 }, { 15.4, 18.8 } } end
  if alert then
    branches[1] = { { 17, 17.4 }, { 14.8, 17.6 }, { 13.9, 17.3 } }
    branches[2] = { { 19, 15.8 }, { 21, 15 }, { 22, 14.4 } }
  end
  for _, b in ipairs(branches) do P:limb(b, 0.75, 0.6, 'a', 'zL') end
  P:limb(shape, 0.4, 0.4, 'r', 'zLa')
  for _, b in ipairs(branches) do P:limb(b, 0.4, 0.3, 'r', 'zLa') end
  P:ell(18.2, 16.7, 0.6, 0.6, 'H', 'zLar')
  if k > 1 then  -- reflexo no vidro, em cima à esquerda
    for a = 205, 245, 3 do
      local x = floor(gx + 3.8 * k * cos(rad(a)) + 0.5)
      local y = floor(gy + 3.8 * k * sin(rad(a)) + 0.5)
      L.set(g, x, y, 'T', 'zL')
    end
  end
  -- ocelos fechados: pálpebra baixa
  for _, x in ipairs({ 10.5, 25.5 }) do
    P:ell(x, 24.5, 1.9, 1.6, 'h', WING)
    P:limb({ { x - 1.2, 24.9 }, { x + 1.2, 24.9 } }, 0.5, 0.5, 'i', WING .. 'h')
    if k > 1 then
      for _, d in ipairs({ -1.1, 0, 1.1 }) do
        local x0, y0 = u2p(x + d, 25.5)
        L.line(g, x0, y0, x0 + d * 0.8 * k, y0 + 1.6 * k, 'A', WING)
      end
    end
  end
  -- veios acesos, 1 px
  for _, v in ipairs({ { 15, 14, 6.2, 25.4 }, { 21, 14, 29.8, 25.4 } }) do
    local x0, y0 = u2p(v[1], v[2]); local x1, y1 = u2p(v[3], v[4])
    L.line(g, x0, y0, x1, y1, 'J', WING)
  end
  -- costuras do Véu, 2 px
  P:limb({ { 13.5, 22 }, { 14.5, 25 } }, 1 / k, 1 / k, 'X', WING)
  P:limb({ { 21.5, 20.5 }, { 23.2, 24.5 } }, 1 / k, 1 / k, 'X', WING)
end

local SPARKS = { { 4, 10, 'S' }, { 31, 12, 's' }, { 6, 33, 's' }, { 30, 32, 'S' }, { 18, 2.6, 's' }, { 2, 20, 'S' } }
local PICK = { [0] = { 1, 4 }, { 2, 5, 6 }, { 3, 1 }, { 4, 6, 5 } }
local function sparks(_, os)
  for i, f in ipairs(os) do
    f.sparks = {}
    for _, n in ipairs(PICK[(i - 1) % 4]) do f.sparks[#f.sparks + 1] = SPARKS[n] end
  end
  return os
end

K.run {
  name = 'stormlamp', stage = 'espirito', W = 36, PW = 96, LEG = LEG, LIT = LIT, draw = draw, DARK = 'C',
  BODY_KEYS = { 'G', 'F', 'E', 'P', 'Q', 'C', 'D', 'R', 'B', 'T', 'K', 'c', 'M', 'o', 'O' },
  fps = { idle = 6, drift = 6 },
  over = {
    idle = sparks, drift = sparks,
    flee = function(_, os) for i = 2, #os do os[i].fly = true end return os end,
  },
  portrait = function(o)
    local g, sg = L.grid(90, 90), L.grid(90, 90)
    draw(g, sg, 2.5, o)
    return g, sg, 3, 3
  end,
  acc = {
    sacred = { 14, 1 }, lit = { 14, 6 }, green = { 12, 9 }, water = { 14, 23 }, urban = { 15, 28 },
    residential = { 24, 27 }, crimson = { 11, 28 },
  },
}
