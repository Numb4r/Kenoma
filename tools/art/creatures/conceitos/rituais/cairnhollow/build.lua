-- Cairnhollow (clod.ritual, proposta, revisão 2): o tatu-bola fechado em bola, no chão. A bola rachou: uma rachadura
-- irregular, em zigue-zague, de cima a baixo, com o cristal de geodo aceso por dentro (luz do tipo Terra). Pela
-- rachadura saem a cabeça, de olho fechado, e as duas mãos de garras. O traço da família (a luz que vaza pelas juntas
-- das cintas) continua. Cores do _clod.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')
local sqrt, max = math.sqrt, math.max

local LEG = {
  A = '#1A1424',
  ['1'] = '#B9B1A0', ['2'] = '#918A7B', ['3'] = '#6C675D', ['4'] = '#4B4843', ['5'] = '#32302F',   -- concreto e brita
  a = '#B39062', b = '#8B6C45', c = '#5F4931',                                                    -- seixo ocre
  p = '#9C614B', q = '#74412F', t = '#4D2B23',                                                    -- caco de tijolo
  K = '#8C7A69', l = '#66574B', M = '#473C35',                                                    -- cinta de queratina
  N = '#9A8474', n = '#74615A', r = '#B5978A',                                                    -- pele do focinho e da orelha
  C = '#CDBFA2', D = '#9A8C74',                                                                   -- garra
  O = '#120D1C',                                                                                  -- o fundo da rachadura
  j = '#4F3F2B', y = '#5F4D33', h = '#3F2E22', v = '#565064',                                     -- apagados
  J = '#C0915A', Y = '#E6C594', H = '#7E5A32', X = '#9B7BFF',
  S = '#C0915A', s = '#E6C594',
}
local LIT = { J = 'j', Y = 'y', H = 'h', X = 'v' }
local OPEN = { { 19, 9.2 }, { 22, 12.5 }, { 19.5, 15.5 }, { 16.5, 20.5 }, { 19.5, 25.5 }, { 22, 28.5 }, { 19, 31.8 }, { 24, 30.2 },
  { 27.2, 25 }, { 28, 20.5 }, { 27.2, 16 }, { 24, 10.8 } }
local TEETH = { { 19.6, 10.4, 3 }, { 21.4, 12.2, 2.6 }, { 20.6, 14.4, 2.8 }, { 18.2, 17.4, 3 }, { 17.4, 20.2, 3 }, { 18.2, 23.8, 2.8 },
  { 20.6, 26.6, 2.4 }, { 21.2, 29.4, 2 }, { 22.6, 30.4, 2 }, { 25.4, 28, 2.4 }, { 27.2, 24, 2.8 }, { 27.6, 18.6, 2.8 },
  { 26.2, 14.4, 2.8 }, { 24.4, 11.4, 2.6 } }

-- O dente só pinta sobre o fundo escuro (`O`) e cresce para o miolo, onde a cabeça e as mãos pintam por cima: a 36 px
-- um dente tem uns 3 px, e um ajuste pequeno no tamanho some no arredondamento. Por isso o tamanho é por escala:
-- TOOTH[1] no mapa, TOOTH[2] no retrato (o retrato tem mais área e estoura o teto de emissivo com o mesmo fator).
local TOOTH = { 1.5, 1.35 }
local function tooth(P, b, c, k)
  local dx, dy = c[1] - b[1], c[2] - b[2]
  local d = sqrt(dx * dx + dy * dy); dx, dy = dx / d, dy / d
  local L = b[3] * TOOTH[k > 1 and 2 or 1] + 0.5
  P:fill(b[1] - L, b[2] - L, b[1] + L, b[2] + L, nil, 'O', function(u, v)
    local t = ((u - b[1]) * dx + (v - b[2]) * dy) / L
    local w = math.abs(-(u - b[1]) * dy + (v - b[2]) * dx)
    if t < -0.2 or t > 1 or w > 1.0 * (1 - t) + 0.25 then return false end
    return t < 0.4 and 'H' or (t < 0.78 and 'J' or 'Y')
  end)
end

