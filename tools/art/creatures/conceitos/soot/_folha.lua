-- Folha de conferência rápida da sessão (não é a folha oficial, que sai do folhas.py).
-- FAM = 'soot'; dofile(este arquivo): roda o build da família, imprime as medidas numa linha e grava <familia>/_folha.png
-- (mapa 2x de dia, 4x com o tom da noite, 3x no escuro, retratos 2x).
local ART = assert(KENOMA_ART)
local out = {}
local real = print
print = function(s)
  s = tostring(s)
  if s:find('^AVISO') then out[#out + 1] = s end
  if s:find('^  ') then
    out[#out + 1] = s:gsub('^%s+', ''):gsub('opacos', 'op'):gsub('detalhe', 'det'):gsub('contorno', 'cont'):gsub('emissivo', 'em'):gsub('ABAIXO DO PISO', '!!')
  end
end
local ok, err = pcall(dofile, ART .. 'creatures/conceitos/' .. FAM .. '/build.lua')
print = real
if not ok then print('ERRO: ' .. tostring(err)) end
print(table.concat(out, ' | '))
local dir = ART .. 'creatures/conceitos/' .. FAM .. '/'
local st = { 'fagulha', 'eco', 'espirito', 'entidade', 'arquetipo' }
local W, H = 1150, 700
local sheet = Image(W, H, ColorMode.RGB)
local pc = app.pixelColor
local function fill(x0, y0, x1, y1, c) for y = y0, y1 do for x = x0, x1 do sheet:drawPixel(x, y, c) end end end
fill(0, 0, W - 1, H - 1, pc.rgba(34, 32, 52, 255))
fill(0, 0, 470, 139, pc.rgba(128, 128, 120, 255))
local function blit(path, x0, y0, sc, tint)
  local okk, im = pcall(function() return Image { fromFile = path } end)
  if not okk or not im then return 0 end
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do
    local c = im:getPixel(x, y)
    if pc.rgbaA(c) > 0 then
      if tint then c = pc.rgba(math.floor(pc.rgbaR(c) * 0.55), math.floor(pc.rgbaG(c) * 0.55), math.floor(pc.rgbaB(c) * 0.75), 255) end
      for j = 0, sc - 1 do for i = 0, sc - 1 do sheet:drawPixel(x0 + x * sc + i, y0 + y * sc + j, c) end end
    end
  end end
  return im.width * sc
end
local function row(kind, x, y, sc, tint)
  for _, s in ipairs(st) do
    local b = dir .. FAM .. '_' .. s .. '_' .. kind
    local w = blit(b .. '.png', x, y, sc, tint); blit(b .. '_emissivo.png', x, y, sc, false)
    x = x + w + 8
  end
end
-- margens da camada corpo: 2 px livres em cima, 1 embaixo e dos lados
local bad = {}
for _, s in ipairs(st) do
  for _, kd in ipairs({ 'mapa', 'retrato' }) do
    local okk, im = pcall(function() return Image { fromFile = dir .. FAM .. '_' .. s .. '_' .. kd .. '.png' } end)
    if okk and im then
      local x0, y0, x1, y1 = im.width, im.height, -1, -1
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do
        if pc.rgbaA(im:getPixel(x, y)) > 0 then x0 = math.min(x0, x); x1 = math.max(x1, x); y0 = math.min(y0, y); y1 = math.max(y1, y) end
      end end
      if y0 < 2 or y1 > im.height - 2 or x0 < 1 or x1 > im.width - 2 then
        bad[#bad + 1] = s .. ' ' .. kd .. ' x' .. x0 .. '-' .. x1 .. ' y' .. y0 .. '-' .. y1
      end
    end
  end
end
print('margens: ' .. (#bad == 0 and 'ok' or table.concat(bad, ' | ')))
row('mapa', 6, 6, 2, false)
row('mapa', 480, 6, 4, true)
row('mapa', 6, 270, 3, false)
row('retrato', 6, 440, 2, false)
sheet:saveAs(dir .. '_folha.png')
