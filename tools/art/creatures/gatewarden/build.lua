-- Gatewarden (rust.ritual), arte final: o ritual da família Rust. O besouro-rinoceronte de perfil, de olho fechado: o
-- casco é uma cúpula alta de grade de portão enferrujada, com a cabeça baixa e o chifre curvo na mesma ferrugem,
-- numa massa só. Duas barras do flanco se afastaram em amêndoa e a luz Metal sai só por essa fresta; o resto da grade
-- é escuro (ao contrário da lanterna do Rustling). Um cadeado de latão aberto pende ao lado.
-- Costuras do Véu: duas, no escudo e na cabeça (só no glow). Limalha solta acima da cúpula e atrás.
-- Camadas: corpo; leds = a espinha da fresta (I: pisca); glow = o resto da luz da fresta, o vazamento nos vãos,
-- as costuras e a limalha.
-- Animação: a cúpula e a cabeça sobem e as patas ficam; a luz da fresta respira; cadeado e ponta do chifre balançam.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/gatewarden/build.lua')
local Ru = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rust.lua')
local L = Ru.L
local sqrt, abs, sin, min, max, floor, pi = math.sqrt, math.abs, math.sin, math.min, math.max, math.floor, math.pi
local iron, hash = Ru.iron, Ru.hash

local DUST = { { 6, 10 }, { 9, 7.4, 's' }, { 12.4, 5.2 }, { 3.4, 14, 's' }, { 17, 6.4 }, { 20.4, 9.6, 's' }, { 1.8, 19 }, { 23, 12 } }

local CX, CY, RX, RY = 14.5, 27, 11, 15.5          -- a cúpula: metade de cima da elipse
local FX, FV0, FV1 = 15.5, 15, 26.5                -- a fresta: amêndoa de v 15 a 26,5
local bw = 0.5

local function almondW(v, wid)
  if v < FV0 or v > FV1 then return nil end
  return wid * sin(pi * (v - FV0) / (FV1 - FV0))
end
-- distância à amêndoa (negativa dentro)
local function adist(u, v, wid)
  local du = abs(u - FX)
  local w = almondW(v, wid)
  if w then return du - w end
  local ev = v < FV0 and FV0 or FV1
  return sqrt(du * du + (v - ev) ^ 2)
end

-- A cúpula (copiada do Ru.elytra): corte em v <= cy, duas travessas, fresta, vãos escuros.
local function dome(u, v, x, y, k, pr)
  if v >= CY then
    if v < CY + 1 and u >= 3.5 and u <= 25.5 then return iron(0, bw, x, y, 0.75, k) end   -- a soleira
    return
  end
  local ex = ((u - CX) / RX) ^ 2 + ((v - CY) / RY) ^ 2
  if ex > 1.0001 then return end
  local hh = RY * sqrt(max(0.02, 1 - ((u - CX) / RX) ^ 2))
  local lat = (v - CY) / hh
  local sh = lat * 0.8 + (u - CX) / RX * 0.25
  if u >= 21.5 then return iron(0, bw, x, y, sh, k) end                 -- o escudo (pronoto): chapa cheia
  local d = adist(u, v, pr.wid)
  if d < 0 then                                                         -- a luz da fresta
    local w = almondW(v, pr.wid)
    local du = abs(u - FX)
    if du < 0.5 / k then return 'I' end
    if du <= w * pr.mf then return 'M' end
    return 'D'
  end
  if d < 1 then return iron(d - 0.5, bw, x, y, sh, k) end               -- a borda de ferro da fresta
  local rim = (1 - sqrt(ex)) * min(RX, RY)
  if rim < 2 * bw then return iron(rim - bw, bw, x, y, sh, k) end
  local q = u - CX + 91.5 - lat * 0.5
  local dd = (q % 3) - 1.5
  local t1, t2 = (lat + 0.62) * hh, (lat + 0.28) * hh
  local onb, ont = abs(dd) < bw, abs(t1) < bw or abs(t2) < bw
  if onb or ont then
    if k > 1 and onb and ont and dd * dd + min(t1 * t1, t2 * t2) < 0.4 then return '5' end   -- rebite
    return iron(onb and dd or (abs(t1) < bw and t1 or t2), bw, x, y, sh, k)
  end
  if d < pr.reach then return 'D' end                                    -- o vazamento nos vãos
  if k > 1 then                                                          -- escorrido de ferrugem sob as travessas
    for n, tt in ipairs({ t1, t2 }) do
      if tt > bw and tt < bw + 0.5 + ((hash(floor(q / 3), n, 77) >> 4) % 10) * 0.12 and hash(floor(q / 3), n, 77) % 2 == 0
        and min(q % 3, 3 - q % 3) < 0.4 then
        return tt < bw + 0.6 and 'R' or 'r'
      end
    end
  end
  return 'z'
end

