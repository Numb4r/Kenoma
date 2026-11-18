-- Kenoma 0.26.0: ícones dos apps do celular (apps/), o app bloqueado (tira de 3 quadros) e as fases da lua (moon/),
-- mais a folha apps/out/folha.png (1x, 2x, 3x e cinza, fundo #1e1830). Fonte única: as linhas de pixels deste arquivo.
-- Rodar: aseprite -b --script tools/art/ui/apps/build.lua
-- Regras: docs/art/estilo-ui.md ("Ícone de 16 px"). Os ajudantes são os de ../build_ui.lua, copiados (aquele arquivo
-- regera a Bolsa inteira quando roda, por isso não é incluído daqui).
local BASE = '/home/yuri/Documentos/kenoma/tools/art/ui/'
local APPS, MOON = BASE .. 'apps/', BASE .. 'moon/'
app.fs.makeAllDirectories(APPS .. 'out')
app.fs.makeAllDirectories(MOON)
local pc = app.pixelColor
local problems = {}

local function hex(h)
  return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

-- A paleta dos ícones da Bolsa (material_sprites.dart) mais o sinal claro e escuro e a sombra da lua.
local PAL = {
  O = '1a1424',
  a = 'f4f0e2', b = 'd8d2c0', c = 'a8a090', -- papel, giz
  k = 'f0faff', l = 'b4dcf2', m = '7aa8d4', -- nuvem
  y = 'f2d15a', Y = 'b8922e', -- ouro
  w = '5aa0e6', x = '3a6eb8', -- água
  s = 'a8a4b4', u = '7c788c', v = '56526a', -- pedra
  A = 'b4c0c8', B = '7e8a94', C = '56606c', -- metal
  R = 'a8553d', Q = 'c8754f', -- cobre
  D = 'e6c48e', E = 'c89a62', F = '9a6a3e', G = '6a4628', -- madeira, couro
  H = 'ff8a8a', I = 'd8324a', J = '8e1c36', -- carmesim
  W = 'fdfbff',
  V = '9b7bff', U = 'c9b8ff', T = '5a4a9e', -- Véu
  S = '5fd3c6', ['1'] = 'a5efe6', ['2'] = '2e8f86', ['3'] = '2f5f66', -- sinal
  M = '6c668a', N = '4a4560', X = '2b2540', -- escuro
  P = 'fff3b0', ['5'] = 'd8c486', -- luz de lua e a sombra dela
  t = 'c9963a', -- cordão
}

local function grid(rows, map, name)
  local w = #rows[1]
  local s = { w = w, h = #rows, px = {} }
  for y, row in ipairs(rows) do
    if #row ~= w then problems[#problems + 1] = (name or '?') .. ': linha ' .. y .. ' com ' .. #row .. ' px, esperado ' .. w end
    for x = 1, math.min(#row, w) do
      local ch = row:sub(x, x)
      if ch ~= '.' then
        local k = map and map[ch] or ch
        local h = #k >= 6 and k or PAL[k]
        if not h then problems[#problems + 1] = (name or '?') .. ': sem cor para ' .. ch else s.px[(y - 1) * w + (x - 1)] = hex(h) end
      end
    end
  end
  return s
end
local function over(s, ox, oy, rows, map)
  local o = grid(rows, map)
  for i, c in pairs(o.px) do s.px[(oy + i // o.w) * s.w + ox + i % o.w] = c end
  return s
end
local function blank(w, h)
  local r = {}
  for i = 1, h do r[i] = string.rep('.', w) end
  return grid(r)
end
local function centered(s, side)
  local d = { w = side, h = side, px = {} }
  local ox, oy = (side - s.w) // 2, (side - s.h) // 2
  for i, c in pairs(s.px) do d.px[(oy + i // s.w) * side + ox + i % s.w] = c end
  return d
end
local function toImage(s)
  local img = Image(s.w, s.h)
  img:clear()
  for i, c in pairs(s.px) do img:drawPixel(i % s.w, i // s.w, c) end
  return img
end
local function save(s, apath, ppath)
  local spr = Sprite(s.w, s.h)
  spr:newCel(spr.layers[1], 1, toImage(s), Point(0, 0))
  if apath then spr:saveAs(apath) end
  spr:saveCopyAs(ppath)
  spr:close()
end
-- O mesmo que o lint_sprite cobra: uma peça só (diagonal conta) e nenhum pixel sozinho.
local function lint(name, s)
  local seen, parts = {}, 0
  for i in pairs(s.px) do
    if not seen[i] then
      parts = parts + 1
      local stack = { i }
      seen[i] = true
      while #stack > 0 do
        local p = table.remove(stack)
        local x, y = p % s.w, p // s.w
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = x + dx, y + dy
          local q = ny * s.w + nx
          if nx >= 0 and nx < s.w and ny >= 0 and ny < s.h and s.px[q] and not seen[q] then seen[q] = true stack[#stack + 1] = q end
        end end
      end
    end
  end
  if parts ~= 1 then problems[#problems + 1] = name .. ': ' .. parts .. ' peças' end
end

local items = {}
local function add(name, s, dir, pdir)
  if s.w > 13 or s.h > 13 then problems[#problems + 1] = name .. ': desenho maior que 13 px' end
  local c = centered(s, 16)
  lint(name, c)
  items[#items + 1] = { name = name, s = c }
  save(c, dir .. name .. '.aseprite', pdir .. name .. '.png')
end
local function appIcon(name, rows, map) add(name, grid(rows, map, name), APPS, APPS .. 'out/') end

-- ---------------------------------------------------------------- apps
-- Visão espectral: o olho, com a íris no violeta do Véu.
appIcon('vision', {
  '....OOOOO....',
  '..OOaaaaaOO..',
  '.OaaaOOOabbO.',
  'OaabOUVVObbcO',
  'OabbOVOTObccO',
  'OabbOVTTObccO',
  '.ObbbOOObccO.',
  '..OObccccOO..',
  '....OOOOO....',
})
-- Radar: o visor redondo num pé de metal, a varredura no ciano do sinal e um eco embaixo à esquerda.
appIcon('radar', {
  '...OOOO...',
  '.OO2222OO.',
  '.O2XXX3SO.',
  'O2XXX3SX2O',
  'O2XX3SXX2O',
  'O2XXSSXX2O',
  'O2X1XXXX2O',
  '.O21XXX2O.',
  '.OO2222OO.',
  '..OABBCO..',
  '.OAABBCCO.',
  '.OOOOOOOO.',
})
-- Bestiário: o livro fechado, a criatura de orelhas na capa e a fita marcando a página.
appIcon('bestiary', {
  '.OOOOOOOOO.',
  'OUVVVVVVVaO',
  'OVUVVVUVTaO',
  'OVUUUUUVTaO',
  'OVUOUOUVTaO',
  'OVUUUUUVTaO',
  'OVVUUUVVTaO',
  'OTTTTTTTTaO',
  'OaaaaaaaabO',
  '.OOOOOOIIO.',
  '......OIJO.',
  '.......OO..',
})
-- Círculo: o círculo de giz com os três lugares das criaturas (furo de verdade no meio).
do
  local s = over(blank(13, 12), 1, 1, {
    '...OOOOO...',
    '.OOaaaaaOO.',
    '.OaaOOOabO.',
    'OaaO...ObbO',
    'OaO.....ObO',
    'OaO.....ObO',
    'OaO.....ObO',
    'ObbO...OccO',
    '.ObbOOOccO.',
    '.OObccccOO.',
    '...OOOOO...',
  })
  local NODE = { '.OOO.', 'O1SSO', 'OSS2O', '.OOO.' }
  over(s, 4, 0, NODE)
  over(s, 0, 8, NODE)
  over(s, 8, 8, NODE)
  add('circle', s, APPS, APPS .. 'out/')
end
-- Coleção: duas cartas, a da frente com o selo.
appIcon('collection', {
  '...OOOOOOOO',
  '...OsssssuO',
  'OOOOOOOOOuO',
  'OaaaaaabOuO',
  'OaaVVaabOuO',
  'OaVUVVabOuO',
  'OaVVVTabOuO',
  'OaaVTaabOuO',
  'OaaaaabbOuO',
  'OabbbbbbOOO',
  'OOOOOOOOO..',
})
-- Bolsa: a bolsa de couro do Conjurador, de alça, com a aba e a fivela.
appIcon('bag', {
  '....OOOO....',
  '...OFOOFO...',
  '..OFO..OFO..',
  '..OFO..OFO..',
  '.OOOOOOOOOO.',
  'OEEEEEEEEEFO',
  'OEFFFFFFFFGO',
  'OOFFFFFFFFOO',
  'OEOOFyyFOOGO',
  'OEFFOyYOFGGO',
  'OEFFFOOFGGGO',
  'OFFFGGGGGGGO',
  '.OOOOOOOOOO.',
})
-- Bancada: almofariz de pedra e pilão (o frasco cônico é do tônico).
appIcon('bench', {
  '........OO..',
  '.......OaaO.',
  '......OabO..',
  '.....OabO...',
  'OOOOOabOOOOO',
  'OssssOOuuuvO',
  'OsuuuuuuuvvO',
  '.OsuuuuuvvO.',
  '..OuuuuvvO..',
  '..OOuuvvOO..',
  '.OsuuuuuvvO.',
  '.OOOOOOOOOO.',
})
-- Loadout: o pingente no cordão em V, o que se veste.
appIcon('loadout', {
  'OO.........OO',
  'OtO.......OtO',
  '.OtO.....OtO.',
  '..OtO...OtO..',
  '...OtOOOtO...',
  '...OOAAAOO...',
  '..OABBBBBCO..',
  '..OABUVVBCO..',
  '..OABVVTBCO..',
  '..OABVTTBCO..',
  '..OBBBBBCCO..',
  '...OOOOOOO...',
})
-- Rotas: o mapa dobrado em três, o traçado e o alfinete.
appIcon('routes', {
  '.......OOO...',
  '......OHIIO..',
  '......OIIJO..',
  'OOOO..OJOOOO.',
  'OaaaOOOJOaaO.',
  'OaaabbbvaaaO.',
  'OaaabbvbaaaO.',
  'OaaavvbbaaaO.',
  'OaavbbbbaaaO.',
  'OavabbbbaacO.',
  'OOOObbbbOOOO.',
  '....OOOO.....',
})
-- Patrulha do Véu: o escudo com o losango do Véu.
appIcon('patrol', {
  'OOOOOOOOOOO',
  'OAAAAAAAABO',
  'OABBBUBBBCO',
  'OABBUVVBBCO',
  'OABUVVVTBCO',
  'OABBVVTBBCO',
  'OABBBTBBBCO',
  '.OABBBBBCO.',
  '.OBBBBBCCO.',
  '..OBBBCCO..',
  '...OBCCO...',
  '....OCO....',
  '.....O.....',
})
-- Céu: o astro atrás da nuvem.
appIcon('sky', {
  '..OOOO.......',
  '.OPPPPO......',
  'OPPPPPPO.....',
  'OPPPPPOOOO...',
  'OPPPPOkkkkO..',
  'OyPPOkkkkkkO.',
  '.OyOkkkkkkkkO',
  '..OOkkllllllO',
  '..OkllllllmmO',
  '...OOOOOOOOO.',
})
-- Chat: o balão com o rabicho e os três pontos.
appIcon('chat', {
  '.OOOOOOOOOO.',
  'OaaaaaaaaabO',
  'OaaaaaaaaabO',
  'OavvavvavvbO',
  'OavvavvavvbO',
  'OabbbbbbbbcO',
  '.OOabOOOOOO.',
  '..OabO......',
  '..OaO.......',
  '..OO........',
})
-- Fórum: o mural de avisos, de pé, com dois recados.
appIcon('forum', {
  'OOOOOOOOOOOOO',
  'ODDDDDDDDDDEO',
  'ODaaaFFFFFFGO',
  'ODaccFaaaaFGO',
  'ODaaaFaccaFGO',
  'ODaccFabbbFGO',
  'ODabbFFFFFFGO',
  'OEGGGGGGGGGGO',
  'OOOOOOOOOOOOO',
  '..OEO...OFO..',
  '..OEO...OFO..',
  '..OOO...OOO..',
})
-- Perfil: o busto do Conjurador, de capuz, os olhos no ciano do sinal.
appIcon('profile', {
  '...OOOOO...',
  '..OssMMMO..',
  '.OssMMMMNO.',
  '.OsOOOOONO.',
  '.OsOSOSONO.',
  '.OsOOOOONO.',
  '..OMMMMNO..',
  '.OOsMMMNOO.',
  'OssMMMMMNNO',
  'OsMMMMMMNNO',
  'OsMMMMMNNNO',
  'OOOOOOOOOOO',
})
-- Ajustes: a engrenagem de oito dentes, com o furo.
appIcon('settings', {
  '.....OOO.....',
  '..OO.OAO.OO..',
  '.OAAOOAOOABO.',
  '.OAABAABBBBO.',
  '..OABBBBBBO..',
  'OOOABOOOBBOOO',
  'OAAABO.OBBCCO',
  'OOOBBOOOBCOOO',
  '..OBBBBBCCO..',
  '.OBBBBBBCCCO.',
  '.OBCOOBOOCCO.',
  '..OO.OCO.OO..',
  '.....OOO.....',
})
-- Destilar: o alambique de cobre, o bico e a gota.
appIcon('distill', {
  '..OOOO.......',
  '.OQQRROOOOO..',
  '.OQRRRRRRRRO.',
  '..OQROOOOORO.',
  '.OOQROO..ORO.',
  'OQQRRRRO.OGO.',
  'OQRRRRRGO.O..',
  'OQRRRRRGO.O..',
  'ORRRRRGGOOwO.',
  '.ORRGGGO.OwO.',
  '..OOOOO...O..',
})
-- Fusão: dois discos na diagonal (o Véu e o sinal) e o claro onde se juntam.
appIcon('fusion', {
  '..OOOO......',
  '.OUUUUO.....',
  'OUUVVVVO....',
  'OUVVVVVO....',
  'OUVVVVWWOO..',
  'OVVVTWWW11O.',
  '.OTTWWW1SSSO',
  '..OOWWSSSSSO',
  '....OSSSSS2O',
  '....OSSSS22O',
  '.....OS222O.',
  '......OOOO..',
})

-- ---------------------------------------------------------------- app bloqueado
-- A silhueta genérica de app (o botão em relevo, com a tela apagada no meio), com fatias deslocadas a cada quadro e
-- uma fatia no ciano apagado do sinal. Tira de 3 quadros de 16 x 16; nenhuma letra.
local LOCK = { O = '1a1424', H = '6c668a', L = '4a4560', B = '2b2540', D = '120e1a', g = '2e8f86', t = '5fd3c6' }
local TILE = {
  '.OOOOOOOOOO.',
  'OHHHHHHHHHLO',
  'OHLLLLLLLLBO',
  'OHLLLLLLLLBO',
  'OHLLDDDDLLBO',
  'OHLLDDDDLLBO',
  'OHLLDDDDLLBO',
  'OHLLDDDDLLBO',
  'OHLLLLLLLLBO',
  'OHLLLLLLLLBO',
  'OLBBBBBBBBBO',
  '.OOOOOOOOOO.',
}
local function glitch(shift, tint)
  local rows = { string.rep('.', 16), string.rep('.', 16) }
  for y, row in ipairs(TILE) do
    local dx = shift[y] or 0
    if tint[y] then row = row:gsub('L', 'g'):gsub('H', 't') end
    rows[#rows + 1] = string.rep('.', 2 + dx) .. row .. string.rep('.', 2 - dx)
  end
  rows[#rows + 1] = string.rep('.', 16)
  rows[#rows + 1] = string.rep('.', 16)
  return grid(rows, LOCK, 'locked')
end
local lockFrames = {
  glitch({ [3] = 2, [4] = 2, [9] = -1 }, { [9] = true }),
  glitch({ [2] = -2, [6] = 1, [7] = 1, [11] = -2 }, { [6] = true, [7] = true }),
  glitch({ [5] = 1, [9] = -2, [10] = -2 }, { [5] = true }),
}
do
  local spr = Sprite(16, 16)
  local strip = { w = 48, h = 16, px = {} }
  for n, f in ipairs(lockFrames) do
    lint('locked ' .. n, f)
    items[#items + 1] = { name = 'locked_' .. n, s = f }
    if n > 1 then spr:newEmptyFrame() end
    spr:newCel(spr.layers[1], n, toImage(f), Point(0, 0))
    for i, c in pairs(f.px) do strip.px[(i // 16) * 48 + (n - 1) * 16 + i % 16] = c end
  end
  spr:saveAs(APPS .. 'locked.aseprite')
  spr:close()
  save(strip, nil, APPS .. 'out/locked.png')
end

-- ---------------------------------------------------------------- lua
-- Disco de 12 px. FULL é a face acesa (a luz de cima à esquerda, duas crateras); NEW é o disco escuro com o aro.
local FULL = {
  '....OOOO....',
  '..OOWWPPOO..',
  '.OWWPPPPPPO.',
  '.OWPP55PPPO.',
  'OWPPP55PPPPO',
  'OWPPPPPPPP5O',
  'OPPPPPPPPP5O',
  'OPP55PPPP55O',
  '.OP55PPP55O.',
  '.OPPPPP555O.',
  '..OO5555OO..',
  '....OOOO....',
}
local NEW = {
  '....OOOO....',
  '..OOMMMMOO..',
  '.OMMXXXXNNO.',
  '.OMXXXXXXNO.',
  'OMXXXXXXXXNO',
  'OMXXXXXXXXNO',
  'OMXXXXXXXXNO',
  'ONXXXXXXXXNO',
  '.ONXXXXXXNO.',
  '.ONNXXXXNNO.',
  '..OONNNNOO..',
  '....OOOO....',
}
-- lit[i] = quantos pixels acesos na linha i do miolo (10 linhas), contados do lado `side` ('L' ou 'R').
-- Hemisfério sul: a crescente acende pela esquerda, a minguante pela direita.
local function phase(lit, side)
  local rows = { FULL[1] }
  for y = 2, 11 do
    local first, last
    for x = 1, 12 do
      local ch = FULL[y]:sub(x, x)
      if ch ~= 'O' and ch ~= '.' then first = first or x last = x end
    end
    local n, row = lit[y - 1], ''
    for x = 1, 12 do
      local on = x >= first and x <= last and ((side == 'L' and x < first + n) or (side == 'R' and x > last - n))
      local ch = on and FULL[y]:sub(x, x) or NEW[y]:sub(x, x)
      row = row .. (ch == 'M' and 'N' or ch)
    end
    rows[y] = row
  end
  rows[12] = FULL[12]
  return grid(rows)
end
local CRESCENT = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
local QUARTER = { 2, 4, 4, 5, 5, 5, 5, 4, 4, 2 }
local GIBBOUS = { 2, 6, 6, 8, 8, 8, 8, 6, 6, 2 }
local function moon(name, s) add(name, s, MOON, MOON) end
moon('moon_0', grid(NEW))
moon('moon_1', phase(CRESCENT, 'L'))
moon('moon_2', phase(QUARTER, 'L'))
moon('moon_3', phase(GIBBOUS, 'L'))
moon('moon_4', grid(FULL))
moon('moon_5', phase(GIBBOUS, 'R'))
moon('moon_6', phase(QUARTER, 'R'))
moon('moon_7', phase(CRESCENT, 'R'))
-- Lua Carmim: a cheia no carmesim.
moon('moon_crimson', grid(FULL, { W = 'H', P = 'I', ['5'] = 'J' }))
-- Lua Dupla: a cheia e a segunda lua, menor, encostada embaixo à direita.
moon('moon_double', over(over(blank(13, 13), 0, 0, {
  '...OOOO...',
  '.OOWWPPOO.',
  '.OWPPPPPO.',
  'OWPP55PPPO',
  'OWPP55PPPO',
  'OPPPPPPP5O',
  'OPPPPPPP5O',
  '.OPPPPP5O.',
  '.OOP555OO.',
  '...OOOO...',
}), 7, 7, {
  '.OOOO.',
  'OWPPPO',
  'OPPP5O',
  'OPPP5O',
  'OP555O',
  '.OOOO.',
}))

-- ---------------------------------------------------------------- folha
-- Fileiras de 10: cada ícone em 3x, 2x e 1x e, embaixo, em 3x só em cinza.
local PER, CELL, GROUP = 10, 52, 166
local SW, SH = PER * CELL + 4, GROUP * math.ceil(#items / PER) + 4
local sheet = { w = SW, h = SH, px = {} }
local bg = hex('1e1830')
for i = 0, SW * SH - 1 do sheet.px[i] = bg end
local function put(s, ox, oy, scale, grey)
  for i, c in pairs(s.px) do
    if grey then
      local l = math.floor(0.299 * pc.rgbaR(c) + 0.587 * pc.rgbaG(c) + 0.114 * pc.rgbaB(c) + 0.5)
      c = pc.rgba(l, l, l, 255)
    end
    local x, y = ox + (i % s.w) * scale, oy + (i // s.w) * scale
    for dy = 0, scale - 1 do for dx = 0, scale - 1 do sheet.px[(y + dy) * SW + x + dx] = c end end
  end
end
for i, it in ipairs(items) do
  local x, y = 4 + CELL * ((i - 1) % PER), 4 + GROUP * ((i - 1) // PER)
  put(it.s, x, y, 3)
  put(it.s, x, y + 52, 2)
  put(it.s, x, y + 88, 1)
  put(it.s, x, y + 108, 3, true)
end
save(sheet, nil, APPS .. 'out/folha.png')

for i, it in ipairs(items) do io.write(i .. ':' .. it.name .. ' ') end
print('')
print(#items .. ' quadros, folha ' .. SW .. 'x' .. SH)
for _, p in ipairs(problems) do print('PROBLEMA ' .. p) end
