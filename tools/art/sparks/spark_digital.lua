-- Static Mote (Fagulha da família Bit, arte final): uma pena de pombo que se desfaz em pixels pela ponta (o traço da
-- família: o glitch na plumagem, com o magenta de pena de um lado e o pixel aceso do outro). Quadros de 12x12
-- (pairando: sobe 1 px e volta; a ponta acende, se desfaz no pico e os pixels soltos sobem em degraus).
-- A luz é só a do tipo (tools/art/ui/types/palette.lua, Digital: Q = d, P = m, R = l); o magenta N é cor de pena (corpo).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: pixel solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '......AAA...', '.....APdcA..', '....AdNcbdA.', '...AdcbPcdA.', '..AecbQbcA..', '..AdQbcbA...', '.AhcbAAA....', '.AhAA.......', '.AA.........' }
local LIT = { '......AA....', '.....APRA...', '....AdNPbA..', '...AdcbPcdA.', '..AecbPbcA..', '..AdQbcbA...', '.AhcbAAA....', '.AhAA.......', '.AA.........' }
local PEAK = { '......AA....', '.....ARRA...', '....APNRbA..', '...AdcPPcdA.', '..AecbPbcA..', '..AdPbcbA...', '.AhcbAAA....', '.AhAA.......', '.AA.........' }
-- a pena em top (linha de cima do contorno) e os pixels soltos { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_digital: pixel solto em cima da pena')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', b = '#4E5560', c = '#6E7783', d = '#959DA8', e = '#BBC1C8', h = '#C9C4BE', N = '#A45C92',
    o = '#2A3320', k = '#1F2A1A', l = '#454C3A', P = '#A8F040', Q = '#62A01E', R = '#DCFA9E',
    p = '#A8F040', y = '#62A01E', t = '#DCFA9E' },
  lit = { P = 'o', Q = 'k', R = 'l' },
  loose = 'pyt',
  frames = {
    frame(REST, 2, { { 1, 10, 'y' }, { 2, 10, 'p' }, { 10, 7, 't' }, { 10, 9, 'p' } }),
    frame(LIT, 1, { { 0, 10, 'p' }, { 1, 9, 'y' }, { 2, 10, 'p' }, { 10, 7, 't' } }),
    frame(PEAK, 1, { { 0, 9, 't' }, { 0, 11, 'y' }, { 1, 9, 'p' }, { 2, 10, 't' }, { 1, 11, 'p' }, { 10, 8, 'y' } }),
    frame(LIT, 2, { { 0, 9, 'y' }, { 1, 10, 'p' }, { 2, 9, 't' }, { 10, 7, 'p' } }),
  },
}