local HO = 2                                      -- desloca o sorteio das manchas na cabeça e no chifre (cinza <= 25%)
local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = crouch and 0.8 or ((o.dy or 0) - all) / k
  oy = oy + all
  local lum = alert and 1.5 or (crouch and 0.6 or ({ [0] = 1, 1.1, 1.2, 1.08 })[ph])
  local pr = { wid = alert and 3.2 or (crouch and 1.2 or 2.4), lum = lum }
  pr.reach = alert and 5.2 or (crouch and 1.2 or 2.5 * lum)
  pr.mf = min(0.9, 0.65 + 0.1 * (lum - 1))
  local st = o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[ph] or 0
  local ts = still and 0 or ({ [0] = 0, 0.4, 0, -0.4 })[ph]               -- ponta do chifre
  local ls = still and 0 or ({ [0] = 0, 0.4, 0, -0.4 })[ph] * (o.lean and 2.2 or 1)   -- cadeado
  local ribs = k > 1 and 3 or nil
  local near, far = {}, {}
  local hv = 27.8 + by
  -- tripé A: perto 1 e 3, longe 2; tripé B: o resto
  Ru.leg(near, { { 8, hv }, { 7.0, 30.5 }, { 6.6 + st, 33.4 } }, 0.7, '4', '2', ribs)
  Ru.leg(near, { { 14.5, hv }, { 15.3, 30.5 }, { 15.2 - st, 33.4 } }, 0.7, '4', '2', ribs)
  Ru.leg(near, { { 21, hv }, { 22.0, 30.5 }, { 23 + st, 33.4 } }, 0.7, '4', '2', ribs)
  Ru.leg(far, { { 10.5, hv }, { 10.2, 30.5 }, { 10.2 - st, 33.4 } }, 0.55, '2', '1', ribs)
  Ru.leg(far, { { 17.5, hv }, { 18.4, 30.5 }, { 18.6 + st, 33.4 } }, 0.55, '2', '1', ribs)
  Ru.leg(far, { { 23.5, hv }, { 24.7, 30.5 }, { 25.6 - st, 33.4 } }, 0.55, '2', '1', ribs)
  local horn = {
    { 29.2, 23.8, 31.4, 22.8, 1.1, 0.95 }, { 31.4, 22.8, 32.4, 20.2, 0.95, 0.8 },
    { 32.4, 20.2, 32.0 + ts, 17.0, 0.8, 0.6 },
  }
  local sw, sp = k > 1 and 0.5 or 0.75, k > 1 and 1.5 or nil
  local lx = 20.5 + ls
  Ru.paint(g, k, ox, oy, function(u, v0, x, y)
    local v = v0 - by
    local he = ((u - 27.2) / 3.4) ^ 2 + ((v - 24.6) / 3.6) ^ 2
    if not o.dark then
      local ed = ((u - CX) / RX) ^ 2 + ((v - CY) / RY) ^ 2
      if (u >= 21.5 and ed <= 1 and Ru.seam(u, v, { 22.4, 17.6 }, { 23.8, 20.0 }, sw, sp))
        or (he <= 1 and Ru.seam(u, v, { 25.6, 25.4 }, { 27.4, 26.8 }, sw, sp)) then return 'Z' end
    end
    if he <= 1 and u >= 28 and u < 29.6 and abs(v - 23.8) < (k > 1 and 0.4 or 0.55) then return 'o' end   -- a pálpebra
    -- cadeado aberto, pendurado na travessa de baixo
    if u >= lx - 1.5 and u < lx + 1.5 and v >= 24 and v < 27 then
      if k > 1 and ((u - lx) ^ 2 + (v - 25.3) ^ 2 < 0.2 or (abs(u - lx) < 0.2 and v > 25.3 and v < 26.4)) then return 'o' end
      return (u > lx + 0.5 or v > 26) and 'b' or 'B'
    end
    local sd = sqrt((u - lx) ^ 2 + (v - 23.9) ^ 2)
    if v < 24 and sd > 0.7 and sd < 1.9 and not (u > lx + 0.5 and v > 22.7) then return u < lx and '5' or '3' end
    if he <= 1 then
      local sh = (v - 24.6) / 3.6 * 0.7 + (u - 27.2) / 3.4 * 0.3
      return iron(0, bw, x + HO, y + HO * 2, sh, k)
    end
    -- ponta de lança do chifre
    local tx = 32.0 + ts
    if abs(u - tx) / 1.3 + abs(v - 18.5) / 1.75 <= 1 then return u < tx and '5' or '4' end
    for n, s in ipairs(horn) do
      local dx, dy = s[3] - s[1], s[4] - s[2]
      local t = max(0, min(1, ((u - s[1]) * dx + (v - s[2]) * dy) / (dx * dx + dy * dy)))
      local px, py = s[1] + dx * t, s[2] + dy * t
      if sqrt((u - px) ^ 2 + (v - py) ^ 2) <= s[5] + (s[6] - s[5]) * t then
        local ring = k > 1 and floor((n - 1 + t) * 2.2) % 2 == 1
        return iron(0, bw, x + HO, y + HO * 2, ring and 0.8 or ((u - px) + (v - py)) * 0.5, k)
      end
    end
    local c = dome(u, v, x, y, k, pr)
    if c then return c end
    return Ru.caps(u, v0, near) or Ru.caps(u, v0, far)
  end)
  Ru.prune(g)
  if not o.dark then L.outline(g, 'A', Ru.SOLID) end
  Ru.dust(g, sg, k, ox, oy, k > 1 and DUST or { DUST[1], DUST[4], DUST[6], DUST[8] }, ph, 4)
end

Ru.run {
  name = 'gatewarden', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.55, o, 1.6, -8.8)
    return g, sg, 0, 0
  end,
  acc = {
    sacred = { 14.5, 8 }, green = { 8.5, 16.5 }, water = { 19.5, 15 }, residential = { 9.5, 21.5 },
    lit = { 20, 19.5 }, urban = { 5, 24.5 }, crimson = { 11, 26.5 },
  },
}