local function draw(P, g, k)
  local cx, cy, r = 16, 20.5, 12
  P:ell(cx, cy, r, r, '!')                                                        -- a bola, no chão
  -- as cintas só nos dois terços da esquerda; uma junta acesa, a outra apagada
  P:fill(3, 8, 30, 33, nil, '!', function(u, v)
    local hw = r * sqrt(max(0.02, 1 - ((v - cy) / r) ^ 2))
    local lon = (u - cx) / hw
    if lon > -0.95 and lon < -0.05 then
      local p = (lon + 0.95) / 0.225
      if p > 0.6 and (p % 1) * 0.225 * hw < 0.75 then return p > 2 and 'M' or 'J' end
      return '@'
    end
  end)
  P:fill(3, 8, 30, 33, nil, '!', function(u, v, x, y)                              -- seixos de outra pedra
    local h = R.hash((x + (y // 3) * 2) // 4, y // 3, 11) % 7
    if h == 0 then return '#' elseif h == 1 then return '&' end
  end)
  -- a abertura de geodo: fundo escuro até a beira da bola, lábio claro, dentes de cristal
  P:poly(OPEN, 'O', '!#&@MJ')
  for i = 1, #OPEN do
    local a, b = OPEN[i], OPEN[i % #OPEN + 1]
    P:limb({ a, b }, 0.5, 0.5, '1', '!#&@')
  end
  for _, b in ipairs(TEETH) do tooth(P, b, { 23.6, 20.4 }, k) end
  if k > 1 then   -- facetas: prisma de 3 px com ponta Y; a espessura da casca no lábio
    for _, q in ipairs({ { 18.6, 17.6 }, { 19, 23.6 }, { 26.6, 17.8 } }) do P:limb({ { q[1], q[2] }, { q[1] + 1.2, q[2] + 0.1 } }, 0.2, 0.2, 'Y', 'HJ') end
    for i = 1, #OPEN do
      local a, b = OPEN[i], OPEN[i % #OPEN + 1]
      P:limb({ { a[1] - 0.9, a[2] }, { b[1] - 0.9, b[2] } }, 0.2, 0.2, '2', '!')
    end
  end
  -- a mão de cima e a de baixo, com duas garras cada, agarrando o lábio
  P:limb({ { 21.5, 12.5 }, { 25.5, 11.5 } }, 1.2, 0.9, '=')
  P:limb({ { 25.5, 11.2 }, { 28.4, 10.2 } }, 0.6, 0.45, '+'); P:limb({ { 25.7, 12 }, { 28.6, 12.2 } }, 0.6, 0.45, '+')
  P:limb({ { 21, 28 }, { 25.5, 28.5 } }, 1.3, 1.0, '=')
  P:limb({ { 25.5, 28 }, { 28.6, 27.6 } }, 0.6, 0.45, '+'); P:limb({ { 25.4, 29.2 }, { 28.4, 30 } }, 0.6, 0.45, '+')
  -- a cabeça, pequena, de olho fechado
  P:ell(24.6, 19.4, 0.6, 0.8, '^')
  P:limb({ { 22.5, 20.6 }, { 26.5, 21.3 }, { 31, 22.2 } }, 1.6, 0.8, '^')
  P:limb({ { 23, 20.1 }, { 27.2, 20.6 } }, 0.8, 0.6, '%')
  P:limb({ { 26.8, 21.3 }, { 28.2, 21.6 } }, 0.5, 0.5, 'M', '^')
  R.seam(P, { 6.4, 15 }, { 5.6, 18.6 }, '!#&')
  R.seam(P, { 14.6, 29.2 }, { 17.4, 30.2 }, '!#&')
  R.shade(g, '!', '1234', { tex = 'stone', seed = 3 })
  R.shade(g, '#', 'abc', { tex = 'noise' })
  R.shade(g, '&', 'pqt', { tex = 'noise' })
  R.shade(g, '@', 'KlM', { tex = 'metal', amp = 0.5 })
  R.shade(g, '%', 'KlM', { amp = 0.4 })
  R.shade(g, '^', 'rNn', { amp = 0.5 })
  R.shade(g, '=', 'lM')
  R.shade(g, '+', 'CD')
end

R.build {
  name = 'cairnhollow', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 3, 12, 'S' }, { 31, 6, 's' }, { 33, 16, 'S' }, { 2.6, 29, 's' }, { 13, 4, 'S' }, { 31, 33, 's' } },
}
