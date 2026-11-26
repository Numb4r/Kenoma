-- Staticroost (bit.ritual, proposta, revisão 2): o pombo empoleirado no alto de uma placa, estufado para dormir, a
-- cabeça encolhida e o olho fechado. As penas do peito e do pescoço se desfazem em Estática (luz do tipo Digital):
-- quanto mais para a frente, menos pena e mais chuvisco, que continua solto no ar. Sem tela nem contorno redondo.
-- O glitch da família continua: uma faixa do dorso anda dois pixels fora do lugar.
-- Cores do _bit.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')

local LEG = {
  A = '#1A1424',
  a = '#33373F', b = '#4E5560', c = '#6E7783', d = '#959DA8', e = '#BBC1C8', f = '#26282F',       -- plumagem
  N = '#A45C92',                                                                                  -- o furta-cor do pescoço
  h = '#C9C4BE',                                                                                  -- bico
  i = '#8A5459', j = '#B57A7C',                                                                   -- pés
  ['1'] = '#1D1F26', ['2'] = '#2C2F38', ['3'] = '#40444F', ['4'] = '#59606B',                     -- placa
  q = '#3A3840',                                                                                  -- pálpebra
  O = '#120D1C',                                                                                  -- o furo na pena
  o = '#2A3320', l = '#454C3A', k = '#1F2A1A', u = '#555A6C',                                     -- apagados
  P = '#A8F040', V = '#DCFA9E', Q = '#62A01E', X = '#9B7BFF',
  S = '#A8F040', s = '#DCFA9E',
}
local LIT = { P = 'o', V = 'l', Q = 'k', X = 'u' }

local function draw(P, g, k)
  -- o alto da placa, com a fileira de LEDs
  P:poly({ { 5, 30.6 }, { 31, 30.6 }, { 31, 33.7 }, { 5, 33.7 } }, '$')
  for x = 7.5, 29, 3 do P:ell(x, 32.2, 0.55, 0.55, 'Q', '$') end
  P:poly({ { 2.6, 21.5 }, { 9, 18.6 }, { 10, 25.6 }, { 3, 25.6 } }, '^')           -- a cauda
  P:limb({ { 15, 28.4 }, { 15, 30.6 } }, 0.7, 0.7, '='); P:limb({ { 20, 28.4 }, { 20, 30.6 } }, 0.7, 0.7, '=')
  P:ell(17, 21.5, 10, 7.6, '!')                                                   -- o corpo estufado
  P:ell(13.4, 21, 7, 4.8, '@', '!')                                               -- a asa
  P:limb({ { 11, 23.6 }, { 15, 18 } }, 0.7, 0.7, 'f', '@')                         -- as duas barras da asa
  P:limb({ { 14.6, 24.6 }, { 18.6, 19 } }, 0.7, 0.7, 'f', '@')
  P:ell(23.5, 12.6, 3.8, 3.6, '#')                                                -- a cabeça encolhida
  P:ell(22.4, 15.8, 3.6, 1.8, 'N', '#!')
  P:limb({ { 26.6, 13.2 }, { 28.4, 15.4 } }, 0.8, 0.5, 'h')                        -- o bico, baixo
  P:ell(26.3, 12.6, 0.8, 0.7, 'e')
  P:limb({ { 23.6, 12 }, { 25.4, 12 } }, 0.5, 0.5, 'q', '#')                       -- o olho fechado
  R.seam(P, { 8.6, 20.4 }, { 9.6, 23.4 }, '@')
  R.seam(P, { 12, 26.6 }, { 15.4, 27.6 }, '!')
  R.shade(g, '!', 'edcb', { tex = 'feather', amp = 0.6 })
  R.shade(g, '@', 'dcba', { tex = 'feather', amp = 0.6, seed = 2, bias = 0.1 })
  R.shade(g, '#', 'dcb', { tex = 'feather', amp = 0.5 })
  R.shade(g, '^', 'baf', { tex = 'fur' })
  R.shade(g, '=', 'ji')
  R.shade(g, '$', '4321', { tex = 'metal', amp = 0.5 })
  -- o glitch: a faixa do dorso fora do lugar, com dois pixels acesos na emenda
  R.glitch(P, 15, 17, 1, 14.5, -2)
  P:ell(15.6, 16, 0.55, 0.9, 'P', 'abcdef')
  P:ell(7.6, 16.4, 0.55, 0.55, 'V', 'abcdef')
  -- o peito e o pescoço se desfazem em Estática: sem borda, mais densa para a frente
  P:fill(18, 13, 30, 29, nil, 'abcdefN', function(u, v, x, y)
    local p = (u - 19.4) / 6.2 - (v < 15.4 and 0.3 or 0)
    if R.rnd(x, y, 5) < p * 0.95 then
      local h = R.hash(x, y, 9) % 10
      return h < 4 and 'P' or (h < 6 and 'V' or (h < 8 and 'Q' or 'O'))
    end
  end)
end

R.build {
  name = 'staticroost', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 5, 13, 'S' }, { 3, 29, 's' }, { 12, 8, 's' } },
  -- o chuvisco que já saiu do corpo
  after = function(P)
    P:fill(26, 14, 33.5, 29, nil, '.', function(u, v, x, y)
      if R.rnd(x, y, 12) < 0.2 * (1 - (u - 26) / 7.5) then return R.hash(x, y, 3) % 2 == 0 and 'S' or 's' end
    end)
  end,
}
