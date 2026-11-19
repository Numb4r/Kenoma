-- Ajudante dos conceitos de criatura (Etapa 1): um quadro parado por etapa, corpo + emissivo.
-- A régua (tamanhos e pisos) está em docs/art/estilo-criaturas.md; PISO abaixo é a cópia que este arquivo confere.
--
-- COMO USAR (no build.lua da família, em tools/art/creatures/conceitos/<familia>/build.lua):
--
--   local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/conceitos/_conceito.lua')
--   local L = C.L                                   -- a lib de grade: grid, get, set, put, frame, line, rect, disc, ring, outline
--   local LEG = { A = '#1A1424', G = '#34305E', h = '#17444C', H = '#5FD3C6', S = '#FFD84A' }
--   local g = L.grid(C.PISO.espirito.mapa, C.PISO.espirito.mapa)
--   ... desenhe em g com os emissivos ACESOS (H) ...
--   L.outline(g, 'A')
--   C.save('hum', 'espirito', 'mapa', g, LEG, { H = 'h' }, 'S')
--
-- Rodar (MCP do Aseprite, run_lua_script), sempre com o caminho do SEU worktree:
--   KENOMA_ART='/home/yuri/Documentos/kenoma-arte/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/<familia>/build.lua')
--
-- C.save(familia, etapa, tipo, g, legenda, aceso, solto)
--   etapa: 'fagulha' | 'eco' | 'espirito' | 'entidade' | 'arquetipo';  tipo: 'mapa' | 'retrato'
--   aceso: { caractere aceso = caractere apagado }. O aceso vai para o emissivo e o apagado fica embaixo dele no corpo.
--   solto: caracteres que só existem no emissivo (faísca solta, sem par no corpo). Opcional.
--   Grava <familia>_<etapa>_<tipo>.png, ..._emissivo.png e o .aseprite (camadas corpo e emissivo) na pasta da família,
--   e imprime as medidas da régua, com "ABAIXO DO PISO" no que não passar. O tamanho do quadro é conferido (erro se errado).
-- C.measure(corpo, emissivo): as mesmas medidas, para grades de cor (C.png(caminho) lê um PNG como grade de cor).
-- C.poly(g, pontos, c, mask): polígono cheio.  C.mirror(g): copia a metade esquerda na direita.
--
-- Depois de gravar: view_sprite e lint_sprite (layer_name 'corpo') em cada .aseprite, e a folha da família sai com
--   python3 tools/art/creatures/conceitos/folhas.py   (docs/art/conceitos/<familia>.png)
-- Cada família só escreve na própria pasta; este arquivo e o folhas.py não se editam numa sessão de família.
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (caminho absoluto de tools/art/ do worktree, com a barra no fim)')
local C = {}
C.L = dofile(ART .. 'npc/_lib.lua')
C.DIR = ART .. 'creatures/conceitos/'
C.OUTLINE = '1a1424'

-- Pisos por etapa (docs/art/estilo-criaturas.md, "Régua"). cores e detalhe são mínimos; contorno é teto;
-- emissivo é a faixa { mínimo, máximo } da fração emissivo / opacos do corpo. As chaves com r são as do retrato
-- (o teto de contorno do retrato é 0.22 e o teto de emissivo é o do mapa, em toda etapa).
C.PISO = {
  fagulha   = { mapa = 12, retrato = 96,  cores = 6,  detalhe = 0.85, contorno = 0.45, emissivo = { 0.15, 0.50 }, rcores = 10, rdetalhe = 0.40, remissivo = 0.10 },
  eco       = { mapa = 28, retrato = 96,  cores = 10, detalhe = 0.80, contorno = 0.28, emissivo = { 0.06, 0.14 }, rcores = 14, rdetalhe = 0.40, remissivo = 0.05 },
  espirito  = { mapa = 36, retrato = 96,  cores = 12, detalhe = 0.75, contorno = 0.28, emissivo = { 0.09, 0.18 }, rcores = 16, rdetalhe = 0.45, remissivo = 0.07 },
  entidade  = { mapa = 48, retrato = 96,  cores = 14, detalhe = 0.70, contorno = 0.26, emissivo = { 0.12, 0.24 }, rcores = 16, rdetalhe = 0.50, remissivo = 0.09 },
  arquetipo = { mapa = 64, retrato = 128, cores = 14, detalhe = 0.65, contorno = 0.24, emissivo = { 0.16, 0.40 }, rcores = 16, rdetalhe = 0.50, remissivo = 0.14 },
}

local function hex(c)
  return string.format('%02x%02x%02x', app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c))
end

