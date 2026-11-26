-- Glitchkin (bit.spirit), arte final: o Espírito da família Bit, a partir do conceito aprovado. O balanço da cabeça
-- do pombo ficou preso em quadros: três pescoços e três cabeças (a de trás é a ave, a do meio já tem linhas de
-- varredura, a da frente é só matriz de pixels), três pernas, duas caudas, uma tela rachada no peito e a asa em
-- fatias fora do lugar.
-- Costuras do Véu: duas, mais largas que as do Eco (no dorso e na raiz da cauda), só no glow, longe da tela.
-- Camadas: corpo; leds = os subpixels do pescoço da ave (piscam); glow = a cabeça de matriz, as colunas da tela, a
-- franja das fatias, as costuras e o pixel solto.
-- Animação: as três cabeças balançam uma depois da outra (cada uma um quadro atrás), a varredura e a matriz rolam, a
-- tela corre as colunas, as fatias da asa trocam de lado. Na deriva as três pernas andam fora de passo.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/glitchkin/build.lua')
local B = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_bit.lua')
local L = B.L
local floor = math.floor

local BOB = { [0] = 0, -0.8, -0.8, 0 }                       -- a cabeça recua e volta
local DUST = { { 2, 13 }, { 4, 10 }, { 31, 21 }, { 33, 17 }, { 30, 29 }, { 3, 31 }, { 12, 6 }, { 8, 9 }, { 33, 25 } }

local function draw(g, sg, kk, o, ox0, oy0)
  ox0, oy0 = ox0 or 0, oy0 or 0
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local k = kk * 1.1                                           -- maior que o Eco
  local ox, oy = 1.5 * kk + ox0, 5 * kk + oy0
  local dy = (o.dy or 0) + (crouch and kk or 0)
  local all = o.jump and (o.dy or 0) or 0
  local by = dy - all
  oy = oy + all
  local function X(v) return v * k + (k - 1) / 2 + ox end
  local function Y(v) return v * k + (k - 1) / 2 + oy + by end
  local p = kk > 1 and 3 or 1
  local function bob(n) return still and (alert and -0.6 or 0) or BOB[(ph - n) % 4] end
  local step = o.lean and { ({ [0] = 1, 0, -1, 0 })[ph], ({ [0] = 0, -1, 0, 1 })[ph], ({ [0] = -1, 0, 1, 0 })[ph] } or nil
  B.layer(g, function(t)
    B.pigeon(t, k, ox, oy, { by = by, roll = still and 0 or ph, step = step, tails = { 0, 1.6 }, legs = { 11.4, 14, 16.8 },
      heads = { { 20.4, 11.8, 23.6, 7.2, 'led', bob(0) }, { 19.4, 11.6, 19.8, 4.4, 'scan', bob(1) }, { 18, 12, 15.8, 6.8, nil, bob(2) } } })
    -- as costuras, no dorso e na raiz da cauda
    local w = kk > 1 and 2 or 1
    B.seam(t, { { X(8.4), Y(12.4) }, { X(11.4), Y(13.6) } }, w, kk > 1 and 4 or nil)
    B.seam(t, { { X(6.4), Y(16.6) }, { X(8.6), Y(18.6) } }, w, kk > 1 and 4 or nil)
    if kk == 1 then B.seam(t, { { X(8.4), Y(12.4) + 1 }, { X(11.4), Y(13.6) + 1 } }, 1) end   -- 2 px no mapa
    -- a tela no peito: moldura, vidro em linhas, colunas acesas que correm, e a rachadura
    local x0, y0, x1, y1 = floor(X(15.4)), floor(Y(12.2)), floor(X(21.4)), floor(Y(17.2))
    local b = B.th(k, 0.8)
    for y = y0, y1 do for x = x0, x1 do
      local ch
      if x < x0 + b or y < y0 + b then ch = '4' elseif x > x1 - b or y > y1 - b then ch = '2'
      else
        local col = floor((x - x0) / p) + (still and 0 or ph)
        ch = (floor(y / p) % 2 == 0) and '1' or '2'
        if col % 4 == 1 and y % (kk > 1 and 3 or 2) == 0 then ch = ({ 'P', 'Q', 'R' })[1 + (col // 4) % 3] end
      end
      t[y][x] = ch
    end end
    B.wire(t, { { X(16.4), Y(13.4) }, { X(18.6), Y(14.8) }, { X(18), Y(16) }, { X(20.2), Y(16.6) } }, '4', 'e', B.th(k, 0.4))
  end, o.dark and '' or nil)                                  -- na silhueta escura do nascer o K.run contorna
  -- a asa em fatias: trocam de lado
  local sg2 = (still or ph < 2) and 1 or -1
  B.tear(g, Y(13.4), Y(14.2), -floor(kk + 0.5) * sg2)
  B.tear(g, Y(15.2), Y(16), floor(2 * kk + 0.5) * (alert and 1.5 or 1) // 1)
  B.tear(g, Y(17.2), Y(17.8), -floor(2 * kk + 0.5) * sg2)
  B.dust(g, sg, kk, ox0, oy0, kk > 1 and DUST or { DUST[1], DUST[3], DUST[5], DUST[7], DUST[9] }, ph, 4)
end

B.run {
  name = 'glitchkin', stage = 'espirito', W = 36, PW = 96, draw = draw,
  -- o retrato é o mesmo desenho feito em 96 (escala 2,5)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.5, o, 3, 3)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 10, 20 }, green = { 7, 22 }, water = { 9, 18 }, residential = { 8, 19 }, lit = { 9, 21 },
    sacred = { 15, 2 }, crimson = { 11, 24 },
  },
}
