-- Pebblet (clod.eco), arte final: o Eco da família Clod, a partir do conceito aprovado. O tatu-bola de perfil, em
-- proporção natural, andando na ponta das garras. Os dois escudos são placas de cascalho (seixos com rejunte), as
-- três cintas são de queratina e as juntas entre elas acendem. O errado é pouco: falta uma placa no escudo de trás,
-- e o buraco é luz.
-- Costuras do Véu: três, curtas e de 1 px (escudo de trás, escudo da frente, escudo da cabeça), só no glow, longe das
-- juntas acesas.
-- Camadas: corpo; leds = o buraco de luz (pisca); glow = as juntas das cintas, as costuras e a poeira solta.
-- Animação: a luz corre pelas juntas, a cabeça fareja (sobe e desce), o rabo balança; o tronco sobe e as garras
-- ficam. Na deriva ele anda. Com medo fecha em bola (a antecipação) e foge rolando, como diz o Bestiário.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/pebblet/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_clod.lua')
local L = C.L
local floor, sqrt, abs, sin, cos, max, rad = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.rad
local stone = C.stone

local DUST = { { 1.2, 24.4 }, { 14.5, 24.6, 's' }, { 23.6, 24.6 }, { 5.2, 8.4, 's' }, { 3.4, 25, 's' }, { 12.6, 25 }, { 4.2, 6.6 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local ball = crouch or o.ball
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k
  oy = oy + all
  local glow = alert and 0.3 or ({ [0] = 0, 0.15, 0.3, 0.15 })[ph]   -- a luz corre pelas juntas
  local nod = alert and -8 or ({ [0] = 0, 3, 6, 3 })[ph]
  local wag = ({ [0] = 0, 0.5, 0, -0.5 })[ph]
  local st = o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[ph] or 0
  if ball then
    -- fechado em bola: os dois escudos se encontram, as cintas dão a volta, e ela rola
    local cx, cy, r = 13, 15, 8.8
    local a0 = rad(o.roll or 0)
    C.paint(g, k, ox, oy, function(u, v, x, y)
      local du, dv = u - cx, v - cy
      if du * du + dv * dv > r * r then return end
      local a, b = du * cos(a0) + dv * sin(a0), -du * sin(a0) + dv * cos(a0)
      local hw = r * sqrt(max(0.02, 1 - (b / r) ^ 2))
      local lon = a / hw
      local sh = du / r * 0.45 + dv / r * 0.9
      for n, sx in ipairs({ -0.17, 0.17, -0.5, 0.5 }) do
        local d = abs(lon - sx) * hw
        if d < (k > 1 and 0.32 or 0.5) then
          if n > 2 then return 'M' end
          return sh > 0.3 and 'H' or 'J'
        end
      end
      if abs(lon) < 0.5 then
        local p = ((lon + 0.5) / 0.333) % 1
        return ('KlM'):sub((p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0), (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0))
      end
      if lon > 0.5 and abs(b) < 2.2 and lon < 0.86 then return stone(x, y, 1.5 * k, 11, { 'KlM', '23M', 'KlM' }, 'M', 0.25 * k, k) end
      return stone(x, y, 2.3 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k)
    end)
  else
    local cx, cy, rx, ry = 11.8, 14.5, 8.8, 9.5
    local ca, sa = cos(rad(26 - nod)), sin(rad(26 - nod))
    local limbs = {
      { 17.4, 19.2 + by, 18.4 + st, 22.2, 1.05, 0.8, 'l', 'M' }, { 18.4 + st, 22.2, 19.2 + st, 23.9, 0.65, 0.4, 'C', 'D' },
      { 6.9, 19.2 + by, 6.4 - st, 22.4, 1.15, 0.85, 'l', 'M' }, { 6.4 - st, 22.4, 7.7 - st, 23.8, 0.65, 0.4, 'C', 'D' },
      { 19.9, 19.2 + by, 20.9 - st, 22.3, 0.8, 0.6, 'M', 'M' }, { 20.9 - st, 22.3, 21.5 - st, 23.5, 0.55, 0.4, 'D', 'D' },
      { 9.7, 19.2 + by, 9.4 + st, 22.5, 0.8, 0.6, 'M', 'M' }, { 9.4 + st, 22.5, 10.4 + st, 23.5, 0.55, 0.4, 'D', 'D' },
      { 3.9, 17.2 + by, 2.9 + wag, 20.8 + by, 1.1, 0.5, 'K', 'l', 5 },
    }
    local sw, st2 = k > 1 and 0.3 or 0.38, k > 1 and 1.1 or nil
    C.paint(g, k, ox, oy, function(u, v0, x, y)
      local v = v0 - by
      local e = ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2
      if e <= 1 and v <= 19.6 then
        local hw = rx * sqrt(max(0.02, 1 - ((v - cy) / ry) ^ 2))
        local lon = (u - cx) / hw
        local sh = (u - cx) / rx * 0.45 + (v - cy) / ry * 0.9
        if v > 18.6 then return floor(u * (k > 1 and 0.6 or 1)) % 2 == 0 and 'l' or 'M' end
        for n, sx in ipairs({ -0.17, 0.17, -0.5, 0.5 }) do
          local d = abs(lon - sx) * hw
          if d < (k > 1 and 0.32 or 0.5) then
            if n > 2 then return 'M' end
            if sh > 0.3 - glow then return 'H' end
            return (sh < -0.45 + glow and (k == 1 or d < 0.16)) and 'Y' or 'J'
          end
        end
        if (u - 5.6) ^ 2 + (v - 10.8) ^ 2 < 1.25 then return ((u - 5.6) ^ 2 + (v - 10.8) ^ 2 < 0.4) and 'I' or 'T' end
        if abs(lon) < 0.5 then
          local p = ((lon + 0.5) / 0.333) % 1
          if k > 1 and (v * 0.62) % 1 < 0.18 then return 'M' end
          local i = (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
          return ('KlM'):sub(i, i)
        end
        if C.seam(u, v, { 3.6, 14.6 }, { 5, 16.4 }, sw, st2) or C.seam(u, v, { 17.6, 9.6 }, { 19, 11.4 }, sw, st2) then return 'Z' end
        return stone(x, y, 2.3 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k)
      end
      local hu = (u - 21.6) * ca + (v - 17.2) * sa
      local hv = -(u - 21.6) * sa + (v - 17.2) * ca
      local hh = -1
      if hu < 0 then
        if hu > -3.4 then hh = 2.2 * sqrt(1 - (hu / 3.4) ^ 2) end
      elseif hu < 4.4 then hh = 1.85 * (1 - hu / 4.4) ^ 0.8 + 0.35 end
      if abs(hv) <= hh then
        if hu > 3.7 then return 'o' end
        if k > 1 and (hu - 1.1) ^ 2 + (hv - 0.3) ^ 2 < 0.07 then return 'W' end
        if (hu - 1.3) ^ 2 + (hv - 0.5) ^ 2 < 0.42 then return 'o' end
        if hv < 0.1 and hu < 2.8 then
          if C.seam(hu, hv, { -1.6, -1 }, { -0.2, -0.6 }, sw, st2) then return 'Z' end
          return stone(x, y, 1.5 * k, 11, { 'KlM', '23M', 'KlM' }, 'M', 0.25 * k, k)
        end
        return hv > 1.0 and 'n' or 'N'
      end
      if ((u - 21.6) / 1.0) ^ 2 + ((v - 14.5) / 1.4) ^ 2 <= 1 then return (u > 21.5 and v > 13.6) and 'n' or 'N' end
      local c = C.caps(u, v0, limbs)
      if c then return c end
      if v > 19.2 and v < 20.4 and u > 5.2 and u < 19.6 then return 'f' end
    end)
  end
  C.prune(g)
  C.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[2], DUST[4] }, ph, 4)
end

C.run {
  name = 'pebblet', stage = 'eco', W = 28, PW = 96, draw = draw,
  -- foge rolando: depois de fechar em bola, ela gira um pouco a cada quadro
  over = { flee = function(_, os)
    for i = 2, #os do os[i].jump, os[i].ball, os[i].roll = true, true, (i - 1) * 50 end
    return os
  end },
  -- o retrato é o mesmo desenho feito em 96 (escala 3,3): seixo, rejunte e trinca no pixel do retrato
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o, 5, 5)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 9, 13 }, green = { 6, 10 }, water = { 8, 12 }, residential = { 8, 14 }, lit = { 8, 15 },
    sacred = { 8, 2 }, crimson = { 10, 12 },
  },
}
