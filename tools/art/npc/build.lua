-- Os Outros Veilbreakers (0.25.0): 3 quadros de 24x24 (parado, passo A, passo B), olhando para a direita.
-- Cada figura é cabeça (8 linhas) + tronco (8) + pernas (5; 6 no passo B, que sobe 1 px). O contorno sai por fora.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local DIR = L.ROOT .. 'npc/'
local BLANK = string.rep('.', 24)

local SKIN = { f = '#E0A878', g = '#B07A58', e = '#2B2540', s = '#2B2540', K = '#1A1424' }
local function legend(t)
  for k, v in pairs(SKIN) do if t[k] == nil then t[k] = v end end
  return t
end

-- Pernas de calça: parado, passada aberta, passagem (uma perna erguida). [top]: a linha do quadril ou da barra do casaco.
local function legs(top)
  top = top or '.......qqqpppp..........'
  return {
    { top, '.......qqq.ppp..........', '.......qqq.ppp..........', '.......qqq.ppp..........', '.......sss.ssss.........' },
    { top, '......qqq..ppp..........', '.....qqq....ppp.........', '....qqq.....ppp.........', '...sss......ssss........' },
    { top, '........qqppp...........', '........pppqq...........', '........ppp.qq..........', '........ppp.ss..........',
      '........ssss............' },
  }
end

