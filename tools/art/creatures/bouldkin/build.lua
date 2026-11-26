-- Bouldkin (clod.spirit), arte final: o Espírito da família Clod, a partir do conceito aprovado. O tatu tomado pelo
-- entulho: a metade da frente da carapaça virou um bloco de guia de concreto quebrada, com vergalhão à mostra e musgo
-- em cima; as cintas abriram e a luz vaza pelas juntas e pela trinca do bloco.
-- O errado: cinco patas, dois rabos e três olhos em fila numa cabeça pequena demais.
-- Costuras do Véu: duas, mais largas que as do Eco (no escudo de trás e na face do bloco), só no glow.
-- Camadas: corpo; leds = os três olhos (piscam); glow = as juntas, a trinca, as costuras e a poeira solta.
-- Animação: anda devagar. A luz corre pelas juntas, as cinco patas pisam fora de passo (na deriva), os dois rabos
-- balançam um contra o outro, a cabeça fareja. O tronco sobe e as garras ficam.
-- O vergalhão não tem contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/bouldkin/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_clod.lua')
local L = C.L
local floor, sqrt, abs, sin, cos, max, min, rad = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.min, math.rad
local stone, dseg, inpoly, hash, vn = C.stone, C.dseg, C.inpoly, C.hash, C.vn

