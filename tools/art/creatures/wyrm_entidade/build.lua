-- Entidade Maior da família Wyrm (nome e pasta provisórios: wyrm_entidade), arte final a partir do conceito aprovado
-- da rodada 2: o teú que nada na rua. O trecho de asfalto faz parte dele: o corpo mergulha e volta três vezes, em
-- arcos, e a rua ondula em volta de cada entrada como água, com a faixa pintada e tudo. Por baixo do asfalto a brasa
-- dele aparece. As pernas pendem dos arcos sem pisar em nada; os olhos saíram da cabeça e estão no flanco; a cabeça,
-- sem olhos, tem duas línguas.
-- REGRA QUEBRADA (física, visível parada): o asfalto se comporta como água. Ele atravessa a rua sem abrir buraco, e
-- as ondas saem de cada entrada.
-- Movimento: as faixas da pele escorrem pelos arcos (o corpo passa, os arcos ficam), as ondas da rua se abrem, a brasa
-- de baixo do asfalto corre, as pernas penduradas balançam fora de fase e as línguas se alternam. O body_dy levanta os
-- arcos; a rua fica. No alerta os arcos sobem e a boca escancara; na deriva os arcos tombam para a frente.
-- Costura do Véu: uma, de 3 px, no arco maior, só no glow.
-- Camadas: corpo; leds = os quatro olhos do flanco e as línguas; glow = a escama em brasa de baixo dos arcos, as
-- entradas e a brasa sob o asfalto, a costura e as fagulhas.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/wyrm_entidade/build.lua')
local W = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_wyrm.lua')
local L = W.L
local floor, sqrt, abs, sin, max = math.floor, math.sqrt, math.abs, math.sin, math.max

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local fr = ph / NL
  local tt = fr * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dy = (o.dy or 0) / k
  local all = o.jump and dy or 0                             -- no salto da fuga vai tudo, a rua junto
  local up = (o.jump and 0 or dy) + (alert and -1.8 or (crouch and 2.4 or 0))   -- os arcos
  local fwd = o.lean and 1.8 or 0
  local sp = max(1, floor(k * 0.9))
  local function pts(list)
    local out = {}
    for i, q in ipairs(list) do out[i] = { q[1] * k, (q[2] + all) * k } end
    return out
  end
  local sk = W.skin({ p = sp, band = 7 * k, boff = (still and 0 or fr) * 7 * k, tw = ph, ember = function(_, dn) return dn > 0.05 end })
  local ENT = { 6, 15.6, 18.4, 30, 33.6 }
  local lite, dark = W.asphalt(true), W.asphalt(false)
  local grow = still and 0 or fr
  -- a rua, com as ondas
  W.fillpoly(g, pts({ { 2.6, 35.8 }, { 9, 34.6 }, { 20, 35.4 }, { 31, 34.4 }, { 45.4, 35.6 }, { 44.6, 43.4 }, { 36, 44.6 }, { 22, 43.6 }, { 10, 44.8 }, { 3.6, 43.6 } }),
    function(x, y)
      local u, v = x / k, y / k - all
      if v > 42 then return dark(x, y) end
      for _, c in ipairs(ENT) do
        local dd = sqrt((u - c) ^ 2 + ((v - 35.6) / 0.5) ^ 2)
        if dd < (alert and 2 or 1.6) then return 'R' end
        for n = -1, 1 do                                       -- a onda: crista clara, cava escura
          local lo = 2.6 + 2.8 * (n + grow)
          if dd > 1.9 and dd < 7.4 and dd >= lo and dd < lo + 1 then return dd < lo + 0.5 and 'g' or 'Q' end
        end
      end
      -- a faixa pintada ondula junto
      if abs(v - 40.2 - 0.7 * sin(u * 0.8 + tt)) < 0.6 and floor(u / 3.4) % 2 == 0 then return (x + y) % 3 == 0 and 'O' or 'o' end
      return lite(x, y)
    end)
  -- a brasa por baixo do asfalto, de uma entrada à outra: corre
  for _, q in ipairs({ { 15.6, 18.4 }, { 30, 33.6 }, { 2.8, 6 } }) do
    for x = floor(q[1] * k), floor(q[2] * k) do
      L.set(g, x, (37.6 + all + sin(x / k * 1.3 + tt) * 0.6) * k, ((x // sp + ph) % 3 == 0) and 'H' or 'J', 'pPQgoO')
    end
  end
  local A1 = W.spline(pts({ { 6, 36.6 }, { 5.6 + fwd * 0.5, 30 + up * 0.5 }, { 9.6 + fwd, 25.6 + up * 0.7 }, { 14 + fwd * 0.5, 29 + up * 0.5 }, { 15.6, 36.6 } }))
  local A2 = W.spline(pts({ { 18.4, 36.6 }, { 17.6 + fwd * 0.5, 20 + up * 0.6 }, { 23.6 + fwd, 8.6 + up }, { 29.6 + fwd * 0.5, 19 + up * 0.6 }, { 30, 36.6 } }))
  local hb = still and 0 or 0.6 * sin(tt)
  local NK = W.spline(pts({ { 33.6, 36.6 }, { 34.6, 27 + up * 0.4 }, { 33 + fwd * 0.5, 19 + up * 0.8 }, { 34.6 + fwd, 13.6 + up + hb } }))
  local W1, W2, W3 = W.prof({ { 0, 1.5 }, { 0.5, 1.9 }, { 1, 1.4 } }, k), W.prof({ { 0, 2 }, { 0.5, 2.7 }, { 1, 2.2 } }, k), W.prof({ { 0, 2.1 }, { 1, 1.7 } }, k)
  -- pernas de lá, penduradas
  local function leg(n, q, dir)
    local s = still and 0 or 0.7 * sin(tt + n * 2.1)
    W.leg(g, { q[1] + fwd * 0.6, q[2] + up * 0.8 + all, q[3] + fwd * 0.6 + s * 0.5 - fwd * 0.3, q[4] + up * 0.8 + all, q[5] + s - fwd * 0.4, q[6] + up * 0.8 + all }, k, W.DARK, dir)
  end
  W.tube(g, A1, W1, sk)
  W.tube(g, A2, W2, sk)
  W.seam(g, A2, W2, 0.3, k > 1 and 5 or 3, 'Z', W.SCALE .. 'JH', 0, k > 1 and 3 or nil)   -- a costura
  W.tube(g, NK, W3, sk)
  local hx, hyy = NK(1)
  W.head(g, hx, hyy, 12 + (alert and -16 or (crouch and 16 or 4 * sin(tt))), 1.8 * k,
    { open = alert and 1.5 or (crouch and 0.3 or 0.9 + 0.3 * sin(tt)), tongue = 2, tl = still and 1 or ({ [0] = 1, 0.7, 0.4, 0.7, 1, 0.6 })[ph] })
  leg(1, { 20, 14, 15.6, 17, 14.6, 21.6 }, -1)
  leg(2, { 27.6, 17, 25, 21.6, 26, 26 }, 1)
  leg(3, { 35.6, 25, 39.6, 27.6, 40.6, 32 }, 1)
  -- os olhos, no flanco (leds)
  for _, q in ipairs({ { A2, 0.36 }, { A2, 0.62 }, { A1, 0.5 }, { NK, 0.55 } }) do
    local x, y = q[1](q[2])
    local tx, ty = W.dirAt(q[1], q[2])
    x, y = x + ty * 1.1 * k, y - tx * 1.1 * k
    x, y = floor(x + 0.5), floor(y + 0.5)
    if k > 1 then
      L.disc(g, x, y, 1.5 * k, '4', W.SCALE .. 'JH'); L.disc(g, x, y, 0.95 * k, 'M'); L.disc(g, x, y, 0.5 * k, 'T')
      L.line(g, x, y - 0.8 * k, x, y + 0.8 * k, '4')
    else
      L.rect(g, x - 1, y - 1, x + 2, y + 1, '4', W.SCALE .. 'JH'); L.set(g, x, y, 'T'); L.set(g, x + 1, y, 'M')
    end
  end
  W.dust(g, sg, { { 3, 22 }, { 13, 19 }, { 17, 11 }, { 31, 9 }, { 43, 20 }, { 44, 29 }, { 24, 28 }, { 12, 32.6 }, { 26.6, 31 }, { 37, 33 }, { 8, 14 }, { 41.6, 6 } },
    ph, NL, k, 0, all * k)
end

W.run {
  name = 'wyrm_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw,
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o desenho de 48 ampliado 2 vezes
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 38 }, green = { 7, 36 }, water = { 34, 38 }, residential = { 20, 36 }, lit = { 9, 40 },
    sacred = { 30, 39 }, crimson = { 4, 38 },
  },
}
