-- Prismkin (glare.spirit), arte final: o Espírito da família Glare, a partir do conceito aprovado. O tronco do
-- beija-flor virou um prisma de vidro: a luz entra branca pelo papo (uma lente de farol com aro cromado) e sai
-- separada em quatro penas de cauda, uma cor em cada (rosa, amarelo, verde, azul: o Glare multicolor).
-- O errado: três asas de vidraça trincada com caixilho (duas de um lado, uma do outro), dois bicos, três olhos em fila.
-- Costuras do Véu: duas, mais largas que as do Eco (na face de baixo do prisma e na asa de baixo), só no glow.
-- Camadas: corpo; leds = a estrela de quatro pontas na asa (pisca); glow = a lente, o raio dentro do prisma, as quatro
-- penas de luz, os reflexos, as costuras e o brilho solto (nas quatro cores).
-- Animação: as três asas batem cada uma no seu passo, o raio corre por dentro do prisma, as penas de luz abrem e
-- fecham em leque. No alerta as asas sobem e o leque abre; na antecipação fecham.
-- Os bicos e a luz da cauda não têm contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/prismkin/build.lua')
local G = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_glare.lua')
local L = G.L
local sqrt, abs, min, max, floor = math.sqrt, math.abs, math.min, math.max, math.floor
local glass, dseg = G.glass, G.dseg

