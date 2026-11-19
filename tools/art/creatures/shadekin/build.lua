-- Shadekin (shade.spirit), arte final: o Espírito da família Shade, a partir do conceito aprovado. O morcego de pé,
-- com três orelhas e sem olhos; um braço desce comprido até o chão, com um resto de membrana.
-- O ELEMENTO ERRADO (o que o Umbrel não tem): a marquise tomou o corpo por dentro. O outro braço É a laje, com a
-- lâmpada tubular acesa por baixo e vergalhões no lugar dos dedos, e o concreto já entra pelo ombro e pelo peito,
-- rachado, no meio do pelo. O Umbrel só se pendura numa lasca; aqui a lasca virou osso.
-- TRAÇO: a sombra é maior que ele, tem três olhos e três orelhas e os braços para cima; uma das mãos já está sobre a
-- cabeça dele. Ela fica do lado da lâmpada que devia apagá-la, não sobe com a respiração dele (body_dy move só o
-- tronco; os pés ficam no chão), tamborila os dedos em outro ritmo, e na deriva pende para trás enquanto ele anda.
-- No alerta é ela que se ergue e abre as duas mãos; ele não se mexe.
-- Costuras do Véu: duas, de 2 px, só no glow (o pulso da sombra sobre a cabeça dele; o ombro, entre o pelo e a laje).
-- Camadas: corpo; leds = os três olhos da sombra; glow = a borda e as pontas dos dedos da sombra, a lâmpada, as
-- costuras e a poeira solta.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/shadekin/build.lua')
local Sh = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_shade.lua')
local L, R = Sh.L, Sh.R
local ceil, sqrt = math.ceil, math.sqrt

-- a cabeça no mapa, pixel a pixel: três orelhas, as listras, nenhum olho
local HEAD = {
  '.A..A.A...',
  'AoAAoAoA..',
  'AonnoAnA..',
  'AbcdcbnAA.',
  'AcdcwwcbjA',
  'AcdcaacbcA',
  'AbccwwcbbA',
  '.AbcccbaA.',
  '..AbcbA...',
}

-- costura atravessada num membro (de a até b), a f do comprimento, com meia largura hw
local function across(t, a, b, f, hw, ch, w, mask)
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local len = sqrt(dx * dx + dy * dy)
  local mx, my, nx, ny = a[1] + dx * f, a[2] + dy * f, -dy / len * hw, dx / len * hw
  t:wire({ { mx - nx, my - ny }, { mx + nx, my + ny } }, ch, nil, w, mask)
end

