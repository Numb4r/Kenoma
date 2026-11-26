-- Eaveshroud (shade.ritual), arte final: o morcego-da-cara-branca pendurado num pedaço de marquise, embrulhado nas asas,
-- de olhos fechados em todo quadro. Onde as asas se cruzam abriu um Sol Negro: o disco escuro com a coroa e os raios na
-- luz do tipo Sombra. Mesma silhueta do conceito (conceitos/rituais/eaveshroud/build.lua), refeita no kit Shade.
-- TRAÇO: o Sol Negro fica sempre no mesmo pixel do quadro (na deriva, 1 px para trás); o body_dy move a laje, o embrulho
-- e a cabeça em volta dele (o disco é desenhado na camada do corpo com -dy / k somado, como o Shadekin faz com os pés).
-- No alerta quem reage é o disco: a coroa cresce, os raios alongam e abre um olho da sombra (leds). Só a asa de cima é
-- matéria de sombra (e, f, g); a de baixo é membrana do morcego e entra nas variantes.
-- Camadas: corpo; leds = os raios e o olho do disco; glow = a coroa, as duas costuras e a poeira solta.
-- Rodar: tools/art/rodar.sh tools/art/creatures/eaveshroud/build.lua
local Sh = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_shade.lua')
local L, R = Sh.L, Sh.R
local ceil = math.ceil

Sh.LEG.D = '#68426E'; Sh.LIT.D = { 'x', 'l' }

local WING = 'efgmnoij'
-- a cabeça no mapa, pixel a pixel (cabeça embaixo, orelhas para o chão, olhos fechados)
local HEAD = {
  '.AbcdcbA.',
  'AbcwwwcbA',
  'AcwawawcA',
  'Ab67w76bA',
  'AdcAAAcdA',
  'AdA...AdA',
  '.A.....A.',
}
local SLAB = { { 7, 3.2 }, { 29, 3.2 }, { 29, 7 }, { 26, 7.9 }, { 9, 7.6 }, { 7, 6.4 } }
local UW = { { 18.5, 9 }, { 12, 14 }, { 11, 24 }, { 16.5, 30 }, { 20.5, 26 }, { 16.6, 18 } }
local DIRS = { { 0.7, -0.7 }, { -0.7, -0.7 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 1, 0 }, { -1, 0 } }
-- o par de raios que alonga em cada fase do laço: horizontal, diagonal, nenhum, a outra diagonal
local LONG = { [0] = { 5, 6 }, { 1, 4 }, {}, { 2, 3 } }