-- PNG como grade de cor ('rrggbb' ou '.').
function C.png(path)
  local im = Image { fromFile = path }
  local g = { w = im.width, h = im.height }
  for y = 0, g.h - 1 do
    g[y] = {}
    for x = 0, g.w - 1 do
      local c = im:getPixel(x, y)
      g[y][x] = app.pixelColor.rgbaA(c) > 0 and hex(c) or '.'
    end
  end
  return g
end

-- Medidas da régua sobre grades de cor. opacos: pixels do corpo. cores: cores distintas do corpo (contorno e apagados
-- contam). contorno: fração dos opacos na cor do contorno. detalhe: fração dos pixels de dentro (opacos fora o
-- contorno) com um vizinho de lado, também de dentro, de outra cor. emissivo: pixels do emissivo / opacos.
function C.measure(body, em)
  local op, out, inner, det, ncol, cols, lit = 0, 0, 0, 0, 0, {}, 0
  for y = 0, body.h - 1 do
    for x = 0, body.w - 1 do
      local c = body[y][x]
      if c ~= '.' then
        op = op + 1
        if not cols[c] then cols[c] = true; ncol = ncol + 1 end
        if c == C.OUTLINE then out = out + 1 else
          inner = inner + 1
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local q = C.L.get(body, x + d[1], y + d[2])
            if q ~= '.' and q ~= C.OUTLINE and q ~= c then det = det + 1; break end
          end
        end
      end
      if em and em[y][x] ~= '.' then lit = lit + 1 end
    end
  end
  return { opacos = op, cores = ncol, contorno = out / math.max(op, 1), detalhe = det / math.max(inner, 1),
    emissivo = lit / math.max(op, 1) }
end

function C.poly(g, pts, c, mask)
  local y0, y1 = math.huge, -math.huge
  for _, p in ipairs(pts) do y0 = math.min(y0, p[2]); y1 = math.max(y1, p[2]) end
  for y = math.floor(y0), math.ceil(y1) do
    local xs = {}
    for i = 1, #pts do
      local a, b = pts[i], pts[i % #pts + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = math.ceil(xs[i] - 0.5), math.floor(xs[i + 1] + 0.5) do C.L.set(g, x, y, c, mask) end
    end
  end
end

function C.mirror(g)
  for y = 0, g.h - 1 do
    for x = 0, g.w // 2 - 1 do g[y][g.w - 1 - x] = g[y][x] end
  end
end

function C.save(fam, stage, kind, g, legend, lit, loose)
  local P = assert(C.PISO[stage], 'etapa desconhecida: ' .. tostring(stage))
  assert(kind == 'mapa' or kind == 'retrato', 'tipo: mapa ou retrato')
  local size = P[kind]
  assert(g.w == size and g.h == size, string.format('%s %s %s: %dx%d, a régua pede %dx%d', fam, stage, kind, g.w, g.h, size, size))
  lit, loose = lit or {}, loose or ''
  local b, e = C.L.grid(g.w, g.h), C.L.grid(g.w, g.h)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = g[y][x]
      if c ~= '.' then
        assert(legend[c], 'sem cor na legenda: ' .. c)
        if lit[c] then b[y][x] = lit[c]; e[y][x] = c
        elseif loose:find(c, 1, true) then e[y][x] = c
        else b[y][x] = c end
      end
    end
  end
  local base = C.DIR .. fam .. '/' .. fam .. '_' .. stage .. '_' .. kind
  C.L.save(base, legend, {
    { name = 'corpo', grid = b, png = base .. '.png' },
    { name = 'emissivo', grid = e, png = base .. '_emissivo.png' },
  })
  local m = C.measure(C.png(base .. '.png'), C.png(base .. '_emissivo.png'))
  local map = kind == 'mapa'
  local cores, detalhe = map and P.cores or P.rcores, map and P.detalhe or P.rdetalhe
  local contorno, emin = map and P.contorno or 0.22, map and P.emissivo[1] or P.remissivo
  local bad = {}
  if m.cores < cores then bad[#bad + 1] = 'cores < ' .. cores end
  if m.detalhe < detalhe then bad[#bad + 1] = 'detalhe < ' .. detalhe end
  if m.contorno > contorno then bad[#bad + 1] = 'contorno > ' .. contorno end
  if m.emissivo < emin or m.emissivo > P.emissivo[2] then
    bad[#bad + 1] = 'emissivo fora de ' .. emin .. '..' .. P.emissivo[2]
  end
  print(string.format('  %s %s: opacos %d, cores %d, detalhe %.2f, contorno %.2f, emissivo %.2f%s', stage, kind,
    m.opacos, m.cores, m.detalhe, m.contorno, m.emissivo, #bad > 0 and ('  ABAIXO DO PISO: ' .. table.concat(bad, '; ')) or ''))
  return m
end

return C
