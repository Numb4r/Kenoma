-- Gratekin (rust.spirit), arte final: o Espírito da família Rust, a partir do conceito aprovado. O besouro tomado
-- pelo portão: um élitro se ergueu como folha de portão de barras torcidas, com três lanças em cima, e a luz vaza
-- pela dobradiça. O errado: sete patas (três finas, de ferrugem, sem contorno), dois chifres, cinco olhos de parafuso
-- no pronoto e um cadeado fechado pendurado atrás.
-- Costuras do Véu: duas, mais largas que as do Eco (no pronoto, em cima e embaixo dos parafusos), só no glow.
-- Camadas: corpo; leds = o miolo da luz atrás da grade (pisca); glow = o resto da luz dos vãos, a que vaza pela
-- dobradiça, o buraco do cadeado, as costuras e a limalha solta.
-- Animação: a folha erguida range (abre e fecha um pouco na dobradiça), a luz de dentro cresce e encolhe, o cadeado
-- balança; o tronco sobe e as patas ficam. No alerta a folha abre e a luz enche; na antecipação ela fecha.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/gratekin/build.lua')
local Ru = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rust.lua')
local L = Ru.L
local sqrt, abs, sin, cos, min = math.sqrt, math.abs, math.sin, math.cos, math.min
local iron = Ru.iron

