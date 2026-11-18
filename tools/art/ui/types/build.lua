-- Ícones dos 12 tipos (0.26.0): 16 x 16 com contorno e 8 x 8 chapado para as etiquetas pequenas, e a folha.
-- Rodar: aseprite -b --script tools/art/sparks/build.lua (as Fagulhas entram na folha) e depois este.
-- Letras: l claro, m principal, d escuro (palette.lua), o contorno. O de 16 é desenhado em 11 x 11 e o contorno
-- de fora entra sozinho (13 x 13 no máximo); furo de verdade leva o próprio 'o' em volta.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local DIR = L.ROOT .. 'ui/types/'
local OUT = DIR .. 'out/'
local PAL = dofile(DIR .. 'palette.lua')
local O, PANEL, FUNDO = '#1A1424', '#1E1830', '#120E1A'
app.fs.makeAllDirectories(OUT)

local ICONS = {
  fire = {  -- chama: ponta no meio, língua à direita, miolo claro
    { '.....m.....', '.....mm....', '....lmm....', '....lmmm.m.', '...llmmmmm.', '..llmlmmmd.', '..lmllmmmd.', '..lmlllmdd.', '..mmlllmdd.', '...mmmmdd..', '....ddd....' },
    { '...m....', '...mm...', '..lmm.m.', '..lmmmm.', '.llmmmm.', '.lmllmd.', '.mmllmd.', '..mmdd..' } },
  water = {  -- gota: ponta fina em cima, bojo embaixo
    { '.....m.....', '.....m.....', '....mmm....', '....lmm....', '...llmmm...', '...lmmmmd..', '..llmmmmdd.', '..lmmmmmdd.', '..mmmmmmdd.', '...mmmddd..', '....ddd....' },
    { '...m....', '...m....', '..lmm...', '..lmm...', '.llmmd..', '.lmmmd..', '.mmmdd..', '..ddd...' } },
  plant = {  -- folha na diagonal, nervura clara, talo embaixo à esquerda
    { '......mmmm.', '....mmmmlm.', '...mmmmlmm.', '..mmmmlmmd.', '..mmmlmmmd.', '.mmmlmmmdd.', '.mmlmmmdd..', '.mlmmmdd...', '.dmmddd....', 'dd.........', 'd..........' },
    { '....mmm.', '..mmmlm.', '.mmmlmm.', '.mmlmmd.', '.mlmmd..', '.mmdd...', 'd.......', '........' } },
  earth = {  -- pedra: bloco torto com pico e facetas
    { '...........', '....llm....', '...lllmm...', '..llllmmd..', '..lllmmmdd.', '.lllmmmmdd.', '.llmmmmdddd', '.lmmmmddmdd', 'lmmmmmddddd', 'mmmmdddddd.', '.ddddddd...' },
    { '........', '..llm...', '.lllmm..', '.llmmmd.', 'llmmmddd', 'lmmmdddd', '.ddddd..', '........' } },
  electric = {  -- raio em Z
    { '.....lmmm..', '....lmmm...', '...lmmm....', '..lmmm.....', '.lmmmmmmmd.', '.....lmmmd.', '....lmmd...', '...lmmd....', '..lmmd.....', '.lmd.......', '.md........' },
    { '....lmm.', '...lmm..', '..lmm...', '.lmmmmm.', '....lmd.', '...lmd..', '..lmd...', '..md....' } },
  metal = {  -- lingote: face de cima clara, frente com o cunho (a engrenagem já é a sucata)
    { '...........', '...........', '...lllllll.', '..lllllllmd', '..mmmmmmmdd', '.mmmmmmmmdd', '.mmmddmmmdd', 'mmmmmmmmmdd', 'ddddddddddd', '...........', '...........' },
    { '........', '..lllll.', '.lllllmd', '.mmmmmdd', 'mmmmmmdd', 'mmmmmmdd', 'dddddddd', '........' } },
  light = {  -- sol: disco e oito raios soltos pelo contorno
    { '.....l.....', '.l...l...m.', '..l.....m..', '....llm....', '...llmmm...', 'll.lmmmd.dd', '...mmmmd...', '....mdd....', '..m.....d..', '.m...d...d.', '.....d.....' },
    { '...l....', '.l...m..', '..llm...', 'l.lmm.d.', '..mmd...', '.m...d..', '...d....', '........' } },
  shadow = {  -- lua escura: crescente aberta à direita
    { '....lmmm...', '..llmm.....', '.llmm......', '.lmm.......', 'lmmm.......', 'lmmm.......', 'mmmmd......', '.mmmdd.....', '.mmmmddd..d', '..mmmmdddd.', '....dddd...' },
    { '..lmm...', '.lm.....', 'lmm.....', 'lmm.....', 'mmm.....', 'mmmd...d', '.mmdddd.', '..ddd...' } },
  spectral = {  -- chama fria: ponta caída para a esquerda e o miolo vazio
    { '..m........', '..lm.......', '..llm......', '..lmmm.....', '.llmmmmm...', '.lmooommm..', 'llo...ommd.', 'lmo...omdd.', 'lmmooommdd.', '.mmmmmddd..', '..mdddd....' },
    { '..m.....', '..lm....', '..lmm...', '.llmmm..', '.lm..md.', '.lm..md.', '.mmmmdd.', '..mddd..' } },
  digital = {  -- pixel: quadrado com pixels se soltando
    { '...........', '........lm.', '........md.', 'lllllll....', 'lmmmmmd..m.', 'lmmmmmd....', 'lmmmmmdmm..', 'lmmmmmdmd..', 'lmmmmmd....', 'mdddddd....', '...........' },
    { '......lm', '......md', 'lllll...', 'lmmmd...', 'lmmmdmm.', 'lmmmdmd.', 'mdddd...', '........' } },
  fae = {  -- asas de fada: par aberto, as de cima maiores
    { '...........', '.ll.....mm.', 'lllm...mmmm', 'llmmm.mmmmd', 'lmmmmdmmmmd', '.mmmmdmmmd.', '..mmmdmmd..', '.lmmm.mmmd.', '.mmm...mdd.', '..d.....d..', '...........' },
    { '........', 'll...mm.', 'lmm.mmd.', 'lmmdmmd.', '.mmdmd..', '.lm.md..', '.md.dd..', '........' } },
  draconic = {  -- escama: arco largo em cima, ponta embaixo, quilha clara
    { '...lllmm...', '.lllmmmmmm.', 'llmmlmmmmmd', 'lmmmlmmmmmd', 'lmmmlmmmmdd', 'lmmmmlmmmdd', '.mmmmlmmdd.', '.mmmmmmddd.', '..mmmmddd..', '...mdddd...', '.....d.....' },
    { '..lllm..', '.llmmmm.', 'lmlmmmmd', 'lmlmmmdd', 'lmmlmmdd', '.mmlmdd.', '..mmdd..', '...dd...' } },
}

