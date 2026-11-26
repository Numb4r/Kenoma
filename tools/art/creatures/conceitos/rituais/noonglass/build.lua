-- Noonglass (glare.ritual, proposta): o beija-flor-tesoura pousado, de bico erguido e olho fechado, num vergalhão
-- fincado no chão. O peito virou uma lente de farol com o sol do meio-dia dentro (a luz de Iaida). A asa de caco de
-- vidro está fechada ao longo do corpo e a tesoura da cauda pende, com as três cores do prisma nas pontas.
-- Cores do _glare.lua; luz do tipo Luz, mais o espectro (a exceção do Glare).
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')

local LEG = {
  A = '#1A1424',
  ['1'] = '#DCE6E8', ['2'] = '#A9BCC2', ['3'] = '#7C939C', ['4'] = '#586E7A', ['5'] = '#3C4E5C',   -- vidro
  a = '#7A9A8E', b = '#55766E', c = '#3A5755', d = '#273E42',                                     -- pena do corpo
  e = '#46587A', f = '#313F5C', n = '#222B42',                                                    -- cabeça e cauda
  M = '#C8CCD0', Z = '#8E9298', ['8'] = '#7A7F80', ['9'] = '#555A5E',                             -- bico, aro e vergalhão
  E = '#A2623C',                                                                                  -- ferrugem do vergalhão
  o = '#1E1A26',
  h = '#4A4230', j = '#5A5540', y = '#6A6650', r = '#5A4044', l = '#3E5440', q = '#38465E', w = '#3F5A5E',   -- apagados
  H = '#CDB468', J = '#FFF0B8', I = '#FFFBE6', R = '#F0A0A0', L = '#A8E0A0', B = '#8AB8F0', X = '#9B7BFF',
  S = '#FFF0B8', s = '#FFFBE6',
}
local LIT = { H = 'h', J = 'j', I = 'y', R = 'r', L = 'l', B = 'q', X = 'w' }

local function draw(P, g, k)
  -- a tesoura da cauda
  P:limb({ { 15, 24 }, { 11.4, 29 }, { 9.6, 33.5 } }, 1.5, 0.6, '$')
  P:limb({ { 17, 25 }, { 15, 30 }, { 14.8, 33.5 } }, 1.4, 0.6, '$')
  -- o vergalhão
  P:limb({ { 27.5, 27.8 }, { 9, 27.8 }, { 7.6, 32.6 } }, 1.2, 1.2, '^')
  P:ell(18.4, 19.2, 6.6, 8.4, '!')                                                -- o corpo
  P:poly({ { 12.6, 12.4 }, { 17.4, 14.6 }, { 15, 25.6 }, { 9.6, 30.4 }, { 9.4, 20 } }, '#')   -- a asa de vidro, fechada
  P:ell(20.6, 10.2, 3.8, 3.5, '@')                                                -- a cabeça
  P:limb({ { 23.6, 9.8 }, { 31.6, 7 } }, 0.9, 0.5, '&')                            -- o bico, erguido
  P:limb({ { 20.8, 10 }, { 22.8, 10 } }, 0.5, 0.5, 'o', '@')                       -- o olho fechado
  P:limb({ { 17.4, 26.4 }, { 17.4, 27 } }, 0.7, 0.7, '9'); P:limb({ { 20.6, 26.4 }, { 20.6, 27 } }, 0.7, 0.7, '9')
  -- a lente de farol no peito
  P:ring(20, 19, 3.3, 4.5, '=')
  P:ell(20, 19, 3.3, 3.3, 'H')
  P:ell(20, 19, 2.4, 2.4, 'J', 'H')
  P:ell(19.5, 18.5, 1.1, 1.1, 'I', 'J')
  -- o prisma nas pontas da cauda
  P:ell(10, 32, 0.6, 0.9, 'R', '$'); P:ell(11, 29.8, 0.6, 0.8, 'L', '$'); P:ell(14.9, 32, 0.6, 0.9, 'B', '$')
  R.seam(P, { 15.4, 20.5 }, { 16.2, 24 }, '!')
  R.seam(P, { 12.4, 20 }, { 12, 23.6 }, '#')
  R.shade(g, '!', 'abcd', { tex = 'feather', amp = 0.6 })
  R.shade(g, '@', 'efn', { tex = 'feather', amp = 0.5 })
  R.shade(g, '#', '12345', { tex = 'leaf', amp = 0.9 })
  R.shade(g, '$', 'efn', { tex = 'fur', bias = 0.1 })
  R.shade(g, '&', 'MZ9')
  R.shade(g, '=', '1MZ', { amp = 0.5 })
  R.shade(g, '^', 'Z89', { tex = 'metal' })
  P:fill(4, 26, 32, 34, nil, 'Z89', function(u, v, x, y) if R.hash(x, y, 6) % 7 == 0 then return 'E' end end)
end

R.build {
  name = 'noonglass', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 26, 15, 'S' }, { 28, 21, 's' }, { 7, 12, 's' }, { 30, 31, 'S' }, { 25, 3, 's' }, { 4, 22, 'S' } },
}
