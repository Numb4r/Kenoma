-- Umbrel (shade.eco), arte final: o Eco da família Shade, a partir do conceito aprovado da rodada 2. O
-- morcego-da-cara-branca dorme pendurado numa lasca de marquise, fechado como guarda-chuva, e nunca abre o olho. A
-- sombra sai dos pés dele, inclinada atrás do corpo, menor, com uma asa aberta, e é ela que olha.
-- TRAÇO: a sombra não acompanha o corpo. O body_dy move só a lasca e o morcego; a sombra fica onde está e abre e
-- fecha a asa em outro ritmo. No alerta quem reage é ela (abre a asa, ergue a cabeça, arregala); ele continua dormindo.
-- Costuras do Véu: quatro, de 1 px, prendendo a sombra ao corpo, só no glow (apagadas quase da cor da sombra).
-- Camadas: corpo; leds = os dois olhos da sombra; glow = a borda da sombra, as costuras e a poeira solta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/umbrel/build.lua')
local Sh = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_shade.lua')
local L, R = Sh.L, Sh.R
local ceil = math.ceil

-- o morcego no mapa, pixel a pixel (pés em cima, cabeça embaixo, de ponta-cabeça)
local BAT = {
  '....jj.....',
  '...AnmA....',
  '..AonnmA...',
  '.AjonmniA..',
  '.AjocbniA..',
  'AjondcnmiA.',
  'AjoncdnmiA.',
  'AojndcnimA.',
  'AnojcbinmA.',
  'AonojinmnA.',
  '.AnonmnmA..',
  '.AcdcccbA..',
  'AcdcwwcbbA.',
  'AcdccaacbcA',
  'AbccwwcbcbA',
  '.AbcdcbaAjA',
  'AonAAAonAA.',
  'AoA...AonA.',
  'AnA....AnA.',
  '.A......A..',
}

