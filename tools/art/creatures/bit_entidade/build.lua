-- Entidade Maior da família Bit (nome e pasta provisórios: bit_entidade), arte final a partir do conceito aprovado da
-- rodada 3. O pombo que não sai dos quadros por onde passou: a cabeça está certa e inteira, no quadro de agora; a
-- traseira e a barriga já escorrem em blocos, e atrás dele ficam três cópias de si mesmo, cada uma num quadro
-- atrasado do mesmo balanço de cabeça, cada uma mais escura, em blocos maiores e mais afundada no chão.
-- REGRA QUEBRADA: o que já passou não sai do lugar; o corpo está em quatro instantes ao mesmo tempo.
-- Costura do Véu: uma, larga, onde o quadro de agora rasga do anterior, só no glow.
-- Camadas: corpo; leds = os subpixels do pescoço do quadro de agora (piscam); glow = a franja das cópias, a ponta do
-- que escorre, a costura e o pixel solto.
-- Animação (6 quadros, lenta): a cabeça de agora balança e cada cópia repete o balanço um quadro depois da anterior;
-- o que escorre cresce e encolhe; a faixa fora do lugar troca de lado. Só o quadro de agora sobe e desce (as cópias
-- estão afundadas); na fuga ele salta e arrasta as cópias junto.
-- Pés e pernas sem contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/bit_entidade/build.lua')
local B = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_bit.lua')
local L = B.L
local floor, max, sin, pi = math.floor, math.max, math.sin, math.pi

local OX, OY = 17.5, 4
local BOB = { [0] = 0, -0.5, -0.9, -0.5, 0, 0 }
local DUST = { { 3, 15 }, { 6, 45 }, { 41, 7 }, { 44.6, 31 }, { 12, 11 }, { 20, 45.4 }, { 31, 45 }, { 8.6, 19 }, { 36.6, 4 } }

local function draw(g, sg, kk, o, ox0, oy0)
  ox0, oy0 = ox0 or 0, oy0 or 0
  local S = g.w
  local big = kk > 1.5
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t6 = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local s = 1.15 * kk
  local all = o.jump and (o.dy or 0) or 0
  local by = (o.dy or 0) - all + (crouch and kk or 0)
  oy0 = oy0 + all
  local function X(v) return v * kk + (kk - 1) / 2 + ox0 end
  local function Y(v) return v * kk + (kk - 1) / 2 + oy0 end
  local function mb(blk) return big and (blk > 0 and blk * 2 + 1 or 0) or blk end   -- blocos ímpares no retrato
  local row = big and 3 or 1
  local function bob(n) return still and 0 or BOB[floor((ph - n) % NL * 6 / NL)] end
  local pulse = still and (alert and 1.2 or 0.7) or 0.85 + 0.25 * sin(t6)
  local function ghost(t, n, dx, dy2, opt, dark, blk, drip, seed)
    local c2 = L.grid(S, S)
    opt.heads[1][6] = bob(n)
    B.pigeon(c2, s, (OX + dx) * kk + ox0, (OY + dy2) * kk + oy0, opt)
    for y = 0, S - 1 do for x = 0, S - 1 do
      if c2[y][x] == 'G' then c2[y][x] = 'Q' elseif c2[y][x] == 'N' then c2[y][x] = 'a' end
    end end
    B.darken(c2, dark); B.mosaic(c2, mb(blk))
    for y = 0, S - 1 do for x = 0, S - 1 do                       -- varredura, e a franja do lado de trás
      if c2[y][x] ~= '.' then
        if L.get(c2, x - 1, y) == '.' and (y // row) % 2 == 0 then c2[y][x] = 'Q'
        elseif (y // row) % 3 == 2 and (not big or y % row == 0) and not ('PQR'):find(c2[y][x], 1, true) then
          c2[y][x] = ({ [0] = 'a', '2', '1' })[dark]
        end
      end
    end end
    B.melt(c2, max(1, mb(max(1, blk))), drip * kk * pulse, seed)
    B.blit(t, c2)
  end
  B.layer(g, function(t)
    ghost(t, 3, -21, 6, { legs = {}, tails = {}, heads = { { 18.6, 12, 18.2, 7.4, 'scan' } } }, 1, 2, 4, 11)
    ghost(t, 2, -14, 4, { legs = {}, heads = { { 18.6, 12, 18.4, 7, 'scan' } } }, 1, 1, 5, 12)
    ghost(t, 1, -7, 2, { legs = { 12.6 }, heads = { { 18.6, 12, 18.6, 6.6, 'scan' } } }, 1, 0, 5, 13)
    B.keepMain(t)
  end, o.dark and '' or nil)
  B.layer(g, function(t)                                          -- o quadro de agora
    B.pigeon(t, s, OX * kk + ox0, OY * kk + oy0, { by = by, roll = still and 0 or ph, heads = { { 18.6, 12, 18.8, 6.4, nil, bob(0) } },
      step = o.lean and { ({ [0] = 1, 0, -1, -1, 0, 1 })[ph % 6], ({ [0] = -1, 0, 1, 1, 0, -1 })[ph % 6] } or nil })
    local m2 = L.grid(S, S)
    B.blit(m2, t); B.mosaic(m2, mb(1) > 1 and mb(1) or 2)
    for y = floor(Y(21)), S - 1 do for x = 0, floor(X(31)) do       -- a traseira e a barriga já em blocos
      if (x - X(31)) + (y - Y(21)) * 1.2 < 6 * kk or y > Y(25) then t[y][x] = m2[y][x] end
    end end
    B.melt(t, big and 3 or 2, 6 * kk * pulse, 14, floor(X(21)), floor(X(33)))
  end, o.dark and '' or nil)
  B.tear(g, Y(23) - (kk - 1) / 2, Y(24) + (kk - 1) / 2, floor(-2 * kk * ((still or ph < NL / 2) and 1 or -1)))
  -- a costura: onde o quadro de agora rasga do anterior
  B.seam(g, { { X(27), Y(17) }, { X(25), Y(23) }, { X(26.4), Y(29) } }, big and 3 or 2, big and 6 or nil)
  B.dust(g, sg, kk, ox0, oy0, DUST, ph, NL)
end

B.run {
  name = 'bit_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw, NOPULL = B.NOPULL .. 'ij', DARK = '2',
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96: blocos de 3 e 5 px e varredura a cada 3 linhas
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o, 0, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 30, 22 }, green = { 27, 25 }, water = { 29, 20 }, residential = { 29, 21 }, lit = { 29, 23 },
    sacred = { 35, 4 }, crimson = { 33, 21 },
  },
}
