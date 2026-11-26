-- Cratercoil (wyrm.ritual, proposta, revisão 4): o teú de perfil, arqueado como uma ponte sobre a borda da cratera:
-- as patas de trás no chão, as da frente na borda de asfalto quebrado, o pescoço e a cabeça erguidos, de olho fechado
-- e boca aberta. O rosa do Dracônico vai na boca (a brasa na garganta), nas escamas das costelas (o traço da família)
-- e no clarão que sobe da cratera por baixo dele. Sem disco nem olho no centro. Cores do _wyrm.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')
local floor = math.floor

local LEG = {
  A = '#1A1424',
  ['1'] = '#6A6670', ['2'] = '#4A4752', ['3'] = '#33313B', ['4'] = '#25232C',                     -- escama
  c = '#BDB6A2', K = '#9C9484', C = '#8F897B', F = '#77736C',                                     -- faixas claras e barriga
  p = '#5C5B60', P = '#45444A', Q = '#303036',                                                    -- asfalto
  o = '#B89A3E',                                                                                  -- tinta da rua
  k = '#D8D2C0',                                                                                  -- garras
  z = '#120D1C',
  r = '#3A1A2C', j = '#4E2438', h = '#643046', v = '#3F3B4C',                                     -- apagados
  N = '#8E2852', J = '#DE4F84', H = '#F797B6', X = '#9B7BFF',
  S = '#DE4F84', s = '#F797B6',
}
local LIT = { N = 'r', J = 'j', H = 'h', X = 'v' }

local function draw(P, g, k)
  local function inhole(u, v) return ((u - 18) / 10) ^ 2 + ((v - 28.5) / 3.2) ^ 2 <= 1 end
  P:ell(18, 28.5, 10, 3.2, 'z')                                                   -- o buraco chato
  -- a parede de trás, por dentro: o corte do asfalto, para baixo
  P:fill(7, 24, 29, 30, nil, 'z', function(u, v, x, y)
    if v < 28.5 and ((u - 18) / 10) ^ 2 + ((v - 28.5) / 3.2) ^ 2 > 0.45 then return R.hash(x, y, 9) % 3 == 0 and 'Q' or 'P' end
  end)
  -- o tronco, cortado dentro do buraco (2 px de escuro até a beira da frente)
  P:limb({ { 18, 29 }, { 16.5, 22 }, { 17.5, 16 } }, 4.2, 3.6, '!', 'zPQ.')
  P:fill(10, 28, 26, 33, nil, '!', function(u, v) return v > 29.6 and inhole(u, v) and 'z' end)
  P:fill(10, 28, 26, 33, nil, 'z', function(u, v) if v >= 29.6 and v < 30.6 and math.abs(u - 18) < 5 then return 'N' end end)
  P:limb({ { 17.5, 16 }, { 20, 11.5 } }, 3.6, 3.2, '!')
  P:ell(21, 11.2, 2.6, 2.4, '$')
  P:rell(23.5, 9.5, 5, 3.1, -12, '^')
  P:limb({ { 22.5, 10.8 }, { 28, 9.4 } }, 0.45, 0.45, 'N', '^$')
  P:limb({ { 22.5, 10.8 }, { 24.2, 10.4 } }, 0.5, 0.5, 'J', 'N')
  P:limb({ { 28, 9.4 }, { 30.5, 10.2 } }, 0.45, 0.45, 'J')
  P:limb({ { 30.5, 10.2 }, { 32, 9.2 } }, 0.4, 0.4, 'H'); P:limb({ { 30.5, 10.2 }, { 32, 11.4 } }, 0.4, 0.4, 'H')
  P:limb({ { 23, 7.8 }, { 24.8, 7.4 } }, 0.5, 0.5, 'z', '^')                       -- o olho fechado
  -- as patas dobradas no cotovelo, as mãos e as garras, fora do buraco
  P:limb({ { 14, 21 }, { 5.5, 22 }, { 6.5, 27 } }, 2.0, 1.5, '&')
  P:limb({ { 20, 21 }, { 30.5, 22 }, { 29.5, 27 } }, 2.0, 1.5, '&')
  P:ell(6.5, 27.6, 1.8, 1, '&'); P:ell(29.5, 27.6, 1.8, 1, '&')
  for _, q in ipairs({ { 6.5, 4.2, 28.4 }, { 6.5, 5.2, 29.4 }, { 6.5, 6.8, 29.8 }, { 29.5, 31.8, 28.4 }, { 29.5, 30.8, 29.4 }, { 29.5, 29.2, 29.8 } }) do
    P:limb({ { q[1], 27.8 }, { q[2], q[3] } }, 0.45, 0.45, 'k')
  end
  -- faixas pretas e brancas, divisas rosa por cima
  P:fill(8, 10, 30, 30, nil, '!', function(u, v) if math.floor((v + (u - 17) * 0.35) / 2) % 2 == 0 then return '#' end end)
  for i, a in ipairs({ 15.5, 19, 22.5 }) do
    P:fill(13, 12, 22, 27, nil, '!#', function(u, v)
      local d = math.abs(u - 17)
      if d < 3 and math.abs(v - (a + d * 0.9)) < 0.4 then return i % 2 == 1 and 'J' or 'N' end
    end)
  end
  if k > 1 then
    P:limb({ { 27.2, 8.7 }, { 27.6, 8.8 } }, 0.2, 0.2, '4', '^')
    P:fill(8, 10, 30, 30, nil, '!', function(u, v, x, y) if R.hash(x, y, 8) % 4 == 0 then return '3' end end)
    P:fill(5, 21, 31, 29, nil, '&', function(u, v, x, y) if R.hash(x, y, 4) % 7 == 0 then return 'c' end end)
    P:limb({ { 23.6, 7.2 }, { 24.0, 7.9 } }, 0.2, 0.2, 'k', '^'); P:limb({ { 25.4, 6.3 }, { 25.8, 7.0 } }, 0.2, 0.2, 'k', '^')
    P:fill(8, 25, 29, 29, nil, 'PQ', function(u, v, x, y) if R.hash(x, y, 5) % 11 == 0 then return 'p' end end)
  end
  R.seam(P, { 17.2, 22 }, { 17.4, 25.6 }, '!#')
  R.seam(P, { 19.4, 11.2 }, { 20.6, 13.6 }, '!#')
  R.shade(g, '#', '434', { tex = 'scale', amp = 0.6 })
  R.shade(g, '!', 'ccKC', { tex = 'scale', amp = 0.5 })
  R.shade(g, '$', 'cKC', { tex = 'scale', amp = 0.5 })
  R.shade(g, '^', '1234', { tex = 'scale', amp = 0.5 })
  R.shade(g, '&', '123')
