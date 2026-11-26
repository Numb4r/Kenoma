-- Entidade Maior da família Glare (nome e pasta provisórios: glare_entidade), arte final a partir do conceito aprovado
-- (rodada 2). Um farol de lente no centro, com aro cromado; dele saem três bicos de agulha e três vidraças em
-- cata-vento, com penas atrás de cada uma. Não tem cabeça: os três olhos só existem refletidos nas vidraças.
-- REGRA QUEBRADA (tempo): cada vidraça reflete uma hora diferente do mesmo céu: o sol numa (a estrela de quatro
-- pontas), o fim de tarde noutra, a lua na terceira. O sol e a lua andam cada um no seu vidro, em passos diferentes.
-- Costura do Véu: uma, larga, na vidraça do fim de tarde, só no glow.
-- Camadas: corpo; leds = o sol (a estrela, pisca); glow = a lente, os reflexos, a lua, a costura e o brilho solto.
-- Animação (6 quadros, lenta): o cata-vento balança em volta do farol sem dar a volta, os anéis da lente correm para
-- fora, as penas abrem e fecham. No alerta ele abre; na antecipação encolhe para o farol.
-- Os bicos não têm contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/glare_entidade/build.lua')
local G = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_glare.lua')
local L = G.L
local sqrt, sin, cos, pi = math.sqrt, math.sin, math.cos, math.pi
local CX, CY = 23.5, 24.5
local function pol(r, a) return CX + cos(a) * r, CY + sin(a) * r end
local function lerp(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t } end

local SKY = { [0] = { pal = 't12', ph = 0 }, { pal = 'uf4', ph = 1 }, { pal = 'vn5', ph = 2 } }
local DUST = { { 4, 7, 's' }, { 41, 8 }, { 44, 31, 'E' }, { 3.4, 37, 'D' }, { 12, 45 }, { 36.6, 45, 'F' }, { 30, 4.6 }, { 7.6, 19, 's' } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local rot = still and 0 or 6 * sin(t)
  if o.lean then rot = -9 + 3 * sin(t) end
  local sc = alert and 1.04 or (crouch and 0.84 or 1)
  local open = alert and 0.1 or (crouch and -0.16 or (still and 0 or 0.05 * sin(t + 1)))
  local panes, thick, feathers = {}, {}, {}
  for i = 0, 2 do
    local a = -pi / 2 + 0.12 + i * 2 * pi / 3
    local b = a + pi / 3
    local p = {}
    for _, q in ipairs({ { 5.6, -0.1 }, { 13, -0.66 }, { 20.6, 0.06 }, { 15.6, 0.6 } }) do
      local px, py = pol(q[1], b + q[2]); p[#p + 1] = { px, py }
    end
    local ex, ey = pol(12.4, b - 0.04)
    -- o astro de cada vidro anda no seu passo (o sol devagar, a lua mais depressa)
    local sa = 0.55 + (still and 0 or (i == 0 and 0.06 * sin(t) or 0.1 * sin(2 * t)))
    panes[i] = { pts = p, ex = ex, ey = ey, sx = ex + (p[3][1] - ex) * sa, sy = ey + (p[3][2] - ey) * sa,
      seam = { lerp(p[1], p[4], 0.55), lerp(p[3], p[4], 0.45) } }
    local x0, y0 = pol(6.4, a); local x1, y1 = pol(13.6, a + 0.05); local x2, y2 = pol(20.4, a + 0.17)
    thick[#thick + 1] = { x0, y0, x1, y1, 1.35, 0.85, 'M', 'm' }
    thick[#thick + 1] = { x1, y1, x2, y2, 0.85, 0.35, 'z', 'Z' }
    for n = 0, 3 do
      local fx0, fy0 = pol(8.4 + n * 1.6, b + 0.5)
      local fx1, fy1 = pol(14.4 + n * 2, b + 0.86 - n * 0.05 + open * (n + 1) * 0.5)
      feathers[#feathers + 1] = { fx0, fy0, fx1, fy1, 1.25, 0.4, n % 2 == 0 and 'b' or 'e', n % 2 == 0 and 'c' or 'f', k > 1 and 7 or nil }
    end
  end
  G.paint(g, k, ox, oy, function(u0, v0)
    local c = G.lens(u0, v0, CX, CY, 5.6, 1.4, k, still and 0 or ph * 2 / NL)
    if c then return c end
    local u, v = G.unrot(u0, v0, CX, CY, rot)
    u, v = CX + (u - CX) / sc, CY + (v - CY) / sc
    for i = 0, 2 do
      local P = panes[i]
      c = G.glass(u, v, k, P.pts, { pal = SKY[i].pal, ph = SKY[i].ph, edge = 'G', ew = 0.6, c = P.ex + P.ey + 2.6, m = P.ex - P.ey,
        len = k > 1 and 2.2 or 3.4,
        fn = function(uu, vv)
          local d = sqrt((uu - P.ex) ^ 2 + (vv - P.ey) ^ 2)
          if k > 1 and (uu - P.ex + 0.5) ^ 2 + (vv - P.ey + 0.5) ^ 2 < 0.12 then return 'W' end
          if d < 1.25 then return 'o' elseif d < 1.9 then return i == 2 and '4' or '5' end
          if i == 0 then return G.star(uu, vv, P.sx, P.sy, 1.8) end
          if i == 1 and G.seam(uu, vv, P.seam, k > 1 and 0.7 or 0.95, k > 1 and 2 or nil) then return 'X' end
          if i == 2 then
            local dm = sqrt((uu - P.sx) ^ 2 + (vv - P.sy) ^ 2)
            if dm < 1.5 and sqrt((uu - P.sx - 0.8) ^ 2 + (vv - P.sy + 0.4) ^ 2) > 1.2 then return 'J' end
          end
        end })
      if c then return c end
    end
    return G.caps(u, v, thick) or G.caps(u, v, feathers)
  end)
  G.prune(g)
  G.dust(g, sg, k, ox, oy, DUST, ph, NL)
end

G.run {
  name = 'glare_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, ownLean = true, DARK = 'd',
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96 (cada função do ponto é avaliada no pixel do retrato)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o, 0, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 31 }, green = { 18, 32 }, water = { 20, 14 }, residential = { 20, 15 }, lit = { 20, 32 },
    sacred = { 20, 15 }, crimson = { 30, 22 },
  },
}
