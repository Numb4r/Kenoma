-- Conferência dos nove conceitos de ritual: refaz os builds e imprime, por quadro, as medidas da régua, as margens
-- (mapa: 2 px livres em cima, 1 embaixo, nada na borda) e as peças soltas da camada corpo (vizinhança de 8).
-- Só imprime os quadros com 'FALHA' e a contagem dos que passam.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rituais/confere.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART')
local NAMES = { 'stormlamp', 'cairnhollow', 'gatewarden', 'noonglass', 'eaveshroud', 'vigilwick', 'staticroost', 'duskwreath', 'cratercoil' }
local say = print
print = function() end
for _, n in ipairs(NAMES) do
  local ok, err = pcall(dofile, ART .. 'creatures/conceitos/rituais/' .. n .. '/build.lua')
  if not ok then say(n .. ' ERRO ' .. tostring(err)) end
end
print = say
local C = dofile(ART .. 'creatures/conceitos/_conceito.lua')
local P = C.PISO.espirito
local function pieces(g)
  local seen, n, small = {}, 0, 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' and not seen[y * g.w + x] then
      n = n + 1
      local stack, size = { y * g.w + x }, 0
      seen[y * g.w + x] = true
      while #stack > 0 do
        local q = table.remove(stack)
        size = size + 1
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = q % g.w + dx, q // g.w + dy
          if nx >= 0 and ny >= 0 and nx < g.w and ny < g.h and g[ny][nx] ~= '.' and not seen[ny * g.w + nx] then
            seen[ny * g.w + nx] = true; stack[#stack + 1] = ny * g.w + nx
          end
        end end
      end
      if size == 1 then small = small + 1 end
    end
  end end
  return n, small
end
for _, n in ipairs(NAMES) do
  for _, kind in ipairs({ 'mapa', 'retrato' }) do
    local base = ART .. 'creatures/conceitos/rituais/' .. n .. '/' .. n .. '_espirito_' .. kind
    local b, e = C.png(base .. '.png'), C.png(base .. '_emissivo.png')
    local m = C.measure(b, e)
    local map = kind == 'mapa'
    local x0, y0, x1, y1, ec, ne = 1e9, 1e9, -1, -1, {}, 0
    for y = 0, b.h - 1 do for x = 0, b.w - 1 do
      if b[y][x] ~= '.' then x0 = math.min(x0, x); x1 = math.max(x1, x); y0 = math.min(y0, y); y1 = math.max(y1, y) end
      if e[y][x] ~= '.' and not ec[e[y][x]] then ec[e[y][x]] = true; ne = ne + 1 end
    end end
    local np, lone = pieces(b)
    local bad = {}
    if m.cores < (map and P.cores or P.rcores) then bad[#bad + 1] = 'cores' end
    if m.detalhe < (map and P.detalhe or P.rdetalhe) then bad[#bad + 1] = 'detalhe' end
    if m.contorno > (map and P.contorno or 0.22) then bad[#bad + 1] = 'contorno' end
    if m.emissivo < (map and P.emissivo[1] or P.remissivo) or m.emissivo > P.emissivo[2] then bad[#bad + 1] = 'emissivo' end
    if ne < 3 then bad[#bad + 1] = 'cores emissivas' end
    if x0 < 1 or x1 > b.w - 2 or y1 > b.h - 2 or y0 < (map and 2 or 1) then bad[#bad + 1] = 'margem' end
    if np > 1 or lone > 0 then bad[#bad + 1] = 'peça solta' end
    if #bad == 0 and not CONFERE_TUDO then PASSAM = (PASSAM or 0) + 1 else say(string.format('%s %s: cores %d det %.2f cont %.2f em %.2f ecor %d caixa %d,%d-%d,%d pecas %d%s', n, kind, m.cores,
      m.detalhe, m.contorno, m.emissivo, ne, x0, y0, x1, y1, np, #bad > 0 and ('  FALHA: ' .. table.concat(bad, ', ')) or '')) end
  end
end
say((PASSAM or 0) .. ' de 18 quadros passam (CONFERE_TUDO = true imprime todos)')
PASSAM = nil
