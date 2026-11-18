-- Extras do tráfego (0.26.0), na grade de 2 dp, no esquema do build.lua: barco e canoa do Dilúvio (vistos de cima,
-- frente para a direita), o cachorro do passeio (de pé, 2 quadros) e o carro da corrida do Modo Viagem.
-- Rodar: aseprite -b --script build_extra.lua. Não mexe em nada do build.lua: os carros da corrida são os PNG do
-- tráfego (hatch, sedan, suv) lidos de volta, mais a luz do teto. Sem logo, marca nem nome.
local S = dofile('/home/yuri/Documentos/kenoma/tools/art/traffic/_strip.lua')
local L = S.L
local DIR = L.ROOT .. 'traffic/'
local OUT = '#1A1424'
local FUR = '#B8875A'

-- As mesmas letras e cores do build.lua onde o papel é o mesmo. Novas: n remo (o hex da bengala), f/F pelo do cachorro,
-- q/Q luz do teto da corrida. A coleira e a guia usam r (o vermelho da lanterna).
local LEG = {
  o = OUT,
  b = '#B8BCC8', a = '#8E92A4', d = '#6A6E82', g = '#BFE9F0', G = '#7FB4C4', y = '#FFE8A3', r = '#E0524A', k = '#3A2F4A',
  h = '#6B4A2F', H = '#4A3220', s = '#F0C9A6', S = '#D9A47C', e = '#2B2540',
  t = '#6C7FB8', T = '#4E5C8A', p = '#4A5578', P = '#363E5A', n = '#A9824F',
  f = FUR, F = S.mix(FUR, OUT, 0.4),
  q = '#5FD3C6', Q = '#B4F0E8',
}
local REV = {}
for ch, hex in pairs(LEG) do REV[hex:upper()] = ch end

-- O quadro f (a partir de 0) de uma tira PNG do tráfego, de volta para a grade de letras.
local function load(file, fw, f)
  local img = Image { fromFile = DIR .. file }
  if img.colorMode ~= ColorMode.RGB then error(file .. ': não é RGB') end
  local g = L.grid(fw or img.width, img.height)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local p = img:getPixel((f or 0) * g.w + x, y)
      if app.pixelColor.rgbaA(p) > 0 then
        local hex = string.format('#%02X%02X%02X', app.pixelColor.rgbaR(p), app.pixelColor.rgbaG(p), app.pixelColor.rgbaB(p))
        g[y][x] = REV[hex] or error(file .. ': cor fora da legenda ' .. hex)
      end
    end
  end
  return g
end

local ART = {}
local function top(name, g, glow)
  S.check(name, g)
  local layers = { { name = 'base', frames = { g }, png = DIR .. name .. '.png' } }
  if glow then layers[2] = { name = 'glow', frames = { glow }, png = DIR .. name .. '_glow.png', hidden = true } end
  S.save(DIR .. name, LEG, layers)
  ART[name] = { g = g, glow = glow }
end

-- ---------------------------------------------------------------------------------------------- Dilúvio

-- Barco a remo: casco de 24 x 11 com o contorno (o carro), borda e convés da proa na cor-chave, fundo e bancos
-- derivados, quem rema no meio com um remo de cada lado, lanterna na proa (o farol do barco).
do
  local hull = {
    '.bbbbbbbbbbbbbb.......',
    'baddaaaaddsaaaabbb....',
    'baddaaaadttaaaadbbbb..',
    'baddaaaadhhhaaadbbbbb.',
    'baddaaaadhhhaaadbbbbyb',
  }
  local g = L.grid(26, 17)
  for i = 1, 5 do L.put(g, 2, 3 + i, { hull[i] }); L.put(g, 2, 13 - i, { hull[i] }) end
  for _, p in ipairs({ { 10, 0 }, { 9, -1 }, { 8, -2 }, { 7, -2 } }) do
    g[4 + p[2]][2 + p[1]] = 'n'; g[12 - p[2]][2 + p[1]] = 'n'
  end
  L.outline(g, 'o')
  top('boat', g, S.pick(g, 'y'))
end

-- Canoa: casco de 21 x 7 com o contorno (a moto), duas pessoas remando, uma de cada lado.
do
  local hull = {
    '....bbbbbbbbbbb....',
    '.bbbattsaadattabbb.',
    'bbaaahhaadahhaaaabb',
    '.bbbattaadattsabbb.',
    '....bbbbbbbbbbb....',
  }
  local g = L.grid(23, 13)
  L.put(g, 2, 4, hull)
  for _, p in ipairs({ { 7, 0 }, { 6, -1 }, { 5, -2 }, { 4, -2 } }) do g[4 + p[2]][2 + p[1]] = 'n' end
  for _, p in ipairs({ { 13, 4 }, { 12, 5 }, { 11, 6 }, { 10, 6 } }) do g[4 + p[2]][2 + p[1]] = 'n' end
  L.outline(g, 'o')
  top('canoe', g, nil)
