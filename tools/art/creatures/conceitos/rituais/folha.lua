-- Folha das espécies de ritual: as três com arte final (quadro 0 do idle e do retrato) e os nove conceitos.
-- Por espécie, de cima para baixo: nome e família, mapa a 4x de noite, mapa a 4x de dia, retrato a 2x de noite,
-- retrato a 2x de dia. Noite = corpo com o tom da noite e os emissivos por cima; dia = corpo puro, emissivos apagados
-- (como o familia.py). Grava docs/art/conceitos/rituais/rituais.png (as doze) e rituais_revisao.png (as três
-- aprovadas na revisão 1 e as seis refeitas na revisão 2).
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rituais/folha.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART')
local DOCS = ART:gsub('tools/art/$', '') .. 'docs/art/conceitos/rituais/'
local pc = app.pixelColor
local TODAS = {
  { 'kilnshade', 'soot', true }, { 'rootseer', 'frond', true }, { 'wellmirror', 'rill', true },
  { 'stormlamp', 'hum' }, { 'cairnhollow', 'clod' }, { 'gatewarden', 'rust' },
  { 'noonglass', 'glare' }, { 'eaveshroud', 'shade' }, { 'vigilwick', 'wisp' },
  { 'staticroost', 'bit' }, { 'duskwreath', 'sprig' }, { 'cratercoil', 'wyrm' },
}
local REVISAO = {
  { 'kilnshade', 'final', true }, { 'rootseer', 'final', true }, { 'wellmirror', 'final', true },
  { 'stormlamp', 'aprovada' }, { 'noonglass', 'aprovada' }, { 'eaveshroud', 'aprovada' },
  { 'staticroost', 'aprovada' }, { 'vigilwick', 'aprovada' }, { 'cairnhollow', 'aprovada' },
  { 'gatewarden', 'refeita' }, { 'cratercoil', 'refeita' }, { 'duskwreath', 'refeita' },
}
local NIGHT, DAY, BG, INK = pc.rgba(38, 36, 70), pc.rgba(128, 126, 120), pc.rgba(27, 23, 40), pc.rgba(220, 214, 236)
local TONE = { 150, 140, 200 }
local GAP, CW = 16, 192
local BH = 14 + 144 + 8 + 144 + 8 + 192 + 8 + 192 + GAP
local sheet

local FONT = {
  A = '010101111101101', B = '110101110101110', C = '011100100100011', D = '110101101101110', E = '111100110100111',
  F = '111100110100100', G = '011100101101011', H = '101101111101101', I = '111010010010111', J = '001001001101010',
  K = '101101110101101', L = '100100100100111', M = '101111111101101', N = '110101101101101', O = '010101101101010',
  P = '110101110100100', Q = '010101101111011', R = '110101110101101', S = '011100010001110', T = '111010010010010',
  U = '101101101101111', V = '101101101101010', W = '101101111111101', X = '101101010101101', Y = '101101010010010',
  Z = '111001010100111', ['2'] = '110001010100111', ['3'] = '111001011001111', ['4'] = '101101111001001',
}
local function text(s, x, y)
  for n = 1, #s do
    local gl = FONT[s:sub(n, n)]
    if gl then
      for i = 0, 14 do
        if gl:sub(i + 1, i + 1) == '1' then
          for dy = 0, 1 do for dx = 0, 1 do sheet:putPixel(x + (i % 3) * 2 + dx, y + (i // 3) * 2 + dy, INK) end end
        end
      end
    end
    x = x + 8
  end
end
local function rect(x, y, w, h, c) for j = y, y + h - 1 do for i = x, x + w - 1 do sheet:putPixel(i, j, c) end end end
-- cola os primeiros [side] pixels de largura da imagem, ampliados s vezes; tone multiplica a cor
local function blit(path, side, x, y, s, tone)
  if not app.fs.isFile(path) then return end
  local im = Image { fromFile = path }
  for j = 0, side - 1 do for i = 0, side - 1 do
    local c = im:getPixel(i, j)
    if pc.rgbaA(c) > 0 then
      local r, g2, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
      if tone then r, g2, b = r * tone[1] // 255, g2 * tone[2] // 255, b * tone[3] // 255 end
      rect(x + i * s, y + j * s, s, s, pc.rgba(r, g2, b))
    end
  end end
end
local function cell(e, kind, side, x, y, s, night)
  rect(x, y, side * s, side * s, night and NIGHT or DAY)
  local body, ems
  if e[3] then
    local base = ART .. 'creatures/' .. e[1] .. '/' .. e[1] .. '_' .. (kind == 'mapa' and 'idle' or 'portrait')
    body, ems = base .. '.png', { base .. '_glow.png', base .. '_leds.png' }
  else
    local base = ART .. 'creatures/conceitos/rituais/' .. e[1] .. '/' .. e[1] .. '_espirito_' .. kind
    body, ems = base .. '.png', { base .. '_emissivo.png' }
  end
  blit(body, side, x, y, s, night and TONE or nil)
  if night then for _, p in ipairs(ems) do blit(p, side, x, y, s) end end
end

local function folha(list, cols, title, out)
  sheet = Image(GAP + cols * (CW + GAP), 22 + math.ceil(#list / cols) * BH, ColorMode.RGB)
  sheet:clear(BG)
  text(title, GAP, 6)
  for n, e in ipairs(list) do
    local x = GAP + ((n - 1) % cols) * (CW + GAP)
    local y = 22 + ((n - 1) // cols) * BH
    text((e[1] .. '  ' .. e[2]):upper(), x, y)
    cell(e, 'mapa', 36, x + 24, y + 14, 4, true)
    cell(e, 'mapa', 36, x + 24, y + 14 + 152, 4, false)
    cell(e, 'retrato', 96, x, y + 14 + 304, 2, true)
    cell(e, 'retrato', 96, x, y + 14 + 304 + 200, 2, false)
  end
  sheet:saveAs(DOCS .. out)
  print('folha: ' .. DOCS .. out .. ' ' .. sheet.width .. 'x' .. sheet.height)
end
folha(TODAS, 6, 'RITUAIS   MAPA 4X NOITE E DIA   RETRATO 2X NOITE E DIA', 'rituais.png')
folha(REVISAO, 6, 'RITUAIS REVISAO 4   MAPA 4X NOITE E DIA   RETRATO 2X NOITE E DIA', 'rituais_revisao.png')
