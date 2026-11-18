-- Ônibus Espectral (48x18, visto de cima, frente à direita, a traseira se desfazendo) e o passageiro (2 quadros de 24x24).
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local DIR = L.ROOT .. 'bus/'
local LEG = {
  A = '#1A1424C0', B = '#B4C0E450', C = '#B4C0E490', D = '#DFE6FAB0', E = '#2B2540A0', F = '#CFF7F1', G = '#7F8CC0A0',
}

do
  local g = L.grid(48, 18)
  L.rect(g, 14, 1, 45, 16, 'D')
  for _, p in ipairs({ { 14, 1 }, { 45, 1 }, { 14, 16 }, { 45, 16 } }) do g[p[2]][p[1]] = '.' end
  L.rect(g, 15, 1, 44, 1, 'A'); L.rect(g, 15, 16, 44, 16, 'A')
  L.rect(g, 14, 2, 14, 15, 'A'); L.rect(g, 45, 2, 45, 15, 'A')
  -- As janelas dos dois lados, vistas na beira do teto.
  for x = 16, 38 do
    if (x - 16) % 4 < 3 then g[2][x] = 'E'; g[15][x] = 'E' end
  end
  L.rect(g, 16, 3, 39, 3, 'C'); L.rect(g, 16, 14, 39, 14, 'C')  -- calha do teto
  for _, x in ipairs({ 16, 27, 38 }) do L.rect(g, x, 4, x, 13, 'C') end  -- emendas das chapas
  for _, x in ipairs({ 19, 30 }) do  -- alçapões
    L.rect(g, x, 6, x + 5, 11, 'G'); L.rect(g, x + 1, 7, x + 4, 10, 'E'); g[7][x + 1] = 'D'
  end
  L.rect(g, 41, 3, 43, 14, 'E'); g[4][42] = 'D'; g[5][41] = 'D'  -- para-brisa
  L.rect(g, 44, 6, 44, 11, 'F')                                  -- letreiro
  for _, y in ipairs({ 3, 4, 13, 14 }) do g[y][45] = 'F' end       -- faróis
  L.rect(g, 41, 0, 42, 0, 'A'); L.rect(g, 41, 17, 42, 17, 'A')   -- retrovisores
  -- A traseira se desfaz em três faixas, cada vez mais rala.
  for y = 1, 16 do
    for x = 2, 13 do
      local edge = y == 1 or y == 16
      if x >= 9 then
        if (x + y) % 2 == 0 then g[y][x] = edge and 'A' or 'C' end
      elseif x >= 5 then
        if not edge and x % 2 == 0 and y % 2 == 0 and (x // 2 + y // 2) % 2 == 0 then g[y][x] = 'C' end
      elseif not edge and x % 2 == 0 and y % 4 == x % 4 then
        g[y][x] = 'B'
      end
    end
  end
  L.save(DIR .. 'bus_spectral', LEG, { { name = 'Layer 1', grid = g, png = DIR .. 'bus_spectral.png' } })
end

do
  local BLANK = string.rep('.', 24)
  local whole = L.frame({
    BLANK, BLANK, BLANK,
    '.........BBBBBB.........',
    '........BBBBBBBB........',
    '........BBBBBEBE........',
    '........BBBBBEBE........',
    '........CBBBBBBB........',
    '.........CCBBBB.........',
    '.......BBBBBBBBBB.......',
    '......BBBBBBBBBBCC......',
    '......BCBBBBBBBCBC......',
    '......BCBBBBBBBCBC......',
    '......BCBBBBBBBCBC......',
    '......CCBBBBBBBCCC......',
    '.......CBBBBBBBCC.......',
    '.......CBBBBBBCCC.......',
    '.......CCBBBBBCCb.......',
    '........CCBBBCCb........',
    '........bCCBCCb.........',
    '.........bCCCb..........',
    '..........bCb...........',
    '...........b............',
    BLANK,
  }, 24, 24, 'passageiro')
  -- Quadro 2: a metade de trás vira poeira, subindo e ficando para trás.
  local gone = L.grid(24, 24)
  for y = 0, 23 do
    for x = 0, 23 do
      local c = whole[y][x]
      if c ~= '.' then
        if x >= 12 then gone[y][x] = c
        elseif x >= 10 then if (x + y) % 2 == 0 then gone[y][x] = 'C' end
        elseif (x + y) % 2 == 0 and y % 4 < 2 then L.set(gone, x - (11 - x) // 2, y - (11 - x) // 2, 'b') end
      end
    end
  end
  L.outline(whole, 'A', 'BCE')
  L.outline(gone, 'A', 'BE')
  local leg = { A = LEG.A, B = LEG.D, C = LEG.C, E = LEG.E, b = LEG.B }
  L.save(DIR .. 'spectral_passenger', leg, { { name = 'Layer 1', grid = L.sheet { whole, gone }, png = DIR .. 'spectral_passenger.png' } })
end