end

-- ---------------------------------------------------------------------------------------------- cachorro do passeio

-- De lado, olhando para a direita: 13 x 8 com o contorno num quadro de 16 x 13. A guia sai da coleira para cima e
-- para a frente (a mão do dono), numa camada só dela, sem contorno.
do
  local rows = {
    { 'f.....Fff..', 'f....rFfefk', '.ffffrffff.', '.fffffF....', '.fF..fF....', 'fF....fF...' },
    { '......Fff..', 'f....rFfefk', 'fffffrffff.', '.fffffF....', '.fF..fF....', '..fF.fF....' },
  }
  local base, leash, comp = {}, {}, {}
  for f = 1, 2 do
    local g = L.grid(16, 13)
    L.put(g, 3, 5, rows[f])
    L.outline(g, 'o')
    S.check('dog q' .. f, g)
    local c = S.copy(g)
    for _, p in ipairs({ { 8, 5 }, { 8, 4 }, { 9, 3 }, { 10, 2 } }) do c[p[2]][p[1]] = 'r' end
    S.check('dog guia q' .. f, c)
    base[f], comp[f], leash[f] = g, c, S.diff(c, g)
  end
  S.save(DIR .. 'dog', LEG, {
    { name = 'body', frames = base, png = DIR .. 'dog.png' },
    { name = 'leash', frames = leash, png = DIR .. 'dog_leash.png' },
  }, 3)
  ART.dog = { base = base, comp = comp }
end

-- ---------------------------------------------------------------------------------------------- carro da corrida

-- O carro do tráfego mais a luz do teto, na cor do sinal: caixa de contorno com 2 colunas acesas.
local function ride(kind, x0, y0, y1)
  local g = load(kind .. '.png')
  L.rect(g, x0, y0, x0 + 3, y1, 'o')
  L.rect(g, x0 + 1, y0 + 1, x0 + 2, y1 - 1, 'q')
  L.rect(g, x0 + 1, y0 + 2, x0 + 2, y1 - 2, 'Q')
  top('ride_' .. kind, g, S.pick(g, 'yrqQ'))
end
ride('hatch', 8, 5, 9)
ride('sedan', 11, 5, 9)
ride('suv', 11, 5, 10)  -- no lugar do teto solar

-- ---------------------------------------------------------------------------------------------- folha de conferência

local function variant(over)
  local t = {}
  for k, v in pairs(LEG) do t[k] = v end
  if over.b then over.a = S.mix(over.b, OUT, 0.3); over.d = S.mix(over.b, OUT, 0.5) end
  if over.f then over.F = S.mix(over.f, OUT, 0.4) end
  for k, v in pairs(over) do t[k] = v end
  return t
end

do
  local items = {}
  local function put(g, x, y, leg, glow) items[#items + 1] = { g = g, glow = glow, x = x, y = y, leg = leg or LEG } end
  local function art(n, x, y, leg) put(ART[n].g, x, y, leg, ART[n].glow) end
  art('boat', 3, 2); art('canoe', 33, 4)
  art('boat', 60, 2, variant { b = '#FF7A45', h = '#3A2A2A', t = '#5FD3C6' })
  art('canoe', 90, 4, variant { b = '#9B7BFF', h = '#D8B45A', t = '#FF7A45', s = '#A8714C' })
  art('ride_hatch', 3, 24); art('ride_sedan', 29, 24); art('ride_suv', 58, 24)
  art('ride_sedan', 88, 24, variant { b = '#E8E4F4' })
  put(load('ped_adult.png', 17, 0), 3, 44)
  put(ART.dog.comp[1], 22, 61); put(ART.dog.comp[2], 40, 61)
  put(ART.dog.base[1], 58, 61, variant { f = '#E8E4F4', r = '#5FD3C6' })
  put(ART.dog.comp[2], 76, 61, variant { f = '#4A4458', r = '#FF7A45' })
  put(ART.dog.comp[1], 94, 61, variant { f = '#D8B45A', r = '#9B7BFF' })
  S.folha(DIR .. 'extra_folha.png', 118, 76, {
    { 0, 21, 0, 117, '#3F6C9A', '#35608C', '#5A86B0' },
    { 22, 41, 0, 117, '#343949', '#2B2F3D', '#40465A' },
    { 42, 75, 0, 117, '#A3A7B3', '#8E92A0', '#B6BAC4' },
  }, items, 4)
end
print('pelo escuro: ' .. LEG.F)
print('problemas: ' .. S.problems)
