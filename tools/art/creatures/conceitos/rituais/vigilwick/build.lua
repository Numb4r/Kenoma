-- Vigilwick (wisp.ritual, proposta, revisão 2): a coruja-buraqueira de pé no montinho de terra da toca, nas pernas
-- compridas e nuas, cabeça chata e larga sobre o pescoço, a asa fechada e o rabo curto. Os dois olhos de vela viraram
-- um só: no rosto abriu um nicho de oratório em arco ogival (pontudo, não redondo), com um toco de vela aceso dentro
-- (a luz de Teloch), e a cera escorre pelo peito. Do rosto sobra a ponta do bico. Na boca da toca, o mesmo frio.
-- Cores do _wisp.lua; luz do tipo Espectral.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')
local sqrt, abs = math.sqrt, math.abs

local LEG = {
  A = '#1A1424',
  a = '#3E3128', b = '#5E4A38', c = '#85694C', d = '#AD9270', e = '#CFC2A4',                      -- pena
  ['1'] = '#8C8676', ['2'] = '#B5AD98', ['3'] = '#D9D2BE',                                        -- cera e moldura do nicho
  l = '#B5A982', f = '#8E8468',                                                                   -- pernas e bico
  t = '#555362', u = '#74727F', ['5'] = '#735C4C',                                                -- terra do montinho
  V = '#150F20',                                                                                  -- o fundo do nicho e da toca
  x = '#34435E', y = '#4C6182', z = '#6A82A4', w = '#6E5A50',                                     -- apagados
  B = '#8A9DBA', D = '#D3E2F4', E = '#F2F7FF', X = '#9B7BFF',
  S = '#D3E2F4', s = '#F2F7FF', T = '#8A9DBA',
}
local LIT = { B = 'x', D = 'y', E = 'z', X = 'w' }

-- arco ogival: meia largura a, raio R dos dois arcos, a linha de nascença em v0 e o pé em v1
local function ogive(u, v, cx, v0, v1, a, r)
  if v > v1 then return false end
  if v >= v0 then return abs(u - cx) <= a end
  return sqrt((u - (cx - a + r)) ^ 2 + (v - v0) ^ 2) <= r and sqrt((u - (cx + a - r)) ^ 2 + (v - v0) ^ 2) <= r
end

local function draw(P, g, k)
  -- o montinho da toca, com a boca escura
  P:ell(18.5, 32.4, 11.5, 1.6, '$')
  P:ell(18, 31.6, 6, 1.4, '$')
  P:ell(25.6, 32.3, 2.6, 0.9, 'V', '$')
  P:ell(25.6, 32.5, 1.6, 0.55, 'B', 'V')
  P:poly({ { 12.6, 21 }, { 9.4, 26.4 }, { 13.4, 25.4 } }, '@')                     -- o rabo curto
  P:limb({ { 15.8, 24 }, { 15.2, 30.6 } }, 0.8, 0.6, '^')                          -- as pernas compridas
  P:limb({ { 20.2, 24 }, { 20.8, 30.6 } }, 0.8, 0.6, '^')
  P:limb({ { 14.4, 30.8 }, { 17, 30.8 } }, 0.5, 0.5, '^'); P:limb({ { 20, 30.8 }, { 22.6, 30.8 } }, 0.5, 0.5, '^')
  P:ell(17.6, 19.6, 5.6, 6.2, '!')                                                -- o corpo
  P:ell(13.6, 20, 2.8, 5.4, '@', '!')                                             -- a asa fechada
  P:ell(18.6, 9.8, 6.6, 5.6, '!')                                                 -- a cabeça, larga e chata
  P:poly({ { 18.2, 14.8 }, { 20.2, 14.8 }, { 19.2, 16.8 } }, 'f')                 -- a ponta do bico
  -- o nicho em arco ogival: moldura, vão escuro, toco de vela e chama (a única luz do rosto)
  P:fill(14, 4, 24, 15, nil, '!', function(u, v) return ogive(u, v, 19, 10.8, 14.6, 4.0, 6.4) and '#' end)
  P:fill(14, 4, 24, 15, nil, nil, function(u, v) if ogive(u, v, 19, 10.8, 13.9, 3.0, 5.4) then return 'V' end end)
  P:poly({ { 18, 12 }, { 20.2, 12 }, { 20.2, 13.9 }, { 18, 13.9 } }, '&', 'V')
  P:poly({ { 18, 12 }, { 20.2, 12 }, { 20.2, 13 }, { 18, 13 } }, 'B', '&')
  P:ell(19.1, 9.6, 1.3, 2.8, 'D', 'V')
  P:ell(19.1, 10.2, 0.6, 1.2, 'E', 'D')
  P:ell(19.1, 7, 0.5, 0.5, 'E', 'D')
  if k > 1 then P:limb({ { 19.1, 12.2 }, { 19.1, 11.7 } }, 0.2, 0.2, 'V', 'DE') end   -- o pavio
  -- a cera que escorre
  P:limb({ { 18, 14.4 }, { 17.4, 19.6 } }, 0.6, 0.5, '&', '!#')
  P:limb({ { 20.2, 14.6 }, { 20.8, 17.6 } }, 0.5, 0.5, '&', '!#')
  R.seam(P, { 20.8, 19.6 }, { 21.8, 23 }, '!')
  R.seam(P, { 12.8, 17.4 }, { 13.2, 21 }, '@')
  R.shade(g, '!', 'dcba', { tex = 'feather', amp = 0.6 })
  R.shade(g, '@', 'cba', { tex = 'feather', amp = 0.6, seed = 3 })
  R.shade(g, '#', '3e2', { amp = 0.4 })
  R.shade(g, '&', '321', { amp = 0.4 })
  R.shade(g, '^', 'lf')
  R.shade(g, '$', 'u5t', { tex = 'stone', seed = 4 })
  if k > 1 then P:ell(20.9, 15, 0.35, 0.5, '3', '!#') end                          -- a gota de cera no parapeito
  -- as pintas claras do peito e as sobrancelhas brancas
  P:fill(13, 15, 24, 26, nil, 'cd', function(u, v, x, y) if R.hash(x // 2, y, 5) % 9 == 0 then return 'e' end end)
  P:limb({ { 13.6, 7.4 }, { 15.4, 6.2 } }, 0.5, 0.5, 'e', 'abcd'); P:limb({ { 22.8, 6.2 }, { 24, 7.4 } }, 0.5, 0.5, 'e', 'abcd')
end

R.build {
  name = 'vigilwick', LEG = LEG, LIT = LIT, LOOSE = 'SsT', draw = draw,
  sparks = { { 7, 9, 'S' }, { 29, 7, 'T' }, { 28, 19, 's' }, { 6, 22, 'T' }, { 30, 27, 'S' }, { 10, 3, 's' }, { 28.6, 30, 'T' } },
}