local BL = { { 15.5, 8 }, { 27.5, 10.5 }, { 31, 18 }, { 29.2, 26.2 }, { 16.5, 26.2 }, { 14.5, 16.5 } }
local TOP = { { 15.5, 8 }, { 27.5, 10.5 }, { 25.6, 13.2 }, { 14.9, 11.2 } }
local BARS = {
  { 25, 11, 27.2, 6.2, 0.62, 0.62, 'e', 'E', 7 }, { 27.2, 6.2, 31, 4.6, 0.62, 0.62, 'e', 'E', 5 },
  { 19.6, 9.4, 20, 5.2, 0.62, 0.62, 'e', 'E', 6 }, { 20, 5.2, 17.6, 3.8, 0.62, 0.62, 'e', 'E', 4 },
}
local DUST = { { 31.8, 4 }, { 16.4, 3.4, 's' }, { 6.6, 33, 's' }, { 30.6, 33.4 }, { 11.4, 8.6, 's' }, { 33, 7.4 }, { 1.4, 30.6 }, { 16, 33.6 },
  { 20.8, 34, 's' }, { 9.6, 6.6 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k + (crouch and 1 or 0)
  oy = oy + all
  local glow = alert and 0.3 or ({ [0] = 0, 0.15, 0.3, 0.15 })[ph]
  local nod = alert and -8 or (still and 0 or ({ [0] = 0, 3, 5, 3 })[ph])
  local wag = still and 0 or ({ [0] = 0, 0.6, 0, -0.6 })[ph]
  local function st(n) return o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[(ph + n) % 4] or 0 end
  local cx, cy, rx, ry = 13.5, 20, 10, 10
  local ca, sa = cos(rad(30 - nod)), sin(rad(30 - nod))
  local limbs = {}
  for n, q in ipairs({ { 8.5, 9.2, 10.6, 28.6, 31, 'l', 'C' }, { 12.6, 13.2, 14.6, 30.4, 32.6, 'M', 'D' }, { 17.6, 18.2, 19.8, 29.4, 31.6, 'l', 'C' },
    { 22, 22.5, 24, 30.8, 33.2, 'M', 'D' }, { 26.4, 26.8, 28.4, 29.6, 32, 'l', 'C' } }) do
    local s = st(n)
    limbs[#limbs + 1] = { q[1], 25.8 + by, q[2] + s, q[4], q[6] == 'l' and 1.15 or 1.0, q[6] == 'l' and 0.9 or 0.8, q[6], 'M' }
    limbs[#limbs + 1] = { q[2] + s, q[4], q[3] + s, q[5], q[6] == 'l' and 0.7 or 0.6, 0.4, q[7], 'D' }
  end
  limbs[#limbs + 1] = { 4.6, 22.4 + by, 2.6 + wag, 27 + by, 1.2, 0.5, 'K', 'l', 6 }
  limbs[#limbs + 1] = { 5.6, 24.6 + by, 4.6 - wag, 30 + by, 1.0, 0.5, 'l', 'M', 6 }
  local sw, sp = k > 1 and 0.55 or 0.8, k > 1 and 1.6 or nil
  C.paint(g, k, ox, oy, function(u, v0, x, y)
    local v = v0 - by
    if inpoly(u, v, BL) then
      local top = 8 + (u - 15.5) * 0.208
      local md = 0.6 + 3.2 * vn(u * 0.8, 31)
      if v < top + md then
        local q = (v - top) / md
        return q < 0.35 and 'g' or ((q < 0.75 or hash(x, y, 2) % 3 == 0) and 'G' or 'm')
      end
      local cr = min(dseg(u, v, 22, 13, 20.5, 19), dseg(u, v, 20.5, 19, 23.5, 26), dseg(u, v, 20.5, 19, 16.5, 21.5))
      if cr < 0.45 then return cr < 0.2 and k > 1 and 'J' or (k > 1 and '5' or 'J') end
      if C.seam(u, v, { 25, 16.4 }, { 27.4, 20.6 }, sw, sp) then return 'Z' end
      if inpoly(u, v, TOP) then return stone(x, y, 1.8 * k, 5, { '112', '122', '1a2' }, nil, 0, k) end
      if u > 27.4 + (v - 10.5) * 0.25 then return stone(x, y, 1.8 * k, 5, { '455', '345', 'c45' }, nil, 0, k) end
      if v > 25.4 then return stone(x, y, 1.6 * k, 5, { '345', '455' }, nil, 0, k) end
      return stone(x, y, 2.6 * k, 5, { '233', '223', '233', '2b3' }, nil, 0, k)
    end
    local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
    if e <= 1 and v <= 25.8 then
      local hw = rx * sqrt(max(0.02, 1 - ((v - cy) / ry) ^ 2))
      local lon = (u - cx) / hw
      local sh = (u - cx) / rx * 0.45 + (v - cy) / ry * 0.9
      if v > 24.8 then return floor(u * (k > 1 and 0.6 or 1)) % 2 == 0 and 'l' or 'M' end
      for n, sx in ipairs({ -0.02, 0.22, -0.27 }) do
        local d = abs(lon - sx) * hw
        if d < (n == 3 and 0.5 or 0.85) * (k > 1 and 0.6 or 1) then
          if sh > 0.35 - glow then return 'H' end
          return (d < 0.25 and sh < glow) and 'Y' or 'J'
        end
      end
      if lon > -0.27 then
        local p = ((lon + 0.27) / 0.245) % 1
        if k > 1 and (v * 0.62) % 1 < 0.18 then return 'M' end
        local i = (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
        return ('KlM'):sub(i, i)
      end
      local top = cy - ry * sqrt(max(0, 1 - ((u - cx) / rx) ^ 2))
      local md = 0.4 + 3 * vn(u * 0.9, 77)
      if v < top + md and u > 5.5 then
        return (v - top) / md < 0.4 and 'g' or (hash(x, y, 2) % 3 == 0 and 'm' or 'G')
      end
      if C.seam(u, v, { 5.4, 18.6 }, { 7.6, 22.4 }, sw, sp) then return 'Z' end
      return stone(x, y, 2.4 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k)
    end
    local c = C.caps(u, v, BARS)
    if c then return c end
    local hu = (u - 29.6) * ca + (v - 26) * sa
    local hv = -(u - 29.6) * sa + (v - 26) * ca
    local hh = -1
    if hu < 0 then
      if hu > -3.4 then hh = 2.3 * sqrt(1 - (hu / 3.4) ^ 2) end
    elseif hu < 4.5 then hh = 1.9 * (1 - hu / 4.5) ^ 0.8 + 0.4 end
    if abs(hv) <= hh then
      if hu > 3.8 then return 'o' end
      for _, ex in ipairs({ -1.0, 0.6, 2.2 }) do
        local d = (hu - ex) ^ 2 + (hv - 0.35) ^ 2
        if d < 0.36 then return 'I' elseif d < 0.8 and k > 1 then return 'o' end
      end
      if hv < 0.1 and hu < 2.9 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M', '34M' }, 'M', 0.25 * k, k) end
      return hv > 1.0 and 'n' or 'N'
    end
    c = C.caps(u, v0, limbs)
    if c then return c end
    if v > 25.6 and v < 26.9 and u > 6 and u < 28.6 then return 'f' end
  end)
  C.prune(g)
  C.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[2], DUST[3], DUST[4], DUST[5] }, ph, 4)
end

C.run {
  name = 'bouldkin', stage = 'espirito', W = 36, PW = 96, draw = draw, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96 (escala 2,55)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.55, o, 2.1, 4.1)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 5, 18 }, green = { 2, 15 }, water = { 4, 17 }, residential = { 4, 19 }, lit = { 4, 20 },
    sacred = { 5, 6 }, crimson = { 6, 17 },
  },
}