local function draw(g, sg, k, o)
  local ph = (o.ph or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local dy = o.dy or 0
  local sdy = (o.jump and dy < 0) and ceil(dy / 2) or 0       -- na fuga a sombra vai atrás, atrasada
  local fo = o.jump and 0 or -dy / k                          -- os pés ficam no chão
  local st = o.lean and ({ [0] = 1, 0, -1, 0 })[ph] or 0      -- o passo
  local sw = still and 0 or ({ [0] = 0, 1, 0, -1 })[ph]       -- o ritmo da sombra (não é o do corpo)
  local lx = o.lean and -1 or 0                               -- na deriva a sombra pende para trás
  local hd = crouch and 1.6 or (alert and -0.8 or 0)
  local bx = 20.4
  local ds = Sh.ctx(g, k, 0, sdy)
  local sf = Sh.matter(ds, 14)
  ds:layer(function(t)
    t:cap(bx - 0.9, 30.8, 10 + lx, 14 + hd * 0.5, 2.2, 3.8, sf)
    t:ell(9.6 + lx, 9.4 + hd, 2.9, 3.1, sf)
    for _, e in ipairs({ { 7.2, 7.6, 6.6, 3.2, 8.8, 6.6 }, { 8.8, 6.6, 9.6, 2.6, 10.6, 6.6 }, { 10.6, 6.6, 12.6, 3.4, 12.2, 7.8 } }) do
      t:poly({ { e[1] + lx, e[2] + hd }, { e[3] + lx, e[4] + hd }, { e[5] + lx, e[6] + hd } }, sf)
    end
    -- braço de trás para cima, mão aberta
    local w1 = { 6.4 + lx, 10.6 + hd }
    t:cap(8.4 + lx, 13.4 + hd, w1[1], w1[2], 1.2, 0.8, sf)
    local tp = Sh.hand(t, w1[1], w1[2], alert and -92 or (crouch and -150 or -104 + sw * 7), crouch and 4 or (alert and 6.2 or 5.8),
      alert and 84 or 78, 4, { 'g', 'f' }, sf, 0.6, 0.25)
    -- braço da frente: passa por cima e desce sobre a cabeça do corpo (no alerta sai de cima dela e abre)
    local s2 = { 11.4 + lx, 13.2 + hd }
    local w2 = alert and { 15.4, 7.6 } or (crouch and { 15, 9.4 } or { 15.2, 7 })
    t:cap(s2[1], s2[2], w2[1], w2[2], 1.2, 0.8, sf)
    local tp2 = Sh.hand(t, w2[1], w2[2], alert and -30 or (crouch and 34 or 22), crouch and 5 or (alert and 5.6 or 6.4), alert and 84 or 78 + sw * 9, 4,
      { 'g', 'f' }, sf, 0.6, 0.25)
    t:rim(Sh.SHADE, 'R', false, 0.6, k > 1 and 3 or nil)
    for _, q in ipairs(tp) do t:ell(q[1], q[2], 0.5, 0.5, 'P') end
    for _, q in ipairs(tp2) do t:ell(q[1], q[2], 0.5, 0.5, 'P') end
    for _, e in ipairs({ { 8.2, 8.8 }, { 10.6, 8.6 }, { 9.6, 10.8 } }) do Sh.eye(t, e[1] + lx, e[2] + hd, true) end
    across(t, s2, w2, 0.55, 1.5, 'Z', k > 1 and 1 or 2, 'efgR')            -- costura: o pulso que desce sobre a cabeça dele
  end)
  local db = Sh.ctx(g, k, 0, dy)
  db:layer(function(t)
    local p = t:pp()
    local vr, dg, nz = R.ver(p), R.diag(p), R.noise(p, 7)
    -- pernas e pés
    for _, s in ipairs({ -1, 1 }) do
      t:wire({ { bx + s * 1.2, 26 }, { bx + s * 1.4 + s * st * 0.5, 29.6 + fo / 2 }, { bx + s * 1.4 + s * st, 32.4 + fo },
        { bx + s * 1.4 + s * st + 1.6, 33 + fo } }, 'i', 'j', 0.6)
    end
    -- braço comprido, com um resto de membrana; a mão fica no chão
    t:poly({ { bx - 1.6, 16.6 }, { bx - 6, 23.6 }, { bx - 4.4, 30.6 + fo }, { bx - 3, 28.4 }, { bx - 1.8, 31.6 + fo }, { bx - 0.4, 29 }, { bx + 0.8, 32 + fo }, { bx + 1.4, 26 } },
      R.mat('mno', vr, function(u) return 0.9 - (u - (bx - 5)) / 6 * 0.8 end))
    t:wire({ { bx - 1.8, 16 }, { bx - 5.8, 23.6 }, { bx - 3.6, 29.6 + fo } }, 'i', 'j', 0.7)
    for _, e in ipairs({ { -5.2, 32.8 }, { -3.6, 33 }, { -2.2, 32.6 } }) do
      t:wire({ { bx - 3.6, 29.6 + fo }, { bx + e[1], e[2] + fo } }, 'j', 'i', 0.5)
    end
    -- a laje no lugar do outro braço: a lâmpada por baixo, vergalhão no lugar dos dedos
    local ex = bx + 11
    t:poly({ { bx + 1.4, 14.6 }, { ex, 12.4 }, { ex + 1, 13.4 }, { bx + 2.4, 15.8 } }, R.mat('34', nz, 0))
    t:poly({ { bx + 2.2, 15.8 }, { ex + 1, 13.6 }, { ex + 1, 16.2 }, { bx + 2.2, 18.4 } }, R.mat('23', nz, 0))
    t:wire({ { bx + 2.2, 18.8 }, { ex + 1, 16.6 } }, '1', '5', 0.8)
    local lamp = (not still and ph == 3) and 'V' or 'T'       -- a lâmpada falha num quadro do laço
    t:wire({ { bx + 4.2, 19 }, { bx + 10.2, 17.8 } }, lamp, nil, 0.8)
    t:wire({ { bx + 3.6, 19.1 }, { bx + 3.6, 19.1 } }, 'V', nil, 0.8)
    t:wire({ { bx + 10.8, 17.7 }, { bx + 10.8, 17.7 } }, 'V', nil, 0.8)
    t:wire({ { ex + 0.8, 14.6 }, { ex + 1.5, 14.2 } }, 'r', 'q', 0.6)
    t:wire({ { bx + 7.2, 15.2 }, { bx + 7.4, 17 } }, '5', nil, 0.4, '23')
    t:wire({ { bx + 9.6, 14.6 }, { bx + 9.8, 16 } }, '5', nil, 0.4, '23')
    if k > 1 then
      t:wire({ { ex + 0.8, 13.4 }, { ex + 1.6, 12.6 } }, 'r', 'q', 0.5)
      t:wire({ { ex + 0.8, 15.8 }, { ex + 1.5, 16.4 } }, 'r', 'q', 0.5)
      t:wire({ { bx + 5, 15.6 }, { bx + 5.6, 16.6 }, { bx + 5.2, 17.6 } }, '5', nil, 0.3, '23')
      t:wire({ { bx + 8, 18.8 }, { bx + 8, 20.6 } }, '1', '5', 0.3)
    end
    -- tronco; o concreto entra pelo ombro e pelo peito
    local cv = R.chev(t:X(bx), p)
    t:ell(bx, 21.2, 3.7, 6.4, R.mat('abcd', cv, R.lum(bx, 21.2, 3.7, 6.4)))
    t:poly({ { bx + 0.4, 15.4 }, { bx + 3.6, 15.4 }, { bx + 3.4, 19.4 }, { bx + 1.8, 22.2 }, { bx + 0.6, 20.4 }, { bx + 1.2, 18 } },
      R.mat('123', nz, function(_, v) return 0.9 - (v - 15) / 8 end), 'abcd')
    t:wire({ { bx + 2.6, 16 }, { bx + 2, 18.6 }, { bx + 2.4, 20.6 } }, '5', nil, 0.3, '123')
    t:wire({ { bx + 1.2, 14.6 }, { bx + 0.2, 18.2 } }, 'Q', nil, k > 1 and 1 or 2, 'abcd1234')   -- costura: o ombro, entre o pelo e a laje
    if k == 1 then return end
    Sh.fill(t.g, 'b', 6)
    local hx = o.lean and 0.4 or 0
    for _, e in ipairs({ { bx - 2, 11, bx - 2.6, 6.4, bx - 0.4, 10 }, { bx - 0.2, 10, bx + 0.4, 5.8, bx + 1.4, 10 }, { bx + 1.4, 10.4, bx + 3.2, 6.8, bx + 2.8, 11.2 } }) do
      t:poly({ { e[1] + hx, e[2] }, { e[3] + hx, e[4] }, { e[5] + hx, e[6] } }, R.mat('no', dg, 0))
    end
    t:ell(bx + 0.2 + hx, 12.6, 2.9, 2.7, R.mat('abcd', cv, R.lum(bx, 12.6, 2.9, 2.7)))
    t:ell(bx + 3 + hx, 13.4, 1.3, 1.1, R.mat('bc', dg, 0))
    t:wire({ { bx + 3.6 + hx, 12.2 }, { bx + 3.8 + hx, 11.2 } }, 'j', nil, 0.6)
    t:wire({ { bx + 0.6 + hx, 11.4 }, { bx + 2.6 + hx, 12.4 } }, 'w', nil, 0.5)
    t:wire({ { bx + 0.8 + hx, 14.2 }, { bx + 2.2 + hx, 14 } }, 'w', nil, 0.5)
    t:wire({ { bx + 0.8 + hx, 12.9 }, { bx + 2.2 + hx, 13 } }, 'a', nil, 0.5)          -- sem olhos: uma faixa escura
  end)
  if k == 1 then L.put(g, 17 + (o.lean and 1 or 0), 6 + dy, HEAD) end
  Sh.dust(ds, sg, { { 2, 20, 'K' }, { 5, 27, 'S' }, { 13.4, 3.6, 's' }, { 28, 23, 's' }, { 30.4, 26, 'S' }, { 26, 28, 'K' } }, ph, 4)
end

Sh.run {
  name = 'shadekin', stage = 'espirito', W = 36, PW = 96, draw = draw,
  fleeDy = { 1, 0, 0, -1, -1, -1 },
  over = { flee = function(_, os) for i = 2, #os do os[i].jump = true end return os end },
  -- o retrato é o desenho de 36 ampliado 2,5 vezes, no meio do quadro de 96
  portrait = function(o)
    local g, sg = L.grid(90, 90), L.grid(90, 90)
    draw(g, sg, 2.5, o)
    return g, sg, 3, 3
  end,
  acc = {
    urban = { 18, 22 }, green = { 16, 5 }, water = { 17, 16 }, residential = { 17, 24 }, lit = { 17, 19 },
    sacred = { 23, 12 }, crimson = { 20, 17 },
  },
}