local function draw(g, sg, k, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local dy = o.dy or 0
  local sdy = (o.jump and dy < 0) and ceil(dy / 2) or 0       -- na fuga a sombra vai atrás, atrasada
  local op = alert and 1.6 or (crouch and -1 or ({ [0] = 0, 0.5, 1, 0.5 })[ph])   -- a asa da sombra
  if o.lean then op = op + 0.6 end
  local hy = alert and -1 or 0
  local look = (not alert and not crouch and ph == 2) and -1 or 0
  local ds = Sh.ctx(g, k, 0, sdy)
  local sf = Sh.matter(ds, 11)
  ds:layer(function(t)
    t:cap(20, 7.4, 11.8, 20.6, 2.6, 3.3, sf)
    local el = { 11 - op * 0.8, 9.4 - op * 0.6 }
    t:poly({ { 18, 8.6 }, el, { 6.6 - op * 1.6, 14.6 - op * 1.2 }, { 7.6 - op * 1.2, 19.4 - op * 0.4 }, { 12, 19.6 } }, sf)
    t:wire({ { 15.6, 9.6 }, { el[1], el[2] + 0.6 }, { 8 - op * 1.4, 14 - op } }, 'g', nil, 0.4, 'ef')
    t:wire({ { el[1], el[2] + 0.6 }, { 9.4 - op * 0.8, 18 } }, 'g', nil, 0.4, 'ef')
    t:ell(10.8, 22.4 + hy, 2.7, 2.4, sf)
    t:poly({ { 8.4, 23 + hy }, { 7, 25.4 + hy }, { 10, 24.8 + hy }, { 11.4, 25.6 + hy }, { 13.2, 24 + hy } }, sf)
    t:rim(Sh.SHADE, 'R', false, 0.7, k > 1 and 4 or nil)
    Sh.eye(t, 9.6 + look, 22 + hy, alert); Sh.eye(t, 12 + look, 23 + hy, alert)
    for _, e in ipairs({ { 15.4, 10.4 }, { 13.4, 14 }, { 11.6, 17.4 }, { 14.6, 19.6 } }) do
      t:wire({ { e[1] - 1, e[2] - 0.5 }, { e[1] + 1, e[2] + 0.5 } }, 'Z', nil, 0.34, 'efgR')
    end
  end)
  local db = Sh.ctx(g, k, 0, dy)
  db:layer(function(t)
    local bx, p = 20.5, t:pp()
    local nz, vr, dg = R.noise(p, 5), R.ver(p), R.diag(p)
    -- lasca de marquise
    t:poly({ { 13.4, 3 }, { 24.4, 3 }, { 25, 4.2 }, { 24, 5.4 }, { 14.2, 5.4 }, { 12.8, 4.2 } },
      R.mat('1234', nz, function(_, v) return v < 3.6 and 0.95 or (v < 4.6 and 0.5 or 0.05) end))
    t:wire({ { 24.6, 4.4 }, { 25.2, 4.6 } }, 'r', 'q', 0.6)
    if k == 1 then return end
    t:wire({ { 18, 3.4 }, { 18.6, 4.6 }, { 18.2, 5.6 } }, '5', nil, 0.3)
    t:wire({ { 22.4, 4.4 }, { 23, 5.8 } }, '5', nil, 0.3)
    -- asas fechadas em capa, uma meio aberta, como guarda-chuva mal fechado (respira)
    local br = ({ [0] = 0, 0.3, 0.6, 0.3 })[ph]
    t:poly({ { bx - 0.8, 6.4 }, { bx + 0.8, 6.4 }, { bx + 2.8, 9.4 }, { bx + 3.8, 14 }, { bx + 3, 17.2 }, { bx - 3, 17.2 }, { bx - 3.8, 14 }, { bx - 2.8, 9.4 } },
      R.mat('mno', vr, function(u) return 0.95 - (u - (bx - 3.8)) / 7.6 * 0.9 end))
    t:poly({ { bx + 2.6, 9.6 }, { bx + 5 + br, 9 }, { bx + 5.2 + br, 13 }, { bx + 4.4, 12.2 }, { bx + 4.4 + br * 0.5, 16.6 }, { bx + 3.4, 15 } }, R.mat('mno', vr, 0.1))
    t:wire({ { bx + 2.6, 10 }, { bx + 5 + br, 9 }, { bx + 4.4 + br * 0.5, 16.4 } }, 'i', 'j', 0.5)
    local cv = R.chev(t:X(bx), p)
    t:ell(bx, 13, 1.4, 3.6, R.mat('bcd', cv, R.lum(bx, 13, 1.4, 3.6)))                 -- peito no vão das asas
    for _, sg2 in ipairs({ -1, 1 }) do
      t:wire({ { bx + sg2 * 0.6, 7 }, { bx + sg2 * 3.2, 13.4 } }, 'j', 'i', 0.5)       -- antebraço
      t:wire({ { bx + sg2 * 3.2, 13.4 }, { bx + sg2 * 1.4, 16.8 } }, 'i', nil, 0.5)    -- dedos dobrados
      t:wire({ { bx + sg2 * 3, 13.4 }, { bx + sg2 * 2.6, 16.8 } }, 'i', nil, 0.3, 'mno')
    end
    t:wire({ { bx - 0.6, 5.6 }, { bx - 0.6, 6.6 } }, 'j', nil, 0.5)                    -- pés agarrados na laje
    t:wire({ { bx + 0.6, 5.6 }, { bx + 0.6, 6.6 } }, 'j', nil, 0.5)
    -- cabeça (de ponta-cabeça: orelhas para baixo e para fora)
    for _, e in ipairs({ { bx - 2.6, 20, bx - 4.4, 23.6, bx - 1, 22.4 }, { bx + 0.8, 22.6, bx + 3.4, 24.4, bx + 3, 21 } }) do
      t:poly({ { e[1], e[2] }, { e[3], e[4] }, { e[5], e[6] } }, R.mat('no', dg, 0.6))
    end
    t:ell(bx + 0.2, 19.6, 3.1, 2.8, R.mat('abcd', cv, function(u, v) return 0.2 + R.lum(bx, 19.6, 3.1, 2.8)(u, v) end))
    t:ell(bx + 3, 20.2, 1.3, 1.1, R.mat('bc', dg, 0))
    t:wire({ { bx + 3.8, 21.2 }, { bx + 4, 22 } }, 'j', nil, 0.6)                      -- folha nasal
    t:wire({ { bx + 0.2, 18.4 }, { bx + 2.2, 19 } }, 'w', nil, 0.5)                    -- listras da cara
    t:wire({ { bx + 0.4, 21 }, { bx + 1.8, 21 } }, 'w', nil, 0.5)
    t:wire({ { bx + 1, 20 }, { bx + 2, 20 } }, 'a', nil, 0.4)                          -- olho fechado
    t:wire({ { bx - 2.2, 18.4 }, { bx - 1.4, 17.8 } }, 'd', nil, 0.3)
    t:wire({ { bx - 3.4, 22.6 }, { bx - 2, 21.6 } }, 'm', nil, 0.3)
    t:wire({ { bx + 2.6, 23.4 }, { bx + 2.2, 22.2 } }, 'm', nil, 0.3)
  end)
  if k == 1 then
    -- na deriva a lasca puxa e a cabeça fica 1 px para trás, como quem vai pendurado
    for j, row in ipairs(BAT) do L.put(g, 16 - ((o.lean and j > 11) and 1 or 0), 5 + j + dy, { row }) end
    -- onde o corpo encosta na sombra, é ela que faz o contorno
    for y = 6, 25 do for x = 14, 17 do
      if g[y][x] == 'A' and ('efgRZ'):find(g[y][x - 1], 1, true) and g[y][x + 1] ~= '.' and g[y][x + 1] ~= 'A' then g[y][x] = 'e' end
    end end
  end
  Sh.dust(ds, sg, { { 3, 23, 'K' }, { 5.4, 25.6, 's' }, { 14.6, 26, 'S' }, { 26, 12, 'K' } }, ph, 4)
end

Sh.run {
  name = 'umbrel', stage = 'eco', W = 28, PW = 96, draw = draw,
  fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 28 ampliado 3 vezes, no meio do quadro de 96
  portrait = function(o)
    local g, sg = L.grid(84, 84), L.grid(84, 84)
    draw(g, sg, 3, o)
    return g, sg, 6, 6
  end,
  acc = {
    urban = { 18, 9 }, green = { 13, 3 }, water = { 17, 12 }, residential = { 18, 17 }, lit = { 17, 19 },
    sacred = { 17, 21 }, crimson = { 21, 11 },
  },
}
