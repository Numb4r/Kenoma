-- Rustling (rust.eco), arte final: o Eco da família Rust, a partir do conceito aprovado. O besouro-rinoceronte de
-- perfil, em proporção natural. Os élitros são uma grade de ferro enferrujado com resto de tinta verde e luz dentro,
-- como uma lanterna; o chifre é uma ponta de lança de portão. O errado é pouco: uma barra do casco está arrombada
-- para fora.
-- Costuras do Véu: três, curtas e de 1 px (duas no pronoto, uma na cabeça), só no glow, longe da luz da grade.
-- Camadas: corpo; leds = o miolo da luz atrás da grade (pisca); glow = o resto da luz dos vãos, as costuras e a
-- limalha solta.
-- Animação: a luz de dentro cresce e encolhe (a lanterna respira), a barra arrombada treme, o chifre acena; o tronco
-- sobe e as patas ficam. Na deriva ele anda; na fuga, salta. No alerta a luz enche a grade; na antecipação apaga.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rustling/build.lua')
local Ru = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rust.lua')
local L = Ru.L

local DUST = { { 6.2, 6 }, { 8.6, 5.2, 's' }, { 4.6, 7.6 }, { 9.6, 7.4 }, { 1.4, 25.4 }, { 14, 26, 's' }, { 25.4, 25 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k + (crouch and 0.8 or 0)
  oy = oy + all
  local glow = alert and 1.3 or (crouch and 0.6 or ({ [0] = 1, 1.12, 1.2, 1.08 })[ph])
  local wob = still and 0 or ({ [0] = 0, 0.4, 0, -0.4 })[ph]
  local st = o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[ph] or 0
  local cx, cy, rx, ry = 10.6, 15.4, 8.6, 6.6
  local parts = {
    { 22.4, 14.6 + by, 23.1 + wob * 0.5, 10.4 + by, 0.66, 0.6, '4', '2' },
    { 23.1, 17.6 + by, 24.7, 18.9 + by, 0.42, 0.4, '3', '2' }, { 24.7, 18.9 + by, 25.0, 19.2 + by, 0.7, 0.7, 'q', 'R' },
    { 7.8, 10.6 + by, 6.6 + wob, 8.3 + by, 0.56, 0.56, 'q', 'R' }, { 6.6 + wob, 8.3 + by, 7.5 + wob * 1.5, 6.9 + by, 0.56, 0.5, 'Q', 'q' },
  }
  Ru.leg(parts, { { 18.4, 19.4 + by }, { 20.4 + st, 21.6 }, { 21 + st, 24 } }, 0.62, '4', '2')
  Ru.leg(parts, { { 12.4, 20.8 + by }, { 11.4 - st, 22.8 }, { 12.3 - st, 24.4 } }, 0.62, '4', '2')
  Ru.leg(parts, { { 6.2, 19.8 + by }, { 4.3 + st, 22 }, { 4.7 + st, 24.2 } }, 0.62, '4', '2')
  local sw, sp = k > 1 and 0.3 or 0.38, k > 1 and 1.1 or nil
  Ru.paint(g, k, ox, oy, function(u, v0, x, y)
    local v = v0 - by
    local pe = ((u - 19) / 3.6) ^ 2 + ((v - 15.2) / 5.1) ^ 2
    if pe <= 1 then
      local sh = (v - 15.2) / 5.1 * 0.85 + (u - 19) / 3.6 * 0.3
      if Ru.seam(u, v, { 17.8, 12.4 }, { 19.2, 13.8 }, sw, sp) or Ru.seam(u, v, { 19.4, 16.8 }, { 20.8, 18.2 }, sw, sp) then return 'Z' end
      if k > 1 and pe > 0.52 and pe < 0.8 and (math.atan(v - 15.2, u - 19) * 2.2) % 1 < 0.22 then return sh < 0 and '5' or '3' end
      return Ru.plate(x, y, sh, k)
    end
    local c = Ru.elytra(u, v, x, y, k, cx, cy, rx, ry, glow)
    if c then return c end
    local he = ((u - 22.4) / 1.9) ^ 2 + ((v - 16.2) / 2.3) ^ 2
    if he <= 1 then
      if k > 1 and (u - 22.8) ^ 2 + (v - 15.3) ^ 2 < 0.07 then return 'W' end
      if (u - 23.0) ^ 2 + (v - 15.6) ^ 2 < 0.42 then return 'o' end
      if Ru.seam(u, v, { 21.4, 17 }, { 22.6, 17.8 }, sw, sp) then return 'Z' end
      if u > 23.6 and v > 17 then return 'r' end
      return v < 15.4 and '3' or (v < 17 and '2' or '1')
    end
    c = Ru.spear(u, v, 23.1 + wob * 0.5, 10.4, 0.16, -0.987, 0.9, 0.62, '5', '3', 'q')
    if c then return c end
    return Ru.caps(u, v0, parts)
  end)
  Ru.prune(g)
  Ru.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[3], DUST[6] }, ph, 4)
end

Ru.run {
  name = 'rustling', stage = 'eco', W = 28, PW = 96, draw = draw,
  -- o retrato é o mesmo desenho feito em 96 (escala 3,3): a barra tem aresta, miolo e ferrugem no pixel do retrato
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 3.3, o, 3, 6)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 16, 14 }, green = { 13, 13 }, water = { 15, 12 }, residential = { 15, 14 }, lit = { 15, 15 },
    sacred = { 15, 6 }, crimson = { 17, 13 },
  },
}
