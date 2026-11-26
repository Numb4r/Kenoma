-- Gatewarden (rust.ritual, proposta, revisão 4): o besouro-rinoceronte de pé como um mourão, visto pelas costas, no
-- chão (as patas de trás e a ponta do abdômen pisam; sem capitel). Os dois élitros são duas folhas de portão de ferro,
-- com lanças no alto, entreabertas (a da direita mais); no vão escuro entre elas a limalha gira, na luz do tipo Metal.
-- Visto pelas costas não há olho. Cores do _rust.lua.
local R = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/rituais/_ritual.lua')

local LEG = {
  A = '#1A1424',
  ['1'] = '#2E2B33', ['2'] = '#44404A', ['3'] = '#5E5A66', ['4'] = '#858290', ['5'] = '#AEB0BC',   -- ferro
  Q = '#D09458', e = '#B06A3C', E = '#874A2E', r = '#5A3324',                                     -- ferrugem
  G = '#5F7868', g = '#3F5248',                                                                   -- zinabre
  j = '#272830', l = '#2C2D36', d = '#22232B', v = '#4A4658',                                     -- apagados
  M = '#93A1B3', I = '#CCD6E2', D = '#566274', X = '#9B7BFF',
  S = '#93A1B3', s = '#CCD6E2',
}
local LIT = { M = 'j', I = 'l', D = 'd', X = 'v' }

local function draw(P, g, k)
  local function bars(l, r0, r1, c, m) P:limb(l, r0, r1, c, m) end
  -- patas de longe
  bars({ { 25, 26 }, { 27, 30 }, { 26.5, 32.5 } }, 1.0, 0.8, '~')
  bars({ { 18, 27 }, { 18.5, 32.5 } }, 1.0, 0.8, '~')
  bars({ { 12, 27 }, { 11, 32.5 } }, 1.0, 0.8, '~')
  -- folha de longe, com duas lanças para trás
  P:poly({ { 21, 15.5 }, { 8, 11 }, { 4.5, 12 }, { 4, 14.5 }, { 20.5, 17.5 } }, '!')
  bars({ { 4.4, 12.4 }, { 2.4, 12.4 } }, 0.8, 0.4, '!'); bars({ { 4.2, 14 }, { 2.4, 14 } }, 0.8, 0.4, '!')
  -- a fresta: cunha de luz sólida
  P:poly({ { 20.5, 17.5 }, { 4, 14.5 }, { 3.6, 19.5 }, { 20.5, 18.5 } }, 'M')
  bars({ { 20.5, 17.5 }, { 4, 14.5 } }, 0.5, 0.5, 'D', 'M'); bars({ { 20.5, 18.5 }, { 3.6, 19.5 } }, 0.5, 0.5, 'D', 'M')
  bars({ { 19, 18 }, { 4, 17 } }, 0.4, 1.0, 'I', 'M')
  -- folha de perto, três lanças, duas barras
  P:poly({ { 21, 18.5 }, { 3.6, 19.5 }, { 3.4, 26.5 }, { 20.5, 27.5 } }, '$')
  for _, y in ipairs({ 20.8, 23, 25.4 }) do bars({ { 3.6, y }, { 2.2, y } }, 0.8, 0.4, '$') end
  bars({ { 4, 21.6 }, { 19, 21.6 } }, 0.5, 0.5, '&', '$'); bars({ { 4, 24.6 }, { 19, 24.6 } }, 0.5, 0.5, '&', '$')
  P:ell(13, 27, 9, 1.8, '@', '.')
  -- patas de perto
  bars({ { 22, 26.5 }, { 24, 29.5 }, { 23.5, 32.5 } }, 1.1, 0.8, '^')
  bars({ { 15, 27 }, { 15.5, 30 }, { 14.5, 32.5 } }, 1.1, 0.8, '^')
  bars({ { 9, 26.5 }, { 7, 30 }, { 7.5, 32.5 } }, 1.1, 0.8, '^')
  P:ell(24.5, 21.5, 4.4, 5.2, '#')
  P:ell(27.2, 25.5, 2.4, 2.1, '@')
  bars({ { 28.2, 27.6 }, { 31, 28.9 }, { 33, 27.7 } }, 2.0, 0.7, '+')
  bars({ { 27.6, 24.8 }, { 28.6, 24.8 } }, 0.5, 0.5, '1')
  R.seam(P, { 10, 21.6 }, { 11, 25 }, '$&G')
  R.seam(P, { 23, 19 }, { 24, 23 }, '#')
  P:fill(3, 18, 21, 28, nil, '$', function(u, v, x, y) if R.hash(x, y // 2, 4) % 6 == 0 then return 'G' end end)
  P:fill(3, 18, 21, 28, nil, 'G', function(u, v, x, y) if R.hash(x, y, 2) % 2 == 0 then return 'g' end end)
  R.shade(g, '!', 'QeEr', { tex = 'metal', amp = 0.6 })
  R.shade(g, '$', 'eEr1', { tex = 'metal', amp = 0.6, seed = 3 })
  R.shade(g, '&', '543', { amp = 0.4 })
  R.shade(g, '#', '5432', { tex = 'noise' })
  R.shade(g, '@', '543', { tex = 'feather', amp = 0.5 })
  R.shade(g, '+', '54', { tex = 'metal', amp = 0.4 })
  R.shade(g, '^', '43', { tex = 'metal' })
  R.shade(g, '~', '32', { tex = 'metal' })
  if k > 1 then
    P:fill(20, 16.5, 28.5, 26.5, nil, '2345', function(u, v, x, y) local h = R.hash(x, y, 6) % 14; if h == 0 then return 'Q' elseif h == 1 then return 'e' end end)
    for _, q in ipairs({ { 7, 21.6 }, { 11, 21.6 }, { 15, 21.6 }, { 7, 24.6 }, { 11, 24.6 }, { 15, 24.6 } }) do P:ell(q[1], q[2], 0.35, 0.35, '1', '&') end
    for _, u in ipairs({ 8, 16 }) do bars({ { u, 19.4 }, { u, 27 } }, 0.2, 0.2, '&', '$') end
    for _, y in ipairs({ 29, 31 }) do for _, u in ipairs({ 23.6, 15.2, 7.4 }) do bars({ { u - 0.7, y }, { u + 0.7, y } }, 0.15, 0.15, '2', '^') end end
    for i = 0, 2 do bars({ { 29.6 + i * 1.2, 27.4 + i * 0.2 }, { 29.8 + i * 1.2, 29.6 } }, 0.15, 0.15, '2', '+') end
  end
end

R.build {
  name = 'gatewarden', LEG = LEG, LIT = LIT, LOOSE = 'Ss', draw = draw,
  sparks = { { 26, 12, 'S' }, { 31, 16, 's' }, { 13, 6, 'S' }, { 2, 8, 's' }, { 33, 21, 's' }, { 1.6, 23, 'S' } },
}