local function draw(g, sg, k, o)
  local ph = (o.ph or (o.portrait and o.portrait - 1) or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local dy = o.dy or 0
  local sdy = (o.jump and dy < 0) and ceil(dy / 2) or 0       -- na fuga o Sol Negro vai atrás, atrasado
  local hot = o.hot or 0
  local cx = o.lean and 17 or 18                              -- na deriva o Sol Negro fica 1 px para trás
  local cy = 18.6 + (sdy - dy) / k                            -- o disco não sai do pixel
  local outer = crouch and 4.0 or (alert and ({ 4.6, 5.2, 5.8 })[hot + 1])
    or (o.portrait and ({ 4.6, 5.0, 5.4, 5.0 })[o.portrait]) or (ph == 2 and 5.0 or 4.6)
  local hy = crouch and -1 / k or 0                           -- encolhido: a cabeça sobe 1 px
  local rx = crouch and 6.4 or 7.2
  local db = Sh.ctx(g, k, 0, dy)
  db:layer(function(t)
    local p = t:pp()
    local nz, vr, dg = R.noise(p, 5), R.ver(p), R.diag(p)
    -- o pedaço de marquise, em três faixas
    t:poly(SLAB, R.mat('1234', nz, function(_, v) return v < 4.6 and 0.95 or (v < 6.3 and 0.5 or 0.05) end))
    t:wire({ { 29, 5 }, { 32.6, 4.5 } }, 'q', 'r', 0.6)
    if k > 1 then
      t:wire({ { 13, 3.6 }, { 13.6, 5 }, { 13.2, 7 } }, '5', nil, 0.3, '1234')
      t:wire({ { 20, 4 }, { 20.8, 6 } }, '5', nil, 0.3, '1234')
      t:wire({ { 24.6, 7.2 }, { 25, 5 } }, '5', nil, 0.3, '1234')
      t:wire({ { 29, 3.8 }, { 31.4, 3.2 } }, 'q', 'r', 0.5)
      t:wire({ { 29, 6.2 }, { 31.6, 6.8 } }, 'q', 'r', 0.5)
    end
    -- os pés ligam a laje ao embrulho
    t:wire({ { 16.4, 7 }, { 17, 10 } }, 'b', 'c', 1.0)
    t:wire({ { 19.6, 7 }, { 19, 10 } }, 'b', 'c', 1.0)
    -- asa de baixo: membrana, luz à esquerda
    t:ell(18, 19.5, rx, 10.8, R.mat('mno', vr, function(u) return 0.9 - (u - 10.8) / 14.4 * 0.8 end))
    if k > 1 then
      t:wire({ { 23, 12 }, { 24, 19 }, { 22.4, 26 } }, 'm', nil, 0.3, 'mno')
      t:wire({ { 13, 12.4 }, { 11.8, 20 } }, 'm', nil, 0.3, 'mno')
    end
    -- asa de cima: matéria de sombra, mais clara em cima
    t:poly(UW, Sh.matter(t, function(_, v) return 0.85 - (v - 9) / 21 * 0.8 end))
    -- ossos dos dedos, só sobre as asas
    t:wire({ { 18, 9.6 }, { 12.4, 22 } }, 'i', 'j', 0.5, WING)
    t:wire({ { 18, 9.6 }, { 15.4, 28 } }, 'i', 'j', 0.5, WING)
    t:wire({ { 18.6, 9.6 }, { 23.6, 25 } }, 'i', 'j', 0.5, WING)
    -- costuras do Véu, de 2 px no mapa, só no glow
    local sw = k > 1 and 1 or 2
    t:wire({ { 13, 25 }, { 15, 27.6 } }, 'Z', nil, sw, 'efg')
    t:wire({ { 21.4, 10.8 }, { 22.8, 13.8 } }, 'X', nil, sw, 'mno')
    -- cabeça (no mapa vai pixel a pixel, abaixo)
    if k > 1 then
      t:poly({ { 15.2, 31 + hy }, { 14.6, 33.8 + hy }, { 17, 32.6 + hy } }, R.mat('bcd', dg, 0.5))
      t:poly({ { 20.8, 31 + hy }, { 21.4, 33.8 + hy }, { 19, 32.6 + hy } }, R.mat('bcd', dg, 0.5))
      t:ell(18, 30.4 + hy, 3.4, 2.7, R.mat('abcd', R.chev(t:X(18), p), R.lum(18, 30.4 + hy, 3.4, 2.7)))
      t:ell(18, 31 + hy, 2.3, 1.7, R.mat('w67', dg, R.lum(18, 31 + hy, 2.3, 1.7)))
      t:ell(17, 30.6 + hy, 0.5, 0.5, 'a'); t:ell(19.1, 30.6 + hy, 0.5, 0.5, 'a')
      t:wire({ { 16.2, 30.4 + hy }, { 17.8, 30.4 + hy } }, 'a', nil, 0.3, 'w67')       -- pálpebras em linha
      t:wire({ { 18.3, 30.4 + hy }, { 19.9, 30.4 + hy } }, 'a', nil, 0.3, 'w67')
    end
    -- o Sol Negro: raios (só sobre as asas), coroa de fora, coroa de dentro, disco
    local long = {}
    for _, i in ipairs(alert and {} or (crouch and {} or LONG[ph])) do long[i] = true end
    if not crouch then
      for i, d in ipairs(DIRS) do
        local to = alert and 7.4 or (long[i] and 7.2 or 6.2)
        t:wire({ { cx + d[1] * 4.4, cy + d[2] * 4.4 }, { cx + d[1] * to, cy + d[2] * to } }, 'D', nil, 0.6, WING)
      end
    end
    t:ell(cx, cy, outer, outer, 'P')
    t:ell(cx, cy, 3.7, 3.7, 'W')
    t:ell(cx, cy, 3, 3, 'k')
    if k > 1 and not crouch then
      for _, d in ipairs(DIRS) do
        t:wire({ { cx + d[1] * outer, cy + d[2] * outer }, { cx + d[1] * (outer + 0.7), cy + d[2] * (outer + 0.7) } }, 'I', nil, 0.6, 'D')
      end
    end
    if alert then
      if hot == 0 then L.set(t.g, t:X(cx), t:Y(cy), 'E') else Sh.eye(t, cx, cy, true, 'k') end
    end
  end)
  if k == 1 then L.put(g, 14, 28 + dy + (crouch and -1 or 0), HEAD) end
  local ds = Sh.ctx(g, k, 0, 0)
  local dust = { { 5, 14, 'S' }, { 29, 12, 's' }, { 30, 26, 'S' }, { 5, 28, 's' }, { 27, 32, 's' }, { 9, 33, 'S' } }
  if o.lean then dust = { { 5, 14, 'S' }, { 3, 22, 'K' }, { 7, 25, 's' }, { 5, 28, 's' }, { 9, 33, 'S' } } end  -- só atrás
  Sh.dust(ds, sg, dust, ph, 4)
end

Sh.run {
  name = 'eaveshroud', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fps = { idle = 6, drift = 6 },
  fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,5 vezes, no meio do quadro de 96
  portrait = function(o)
    local g, sg = L.grid(90, 90), L.grid(90, 90)
    draw(g, sg, 2.5, o)
    return g, sg, 3, 3
  end,
  acc = {
    sacred = { 14, 1 }, urban = { 7, 4 }, residential = { 21, 3 }, crimson = { 29, 3 },
    green = { 12, 8 }, water = { 15, 24 }, lit = { 14, 29 },
  },
}
