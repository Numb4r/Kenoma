-- Wyrmlet (wyrm.eco), arte final: o Eco da família Wyrm, a partir do conceito aprovado. Um teú jovem em proporção
-- natural, de perfil, andando; não parece dragão (GDD, "Tipos"). O errado é pouco: só nas costelas a escama está em
-- brasa (escama escura com a junta acesa), e a brasa respira; a língua bifurcada é uma chama pequena.
-- Costuras do Véu: quatro, de 1 px (rabo, anca, lombo, pescoço), só no glow; apagadas ficam quase na cor da escama.
-- Camadas: corpo; leds = o olho e a língua (piscam); glow = a escama em brasa, as costuras e as fagulhas.
-- Bicho de chão: o tronco sobe e desce (body_dy) e os pés ficam; na deriva ele anda; na fuga, salta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wyrmlet/build.lua')
local W = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wyrm.lua')
local L = W.L
local OX, OY = 0, 1

local function draw(g, sg, k, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local b = (o.dy or 0) / k + (crouch and 1 or 0)            -- o tronco
  local f = o.jump and (o.dy or 0) / k or 0                  -- os pés (só saem do chão no salto da fuga)
  local m = (b + f) / 2
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0     -- o passo
  local br = still and (alert and 1 or 0) or ({ [0] = 0, 0.5, 1, 0.5 })[ph]   -- a brasa respira
  local sw = still and 0 or ({ [0] = 0, 0.4, 0.8, 0.4 })[ph] -- o rabo balança
  local ty = alert and -1 or (crouch and 2 or 0)             -- o rabo sobe no alerta e baixa encolhido
  local hy = b + (alert and -1.6 or (crouch and 0.8 or 0))   -- a cabeça
  local ha = alert and -30 or (crouch and 2 or -16)
  local p = k > 1 and 2 or 1
  local function pts(list)
    local out = {}
    for i, q in ipairs(list) do out[i] = { (q[1] + OX) * k, (q[2] + OY) * k } end
    return out
  end
  local function leg(hx, hyy, kx, ky, fx, fy, s, pal)
    W.leg(g, { hx + OX, hyy + OY + b, kx + OX + s * 0.5, ky + OY + m, fx + OX + s, fy + OY + f }, k, pal, 1)
  end
  local body = W.spline(pts({ { 6 + sw, 5 + b + ty }, { 3.4 + sw * 0.5, 8.4 + b + ty * 0.6 }, { 3.4, 13.4 + b + ty * 0.2 }, { 6.5, 16.6 + b },
    { 11, 16.6 + b }, { 15.5, 15.4 + b }, { 18.6, 13.2 + (b + hy) / 2 }, { 20.4, 10.6 + hy } }))
  local w = W.prof({ { 0, 0.7 }, { 0.38, 2.6 }, { 0.62, 3.9 }, { 0.84, 3.4 }, { 1, 2.4 } }, k)
  leg(17.8, 15, 19.6, 17.6, 21.2, 19.4, -st, W.FARLEG)
  leg(10.4, 16.2, 12.6, 18.4, 11.4, 20.2, st, W.FARLEG)
  W.tube(g, body, w, W.skin({ p = p, band = 4.5 * k,
    ember = function(t, dn) return t > 0.56 - 0.03 * br and t < 0.78 + 0.03 * br and dn > -0.35 - 0.15 * br and dn < 0.6 end }))
  -- costuras do Véu: quatro, finas
  for n, t0 in ipairs({ 0.17, 0.33, 0.47, 0.9 }) do
    W.seam(g, body, w, t0, 1, 'Z', W.SCALE, n % 2 == 0 and 0.5 or -0.5, k > 1 and 2 or nil)
  end
  local tl = alert and 1 or (crouch and 0 or ({ [0] = 1, 0.6, 0, 0.6 })[ph])   -- a língua entra e sai
  W.head(g, (20.6 + OX) * k, (9.8 + OY + hy) * k, ha, k * 0.95, { eye = true, tongue = 1, tl = tl,
    open = alert and 0.7 or (k > 1 and 0.3 or 0) })
  leg(16, 16, 17.6, 18.8, 19.4, 20.6, st, W.DARK)
  leg(8.4, 17, 10.6, 19.4, 9.2, 21.2, -st, W.DARK)
  W.dust(g, sg, { { 14, 9.5, 'S' }, { 16.5, 7.4, 's' }, { 10, 9, 'N' } }, ph, 4, k, OX * k, (OY + b) * k)
end

W.run {
  name = 'wyrmlet', stage = 'eco', W = 28, PW = 96, draw = draw,
  -- o retrato é o desenho do mapa ampliado, com detalhe (dente, narina, olho de fenda, pontos nas costuras)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 96 / 28, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 10, 15 }, green = { 7, 12 }, water = { 9, 14 }, residential = { 11, 13 }, lit = { 10, 16 },
    sacred = { 9, 13 }, crimson = { 5, 14 },
  },
}