local DUST = { { 24.6, 7 }, { 26.4, 9.4, 's' }, { 5.6, 10 }, { 4, 13, 's' }, { 6.4, 15.4 }, { 31.4, 13 }, { 1.6, 33.6 }, { 30.6, 33 }, { 20, 34.2, 's' } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k + (crouch and 0.8 or 0)
  oy = oy + all
  local glow = alert and 1.5 or (crouch and 0.8 or ({ [0] = 1.25, 1.35, 1.45, 1.32 })[ph])
  local swing = alert and 1.6 or (crouch and -1.5 or ({ [0] = 0, 0.6, 1, 0.5 })[ph])   -- a folha range
  local sway = still and 0 or ({ [0] = 0, 0.4, 0, -0.4 })[ph]
  local st = o.lean and ({ [0] = 0.7, 0, -0.7, 0 })[ph] or 0
  local cx, cy, rx, ry = 13.5, 22, 10, 6.2
  local OX, OY, AX, AY, BX, BY = 8.5, 18, 12, -1, 1.5 - swing, -10
  local det = AX * BY - AY * BX
  local parts = {
    { 27, 20.6 + by, 28.4, 17 + by, 0.66, 0.6, '3', '2' },
    { 26.2, 20.4 + by, 26, 17.4 + by, 0.6, 0.56, 'q', 'R' }, { 26, 17.4 + by, 24.5, 16 + by, 0.56, 0.5, 'q', 'R' },
    { 28.4, 24 + by, 30.2, 25.6 + by, 0.45, 0.42, '3', '2' }, { 30.2, 25.6 + by, 30.6, 26 + by, 0.75, 0.75, 'q', 'R' },
    { 5, 23.4 + by, 4.2 + sway, 26.4 + by, 0.56, 0.56, '4', '2', 5 },
  }
  Ru.leg(parts, { { 22.6, 26 + by }, { 24.8 + st, 28.4 }, { 25.6 + st, 32.4 } }, 0.64, '3', '2')
  Ru.leg(parts, { { 17.4, 27.6 + by }, { 16.6 - st, 30.2 }, { 18 - st, 33.6 } }, 0.64, '3', '2')
  Ru.leg(parts, { { 12.4, 28 + by }, { 10.6 + st, 30.6 }, { 11.4 + st, 33 } }, 0.64, '3', '2')
  Ru.leg(parts, { { 8, 26.6 + by }, { 6.4 - st, 29.4 }, { 7.4 - st, 31.6 }, { 6.6 - st, 33.8 } }, 0.64, 'q', 'R')
  local thin = {}
  Ru.leg(thin, { { 24.6, 25.6 + by }, { 27.6 - st, 27.6 }, { 28.4 - st, 31.4 } }, 0.58, 'e', 'E', 3)
  Ru.leg(thin, { { 20, 27.6 + by }, { 20.8 + st, 30.6 }, { 22 + st, 32.6 } }, 0.58, 'e', 'E', 3)
  Ru.leg(thin, { { 14.6, 28.2 + by }, { 14.4 - st, 31 }, { 15.4 - st, 32.2 } }, 0.58, 'e', 'E', 3)
  local bw = 0.5
  local sw, sp = k > 1 and 0.5 or 0.75, k > 1 and 1.5 or nil
  local px0 = 4.1 + sway                                           -- o cadeado balança
  Ru.paint(g, k, ox, oy, function(u, v0, x, y)
    local v = v0 - by
    -- a folha de portão
    local s = ((u - OX) * BY - (v - OY) * BX) / det
    local t = (AX * (v - OY) - AY * (u - OX)) / det
    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
      local sh = (s - 0.5) * 0.8 - (t - 0.5) * 0.8
      local ds, dt = min(s, 1 - s) * 12, min(t, 1 - t) * 10.1
      if ds < 2 * bw or dt < 2 * bw then return iron(min(ds, dt) - bw, bw, x, y, sh, k) end
      for n = 1, 4 do
        local d = (s - n / 5 - 0.03 * sin(t * 8 + n * 2.1)) * 12
        if abs(d) < bw and not (n == 3 and t > 0.62 and t < 0.8) then return iron(d, bw, x, y, sh, k) end
      end
      local d = (t - 0.52 - 0.04 * sin(s * 7)) * 10.1
      if abs(d) < bw then return iron(d, bw, x, y, sh, k) end
      return
    end
    for n = 0, 2 do
      local px, py = OX + AX * (0.17 + n * 0.33) + BX, OY + AY * (0.17 + n * 0.33) + BY
      local c = Ru.spear(u, v, px, py, 0.148, -0.989, 1.5, 0.5, '4', '2', 'q')
      if c then return c end
    end
    local pe = ((u - 23.2) / 3.8) ^ 2 + ((v - 21.4) / 5) ^ 2
    if pe <= 1 then
      for n = -2, 2 do
        local a = n * 0.5
        local c = Ru.screw(u, v, 23.2 + 2.7 * cos(a), 21.4 + 3.9 * sin(a), k > 1 and 0.85 or 0.75, k, n * 0.9 + ph * 0.4)
        if c then return c end
      end
      if Ru.seam(u, v, { 21, 18.2 }, { 22.8, 17.4 }, sw, sp) or Ru.seam(u, v, { 21, 24.6 }, { 22.8, 25.4 }, sw, sp) then return 'Z' end
      return Ru.plate(x, y, (v - 21.4) / 5 * 0.85 + (u - 23.2) / 3.8 * 0.3, k)
    end
    -- a luz que vaza por baixo da folha erguida
    if t < 0 and t > -0.16 and s > 0.04 and s < 0.96 and ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2 < 0.9 then
      return t > -0.07 and 'L' or 'M'
    end
    local c = Ru.elytra(u, v, x, y, k, cx, cy, rx, ry, glow)
    if c then return c end
    local he = ((u - 27.4) / 2.1) ^ 2 + ((v - 22.6) / 2.5) ^ 2
    if he <= 1 then
      if u > 28.6 and v > 23.6 then return 'r' end
      return v < 21.6 and '3' or (v < 23.6 and '2' or '1')
    end
    c = Ru.spear(u, v, 28.4, 17, 0.3, -0.954, 1.8, 0.55, '4', '2', 'q')
    if c then return c end
    -- cadeado
    if u > px0 - 1.7 and u < px0 + 1.7 and v > 27.4 and v < 31 then
      if (u - px0) ^ 2 + (v - 28.8) ^ 2 < 0.36 or (abs(u - px0) < 0.3 and v > 28.8 and v < 30) then return 'L' end
      return (u > px0 + 0.9 or v > 30.2) and 'b' or 'B'
    end
    local dd = sqrt((u - px0) ^ 2 + (v - 27.4) ^ 2)
    if v <= 27.4 and dd < 1.7 and dd > 0.8 then return u < px0 and '5' or '3' end
    return Ru.caps(u, v0, parts)
  end)
  Ru.prune(g)
  if not o.dark then L.outline(g, 'A', Ru.SOLID) end               -- as patas finas entram depois do contorno
  Ru.behind(g, k, ox, oy, thin)
  Ru.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[3], DUST[5], DUST[6] }, ph, 4)
end

Ru.run {
  name = 'gratekin', stage = 'espirito', W = 36, PW = 96, draw = draw, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96 (escala 2,55)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.55, o, 2.1, 4.1)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 20, 20 }, green = { 17, 19 }, water = { 19, 18 }, residential = { 19, 20 }, lit = { 19, 21 },
    sacred = { 19, 13 }, crimson = { 21, 19 },
  },
}
