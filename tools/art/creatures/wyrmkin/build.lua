-- Wyrmkin (wyrm.spirit), arte final: o Espírito da família Wyrm, a partir do conceito aprovado. O teú tomado pelo
-- asfalto: placas de rua levantadas na espinha, ainda com a faixa pintada, uma asa só (de placa), cinco pernas, duas
-- caudas e duas línguas; a escama em brasa aparece nas costelas, onde o asfalto abriu.
-- ELEMENTO ERRADO (o Eco não tem): a rua tomou o corpo por dentro. No flanco abriu um buraco de rua, com a borda de
-- asfalto, a terra vermelha e a brasa no fundo, e do fundo dele um olho olha para fora (o terceiro, fora da cabeça).
-- Costuras do Véu: duas, de 2 px (a base do rabo e o pescoço), só no glow.
-- Camadas: corpo; leds = os olhos (o da cabeça e o do buraco) e as línguas; glow = a escama em brasa, o fundo do
-- buraco e as trincas em volta dele, as costuras e as fagulhas.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; na deriva ele anda; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wyrmkin/build.lua')
local W = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wyrm.lua')
local L = W.L
local sqrt, floor = math.sqrt, math.floor
local OX, OY = 0.5, -1

local function draw(g, sg, k, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k + (crouch and 1 or 0)            -- o tronco
  local f = o.jump and (o.dy or 0) / k or 0                  -- os pés
  local m = (b + f) / 2
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0
  local br = still and (alert and 1 or 0) or ({ [0] = 0, 0.5, 1, 0.5 })[ph]
  local sw = still and 0 or ({ [0] = 0, 0.4, 0.8, 0.4 })[ph]
  local sw2 = still and 0 or ({ [0] = 0.8, 0.4, 0, 0.4 })[ph] -- a segunda cauda, fora de fase
  local ty = alert and -1 or (crouch and 2 or 0)
  local hy = b + (alert and -1.6 or (crouch and 0.8 or 0))
  local ha = alert and -22 or (crouch and 6 or -8)
  local up = alert and 1.6 or (crouch and -1.2 or 0.3 * br)  -- as placas se eriçam
  local p = k > 1 and 2 or 1
  local function pts(list)
    local out = {}
    for i, q in ipairs(list) do out[i] = { (q[1] + OX) * k, (q[2] + OY) * k } end
    return out
  end
  local function leg(hx, hyy, kx, ky, fx, fy, s, pal)
    W.leg(g, { hx + OX, hyy + OY + b, kx + OX + s * 0.5, ky + OY + m, fx + OX + s, fy + OY + f }, k, pal, 1)
  end
  local body = W.spline(pts({ { 6.5 + sw, 6.5 + b + ty }, { 3.2 + sw * 0.5, 11 + b + ty * 0.6 }, { 3.6, 17.5 + b + ty * 0.2 }, { 7.5, 22.6 + b },
    { 13.5, 23.6 + b }, { 19.5, 22 + b }, { 23.4, 18 + b }, { 24.2, 13.4 + (b + hy) / 2 }, { 25.6, 10.6 + hy } }))
  local w = W.prof({ { 0, 0.5 }, { 0.4, 2.6 }, { 0.62, 4 }, { 0.82, 3.3 }, { 1, 2.4 } }, k)
  leg(21.6, 21.4, 24.4, 25, 26.4, 27.6, -st, W.FARLEG)
  leg(11.6, 23, 13.6, 26.4, 12.6, 29, st, W.FARLEG)
  -- a segunda cauda: arrasta no chão
  W.tube(g, W.spline(pts({ { 5.4, 20.4 + b }, { 3.4 - sw2 * 0.4, 23.4 + b * 0.6 }, { 3.2 - sw2, 27 + f }, { 5.6 - sw2, 29.6 + f } })),
    W.prof({ { 0, 1.7 }, { 1, 0.5 } }, k), W.skin({ p = p, band = 4 * k }))
  -- placas na espinha (por trás do corpo) e a asa de placa
  for n, q in ipairs({ { 0.44, 3 }, { 0.53, 4.4 }, { 0.62, 5.6 }, { 0.71, 4.6 }, { 0.8, 3.2 } }) do
    local x, y = body(q[1])
    local tx, tyy = W.dirAt(body, q[1])
    W.slab(g, x + tyy * w(q[1]) * 0.6, y - tx * w(q[1]) * 0.6, tyy * 0.92 - tx * 0.38, -tx * 0.92 - tyy * 0.38, 3.6 * k, (q[2] + 2 + up) * k,
      (n == 2 or n == 3 or n == 4) and 'o' or nil)
  end
  local wa = math.rad(alert and -112 or (crouch and -150 or -128.5 - 4 * br))
  W.slab(g, (20.6 + OX) * k, (16 + OY + b) * k, math.cos(wa), math.sin(wa), 5 * k, (10.5 + up) * k, 'w')
  W.tube(g, body, w, W.skin({ p = p, band = 5 * k,
    ember = function(t, dn) return ((t > 0.4 and t < 0.5 + 0.02 * br) or (t > 0.7 - 0.02 * br and t < 0.86)) and dn > -0.8 and dn < 0.5 end }))
  -- costuras do Véu: duas, de 2 px
  W.seam(g, body, w, 0.3, k > 1 and 4 or 2, 'Z', W.SCALE, 0.4, k > 1 and 3 or nil)
  W.seam(g, body, w, 0.92, k > 1 and 4 or 2, 'Z', W.SCALE, -0.3, k > 1 and 3 or nil)
  local tl = alert and 1 or (crouch and 0 or ({ [0] = 1, 0.6, 0, 0.6 })[ph])
  W.head(g, (26 + OX) * k, (9.6 + OY + hy) * k, ha, k * 1.15, { eye = true, tongue = 2, tl = tl, open = alert and 0.9 or 0.5 })
  leg(19.6, 22.6, 21.8, 26.6, 23.8, 29.4, st, W.DARK)
  leg(14.6, 23.8, 15.4, 27.6, 17.6, 30.6, -st, W.DARK)
  leg(8.6, 22.6, 7.6, 26.6, 9.8, 30, st, W.DARK)
  -- o buraco de rua no flanco, com o olho no fundo
  do
    local x, y = body(0.6)
    local tx, tyy = W.dirAt(body, 0.6)
    local cx, cy = floor(x + tyy * 1.5 * k + 0.5), floor(y - tx * 1.5 * k + 0.5)
    local rx, ry = (alert and 3.5 or 3.1) * k, (alert and 2.9 or 2.5) * k
    local MASK = W.SCALE .. 'JHRjhr'
    for n, a in ipairs({ 200, 250, 320, 20, 100 }) do         -- trincas no asfalto da pele, em volta
      local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
      local len = (1.6 + (n % 2) * 0.8 + (alert and 0.8 or 0)) * k
      L.line(g, cx + ca * rx, cy + sa * ry, cx + ca * (rx + len), cy + sa * (ry + len), 'J', W.SCALE)
    end
    W.ell(g, cx, cy, rx, ry, 0, function(px, py, u, v, l)
      local rho = sqrt(u * u + v * v)
      if rho > 0.74 then
        if v < 0.1 then return (px // p + py // p) % 2 == 0 and 'g' or 'p' end
        return (px // p + py // p) % 2 == 0 and 'P' or 'Q'
      end
      if rho > 0.46 then return l > 0 and 'E' or 'e' end
      return 'R'
    end, MASK)
    local look = (not still and ph == 2) and -1 or 0           -- o olho olha para trás num quadro
    if k > 1 then
      L.disc(g, cx + look * k * 0.4, cy, 0.95 * k, 'M', 'R'); L.disc(g, cx + look * k * 0.4, cy, 0.5 * k, 'T', 'RM')
      L.line(g, cx + look * k * 0.4, cy - 0.8 * k, cx + look * k * 0.4, cy + 0.8 * k, '4', 'MT')
    else
      L.set(g, cx + look, cy, 'T', 'ReE'); L.set(g, cx + look + 1, cy, 'M', 'ReE')
    end
  end
  W.dust(g, sg, { { 10, 14, 'S' }, { 12.5, 10.5, 's' }, { 8, 9, 'N' }, { 30, 7, 's' }, { 17, 6, 'S' }, { 29, 18, 'N' } }, ph, 4, k, OX * k, (OY + b) * k)
end

W.run {
  name = 'wyrmkin', stage = 'espirito', W = 36, PW = 96, draw = draw,
  -- o retrato é o desenho do mapa ampliado, com detalhe (dente, narina, olho de fenda, pontos nas costuras)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 96 / 36, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 13, 20 }, green = { 9, 17 }, water = { 12, 19 }, residential = { 14, 18 }, lit = { 13, 22 },
    sacred = { 11, 18 }, crimson = { 7, 19 },
  },
}
