-- Kenoma 0.26.0: ícones de evento (16 x 16). Carregado por ../climate/build.lua, que traz a paleta, o contorno,
-- a conferência e a folha; rodar este arquivo sozinho roda aquele.
-- Rodar: aseprite -b --script tools/art/ui/event/build.lua
-- Regra de forma: todo evento é uma bandeirola (11 x 13, pano escuro, corte em V embaixo) com o emblema de 9 x 8
-- dentro. Nenhum clima usa a bandeirola, e nenhum evento sai dela: só o miolo muda.
if not K then
  dofile('/home/yuri/Documentos/kenoma/tools/art/ui/climate/build.lua')
  return
end

-- emblem: 8 linhas de 9 px; '.' é o pano.
local function event(id, emblem)
  local rows = { 'OOOOOOOOOOO', 'OMMMMMMMMMO' }
  for _, r in ipairs(emblem) do rows[#rows + 1] = 'O' .. (r:gsub('%.', 'N')) .. 'O' end
  rows[#rows + 1] = 'ONNNNONNNNO'
  rows[#rows + 1] = 'ONNNO.ONNNO'
  rows[#rows + 1] = '.OOO...OOO.'
  if #emblem ~= 8 then rows[#rows + 1] = 'emblema com ' .. #emblem .. ' linhas' end
  K.icon('event', id, rows)
end

-- Ordem de eventos.json.
-- Arco-íris: três arcos.
event('rainbow', {
  '.........',
  '..IIIII..',
  '.IyyyyyI.',
  'IyywwwyyI',
  'Iyw...wyI',
  'Iyw...wyI',
  'Iyw...wyI',
  '.........',
})
-- Tornado: o funil em faixas.
event('tornado', {
  '.........',
  '888888888',
  '.9999999.',
  '..88888..',
  '...9999..',
  '...888...',
  '....99...',
  '....8....',
})
-- Aurora: a cortina, verde em cima e violeta na barra.
event('aurora', {
  '.........',
  'EE..EE...',
  'EEEEEEEEE',
  'SESSESSES',
  'S.SS.SS.S',
  'V.SV.VS.V',
  'V..V.V..V',
  '.........',
})
-- Estática: barras de ruído deslocadas.
event('static', {
  '.........',
  'SSSS.....',
  '..SSSSSS.',
  '.........',
  'WWWWW.VVV',
  '...SSSS..',
  '.VV......',
  '....SSSS.',
})
-- Chuva de meteoros: um meteoro grande e um pequeno, com a cauda.
event('meteor_shower', {
  '.......h.',
  '......h..',
  '.....y...',
  '....y....',
  '..WW....h',
  '..WW...y.',
  '......W..',
  '.........',
})
-- Lua Dupla: a lua e a segunda, lilás.
event('double_moon', {
  '.zzz.....',
  'zzzzz....',
  'zzzzz....',
  'zzzzz.UU.',
  '.zzz.UUUU',
  '.....UUUU',
  '......UU.',
  '.........',
})
-- Sol Negro: o disco escuro e a coroa.
event('black_sun', {
  '....y....',
  '..yyyyy..',
  '.yyOOOyy.',
  '.yOOOOOy.',
  'yyOOOOOyy',
  '.yOOOOOy.',
  '.yyOOOyy.',
  '..yyyyy..',
})
-- Vigília: o olho vermelho.
event('vigil', {
  '.........',
  '..IIIII..',
  '.IWWWWWI.',
  'IWWIOIWWI',
  'IWWIOIWWI',
  '.IWWWWWI.',
  '..IIIII..',
  '.........',
})
-- Silêncio: o sino riscado.
event('silence', {
  '....9..W.',
  '...999W..',
  '..999W9..',
  '..99W99..',
  '..9W999..',
  '.9W99999.',
  '.W..9....',
  '.........',
})
-- Procissão na névoa: a figura de capuz, a vela e a névoa no chão.
event('fog_procession', {
  '...88....',
  '..8888...',
  '..8OO8.y.',
  '..8888.h.',
  '.88888.9.',
  '.88888.9.',
  '.888888..',
  '99.999.99',
})
-- Maré do Véu: a onda violeta quebrando.
event('veil_tide', {
  '.........',
  '...UUU...',
  '..UVVVU..',
  '.UVV.VU..',
  '.UV..U...',
  'UVVV....U',
  'VVVVVUUVV',
  'TTTTTTTTT',
})
-- Vento das Fendas: duas linhas de vento violeta.
event('rift_wind', {
  '.....UU..',
  '.......U.',
  'UUUUUUU..',
  '.........',
  'VVVVVVVV.',
  '........V',
  '......VV.',
  '.........',
})
-- Tempestade de Ecos: o raio violeta.
event('echo_storm', {
  '.....UU..',
  '....UU...',
  '...UU....',
  '..UUUUU..',
  '....VV...',
  '...VV....',
  '..VV.....',
  '..V......',
})
-- Lua Carmim: a lua cheia vermelha.
event('crimson_moon', {
  '.........',
  '...HHH...',
  '..HHHHI..',
  '.HHHHIII.',
  '.HHHIIII.',
  '.HHIIIII.',
  '..IIIII..',
  '...III...',
})
-- Prisma do Véu: o prisma em faixas.
event('veil_prism', {
  '....W....',
  '...WKz...',
  '...WKz...',
  '..WKKzL..',
  '..WKKzL..',
  '.WKKzzLL.',
  '.WKKzzLL.',
  '.........',
})
