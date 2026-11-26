-- Stormlamp (hum.ritual, proposta): a mariposa pousada, vista de cima, de asas fechadas em delta. O tórax virou um
-- globo de lâmpada de rua (aro de cobre, isoladores de porcelana) com a tempestade dentro: o raio de Ozongon.
-- Sem olho aberto: os dois ocelos das asas estão fechados (pálpebra). O que pisca fica dentro do globo.
-- Cores do _hum.lua; luz do tipo Elétrico, com o ciano só no ponto do meio (o LED do Hum).
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')

local LEG = {
  A = '#1A1424',
  E = '#7672B8', F = '#4D4A8A', G = '#34305E', P = '#28244A', Q = '#3D3A70',   -- asa (pó índigo)
  C = '#2A2140', D = '#4A3D6B', R = '#6A5C94',                                 -- pelo
  B = '#8F86C9', T = '#C4BDF0',                                                -- antena
  K = '#6B3A22', c = '#A8663A', M = '#DDA060',                                 -- cobre do aro
  o = '#6E3A2C', O = '#9A5A44',                                                -- porcelana
  z = '#0D0914',                                                               -- o dentro do globo
  h = '#17444C', i = '#245A62',                                                -- ocelo fechado e a pálpebra
  j = '#6B5A44', u = '#2B2836', v = '#3F3A74',                                 -- apagados: veio e raio, halo, costura
  J = '#FFD23A', Y = '#FFEE9A', U = '#B8901C', H = '#5FD3C6', X = '#9B7BFF',
  S = '#FFD23A', s = '#FFEE9A',
}
local LIT = { J = 'j', Y = 'j', U = 'u', H = 'h', X = 'v' }

local function draw(P, g, k)
  P:poly({ { 16, 25 }, { 9, 30 }, { 12.5, 33.6 }, { 17, 29 } }, '$')            -- asas de trás
  P:poly({ { 20, 25 }, { 27, 30 }, { 23.5, 33.6 }, { 19, 29 } }, '$')
  P:ell(18, 28, 2.6, 5.6, '@')                                                 -- abdômen
  P:poly({ { 17.4, 10 }, { 3.5, 26.5 }, { 8.5, 30.5 }, { 17.4, 24 } }, '!')     -- asas da frente, em delta
  P:poly({ { 18.6, 10 }, { 32.5, 26.5 }, { 27.5, 30.5 }, { 18.6, 24 } }, '!')
  P:limb({ { 16.6, 6.6 }, { 13, 4.6 }, { 9.5, 4.3 } }, 0.6, 0.5, '#')            -- antenas
  P:limb({ { 19.4, 6.6 }, { 23, 4.6 }, { 26.5, 4.3 } }, 0.6, 0.5, '#')
  P:ell(18, 8.2, 2.8, 2.4, '@')                                                -- cabeça
  P:ell(18, 11.2, 1.7, 1.2, '^'); P:ell(18, 22.8, 1.7, 1.2, '^')               -- isoladores
  -- o globo no lugar do tórax
  P:ring(18, 17, 4.4, 6, '&')
  P:ell(18, 17, 4.4, 4.4, 'z')
  P:ell(18, 17, 3, 3, 'U', 'z')
  P:limb({ { 16.5, 13.8 }, { 19, 15.8 }, { 17, 17.4 }, { 19.6, 20.2 } }, 0.55, 0.55, 'Y', 'zU')
  P:ell(18.2, 16.7, 0.6, 0.6, 'H')
  -- ocelos fechados
  for _, x in ipairs({ 10.5, 25.5 }) do
    P:ell(x, 24.5, 1.9, 1.6, 'h', '!')
    P:limb({ { x - 1.5, 24.9 }, { x + 1.5, 24.9 } }, 0.5, 0.5, 'i', 'h')
  end
  -- veios acesos
  P:limb({ { 15, 14 }, { 6.2, 25.4 } }, 0.5, 0.5, 'J', '!')
  P:limb({ { 21, 14 }, { 29.8, 25.4 } }, 0.5, 0.5, 'J', '!')
  R.seam(P, { 13.5, 22 }, { 14.5, 25 }, '!')
  R.seam(P, { 21.5, 20.5 }, { 23.2, 24.5 }, '!')
  R.shade(g, '!', 'EFGP', { tex = 'scale', amp = 0.5, bias = -0.05 })
  R.shade(g, '$', 'QP', { tex = 'feather' })
  R.shade(g, '@', 'RDC', { tex = 'fur' })
  R.shade(g, '#', 'TB')
  R.shade(g, '^', 'Oo')
  R.shade(g, '&', 'McK', { tex = 'metal' })
end

R.build {
  name = 'stormlamp', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 4, 10, 'S' }, { 31, 12, 's' }, { 6, 33, 's' }, { 30, 32, 'S' }, { 18, 2.6, 's' }, { 2, 20, 'S' } },
}
