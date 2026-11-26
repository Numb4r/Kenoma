-- Duskwreath (sprig.ritual, proposta, revisão 4): a maritaca de pé, de olho fechado, dentro da própria guirlanda.
-- As duas asas de folha seca saem dos ombros, se curvam (uma por cima da cabeça, a outra por baixo dos pés) e se
-- fecham uma na outra em volta do corpo: onze folhas. Não há disco: o crepúsculo é a luz entre as folhas (um ponto
-- claro em cada emenda) e a nervura rosa de cada uma, na luz do tipo Feérico. A roda encosta no chão.
-- Cores do _sprig.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')
local cos, sin, rad = math.cos, math.sin, math.rad

local LEG = {
  A = '#1A1424',
  ['1'] = '#8C9656', ['2'] = '#667240', ['3'] = '#4A5632', ['4'] = '#353F2A',                     -- pena verde
  a = '#D9B46C', b = '#B5853F', c = '#8C5A2B', d = '#5E3A22',                                     -- folha seca
  B = '#CFC9BA', D = '#A39E92', E = '#77736C',                                                    -- bico
  R = '#6E2E2A', r = '#9A4438',                                                                   -- o vermelho da cauda
  U = '#3E4668', u = '#56608A',                                                                   -- o azul da testa
  P = '#8A877F',                                                                                  -- pés
  h = '#6A4A58', i = '#63564A', t = '#5A3A4A', v = '#51465A',                                     -- apagados
  O = '#C0669E', M = '#FFA8E0', C = '#FFD6F1', X = '#9B7BFF',
  S = '#FFA8E0', s = '#FFD6F1',
}
local LIT = { O = 't', M = 'h', C = 'i', X = 'v' }

local CX, CY = 18, 19
local ANG = { 160, 194, 228, 262, 320, 350, 380 }
local MID = { 177, 211, 245, 335, 365 }
local PROF = { { 0, 0 }, { 1.4, 1.1 }, { 2.4, 1.8 }, { 3.2, 0.9 }, { 4.2, 1.6 }, { 5, 0.7 }, { 5.8, 1.1 }, { 6.5, 0 } }

local function leafpts(n)
  local a = rad(ANG[n])
  local bx, by = CX + 9.5 * cos(a), CY + 9.5 * sin(a)
  local d = a + rad(n % 2 == 0 and 8 or -8)
  local tx, ty = cos(d), sin(d)
  local function at(t, s) return { bx + tx * t - ty * s, by + ty * t + tx * s } end
  local pts = {}
  for _, q in ipairs(PROF) do pts[#pts + 1] = at(q[1], q[2] * 1.12) end
  for i = #PROF - 1, 2, -1 do pts[#pts + 1] = at(PROF[i][1], -PROF[i][2] * 1.12) end
  return pts, at
end

local function draw(P, g, k)
  -- o raminho de cada lado
  P:limb({ { 16, 20.6 }, { 11, 22.4 }, { 9.1, 22.3 }, { 8.8, 16.7 }, { 11.6, 11.9 }, { 16.7, 9.6 } }, 1.1, 0.7, '&')
  P:limb({ { 22.6, 20.4 }, { 26.9, 22.3 }, { 27.4, 17.4 }, { 25.3, 12.9 } }, 1.1, 0.7, '&')
  for n = 1, 7 do
    local pts, at = leafpts(n)
    P:poly(pts, n % 2 == 1 and '!' or '$')
    local c = n % 2 == 0 and 'M' or 'O'
    local a0, a1 = at(0.6, 0), at(5.4, 0)
    P:limb({ a0, a1 }, 0.4, 0.4, c, '!$')
    if k > 1 then
      for _, t in ipairs({ 1.6, 2.8, 4.0 }) do
        local m = at(t, 0)
        P:limb({ m, at(t + 0.9, 1.0) }, 0.15, 0.15, 'O', '!$'); P:limb({ m, at(t + 0.9, -1.0) }, 0.15, 0.15, 'O', '!$')
      end
      P:ell(at(6.2, 0)[1], at(6.2, 0)[2], 0.4, 0.4, 'd', '!$')
    end
  end
  for _, m in ipairs(MID) do
    local a = rad(m)
    P:ell(CX + 9.5 * cos(a), CY + 9.5 * sin(a), 0.7, 0.7, 'C', '&')
  end
  do
    local _, at = leafpts(2)
    R.seam(P, at(2, 0), at(4.5, 0), '!$')
  end
  -- a maritaca, grande e na frente
  P:limb({ { 17.5, 29 }, { 15, 33 } }, 1.5, 0.8, '^')                              -- a cauda
  P:ell(19, 23, 5.6, 7.4, '@')
  P:ell(16.6, 22.5, 2.6, 5, '=', '@')                                             -- o coto da asa
  P:limb({ { 18.2, 28.6 }, { 18.2, 32.5 } }, 0.7, 0.7, 'P'); P:limb({ { 21, 28.6 }, { 21, 32.5 } }, 0.7, 0.7, 'P')
  P:ell(20.5, 12.5, 4.4, 4.2, '#')
  P:ell(20.2, 9.4, 2.6, 1.2, '%', '#')                                            -- a testa azul
  P:ell(25.2, 13.5, 1.9, 2.1, '+')                                                -- o bico
  P:ell(24.6, 15.4, 0.9, 0.7, 'E')
  P:limb({ { 21.2, 12.4 }, { 23, 12.4 } }, 0.5, 0.5, 'd', '#')                     -- o olho fechado
  if k > 1 then   -- mordida de 1 unidade nas folhas 2 e 6
    for _, n in ipairs({ 2, 6 }) do
      local _, at = leafpts(n)
      local m = at(3.6, 1.1)
      P:ell(m[1], m[2], 0.5, 0.5, '.', '!$')
    end
  end
  R.seam(P, { 20, 22.4 }, { 21, 25.6 }, '@')
  R.shade(g, '&', 'cd')
  R.shade(g, '!', 'abc', { tex = 'leaf', amp = 0.7 })
  R.shade(g, '$', 'bcd', { tex = 'leaf', amp = 0.7, seed = 5 })
  R.shade(g, '@', '1234', { tex = 'feather', amp = 0.6 })
  R.shade(g, '=', '234', { tex = 'feather', amp = 0.5, seed = 2 })
  R.shade(g, '#', '123', { tex = 'feather', amp = 0.5 })
  R.shade(g, '%', 'uU')
  R.shade(g, '+', 'BD')
  R.shade(g, '^', 'rR4', { tex = 'fur' })
end

R.build {
  name = 'duskwreath', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  after = function(P, g, k)
    local l = {}
    for _, m in ipairs(MID) do
      local a = rad(m)
      l[#l + 1] = { CX + 11.5 * cos(a), CY + 11.5 * sin(a), 's' }
      l[#l + 1] = { CX + 13.5 * cos(a), CY + 13.5 * sin(a), 'S' }
    end
    R.sparks(P, l)
  end,
  sparks = { { 22, 4.6, 'S' }, { 25, 6.4, 's' }, { 24, 3, 's' }, { 27.4, 4, 'S' }, { 3, 9, 's' }, { 33, 30, 'S' }, { 3.4, 30, 'S' }, { 33, 17, 's' } },
}
