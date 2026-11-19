-- Grade de caracteres para as folhas de NPC, veículo e ônibus (0.25.0, pixel de 2 dp).
-- Um caractere por pixel, '.' vazio. Rodar pelo Aseprite: aseprite -b --script build.lua
local L = {}
-- KENOMA_ART (global, com a barra no fim): o tools/art/ do worktree em que se está trabalhando.
L.ROOT = KENOMA_ART or '/home/yuri/Documentos/kenoma/tools/art/'

function L.grid(w, h)
  local g = { w = w, h = h }
  for y = 0, h - 1 do
    g[y] = {}
    for x = 0, w - 1 do g[y][x] = '.' end
  end
  return g
end

function L.get(g, x, y)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return '.' end
  return g[y][x]
end

-- mask: caracteres que podem ser cobertos; nil cobre tudo.
function L.set(g, x, y, c, mask)
  x = math.floor(x + 0.5); y = math.floor(y + 0.5)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
  if mask == nil or mask:find(g[y][x], 1, true) then g[y][x] = c end
end

-- '.' e ' ' não mexem; '_' apaga.
function L.put(g, x0, y0, rows)
  for j, row in ipairs(rows) do
    for i = 1, #row do
      local c = row:sub(i, i)
      if c == '_' then L.set(g, x0 + i - 1, y0 + j - 1, '.')
      elseif c ~= '.' and c ~= ' ' then L.set(g, x0 + i - 1, y0 + j - 1, c) end
    end
  end
end

-- Quadro a partir de linhas, conferindo o tamanho (erro com o número da linha).
function L.frame(rows, w, h, tag)
  if #rows ~= h then error((tag or '?') .. ': ' .. #rows .. ' linhas, esperava ' .. h) end
  for j, row in ipairs(rows) do
    if #row ~= w then error((tag or '?') .. ': linha ' .. j .. ' com ' .. #row .. ' colunas: ' .. row) end
  end
  local g = L.grid(w, h)
  L.put(g, 0, 0, rows)
  return g
end

function L.line(g, x0, y0, x1, y1, c, mask)
  local n = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
  for i = 0, n do
    local t = n == 0 and 0 or i / n
    L.set(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c, mask)
  end
end

function L.rect(g, x0, y0, x1, y1, c, mask)
  for y = y0, y1 do for x = x0, x1 do L.set(g, x, y, c, mask) end end
end

local function inside(x, y, cx, cy, r) return (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r end

function L.disc(g, cx, cy, r, c, mask)
  for y = math.floor(cy - r), math.ceil(cy + r) do
    for x = math.floor(cx - r), math.ceil(cx + r) do
      if inside(x, y, cx, cy, r) then L.set(g, x, y, c, mask) end
    end
  end
end

-- Anel de 1 px sem dobra em L: os pixels de dentro com um vizinho de lado fora.
function L.ring(g, cx, cy, r, c, mask)
  for y = math.floor(cy - r), math.ceil(cy + r) do
    for x = math.floor(cx - r), math.ceil(cx + r) do
      if inside(x, y, cx, cy, r) and not (inside(x - 1, y, cx, cy, r) and inside(x + 1, y, cx, cy, r)
            and inside(x, y - 1, cx, cy, r) and inside(x, y + 1, cx, cy, r)) then
        L.set(g, x, y, c, mask)
      end
    end
  end
end

-- Contorno de 1 px só por fora (o vazio fechado dentro da forma fica vazio). Pixel já em [c] não puxa contorno;
-- [solid]: se dado, só esses caracteres puxam.
function L.outline(g, c, solid)
  local ext, stack = {}, {}
  local function push(x, y)
    if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
    local k = y * g.w + x
    if ext[k] or g[y][x] ~= '.' then return end
    ext[k] = true; stack[#stack + 1] = k
  end
  for x = 0, g.w - 1 do push(x, 0); push(x, g.h - 1) end
  for y = 0, g.h - 1 do push(0, y); push(g.w - 1, y) end
  while #stack > 0 do
    local k = table.remove(stack)
    local x, y = k % g.w, k // g.w
    push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1)
  end
  local function pulls(x, y)
    local ch = L.get(g, x, y)
    if ch == '.' or ch == c then return false end
    return solid == nil or solid:find(ch, 1, true) ~= nil
  end
  local add = {}
  for k in pairs(ext) do
    local x, y = k % g.w, k // g.w
    if pulls(x - 1, y) or pulls(x + 1, y) or pulls(x, y - 1) or pulls(x, y + 1) then add[#add + 1] = { x, y } end
  end
  for _, p in ipairs(add) do g[p[2]][p[1]] = c end
end

-- Quadros lado a lado numa folha.
function L.sheet(frames)
  local fw, fh = frames[1].w, frames[1].h
  local g = L.grid(fw * #frames, fh)
  for i, f in ipairs(frames) do
    for y = 0, fh - 1 do for x = 0, fw - 1 do g[y][(i - 1) * fw + x] = f[y][x] end end
  end
  return g
end

local function rgba(hex)
  local r, gg, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  local a = #hex >= 9 and tonumber(hex:sub(8, 9), 16) or 255
  return app.pixelColor.rgba(r, gg, b, a)
end

-- layers: { { name=, grid=, png= (caminho, opcional) } }, de baixo para cima. Cada png sai só com a própria camada.
function L.save(base, legend, layers)
  local w, h = layers[1].grid.w, layers[1].grid.h
  local spr = Sprite(w, h, ColorMode.RGB)
  local col, missing = {}, {}
  for ch, hex in pairs(legend) do col[ch] = rgba(hex) end
  for i, ly in ipairs(layers) do
    local layer = i == 1 and spr.layers[1] or spr:newLayer()
    layer.name = ly.name
    local img = Image(w, h, ColorMode.RGB)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local ch = ly.grid[y][x]
        if ch ~= '.' then
          if col[ch] then img:putPixel(x, y, col[ch]) else missing[ch] = true end
        end
      end
    end
    spr:newCel(layer, 1, img, Point(0, 0))
  end
  for ch in pairs(missing) do print('SEM COR em ' .. base .. ': ' .. ch) end
  for _, ly in ipairs(layers) do
    if ly.png then
      for _, l in ipairs(spr.layers) do l.isVisible = (l.name == ly.name) end
      spr:saveCopyAs(ly.png)
    end
  end
  for _, l in ipairs(spr.layers) do l.isVisible = true end
  spr:saveAs(base .. '.aseprite')
  spr:close()
  print('ok ' .. base .. ' ' .. w .. 'x' .. h)
end

return L
