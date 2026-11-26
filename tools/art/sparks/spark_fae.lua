-- Pollen Mote (Fagulha da família Sprig, arte final): uma sâmara de tipuana cuja semente é um grão de pólen aceso;
-- a asa da sâmara é a folha seca com a nervura central acesa (o traço da família: a asa de folha). Quadros de 12x12
-- (pairando: sobe 1 px e volta; a semente acende até o pico, a nervura acende junto e o pólen solto sobe).
-- A luz é só a do tipo (tools/art/ui/types/palette.lua, Feérico: O = d, W = m, L = l).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: pólen solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '..AAAA......', '.AaaObA.....', '.AbacOcA....', '..AcbaOcAA..', '...AcbWLLWA.', '....AAWLLWA.', '......AWWA..', '.......AA...' }
local LIT = { '..AAAA......', '.AaaObA.....', '.AbacOcA....', '..AcbaWcAA..', '...AcbLLLWA.', '....AALLLWA.', '......AWWA..', '.......AA...' }
local PEAK = { '..AAAA......', '.AaaWbA.....', '.AbacWcA....', '..AcbaWcAA..', '...AcbLLLLA.', '....AALLLLA.', '......ALLA..', '.......AA...' }
-- a sâmara em top (linha de cima do contorno) e o pólen solto { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_fae: pólen em cima da sâmara')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', a = '#D9B46C', b = '#B5853F', c = '#8C5A2B',
    e = '#4A2C38', h = '#6A4A58', g = '#3E2632', W = '#FFA8E0', L = '#FFD6F1', O = '#C0669E', S = '#FFA8E0', s = '#FFD6F1' },
  lit = { W = 'e', L = 'h', O = 'g' },
  loose = 'Ss',
  frames = {
    frame(REST, 2, { { 0, 8, 'S' }, { 11, 2, 's' }, { 1, 11, 'S' } }),
    frame(LIT, 1, { { 0, 9, 's' }, { 10, 2, 'S' }, { 11, 8, 's' }, { 9, 11, 'S' } }),
    frame(PEAK, 1, { { 0, 7, 'S' }, { 10, 4, 'S' }, { 11, 9, 's' }, { 9, 11, 's' }, { 10, 0, 's' }, { 0, 11, 'S' } }),
    frame(LIT, 2, { { 0, 7, 'S' }, { 11, 5, 'S' }, { 1, 11, 's' } }),
  },
}
