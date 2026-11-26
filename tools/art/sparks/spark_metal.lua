-- Filing Mote (Fagulha da família Rust, arte final): um caco de grade de ferro enferrujado que a limalha remontou,
-- com a luz ainda nos vãos (o traço da família: a luz que passa pela grade). Quadros de 12x12 (pairando: sobe 1 px e
-- volta; a luz dos vãos cresce até o pico e a limalha solta gira em volta).
-- A luz é só a do tipo (tools/art/ui/types/palette.lua, Metal: D = d, M = m, L = l), no lugar do azul-aço.
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: limalha solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '..AAAAAAA...', '.AQqqRq43A..', '.AqMRLrM2A..', '.AqRr4321A..', '.ARLrM2D1A..', '.Arr32211A..', '..ArAA2AA...', '..ARA.A.....', '...A........' }
local LIT = { '..AAAAAAA...', '.AQqqRq43A..', '.AqLRLrM2A..', '.AqRr4321A..', '.ARLrL2M1A..', '.Arr32211A..', '..ArAA2AA...', '..ARA.A.....', '...A........' }
local PEAK = { '..AAAAAAA...', '.AQqqRq43A..', '.AqLRLrL2A..', '.AqRr5421A..', '.ARLrL2L1A..', '.Arr32211A..', '..ArAA2AA...', '..ARA.A.....', '...A........' }
-- o caco em top (linha de cima do contorno) e a limalha solta { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_metal: limalha em cima do caco')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', ['1'] = '#2E2B33', ['2'] = '#44404A', ['3'] = '#5E5A66', ['4'] = '#858290', ['5'] = '#AEB0BC',
    r = '#5A3324', R = '#874A2E', q = '#B06A3C', Q = '#D09458',
    l = '#2C2D36', j = '#272830', d = '#22232B', L = '#CCD6E2', M = '#93A1B3', D = '#566274', S = '#93A1B3', s = '#CCD6E2' },
  lit = { L = 'l', M = 'j', D = 'd' },
  loose = 'Ss',
  frames = {
    frame(REST, 2, { { 1, 7, 's' }, { 2, 1, 'S' }, { 4, 10, 'S' }, { 9, 9, 's' }, { 11, 8, 'S' } }),
    frame(LIT, 1, { { 0, 8, 's' }, { 3, 11, 'S' }, { 10, 9, 's' }, { 11, 2, 'S' }, { 2, 0, 'S' } }),
    frame(PEAK, 1, { { 0, 9, 'S' }, { 4, 11, 's' }, { 10, 10, 'S' }, { 11, 3, 's' }, { 3, 0, 's' }, { 10, 6, 'S' } }),
    frame(LIT, 2, { { 1, 10, 'S' }, { 5, 11, 's' }, { 11, 9, 'S' }, { 4, 0, 'S' }, { 0, 4, 's' } }),
  },
}