local function person(name, d)
  local function mk(lead, legset, tag)
    local rows = {}
    for _ = 1, lead do rows[#rows + 1] = BLANK end
    for _, r in ipairs(d.head) do rows[#rows + 1] = r end
    for _, r in ipairs(d.torso) do rows[#rows + 1] = r end
    for _, r in ipairs(legset) do rows[#rows + 1] = r end
    rows[#rows + 1] = BLANK
    local g = L.frame(rows, 24, 24, name .. ' ' .. tag)
    L.outline(g, 'K')
    return g
  end
  local sheet = L.sheet { mk(2, d.legs[1], 'parado'), mk(2, d.legs[2], 'A'), mk(1, d.legs[3], 'B') }
  L.save(DIR .. name, legend(d.legend), { { name = 'Layer 1', grid = sheet, png = DIR .. name .. '.png' } })
end

-- Capuz petróleo, visor ciano, LED no peito, antena na mochila.
person('npc_technomancer_0', {
  legend = { T = '#4A6278', t = '#33465A', u = '#24303F', v = '#1F2733', c = '#5FD3C6', w = '#CFF7F1', p = '#3A3F52', q = '#2A2D3C' },
  head = {
    '.........TTtt...........',
    '...c...TTTttttu.........',
    '...K..TTtttttttu........',
    '...K..Tttuuuuuuu........',
    '...K..Tttucwcccc........',
    '...K..Tttugfffff........',
    '...K..ttuugffffg........',
    '...K...tuuuggfu.........',
  },
  torso = {
    '...K...TTttttuu.........',
    '...vvvTTttcttutt........',
    '...vvvTtttcttutt........',
    '...vvvTttttttutt........',
    '...vvvTtttcttutt........',
    '....vvTtttcttutu........',
    '......Tttttttuff........',
    '.......utttttuu.........',
  },
  legs = legs(),
})

-- Cabelo escuro, fone ciano, moletom cinza com faixa, celular aceso na mão.
person('npc_technomancer_1', {
  legend = { h = '#2A2233', H = '#3F3450', c = '#5FD3C6', w = '#CFF7F1', J = '#AAB4C4', j = '#8A94A6', k = '#636C80', p = '#33465A', q = '#24303F' },
  head = {
    '.........Hchhh..........',
    '........HHchhhhh........',
    '.......Hhhchhhhh........',
    '.......hhhchffff........',
    '.......hhcwcfeff........',
    '.......hhcccfefff.......',
    '........hgcfffff........',
    '..........ggfff.........',
  },
  torso = {
    '......JJJjjgjjk.........',
    '......JjcjjjjkJj........',
    '......Jjcjjjjkjj........',
    '......Jjcjjjjkjj........',
    '......Jjcjjjjkjj........',
    '......Jjcjjjjkjkww......',
    '......jjcjjjjkffcw......',
    '.......kjjjjjkk.........',
  },
  legs = legs(),
})

-- Chapéu de palha com fita brasa, poncho com risca e barra brasa.
person('npc_shaman_0', {
  legend = { A = '#E0C388', a = '#C9A56A', b = '#94763F', d = '#3A2A2A', O = '#FF7A45', o = '#C2552B', M = '#8A6248', m = '#6B4A3A', n = '#4A3228', p = '#4A4458', q = '#353044' },
  head = {
    '.........Aaaa...........',
    '........AAaaab..........',
    '........oOOOOo..........',
    '...AAAaaaaaaaaaabbbb....',
    '.......dddgggggg........',
    '.......ddgfffeff........',
    '.......ddgfffefff.......',
    '..........ggfff.........',
  },
  torso = {
    '........MmmOmmn.........',
    '.......MMmmOmmmn........',
    '......MMmmmOmmmmn.......',
    '.....MMmmmmOmmmmmn......',
    '....MMmmmmmOmmmmmmn.....',
    '...MMmmmmmmOmmmmmmmn....',
    '...OoOoOoOoOoOoOoOoO....',
    '........nmmmmmn.........',
  },
  legs = legs(),
})

-- Cabelo comprido, manto verde até o chão, lenço brasa.
local cloakTop = { '...GGvvvvvvvvvvvwww.....', '...Gvvvvvwvvvwvvwww.....' }
person('npc_shaman_1', {
  legend = { h = '#5A3A2A', H = '#7A5238', O = '#FF7A45', o = '#C2552B', G = '#66755A', v = '#4C5A40', w = '#36402E', x = '#283022' },
  head = {
    '.........Hhhhh..........',
    '.......HHhhhhhhh........',
    '......HHhhhhhhhh........',
    '......Hhhhhhffff........',
    '......Hhhhfffeff........',
    '......Hhhhgffefff.......',
    '......Hhhhgfffff........',
    '......hhhhhggff.........',
  },
  torso = {
    '.....hhhOOOOOOO.........',
    '.....hhGvvvOOvvw........',
    '.....hhGvvvOovvww.......',
    '.....hGGvvvvovvvw.......',
    '.....GGvvvvvvvvww.......',
    '....GGvvvvvvvfvvww......',
    '....Gvvvvvvvvvvvww......',
    '....Gvvvvvvvvvvvwww.....',
  },
  legs = {
    { cloakTop[1], cloakTop[2], '..GGvvvvvwvvvwvvwwww....', '..Gvvvvvvwvvvwvvvwww....', '..xwwwwwwwwwwwwwwwwx....' },
    { cloakTop[1], cloakTop[2], '.GGvvvvvvwvvvwvvwwww....', '.Gvvvvvvvwvvvwvvvwww....', '.xwwwwwwwwwwwwwwwxsss...' },
    { cloakTop[1], cloakTop[2], '...Gvvvvvwvvvwvvwww.....', '...GGvvvvwvvvwvvvwww....', '...Gvvvvvwvvvwvvvwww....',
      '...xwwwwwwwwwwwwwwwx....' },
  },
})

-- Túnica creme de capuz pontudo, selos violeta descendo pelo meio e na barra.
local robeTop = { '...AAbbbbbVbbbbbccc.....', '...Abbbbbbbbbbbbccc.....' }
person('npc_sealer_0', {
  legend = { A = '#EFEADB', b = '#D8D2C0', c = '#A8A290', d = '#6B6480', V = '#9B7BFF' },
  head = {
    '..........AAb...........',
    '.........AAbbc..........',
    '........AAbbbbc.........',
    '.......AAbbddddc........',
    '.......Abbdffefc........',
    '.......Abbdgfefc........',
    '.......Abbbdgffc........',
    '.......Abbbbddcc........',
  },
  torso = {
    '......AAbbVbbbcc........',
    '......AbbbbbbcAbc.......',
    '......AbbbVbbcAbc.......',
    '.....AAbbbbbbcAbbc......',
    '.....AbbbbVbbccffc......',
    '.....Abbbbbbbbcccc......',
    '....AAbbbbVbbbbccc......',
    '....Abbbbbbbbbbbccc.....',
  },
  legs = {
    { robeTop[1], robeTop[2], '..AAbbbbbbVbbbbbcccc....', '..Abbbbbbbbbbbbbbccc....', '..cVcVcVcVcVcVcVcVcc....' },
    { robeTop[1], robeTop[2], '.AAbbbbbbbVbbbbbcccc....', '.Abbbbbbbbbbbbbbbccc....', '.cVcVcVcVcVcVcVcVccsss..' },
    { robeTop[1], robeTop[2], '...AAbbbbbVbbbbbccc.....', '...Abbbbbbbbbbbbbccc....', '...AbbbbbbVbbbbbbccc....',
      '...cVcVcVcVcVcVcVccc....' },
  },
})

-- Cabelo grisalho de coque, casaco marinho comprido, estola violeta, rolo de selos nas costas.
person('npc_sealer_1', {
  legend = { h = '#B8B4C8', H = '#D4D0E0', i = '#8C88A0', V = '#9B7BFF', v = '#6F55C4', N = '#38496A', n = '#26324A', m = '#1C2436', r = '#D8D2C0', R = '#A8A290', p = '#33384C', q = '#24283A' },
  head = {
    '.........HHhh...........',
    '.......HHHhhhhh.........',
    '.....hiHHhhhhhhh........',
    '.....hiHhhhhffff........',
    '.......hhhfffeff........',
    '.......iihgffefff.......',
    '........igffffff........',
    '..........ggfff.........',
  },
  torso = {
    '...rR..NNnVVnnm.........',
    '...rrRNNnnVvnmNn........',
    '....rRNnnnVvnmnn........',
    '....rRNnnnVvnmnn........',
    '.....rNnnnVvnmnn........',
    '.....RNnnnVvnmnm........',
    '......NnnnVvnmff........',
    '......Nnnnvvnnmm........',
  },
  legs = legs('......mnnnnnnmmm........'),
})

-- Sem escola: cabelo ruivo, jaqueta cinza, mochila ameixa.
person('npc_none_0', {
  legend = { h = '#8A5A5A', H = '#A87272', d = '#3A2A2A', J = '#767A8A', j = '#5B5F6E', k = '#40434F', b = '#3A3040', B = '#544660', p = '#3D4A5E', q = '#2C3646' },
  head = {
    '.........Hhhhh..........',
    '........HHhhhhhh........',
    '.......HHhhhhhhh........',
    '.......Hhhhhffff........',
    '.......hhhfffeff........',
    '.......ddhgffefff.......',
    '.......ddgffffff........',
    '..........ggfff.........',
  },
  torso = {
    '.......JJjjgjjk.........',
    '....BbJJjjjjjkJj........',
    '....BbJjjjjjjkjj........',
    '....bbJjjjjjjkjj........',
    '....bbJjjjjjjkjj........',
    '....bbJjjjjjjkjk........',
    '.....bJjjjjjjkff........',
    '.......kjjjjjkk.........',
  },
  legs = legs(),
})

-- Sem escola: cabelo loiro, casaco marrom comprido, cachecol claro com a ponta solta para trás.
person('npc_none_1', {
  legend = { h = '#B89A6A', H = '#D4B888', c = '#B8B0A0', C = '#948C7E', J = '#86746A', j = '#6A5A50', k = '#4A3E38', p = '#40434F', q = '#2E3038' },
  head = {
    '.........HHhh...........',
    '.......HHHhhhhh.........',
    '.......HHhhhhhhh........',
    '.......Hhhhfffff........',
    '.......hhhfffeff........',
    '.......hhgfffefff.......',
    '........hgffffff........',
    '..........ggfff.........',
  },
  torso = {
    '......ccccccccc.........',
    '...CccJJjjjjjkJj........',
    '...Cc.JjjjjjjkJj........',
    '......Jjjjjjjkjj........',
    '......Jjjjjjjkjj........',
    '......Jjjjjjjkjk........',
    '......Jjjjjjjkff........',
    '......Jjjjjjjjkk........',
  },
  legs = legs('......kjjjjjjkkk........'),
})

-- A sintonia do NPC: o anel fechando no Eco, centrado no quadro (centro entre os pixels 11 e 12).
do
  local frames = {}
  local function ghost(g, r, c)
    local t = L.grid(24, 24)
    L.ring(t, 11.5, 11.5, r, 'x')
    for y = 0, 23 do for x = 0, 23 do
      if t[y][x] == 'x' and (x + y) % 3 == 0 then g[y][x] = c end
    end end
  end
  local function ticks(g, r, c)
    local n = math.floor(r)
    for k = 2, 3 do
      for s = 11, 12 do
        L.set(g, s, 11 - n - k, c); L.set(g, s, 12 + n + k, c)
        L.set(g, 11 - n - k, s, c); L.set(g, 12 + n + k, s, c)
      end
    end
  end
  local g1 = L.grid(24, 24)
  L.ring(g1, 11.5, 11.5, 10.6, 'D')
  for _, p in ipairs({ { 11, 1 }, { 12, 1 }, { 11, 22 }, { 12, 22 }, { 1, 11 }, { 1, 12 }, { 22, 11 }, { 22, 12 } }) do g1[p[2]][p[1]] = 'C' end
  local g2 = L.grid(24, 24)
  ghost(g2, 10.6, 'd'); L.ring(g2, 11.5, 11.5, 7.6, 'C'); ticks(g2, 7.6, 'd')
  local g3 = L.grid(24, 24)
  ghost(g3, 7.6, 'd'); L.ring(g3, 11.5, 11.5, 4.6, 'C'); ticks(g3, 4.6, 'c')
  local g4 = L.grid(24, 24)
  ghost(g4, 4.6, 'c')
  L.put(g4, 8, 8, {
    '...CC...',
    '...CC...',
    '........',
    'CC.WW.CC',
    'CC.WW.CC',
    '........',
    '...CC...',
    '...CC...',
  })
  frames = { g1, g2, g3, g4 }
  L.save(DIR .. 'fx_npc_tune', { D = '#2E8F86', d = '#2E8F8670', C = '#5FD3C6', c = '#5FD3C670', W = '#CFF7F1' },
    { { name = 'Layer 1', grid = L.sheet(frames), png = DIR .. 'fx_npc_tune.png' } })
end
