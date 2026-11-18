-- Kenoma 0.26.0: ícones de clima (16 x 16) para a barra do HUD e o app Céu, e a folha out/folha.png
-- (climas e eventos em 1x, 2x e 3x, em cor e em cinza). Fonte única: as linhas de pixels deste arquivo
-- e as de ../event/build.lua, que este arquivo carrega.
-- Rodar: aseprite -b --script tools/art/ui/climate/build.lua
-- Regras do estilo: docs/art/estilo-ui.md ("Ícone de 16 px").
-- As linhas trazem só a cor: o contorno #1a1424 de 1 px é posto em volta por `outline` (fechado, canto com chanfro).
local ROOT = '/home/yuri/Documentos/kenoma/tools/art/ui/'
local pc = app.pixelColor
local problems, icons = {}, {}

local PAL = {
  O = '1a1424',
  a = 'f4f2fa', b = 'c8c6d8', c = '9c98b0', -- nuvem clara, vento, névoa
  d = '9a9cb4', e = '6c6e88', f = '4a4b62', -- nuvem escura
  z = 'fff3b0', y = 'f2d15a', Y = 'c8922e', -- sol, raio, lua
  h = 'ffb36b', i = 'e8622e', -- calor, brasa
  q = 'e6f4ff', w = '5aa0e6', x = '3a6eb8', -- água
  k = 'f0faff', l = 'b4dcf2', m = '7aa8d4', -- gelo
  s = 'f0dca0', t = 'e0c27a', u = 'b08a48', -- areia
  g = 'd4f08a', G = 'a8e36a', j = '6a9e3a', -- ácido
  H = 'ff8a8a', I = 'd8324a', J = '8e1c36', -- carmim
  U = 'c9b8ff', V = '9b7bff', T = '5a4a9e', -- Véu
  n = 'a8a4b4', o = '7c788c', p = '56526a', -- fumaça, prédio
  r = '9a7a5c', R = '6b4a2f', -- fuligem
  K = 'ff9ac8', L = '8ab4ff', W = 'fdfbff', -- prisma
  M = '6c668a', N = '4a4560', -- pano da bandeirola dos eventos
  ['8'] = 'd6d2de', ['9'] = '9c98a8', -- neutro
  S = '5fd3c6', E = '6bd36a', -- sinal, verde da aurora
}

local function hex(h) return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255) end
local OUTLINE = hex(PAL.O)

