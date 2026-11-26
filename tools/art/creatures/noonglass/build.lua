-- Noonglass (glare.ritual), arte final: o beija-flor-tesoura pousado num vergalhão, de perfil para a direita, bico
-- erguido e olho fechado em todo quadro. O peito é uma lente de farol com o sol do meio-dia dentro; o miolo do sol
-- cai sempre no mesmo pixel. O vergalhão faz parte do sprite e vai junto em toda animação, inclusive na fuga.
-- Mesma silhueta do conceito (conceitos/rituais/noonglass/build.lua), refeita na linguagem do kit Glare (_glare.lua).
-- Rodar: tools/art/rodar.sh tools/art/creatures/noonglass/build.lua
local G = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_glare.lua')
local R = dofile(KENOMA_ART .. 'creatures/conceitos/rituais/_ritual.lua')
local L = G.L
local sqrt, abs, floor, atan, deg = math.sqrt, math.abs, math.floor, math.atan, math.deg
local glass, dseg = G.glass, G.dseg

local LEG = {}
for c, hex in pairs(G.LEG) do LEG[c] = hex end
LEG.p = '#A2623C'                                              -- ferrugem do vergalhão
local BODY_KEYS = { 'p' }
for _, c in ipairs(G.BODY_KEYS) do BODY_KEYS[#BODY_KEYS + 1] = c end

local DISC = { [0] = 2.4, 2.6, 2.8, 2.6 }                      -- o disco J respira em volta do miolo fixo
local TX = { [0] = 0, 0.5, 0, -0.5 }                           -- a tesoura balança com o prisma
local DUST = { { 26, 15 }, { 28, 21, 's' }, { 7, 12, 's' }, { 30, 31 }, { 25, 3, 's' }, { 4, 22 }, { 6, 30, 'E' },
  { 12.5, 33, 'F' }, { 17.5, 33, 'D' } }
local LC, LR = { 20, 19 }, 3.3

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch, fly = o.pose == 'alert', o.pose == 'crouch', o.fly
  local tx = TX[ph]
  if o.lean then tx = -1.5 + tx end
  local tx1, tx2 = tx, 0.6 * tx
  local hy = crouch and 1 or 0                                  -- cabeça desce 1 px
  local b0, b1 = { 23.6, 9.8 + hy }, { 31.6, 7 }                -- bico
  if o.lean then b1 = { 31.6, 8 } end
  if alert then b1 = { 31, 5 } end
  if crouch then b0, b1 = { 23.6, 10.2 }, { 32, 9.5 }; tx1, tx2 = 1, 0 end
  local up = alert and (o.hot or 0) or 0                        -- o prisma sobe no alerta
  local disc = (o.portrait or alert) and DISC[o.portrait and (ph - 1) % 4 or ph] or DISC[ph]
  local open = alert and 3 or (fly and 6 or 0)                  -- a ponta de baixo da asa abre para a esquerda
  local e1x, e2x = 9.6 + tx1, 14.8 + tx2
  if crouch then e1x, e2x = 9.6 + 1, 11.6 end
  local WING = { { 12.6, 12.4 }, { 17.4, 14.6 }, { 15, 25.6 }, { 9.6 - open, 30.4 }, { 9.4 - open * 0.4, 20 } }
  local rc = ph * 0.8
  local BILL = { { b0[1], b0[2], b1[1], b1[2], 0.9, 0.5, 'z', 'Z' } }
  local SC = { { 15, 24, e1x, 33.5, 1.5, 0.6, 'f', 'n' }, { 17, 25, e2x, 33.5, 1.4, 0.6, 'e', 'n' } }
  local PRISM = { { 'R', e1x + 0.4, 32 - up }, { 'L', 11 + 0.6 * tx1, 29.8 - up }, { 'B', e2x + 0.1, 32 - up } }
  local sw = k > 1 and 0.55 or 0.8
  local step = k > 1 and 1.6 or nil
  local P = R.pen(g, k, ox, oy)

  -- atrás: a tesoura e o prisma da cauda
  G.paint(g, k, ox, oy, function(u, v)
    for _, p in ipairs(PRISM) do
      if ((u - p[2]) / 0.6) ^ 2 + ((v - p[3]) / 0.95) ^ 2 <= 1 then return p[1] end
    end
    return G.caps(u, v, SC)
  end)
  -- o vergalhão, atrás do corpo (provisório '^', ferrugem e sombra no fim)
  P:limb({ { 27.5, 27.8 }, { 9, 27.8 }, { 7.6, 32.6 } }, 1.2, 1.2, '^')

  G.paint(g, k, ox, oy, function(u, v, x, y)
    -- olho fechado
    local hw = 0.5 / math.max(1, k)
    if u >= 20.8 and u <= 22.8 and abs(v - (10.1 + hy)) < hw + (k > 1 and 0 or 0.0) then return 'o' end
    local c = G.caps(u, v, BILL)
    if c then return c end
    -- cabeça
    if ((u - 20.6) / 3.8) ^ 2 + ((v - (10.2 + hy)) / 3.5) ^ 2 <= 1 then
      local sh = (u - 20.6) * 0.5 + (v - 10.2 - hy)
      return sh < -1.2 and 'e' or (sh < 1 and 'f' or 'n')
    end
    -- lente de farol no peito
    local d = sqrt((u - LC[1]) ^ 2 + (v - LC[2]) ^ 2)
    if d <= 4.5 then
      if d > LR then return '=' end
      if (u - 19.5) ^ 2 + (v - 18.5) ^ 2 <= 1.21 then return 'Y' end
      if k > 1 and d > 2.7 and d < 3.1 then
        local a = deg(atan(v - LC[2], u - LC[1])) % 360
        if a > 200 and a < 250 then return '1' end
      end
      if k > 1 and abs((u - LC[1]) % 1.5 - 0.75) < 0.2 then return 'H' end
      return d <= disc and 'J' or 'H'
    end
    -- asa de vidro fechada, com a estrela e a costura do Véu
    c = glass(u, v, k, WING, { pal = '123', edge = '4', c = 31 + rc, m = -7, len = k > 1 and 5 or 6, fn = function(uu, vv)
      if G.seam(uu, vv, { { 12.4, 20 }, { 12, 23.6 } }, sw, step) then return 'X' end
      if dseg(uu, vv, 17.4, 14.6, 15, 25.6) < 1.6 then return '5' end
    end })
    if c then return G.star(u, v, 11.6, 17.4, 1.4) or c end
    -- corpo: pena em fileiras, costura do Véu só sobre a pena
    if ((u - 18.4) / 6.6) ^ 2 + ((v - 19.2) / 8.4) ^ 2 <= 1 then
      if G.seam(u, v, { { 15.4, 20.5 }, { 16.2, 24 } }, sw, step) then return 'V' end
      local lb = u - 18.4
      local i = lb < -2.4 and 1 or (lb < 2 and 2 or 3)
      if ((v - 19.2) * 1.1 + (floor(lb * 1.3) % 2) * 0.5) % 1 < 0.34 then i = i + 1 end
      return ('abcd'):sub(i, i)
    end
  end)
  -- pés
  P:limb({ { 17.4, 26.4 }, { 17.4, 27 } }, 0.7, 0.7, '9')
  P:limb({ { 20.6, 26.4 }, { 20.6, 27 } }, 0.7, 0.7, '9')
  -- vergalhão: ferrugem em 1 de cada 7 px, depois o metal
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == '^' and R.hash(x, y, 6) % 7 == 0 then g[y][x] = 'p' end
  end end
  R.shade(g, '^', 'm89', { tex = 'metal' })
  R.shade(g, '=', 'Mm8', { amp = 0.5 })
  G.prune(g)
  G.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[3], DUST[7] }, ph, 4)
end

G.run {
  name = 'noonglass', stage = 'espirito', W = 36, PW = 96, draw = draw, LEG = LEG, BODY_KEYS = BODY_KEYS,
  NOPULL = G.NOPULL, ownLean = true, fps = { idle = 6, drift = 6 },
  over = {
    flee = function(_, os)
      for i = 2, #os do
        os[i].fly = true
        if i == 2 then os[1].dy = 0 end
        local sp = {}
        for n, s in ipairs(os[i].sparks or {}) do sp[n] = { s[1], s[2], ({ 'E', 'F', 'D' })[n % 3 + 1] } end
        os[i].sparks = sp
      end
      return os
    end,
  },
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.7, o, -4.6, -6.9)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 17, 3 }, green = { 15, 7 }, lit = { 17, 13 }, urban = { 18, 24 }, water = { 19, 29 },
    residential = { 23, 29 }, crimson = { 24, 20 },
  },
}