local FR = { { 20.5, 13.5 }, { 23.5, 19.5 }, { 17.5, 20.5 } }
local TOPF = { { 20.5, 13.5 }, { 17.5, 20.5 }, { 8.5, 25.5 }, { 11.5, 18.5 } }
local BOT = { { 17.5, 20.5 }, { 23.5, 19.5 }, { 14.5, 24.5 }, { 8.5, 25.5 } }
local W1 = { { 19.6, 14.2 }, { 17, 15.8 }, { 5.4, 8.4 }, { 8.4, 4.6 }, { 12.4, 6.6 } }
local W2 = { { 20.8, 13 }, { 18.6, 14 }, { 13.4, 4.4 }, { 16.6, 3.2 }, { 19.4, 7.4 } }
local W3 = { { 20.6, 20.6 }, { 22.8, 19.9 }, { 29.8, 27.2 }, { 28, 30 }, { 24.8, 28 } }
local BILLS = { { 27, 10, 33.2, 7.8, 0.55, 0.45, 'z', 'Z' }, { 27, 11.2, 32.8, 13.4, 0.55, 0.45, 'z', 'Z' } }
local A1 = { [0] = 0, -12, -26, -10 }
local A2 = { [0] = -8, -22, -6, 4 }
local A3 = { [0] = 0, 10, 22, 8 }
local DUST = { { 3.4, 4.6, 'E' }, { 26.4, 4.4 }, { 31.4, 18.4, 'D' }, { 1.6, 21.4, 's' }, { 1.4, 27.4, 'E' }, { 3.2, 31.6 }, { 6.4, 33.6, 'F' },
  { 14, 31, 'D' }, { 32, 27.4, 's' } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local a1, a2, a3 = A1[ph], A2[ph], A3[ph]
  local fan = ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  if alert then a1, a2, a3, fan = 8, 6, -8, 1.6 elseif crouch then a1, a2, a3, fan = -34, -30, 26, -0.8 end
  if o.lean then a1, a2, a3 = a1 - 10, a2 - 10, a3 + 8 end       -- na deriva as asas ficam para trás
  local tail = {}
  for n, ch in ipairs({ 'R', 'J', 'L', 'B' }) do
    local q = ({ { 10.6, 22.6, 2.8, 23.4 }, { 10.4, 23.4, 3.4, 27.6 }, { 10.6, 24.2, 5.6, 31 }, { 11.2, 24.6, 9, 32.6 } })[n]
    local sp = (n - 2.5) * fan * 0.5                              -- o leque abre e fecha
    tail[n] = { q[1], q[2], q[3] + (n > 2 and sp * 0.6 or 0), q[4] + (n <= 2 and sp or 0), ch }
  end
  local function crack(u, v)
    local d = min(dseg(u, v, 12, 9.4, 9.6, 6.4), dseg(u, v, 12, 9.4, 8, 9.2), dseg(u, v, 12, 9.4, 14.4, 12.2))
    if d < 0.36 then return '5' end
    if abs((u - v) - 1.4) < 0.3 then return 'm' end              -- o caixilho da vidraça
  end
  local sw = k > 1 and 0.55 or 0.8                                -- a costura: 2 px no mapa
  G.paint(g, k, ox, oy, function(u, v, x, y)
    local d = sqrt((u - 24.6) ^ 2 + (v - 10.6) ^ 2)
    if d <= 2.8 then
      for n = 0, 2 do
        local ex, ey = 23.4 + n * 1.35, 9.6 + n * 0.5
        if k > 1 and (u - ex + 0.25) ^ 2 + (v - ey + 0.25) ^ 2 < 0.05 then return 'W' end
        if (u - ex) ^ 2 + (v - ey) ^ 2 < 0.3 then return 'o' end
      end
      local sh = (u - 24.6) * 0.5 + (v - 10.6)
      return sh < -1.2 and 'e' or (sh < 1 and 'f' or 'n')
    end
    local c = G.lens(u, v, 23, 13.9, 1.7, 0.6, k, ph * 0.5)
    if c then return c end
    local wu, wv = G.unrot(u, v, 19.6, 14.2, a1)
    c = glass(wu, wv, k, W1, { pal = '123', edge = 'G', c = 20 + ph * 0.8, m = 1.5, len = k > 1 and 2.4 or 2.2, fn = crack })
    if c then return G.star(wu, wv, 8.4, 7.4, 1.6) or c end
    c = glass(u, v, k, FR, { pal = '123', edge = 'g', ew = 0.5 })
    if c then return c end
    c = glass(u, v, k, TOPF, { pal = '234', edge = 'g', ew = 0.5, fn = function(uu, vv)
      -- o raio branco entra e sai em quatro cores; corre em traços
      if dseg(uu, vv, 19.2, 16.6, 15.6, 19.2) < 0.45 and (k == 1 or floor((uu + vv) * 1.6 - ph) % 3 ~= 0) then return 'Y' end
      for n, ch in ipairs({ 'R', 'J', 'L', 'B' }) do
        if dseg(uu, vv, 15.6, 19.2, 10.4, 19.6 + n * 1.15) < (k > 1 and 0.3 or 0.4) then return ch end
      end
    end })
    if c then return c end
    c = glass(u, v, k, BOT, { pal = '455', edge = 'G', ew = 0.5, fn = function(uu, vv)
      if G.seam(uu, vv, { { 19.6, 21.4 }, { 15.4, 23.4 } }, sw, k > 1 and 1.6 or nil) then return 'X' end
    end })
    if c then return c end
    if ((u - 22) / 2.7) ^ 2 + ((v - 13.2) / 2.3) ^ 2 <= 1 then return (u + v) % 2 < 1 and 'b' or 'c' end
    for _, s in ipairs(tail) do
      -- cada pena da cauda é escura na raiz e na borda, e acesa no miolo
      local dx, dy = s[3] - s[1], s[4] - s[2]
      local t = max(0, min(1, ((u - s[1]) * dx + (v - s[2]) * dy) / (dx * dx + dy * dy)))
      local dd = sqrt((u - s[1] - dx * t) ^ 2 + (v - s[2] - dy * t) ^ 2)
      local rr = 1.0 + (0.45 - 1.0) * t
      if dd <= rr then
        if t < (k > 1 and 0.24 or 0.5) then return 'n' end
        return (k > 1 and dd > rr * 0.5) and 'f' or s[5]
      end
    end
    wu, wv = G.unrot(u, v, 20.6, 20.6, a3)
    c = glass(wu, wv, k, W3, { pal = '234', edge = 'G', c = 49.4, m = -3, len = k > 1 and 2 or 1.6, fn = function(uu, vv)
      if G.seam(uu, vv, { { 23.6, 22.6 }, { 26.2, 25.8 } }, sw, k > 1 and 1.6 or nil) then return 'X' end
    end })
    if c then return c end
    wu, wv = G.unrot(u, v, 20.8, 13, a2)
    c = glass(wu, wv, k, W2, { pal = '345', edge = '5', c = k > 1 and 22 or nil, m = 7.4, len = 1.8 })
    if c then return c end
    return G.caps(u, v, BILLS)
  end)
  G.prune(g)
  G.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[3], DUST[7] }, ph, 4)
end

G.run {
  name = 'prismkin', stage = 'espirito', W = 36, PW = 96, draw = draw, NOPULL = G.NOPULL .. 'RJLB', ownLean = true,
  -- o retrato é o mesmo desenho feito em 96 (escala 2,55)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.55, o, 2.1, 3.6)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 15, 21 }, green = { 10, 19 }, water = { 14, 16 }, residential = { 13, 19 }, lit = { 12, 21 },
    sacred = { 20, 4 }, crimson = { 15, 17 },
  },
}