local function grid(rows, map, name)
  local w = #rows[1]
  local s = { w = w, h = #rows, px = {} }
  for y, row in ipairs(rows) do
    if #row ~= w then problems[#problems + 1] = name .. ': linha ' .. y .. ' com ' .. #row .. ' px, esperado ' .. w end
    for x = 1, math.min(#row, w) do
      local ch = row:sub(x, x)
      if ch ~= '.' then
        local h = PAL[map and map[ch] or ch]
        if not h then problems[#problems + 1] = name .. ': sem cor para ' .. ch else s.px[(y - 1) * w + (x - 1)] = hex(h) end
      end
    end
  end
  return s
end
-- Contorno em todo pixel vazio encostado (4 vizinhos) num pixel de cor, e recorte na caixa do desenho.
local function outline(s)
  local w, h = s.w + 2, s.h + 2
  local px = {}
  for i, c in pairs(s.px) do px[(i // s.w + 1) * w + i % s.w + 1] = c end
  local add = {}
  for i, c in pairs(px) do
    if c ~= OUTLINE then
      for _, j in ipairs({ i - 1, i + 1, i - w, i + w }) do if px[j] == nil then add[j] = true end end
    end
  end
  for j in pairs(add) do px[j] = OUTLINE end
  local x0, y0, x1, y1 = w, h, -1, -1
  for i in pairs(px) do
    local x, y = i % w, i // w
    x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
  end
  local d = { w = x1 - x0 + 1, h = y1 - y0 + 1, px = {} }
  for i, c in pairs(px) do d.px[(i // w - y0) * d.w + i % w - x0] = c end
  return d
end
-- O que o lint_sprite cobra: uma peça só (diagonal conta), desenho de 10 a 13 px.
local function check(s, name)
  if s.w > 13 or s.h > 13 then problems[#problems + 1] = name .. ': ' .. s.w .. 'x' .. s.h .. ', maior que 13 px' end
  if math.max(s.w, s.h) < 10 then problems[#problems + 1] = name .. ': ' .. s.w .. 'x' .. s.h .. ', menor que 10 px' end
  local seen, parts = {}, 0
  for i in pairs(s.px) do
    if not seen[i] then
      parts = parts + 1
      local stack = { i }
      seen[i] = true
      while #stack > 0 do
        local k = table.remove(stack)
        local x, y = k % s.w, k // s.w
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = x + dx, y + dy
          local j = ny * s.w + nx
          if nx >= 0 and nx < s.w and ny >= 0 and ny < s.h and s.px[j] and not seen[j] then seen[j] = true stack[#stack + 1] = j end
        end end
      end
    end
  end
  if parts ~= 1 then problems[#problems + 1] = name .. ': ' .. parts .. ' peças soltas' end
end
local function toImage(s)
  local img = Image(s.w, s.h)
  img:clear()
  for i, c in pairs(s.px) do img:drawPixel(i % s.w, i // s.w, c) end
  return img
end
local function icon(kind, id, rows, map)
  local name = kind .. '/' .. id
  local s = outline(grid(rows, map, name))
  check(s, name)
  local c = { w = 16, h = 16, px = {} }
  local ox, oy = (16 - s.w) // 2, (16 - s.h) // 2
  for i, v in pairs(s.px) do c.px[(oy + i // s.w) * 16 + ox + i % s.w] = v end
  local mask = {}
  for i = 0, 255 do mask[#mask + 1] = c.px[i] and '#' or '.' end
  icons[#icons + 1] = { kind = kind, id = id, s = c, mask = table.concat(mask) }
  app.fs.makeAllDirectories(ROOT .. kind .. '/out')
  local spr = Sprite(16, 16)
  spr:newCel(spr.layers[1], 1, toImage(c), Point(0, 0))
  spr:saveAs(ROOT .. kind .. '/' .. id .. '.aseprite')
  spr:saveCopyAs(ROOT .. kind .. '/out/' .. id .. '.png')
  spr:close()
end
local function climate(id, rows, map) icon('climate', id, rows, map) end

-- A nuvem que leva algo embaixo: 10 x 4 de cor e a linha vazia que vira o contorno de baixo.
local LIGHT = { ['1'] = 'a', ['2'] = 'b', ['3'] = 'c' }
local DARK = { ['1'] = 'd', ['2'] = 'e', ['3'] = 'f' }
local VEIL = { ['1'] = 'U', ['2'] = 'V', ['3'] = 'T' }
local function under(extra)
  local r = { '...1111...', '.1122222..', '1122222223', '1222222333', '..........' }
  for _, v in ipairs(extra) do r[#r + 1] = v end
  return r
end
local SUN_TOP = { '....zzz....', 'yy.zzyyy.yy', '...zyyyY...', '....yYY....', '...........' }
local function sunOver(extra)
  local r = {}
  for _, v in ipairs(SUN_TOP) do r[#r + 1] = v end
  for _, v in ipairs(extra) do r[#r + 1] = v end
  return r
end

-- ---------------------------------------------------------------- climas (ordem de clima.json)
-- Limpo: o sol inteiro, disco e oito raios.
climate('clear', {
  '.....y.....',
  '.y...y...y.',
  '..y.....y..',
  '....zzz....',
  '...zzyyy...',
  'yy.zyyyY.yy',
  '...yyyYY...',
  '....yYY....',
  '..y.....y..',
  '.y...y...y.',
  '.....y.....',
})
-- Sol forte: o sol grande no canto, com raios compridos que varrem o quadro.
climate('strong_sun', {
  'zzzzyy.....',
  'zzzyyy.yyyy',
  'zzyyy......',
  'zyyyY..yy..',
  'yyYY.....yy',
  'yY.........',
  '......y....',
  '.y.y...y...',
  '.y.y....y..',
  '.y..y....y.',
  '.y..y......',
})
-- Nublado: a nuvem sozinha, grande.
climate('cloudy', {
  '....1111...',
  '..11122222.',
  '.1122222223',
  '11222222223',
  '12222222333',
  '12222233333',
}, LIGHT)
-- Garoa: nuvem clara e traços curtos, em duas fileiras desencontradas.
climate('drizzle', under({
  '.l...l...l',
  '.l...l...l',
  '...l...l..',
  '...l...l..',
}), LIGHT)
-- Chuva: nuvem escura e três riscos inclinados.
climate('rain', under({
  '..w..w..w.',
  '.w..w..w..',
  'w..w..w...',
}), DARK)
-- Tempestade: nuvem escura e o raio.
climate('storm', under({
  '.....zz...',
  '....zz....',
  '...yyyy...',
  '....yy....',
  '....y.....',
}), DARK)
-- Granizo: nuvem escura e três pedras redondas.
climate('hail', under({
  '.kk....kk.',
  '.ll....ll.',
  '....kk....',
  '....ll....',
}), DARK)
-- Neblina: quatro faixas grossas, quebradas e desencontradas.
climate('fog', {
  '..aaaaaaaa.',
  '..bbbbbbbb.',
  '...........',
  'aaaaaaa.aaa',
  'bbbbbbb.bbb',
  '...........',
  '.aaa.aaaaaa',
  '.bbb.bbbbbb',
  '...........',
  '..aaaaaaa..',
  '..ccccccc..',
})
-- Frio: o floco grande, quatro braços com farpas.
climate('cold', {
  '.....k.....',
  '...k.k.k...',
  '....kkk....',
  '.k...k...k.',
  '..k..k..k..',
  'kkkkkkkkkkk',
  '..l..l..l..',
  '.l...l...l.',
  '....lll....',
  '...l.l.l...',
  '.....l.....',
})
-- Vento: três linhas, duas com a ponta enrolada.
climate('wind', {
  '.......aa..',
  '......a..a.',
  'aaaaaaaaa..',
  '...........',
  '..bbbbbbbb.',
  '.......b..b',
  'bbbbb...bb.',
})
-- Vendaval: a nuvem pequena em cima e o vento saindo dela.
climate('gale', {
  '..111......',
  '.112222....',
  '11222223...',
  '12222333...',
  '...........',
  '.aaaaaaaaa.',
  '..........a',
  'aaaaaa..aa.',
  '...........',
  '..aaaaaaa..',
}, LIGHT)
-- Poeira seca: o sol pequeno sobre o chão rachado.
climate('dry_dust', sunOver({
  'sssssOsssst',
  'sttttOtttOt',
  'ttOOttOOOtu',
  'tOtttttuuuu',
}))
-- Fumaça de queimada: a chama embaixo e a coluna de fumaça em S.
climate('smoke', {
  '.....nnn...',
  '....nnooo..',
  '....noopp..',
  '...nnop....',
  '..nnoop....',
  '...oopp....',
  '...........',
  '.....h.....',
  '....hhi....',
  '...hhzii...',
  '...hzzzi...',
})
-- Neve: nuvem clara e um floco só, grande.
climate('snow', under({
  '...k.k.k..',
  '....kkk...',
  '...kkkkk..',
  '....kkk...',
  '...k.k.k..',
}), LIGHT)
-- Nevasca: o floco voando, com três riscos de velocidade atrás.
climate('blizzard', {
  '.......k...',
  'aaaa.k.k.k.',
  '......kkk..',
  'bbb.kkkkkkk',
  '......kkk..',
  'aaaa.k.k.k.',
  '.......k...',
})
-- Tempestade de areia: a duna e o vento por cima.
climate('sandstorm', {
  '.......ss..',
  '......s..s.',
  'sssssssss..',
  '...........',
  '.....ss....',
  '...ssstt...',
  '..sstttttu.',
  '.ssttttttuu',
  'sstttttuuuu',
})
-- Dilúvio: nuvem escura, chuva cerrada e a água subindo embaixo.
climate('deluge', under({
  '.w.w.w.w.w',
  '.w.w.w.w.w',
  '..........',
  'llwwllwwll',
  'wxxwwxxwwx',
}), DARK)
-- Onda de calor: o sol pequeno e três linhas de calor subindo em zigue-zague.
climate('heat_wave', sunOver({
  '.h...h...h.',
  '..h...h...h',
  '.h...h...h.',
  'i...i...i..',
  '.i...i...i.',
}))
-- Chuva ácida: nuvem escura e uma gota só, gorda.
climate('acid_rain', under({
  '....gG....',
  '...gGGj...',
  '...GGjj...',
  '....jj....',
}), DARK)
-- Neve do Véu: três estrelas de quatro pontas, no violeta do Véu.
climate('veil_snow', {
  '...U....W..',
  '...U...WWW.',
  '..UVU...W..',
  'UUVVVUU....',
  '..UVU......',
  '...U....U..',
  '...U....U..',
  '......UUUUU',
  '........U..',
  '........U..',
})
-- Chuva Carmim: a lua vermelha atrás da nuvem e os riscos vermelhos.
climate('crimson_rain', {
  '.......HII',
  '.......HII',
  '...1111.JJ',
  '.1122222..',
  '1122222223',
  '1222222333',
  '..........',
  '..I..I..I.',
  '.I..I..I..',
  'I..I..I...',
}, DARK)
-- Chuva de Fagulhas: três brasas caindo, cada uma com o rastro violeta.
climate('spark_rain', {
  '...V.......',
  '..V........',
  'hh.....V...',
  'ii....V....',
  '.....V.....',
  '...hh.....V',
  '...ii....V.',
  '.......hh..',
  '.......ii..',
})
-- Cinzas do Véu: o monte de cinza violeta e os flocos caindo nele.
climate('veil_ash', {
  '..VV....U..',
  '.......UU..',
  '.U...V.....',
  '.UU.VV...VV',
  '...........',
  '....UUV....',
  '..UUVVVVT..',
  '.UVVVVVTTT.',
  'UVVVVTTTTTT',
})
-- Céu Invertido: a nuvem de cabeça para baixo, embaixo, e a chuva subindo.
climate('inverted_sky', {
  'l..l..l...',
  '.l..l..l..',
  '..l..l..l.',
  '..........',
  '1122222223',
  '1222222333',
  '.2222333..',
  '...3333...',
}, VEIL)
-- Garoa Prismática: nuvem clara e dois brilhos em cruz, um de cada cor.
climate('prismatic_drizzle', under({
  '..K.......',
  '.KKK...L..',
  '..K...LLL.',
  '....V..L..',
  '....V.....',
}), LIGHT)
-- Geada forte: os cristais de gelo de pé no chão.
climate('hard_frost', {
  '.....k.....',
  '....kkl....',
  '....kll....',
  '.k..kll..k.',
  '.kl.kll.kl.',
  '.kl.kll.kl.',
  'kklkkllkllm',
  'klllllllmmm',
  'lllmmmmmmmm',
})
-- Trovoada seca: o raio grande, sem nuvem, e a brasa onde ele cai.
climate('dry_thunder', {
  '....zzz....',
  '...zzz.....',
  '..zzz......',
  '.zzzzzz....',
  '....yyy....',
  '...yyy..h..',
  '..yyy..hh..',
  '..yy..hhih.',
  '.yy...hiii.',
  '.y.....ii..',
})
-- Smog: os prédios e a faixa de fuligem atravessada.
climate('smog', {
  '....ooo....',
  '....oop.oo.',
  'ooo.oop.op.',
  'oop.oop.op.',
  'rrrrrrrrrrr',
  'RRRRRRRRRRR',
  'oop.oop.op.',
  'oop.oop.op.',
  'ppppppppppp',
})
-- Chuva congelante: nuvem escura e os pingentes de gelo, de três tamanhos.
climate('freezing_rain', under({
  '.kl.kl.kl.',
  '.kl.kl..l.',
  '..l.kl....',
  '.....l....',
  '.....l....',
}), DARK)
-- Furacão: o anel com o olho furado e os dois braços.
climate('hurricane', {
  '....eee....',
  '.......e...',
  '....ddd.e..',
  '...ddeeee..',
  '..dd...ee..',
  '..de...ef..',
  '..ee...ff..',
  '..eeeeff...',
  '..e.fff....',
  '...f.......',
  '....fff....',
}, { d = 'a', e = 'b', f = 'c' })
-- Chuva de Runas: a runa em triângulo caindo, com dois riscos em cima.
climate('rune_rain', {
  '.V......V.',
  '.V..UU..V.',
  '....UU....',
  '...U..U...',
  '...U..U...',
  '..V....V..',
  '..V....V..',
  '.V......V.',
  '.VVVVVVVV.',
})

-- ---------------------------------------------------------------- eventos
K = { icon = icon }
dofile(ROOT .. 'event/build.lua')
K = nil

-- Duas silhuetas iguais entre os climas: proibido (estilo-ui.md, "O que nunca fazer").
for i = 1, #icons do
  for j = i + 1, #icons do
    if icons[i].kind == 'climate' and icons[j].kind == 'climate' and icons[i].mask == icons[j].mask then
      problems[#problems + 1] = icons[i].id .. ' e ' .. icons[j].id .. ': mesma silhueta'
    end
  end
end

-- ---------------------------------------------------------------- folha: 1x, 2x e 3x, em cor e em cinza
local rowsOf = { {}, {}, {} }
for _, ic in ipairs(icons) do
  local r = ic.kind == 'event' and 3 or (#rowsOf[1] < 16 and 1 or 2)
  rowsOf[r][#rowsOf[r] + 1] = ic
end
local GAP, MARGIN = 4, 6
local SW, SH = MARGIN * 2 + 16 * (48 + GAP), MARGIN
for s = 1, 3 do SH = SH + 2 * (3 * (16 * s + GAP) + GAP) end
local sheet = Image(SW, SH)
sheet:clear(hex('1e1830'))
local y = MARGIN
for pass = 1, 2 do
  for s = 1, 3 do
    for _, list in ipairs(rowsOf) do
      for n, ic in ipairs(list) do
        local x = MARGIN + (n - 1) * (16 * s + GAP)
        for i, c in pairs(ic.s.px) do
          if pass == 2 then
            local v = math.floor(0.299 * pc.rgbaR(c) + 0.587 * pc.rgbaG(c) + 0.114 * pc.rgbaB(c) + 0.5)
            c = pc.rgba(v, v, v, 255)
          end
          for dy = 0, s - 1 do for dx = 0, s - 1 do sheet:drawPixel(x + (i % 16) * s + dx, y + (i // 16) * s + dy, c) end end
        end
      end
      y = y + 16 * s + GAP
    end
    y = y + GAP
  end
end
local spr = Sprite(SW, SH)
spr:newCel(spr.layers[1], 1, sheet, Point(0, 0))
spr:saveCopyAs(ROOT .. 'climate/out/folha.png')
spr:close()

local nc, ne = 0, 0
for _, ic in ipairs(icons) do if ic.kind == 'climate' then nc = nc + 1 else ne = ne + 1 end end
print(nc .. ' climas, ' .. ne .. ' eventos, folha ' .. SW .. 'x' .. SH)
for _, p in ipairs(problems) do print('PROBLEMA ' .. p) end
