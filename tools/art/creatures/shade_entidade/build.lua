-- Entidade Maior da família Shade (nome e pasta provisórios: shade_entidade), arte final a partir do conceito
-- aprovado: a marquise com morcegos. A laje inteira, com as três lâmpadas tubulares por baixo; pendurado nela, o
-- corpo sem rosto (só as listras, cruzadas onde seriam os olhos), com três pares de braços que descem em grade, como
-- uma fileira de morcegos dormindo; em cima da laje, a sombra em cata-vento de três asas, com olhos espalhados e o
-- rosto que falta no corpo.
-- REGRA QUEBRADA (física, visível parada): a sombra fica do lado da luz. As lâmpadas estão embaixo da laje e a sombra
-- está em cima dela, atravessando o concreto, maior que o corpo que a faria.
-- TRAÇO: a sombra não acompanha o corpo. O body_dy move a laje e o corpo pendurado; o cata-vento fica e gira devagar
-- (um terço de volta por laço, com o rosto parado no meio); na deriva o corpo vai pendurado para trás e o cata-vento
-- gira ao contrário. No alerta as asas abrem e os braços sobem; as lâmpadas falham uma de cada vez.
-- Costuras do Véu: duas, de 3 px, só no glow (a laje, onde a sombra a atravessa; o peito do corpo).
-- Camadas: corpo; leds = os olhos da sombra (o rosto e os das asas); glow = a borda da sombra, as lâmpadas e a luz
-- delas nos braços, as costuras e a poeira solta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/shade_entidade/build.lua')
local Sh = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_shade.lua')
local L, R = Sh.L, Sh.R
local floor, ceil, sin, cos, rad = math.floor, math.ceil, math.sin, math.cos, math.rad

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local tt = ph / NL * 2 * math.pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dy = o.dy or 0
  local sdy = (o.jump and dy < 0) and ceil(dy / 2) or 0
  local cx, cy = 23.5, 14
  local rot = still and 0 or (o.lean and -1 or 1) * ph * 120 / NL
  local wl, spr = crouch and 7 or 10.4, alert and 84 or (crouch and 40 or 62)
  local ds = Sh.ctx(g, k, 0, sdy)
  local sf = Sh.matter(ds, function(_, v) return 0.9 - (v - 4) / 18 end)
  ds:layer(function(t)
    for _, a0 in ipairs({ -100, 20, 140 }) do
      local a = rad(a0 + rot)
      Sh.hand(t, cx + cos(a) * 1.5, cy + sin(a) * 1.5, a0 + rot + 24, wl, spr, 3, { 'g', 'f' }, sf, 0.5, 0.12)
    end
    t:ell(cx, cy, 3.4, 3.4, sf)
    t:cap(cx, cy, cx, 23, 1.6, 2.4, sf)
    t:rim(Sh.SHADE, 'R', true, 0.5, k > 1 and 4 or 2)
    for _, a0 in ipairs({ -100, 20, 140 }) do                 -- olhos a mais, espalhados pelas asas
      for m, r in ipairs({ 5.4, 8.4 }) do
        if r < wl then
          local a = rad(a0 + rot + 24 + (m == 1 and -10 or 12))
          local ex, ey = cx + cos(a) * r, cy + sin(a) * r
          if k > 1 then t:ell(ex, ey, 0.8, 0.6, 'I'); t:ell(ex, ey, 0.4, 0.3, 'E')
          else L.set(t.g, t:X(ex), t:Y(ey), 'E'); L.set(t.g, t:X(ex) + 1, t:Y(ey), 'I', 'efgR') end
        end
      end
    end
    for i = 0, 2 do                                           -- o rosto: três olhos em triângulo e a folha nasal
      local a = rad(-90 + i * 120)
      local ex, ey = cx + cos(a) * 1.9, cy + sin(a) * 1.9
      if k > 1 then t:ell(ex, ey, alert and 1.1 or 0.9, 0.7, 'I'); t:ell(ex, ey, 0.5, 0.4, 'E') else L.set(t.g, t:X(ex), t:Y(ey), 'E') end
    end
    t:wire({ { cx, cy - 0.4 }, { cx, cy + 0.8 } }, 'P', nil, 0.6)
  end)
  local db = Sh.ctx(g, k, 0, dy)
  -- a laje
  db:layer(function(t)
    local p = t:pp()
    t:poly({ { 6.4, 21.6 }, { 40.6, 21.6 }, { 41.6, 23 }, { 41, 27.4 }, { 6, 27.4 }, { 5.4, 24 } },
      R.mat('1234', R.noise(p, 11), function(_, v) return v < 22.6 and 0.95 or (v < 25.6 and 0.5 or 0.05) end))
    for _, e in ipairs({ { 9, 23 }, { 14.6, 24 }, { 19, 23 }, { 28, 23.4 }, { 33.4, 23 }, { 38, 24 } }) do
      t:wire({ { e[1], e[2] }, { e[1] + 0.3, 26 } }, '5', nil, 0.4)
    end
    if k > 1 then
      t:wire({ { 11, 22 }, { 12.4, 23.6 }, { 11.8, 25 } }, '5', nil, 0.3)
      t:wire({ { 30, 22 }, { 31, 23 }, { 30.4, 24.6 }, { 31.4, 25.6 } }, '5', nil, 0.3)
      t:wire({ { 22, 24 }, { 24, 24.6 }, { 26, 24.2 } }, '5', nil, 0.3)
    end
    for n, e in ipairs({ { 8, 16 }, { 19, 28 }, { 31, 39 } }) do
      local off = not still and (ph + n * 2) % NL == 0        -- as lâmpadas falham uma de cada vez
      t:rect(e[1], 27, e[2], 28, off and 'V' or 'T')
      t:rect(e[1], 28, e[2], 28, 'V')
      t:rect(e[1] - 1, 27, e[1] - 1, 28, '5'); t:rect(e[2] + 1, 27, e[2] + 1, 28, '5')
    end
    t:wire({ { 5.4, 25 }, { 3.6, 24.4 } }, 'r', 'q', 0.6)
    t:wire({ { 41.4, 25.6 }, { 43.6, 26.4 } }, 'r', 'q', 0.6)
    t:wire({ { 41.6, 23.4 }, { 43, 22.6 } }, 'r', 'q', 0.6)
    -- costura: a laje, onde a sombra a atravessa
    t:wire({ { cx + 3.6, 21.8 }, { cx + 5, 24.2 }, { cx + 3.8, 27 } }, 'Q', nil, k > 1 and 1.5 or 3, '12345')
  end)
  -- o corpo pendurado: os braços balançam fora de fase; na deriva ficam para trás
  db:layer(function(t)
    local p = t:pp()
    local vr, dg = R.ver(p), R.diag(p)
    local up = alert and 2.4 or (crouch and 3.4 or 0)
    for n = 3, 1, -1 do
      for _, s in ipairs({ -1, 1 }) do
        local sway = (still and 0 or 0.6 * sin(tt + n * 1.3 + s)) + (o.lean and -1.4 or 0) + (crouch and -s * 1.2 * n / 3 or 0)
        local wx, wy = cx + s * (2.6 + 4.4 * n), 30.6 + (n % 2) * 0.8
        local tips = {}
        for f = 0, 2 do
          tips[f] = { wx + s * (f - 1) * (alert and 2.2 or 1.7) + s * 0.6 + sway, 46 - n * 2.4 - f * 1.2 + (f == 1 and 1.6 or 0) - up }
        end
        t:poly({ { wx - s * 1.4, wy - 1 }, { cx + s * 2, 30 + n * 0.9 }, { tips[0][1], tips[0][2] - 1 }, { (tips[0][1] + tips[1][1]) / 2, tips[1][2] - 3.4 },
          { tips[1][1], tips[1][2] - 1 }, { (tips[1][1] + tips[2][1]) / 2, tips[2][2] - 3 }, { tips[2][1], tips[2][2] - 1 } }, R.mat('mno', vr, 0.5 - s * 0.3))
        t:wire({ { cx + s * 2.4, 30 + n * 0.9 }, { wx, wy } }, 'i', 'j', 0.7)
        for f = 0, 2 do
          t:wire({ { wx, wy }, { tips[f][1] - s * 0.4 - sway * 0.5, (wy + tips[f][2]) / 2 }, { tips[f][1], tips[f][2] } }, 'i', 'j', 0.5)
        end
      end
    end
    t:wire({ { cx - 0.8, 27.8 }, { cx - 0.8, 29.4 } }, 'j', nil, 0.5)
    t:wire({ { cx + 0.8, 27.8 }, { cx + 0.8, 29.4 } }, 'j', nil, 0.5)
    local cv = R.chev(t:X(cx), p)
    local hx = o.lean and -0.8 or 0
    t:ell(cx + hx * 0.5, 34, 3.2, 5.6, R.mat('abcd', cv, R.lum(cx, 34, 3.2, 5.6)))
    for _, s in ipairs({ -1, 1 }) do
      t:poly({ { cx + hx + s * 2.4, 42 }, { cx + hx + s * 3.2, 45 }, { cx + hx + s * 0.6, 43.4 } }, R.mat('no', dg, 0))
    end
    t:ell(cx + hx, 40.8, 3, 2.8, R.mat('abcd', cv, R.lum(cx, 40.8, 3, 2.8)))
    -- sem rosto: só as listras, que se cruzam onde seriam os olhos
    t:wire({ { cx + hx - 1.8, 39.6 }, { cx + hx + 1.8, 41.8 } }, 'w', nil, 0.5)
    t:wire({ { cx + hx + 1.8, 39.6 }, { cx + hx - 1.8, 41.8 } }, 'w', nil, 0.5)
    -- costura: o peito
    t:wire({ { cx - 2.6, 33.4 }, { cx + 2.6, 34.4 } }, 'X', nil, k > 1 and 1.5 or 3, 'abcd')
    Sh.fill(t.g, 'm', 14 * k * k)
  end)
  -- a luz das lâmpadas cai nos braços pendurados
  local p = db:pp()
  for y = floor(db:Y(29.6)), floor(db:Y(32.4)) do for x = floor(db:X(8)), floor(db:X(39)) do
    local u = (x - (k - 1) / 2) / k
    if ((u >= 8 and u <= 16) or (u >= 19 and u <= 28) or (u >= 31 and u <= 39)) and (x // p + y // p) % 2 == 0
      and ('mnoij'):find(L.get(g, x, y), 1, true) then g[y][x] = 'P' end
  end end
  Sh.dust(ds, sg, { { 10, 30.6 }, { 13.6, 33 }, { 21, 30.4 }, { 26.4, 31.6 }, { 33.4, 30.4 }, { 37, 33 }, { 4, 12 }, { 42, 8 }, { 37, 18 },
    { 8, 17 }, { 44, 31 }, { 3, 36 } }, ph, NL)
end

Sh.run {
  name = 'shade_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw,
  nloop = 6, fps = { idle = 6, drift = 6 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 48 ampliado 2 vezes
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 21, 36 }, green = { 7, 20 }, water = { 31, 22 }, residential = { 8, 23 }, lit = { 20, 23 },
    sacred = { 20, 29 }, crimson = { 22, 38 },
  },
}