local problems = 0
local function bad(msg) print('PROBLEMA ' .. msg); problems = problems + 1 end

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function pc(hex) local r, g, b = rgb(hex); return app.pixelColor.rgba(r, g, b, 255) end
-- Luminância relativa e contraste da WCAG 2.
local function lum(hex)
  local function f(v) v = v / 255; return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  local r, g, b = rgb(hex)
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
end
local function contrast(a, b)
  local x, y = lum(a), lum(b)
  if x < y then x, y = y, x end
  return (x + 0.05) / (y + 0.05)
end
local function mask(g)
  local t = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do t[#t + 1] = g[y][x] == '.' and '.' or '#' end end
  return table.concat(t)
end

local built, masks = {}, {}
for _, t in ipairs(PAL) do
  local rows = ICONS[t.id]
  local leg = { o = O, l = t.l, m = t.m, d = t.d }
  local g = L.grid(16, 16)
  L.put(g, 2, 2, L.frame(rows[1], 11, 11, t.id) and rows[1])
  L.outline(g, 'o')
  local x0, y0, x1, y1 = 16, 16, -1, -1
  for y = 0, 15 do
    for x = 0, 15 do
      if g[y][x] ~= '.' then
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
      end
    end
  end
  local w, h = x1 - x0 + 1, y1 - y0 + 1
  if x0 < 1 or y0 < 1 or x1 > 14 or y1 > 14 then bad(t.id .. ': sem 1 px de folga') end
  if math.max(w, h) < 10 or math.max(w, h) > 13 then bad(t.id .. ': desenho de ' .. w .. ' x ' .. h) end
  local g8 = L.frame(rows[2], 8, 8, t.id .. '_8')
  for _, pair in ipairs({ { g, '16' }, { g8, '8' } }) do
    local m = mask(pair[1])
    if masks[m] then bad(t.id .. ' ' .. pair[2] .. ': mesma silhueta de ' .. masks[m]) end
    masks[m] = t.id
  end
  L.save(DIR .. t.id, leg, { { name = 'icon', grid = g, png = OUT .. t.id .. '.png' } })
  L.save(DIR .. t.id .. '_8', leg, { { name = 'icon', grid = g8, png = OUT .. t.id .. '_8.png' } })
  built[#built + 1] = { t = t, leg = leg, g = g, g8 = g8 }
  local cp, cf = contrast(t.m, PANEL), contrast(t.m, FUNDO)
  print(string.format('%-9s %s  painel %.1f  fundo %.1f  claro %.1f  escuro %.1f  %dx%d', t.id, t.m, cp, cf,
    contrast(t.l, PANEL), contrast(t.d, PANEL), w, h))
  if cp < 4.5 then bad(t.id .. ': contraste ' .. string.format('%.2f', cp) .. ' no painel, menor que 4,5') end
end

-- Folha: quatro blocos lado a lado (painel, fundo, painel em cinza, fundo em cinza). Em cada linha, na ordem do
-- palette.lua: principal, claro, escuro, ícone de 16, ícone de 8 e os 4 quadros da Fagulha.
local BW, RH, K = 112, 18, 4
local H = #built * RH + 2
local img = Image(BW * 4, H, ColorMode.RGB)
local function grid(gr, leg, x0, y0)
  for y = 0, gr.h - 1 do
    for x = 0, gr.w - 1 do
      if gr[y][x] ~= '.' then img:putPixel(x0 + x, y0 + y, pc(leg[gr[y][x]])) end
    end
  end
end
for b = 0, 1 do
  local bg = pc(b == 0 and PANEL or FUNDO)
  for y = 0, H - 1 do for x = 0, BW - 1 do img:putPixel(b * BW + x, y, bg) end end
  for i, it in ipairs(built) do
    local x0, y0 = b * BW + 2, 2 + (i - 1) * RH
    for s, hex in ipairs({ it.t.m, it.t.l, it.t.d }) do
      for y = 2, 13 do for x = 0, 7 do img:putPixel(x0 + (s - 1) * 9 + x, y0 + y, pc(hex)) end end
    end
    grid(it.g, it.leg, x0 + 29, y0)
    grid(it.g8, it.leg, x0 + 48, y0 + 4)
    local sp = Image { fromFile = L.ROOT .. 'sparks/spark_' .. it.t.id .. '.png' }
    for y = 0, sp.height - 1 do
      for x = 0, sp.width - 1 do
        local p = sp:getPixel(x, y)
        if app.pixelColor.rgbaA(p) > 0 then img:putPixel(x0 + 60 + x, y0 + 2 + y, p) end
      end
    end
  end
end
for y = 0, H - 1 do
  for x = 0, BW * 2 - 1 do
    local p = img:getPixel(x, y)
    local v = math.floor(0.299 * app.pixelColor.rgbaR(p) + 0.587 * app.pixelColor.rgbaG(p) + 0.114 * app.pixelColor.rgbaB(p) + 0.5)
    img:putPixel(BW * 2 + x, y, app.pixelColor.rgba(v, v, v, 255))
  end
end
local big = Image(BW * 4 * K, H * K, ColorMode.RGB)
for y = 0, H * K - 1 do
  for x = 0, BW * 4 * K - 1 do big:putPixel(x, y, img:getPixel(x // K, y // K)) end
end
big:saveAs(OUT .. 'folha.png')
print('ok ' .. OUT .. 'folha.png ' .. BW * 4 * K .. 'x' .. H * K)
print('problemas: ' .. problems)