end

-- cinco rachaduras planas (sem contorno, em Q; 2 px junto ao buraco em N), saindo do contorno do buraco
local CR = { { 8, 29.6, 2, 30.4 }, { 28, 29.6, 34, 30.6 }, { 10.4, 31.2, 5, 32.8 }, { 26, 31.4, 31.6, 32.8 }, { 15, 32.2, 11.2, 33 } }
local function after(P, g, k)
  for ci, c in ipairs(CR) do
    local n, placed = 40, 0
    for i = 0, n do
      local u, v = c[1] + (c[3] - c[1]) * i / n, c[2] + (c[4] - c[2]) * i / n
      local x, y = math.floor(u * k + P.ox), math.floor(v * k + P.oy)
      local w = k > 1 and 2 or 1
      for dy = 0, w - 1 do for dx = 0, w - 1 do
        if g[y + dy] and g[y + dy][x + dx] == '.' and x + dx > 0 and x + dx < g.w - 1 and y + dy < g.h - 1 then
          g[y + dy][x + dx] = (i < n * 0.34) and 'N' or ((k > 1 and ci == 2 and i > n * 0.55 and i < n * 0.75) and 'o' or 'Q')
        end
      end end
    end
  end
end

R.build {
  name = 'cratercoil', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw, after = after,
  sparks = { { 30.4, 3.4, 's' }, { 33, 8, 'S' }, { 23, 3, 'S' }, { 4, 16, 's' }, { 32, 17, 'S' }, { 2.6, 22, 's' }, { 33.6, 22, 'S' }, { 12, 11, 's' } },
}
