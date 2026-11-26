-- Drip Mote (Fagulha da família Rill, arte final): uma gota que cai de uma lasca de pele de cururu, ainda refletindo
-- o céu (o traço da família: o espelho d'água). Quadros de 12x12 (a gota enche, pesa e desce 1 px; no pico o céu
-- toma a gota inteira; pingos soltos caem embaixo).
-- A luz é só a do tipo (tools/art/ui/types/palette.lua, Água: B = d, D = m, E = l). A pele é matéria (corpo).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: pingo solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '....AA......', '...AdcA.....', '..AecbaA....', '..AuEErA....', '.ADEEEDBA...', '.AEDEDBDA...', '.AqBDBDrA...', '..ABDBBA....', '...AAAA.....' }
local LIT = { '....AA......', '...AdcA.....', '..AecbaA....', '..AuEErA....', '.AEEEEDBA...', '.AEEDEDDA...', '.ADBDEDBA...', '..ADDBDA....', '...AAAA.....' }
local PEAK = { '....AA......', '...AdcA.....', '..AecbaA....', '..AEEEDA....', '.AEEEEEDA...', '.AEEEEDDA...', '.ADEDEDBA...', '..ADEDBA....', '...AAAA.....' }
-- a gota em top (linha de cima do contorno) e os pingos soltos { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_water: pingo em cima da gota')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', a = '#2E2A22', b = '#453E30', c = '#5F553F', d = '#7D7052', e = '#9A8C68',
    r = '#1B2638', q = '#243449', u = '#30455E', B = '#2A62B8', D = '#4A9CFF', E = '#A4D0FF',
    T = '#2A62B8', S = '#4A9CFF', s = '#A4D0FF' },
  lit = { B = 'r', D = 'q', E = 'u' },
  loose = 'TSs',
  frames = {
    frame(REST, 1, { { 10, 9, 's' }, { 11, 5, 'S' } }),
    frame(LIT, 1, { { 11, 9, 'S' }, { 10, 5, 's' }, { 11, 5, 'T' } }),
    frame(PEAK, 2, { { 0, 9, 's' }, { 11, 9, 'T' } }),
    frame(LIT, 2, { { 1, 9, 's' }, { 0, 9, 'S' }, { 11, 4, 's' } }),
  },
}
