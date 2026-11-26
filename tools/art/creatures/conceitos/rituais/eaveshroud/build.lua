-- Eaveshroud (shade.ritual, proposta): o morcego-da-cara-branca pendurado num pedaço de marquise, embrulhado nas
-- asas como um casulo, de olhos fechados. A sombra da família (a que fica acordada ao lado) entrou no embrulho: onde
-- as asas se cruzam abriu um Sol Negro, o disco escuro com a coroa acesa na luz do tipo Sombra.
-- Cores do _shade.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')

local LEG = {
  A = '#1A1424',
  ['1'] = '#45454E', ['2'] = '#63636B', ['3'] = '#87868A', ['4'] = '#ACA9A4',                     -- concreto da marquise
  a = '#3A2E2C', b = '#574639', c = '#7A654F', d = '#A08A6C',                                     -- pelo
  e = '#231E33', f = '#2F2942', g = '#3C3552', u = '#4A4266',                                     -- membrana
  i = '#6B5560', J = '#927C80',                                                                   -- ossos dos dedos
  w = '#D8CDB8', ['6'] = '#C8C2B4', ['7'] = '#9A9488',                                            -- a cara branca
  q = '#A0623C', r = '#7A4630',                                                                   -- vergalhão
  k = '#120D1C',                                                                                  -- o disco
  y = '#4C3A56', z = '#5E4A68', x = '#3A2A44', v = '#352E4C',                                     -- apagados
  M = '#A677AB', N = '#D2ABD6', K = '#68426E', X = '#9B7BFF',
  S = '#A677AB', s = '#D2ABD6',
}
local LIT = { M = 'y', N = 'z', K = 'x', X = 'v' }

local function draw(P, g, k)
  -- o pedaço de marquise
  P:poly({ { 7, 3.2 }, { 29, 3.2 }, { 29, 7 }, { 26, 7.9 }, { 9, 7.6 }, { 7, 6.4 } }, '$')
  P:limb({ { 29, 5 }, { 32.6, 4.5 } }, 0.55, 0.55, 'q')
  P:limb({ { 16.4, 7 }, { 17, 10 } }, 0.8, 0.7, '^'); P:limb({ { 19.6, 7 }, { 19, 10 } }, 0.8, 0.7, '^')   -- os pés
  -- o embrulho: uma asa por cima da outra
  P:ell(18, 19.5, 7.2, 10.8, '!')
  P:poly({ { 18.5, 9 }, { 12, 14 }, { 11, 24 }, { 16.5, 30 }, { 20.5, 26 }, { 16.6, 18 } }, '@', '!')
  -- os ossos dos dedos
  P:limb({ { 18, 9.6 }, { 12.4, 22 } }, 0.5, 0.5, '#', '!@')
  P:limb({ { 18, 9.6 }, { 15.4, 28 } }, 0.5, 0.5, '#', '!@')
  P:limb({ { 18.6, 9.6 }, { 23.6, 25 } }, 0.5, 0.5, '#', '!@')
  -- a cabeça, embaixo, com as orelhas para o chão
  P:poly({ { 15.2, 31 }, { 14.6, 33.8 }, { 17, 32.6 } }, '&')
  P:poly({ { 20.8, 31 }, { 21.4, 33.8 }, { 19, 32.6 } }, '&')
  P:ell(18, 30.4, 3.4, 2.7, '^')
  P:ell(18, 31, 2.3, 1.7, '=')
  P:ell(17, 30.6, 0.5, 0.5, 'a'); P:ell(19.1, 30.6, 0.5, 0.5, 'a')                 -- os olhos fechados
  -- o Sol Negro
  local cx, cy = 18, 18.6
  for _, q in ipairs({ { 0.7, -0.7 }, { -0.7, -0.7 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 1, 0 }, { -1, 0 } }) do
    P:limb({ { cx + q[1] * 4.4, cy + q[2] * 4.4 }, { cx + q[1] * 6.2, cy + q[2] * 6.2 } }, 0.5, 0.5, 'K', '!@#')
  end
  P:ring(cx, cy, 3, 4.6, 'M')
  P:ring(cx, cy, 3, 3.7, 'N', 'M')
  P:ell(cx, cy, 3, 3, 'k')
  R.seam(P, { 13, 25 }, { 15, 27.6 }, '!@')
  R.seam(P, { 21.4, 10.8 }, { 22.8, 13.8 }, '!@')
  R.shade(g, '!', 'gfe', { tex = 'leaf', amp = 0.6 })
  R.shade(g, '@', 'ugf', { tex = 'leaf', amp = 0.6, seed = 4 })
  R.shade(g, '#', 'Ji')
  R.shade(g, '$', '4321', { tex = 'stone', seed = 2 })
  R.shade(g, '^', 'cba', { tex = 'fur' })
  R.shade(g, '&', 'dcb')
  R.shade(g, '=', 'w67')
  R.shade(g, 'q', 'qr')
end

R.build {
  name = 'eaveshroud', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 6, 14, 'S' }, { 29, 12, 's' }, { 30, 26, 'S' }, { 5, 28, 's' }, { 27, 32, 's' }, { 9, 33, 'S' } },
}
