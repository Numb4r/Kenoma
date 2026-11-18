-- Apoio do tráfego e das Fagulhas (0.25.1): quadros de verdade no .aseprite, tira em PNG por camada,
-- conferência (um pedaço só, nada na borda) e folha de conferência. A grade de caracteres é a do npc/_lib.lua.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local S = { L = L }

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function pc(hex)
  local r, g, b = rgb(hex)
  return app.pixelColor.rgba(r, g, b, 255)
end

-- Mistura a para b em t (0 a 1), em hex.
function S.mix(a, b, t)
  local r0, g0, b0 = rgb(a)
  local r1, g1, b1 = rgb(b)
  local function m(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return string.format('#%02X%02X%02X', m(r0, r1), m(g0, g1), m(b0, b1))
end

function S.copy(g)
  local c = L.grid(g.w, g.h)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do c[y][x] = g[y][x] end end
  return c
end

-- Só os caracteres de [chars], trocados por [map] se houver.
function S.pick(g, chars, map)
  local c = L.grid(g.w, g.h)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local ch = g[y][x]
      if ch ~= '.' and chars:find(ch, 1, true) then c[y][x] = map and map[ch] or ch end
    end
  end
  return c
end

-- O que [comp] tem de diferente de [base]: a peça de roupa sozinha, com o contorno dela.
function S.diff(comp, base)
  local c = L.grid(comp.w, comp.h)
  for y = 0, comp.h - 1 do
    for x = 0, comp.w - 1 do
      if comp[y][x] ~= base[y][x] then c[y][x] = comp[y][x] end
    end
  end
  return c
end

function S.swap(g, x0, y0, x1, y1, map)
  for y = y0, y1 do
    for x = x0, x1 do
      local c = L.get(g, x, y)
      if map[c] then g[y][x] = map[c] end
    end
  end
end

S.problems = 0
-- Um pedaço só (diagonal conta) e nada na borda. Imprime o que achar.
function S.check(tag, g)
  local seen, n = {}, 0
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if g[y][x] ~= '.' then
        if x == 0 or y == 0 or x == g.w - 1 or y == g.h - 1 then
          print('BORDA ' .. tag .. ' ' .. x .. ',' .. y); S.problems = S.problems + 1
        end
        if not seen[y * g.w + x] then
          n = n + 1
          local stack = { { x, y } }
          seen[y * g.w + x] = true
          while #stack > 0 do
            local p = table.remove(stack)
            for dy = -1, 1 do
              for dx = -1, 1 do
                local qx, qy = p[1] + dx, p[2] + dy
                if L.get(g, qx, qy) ~= '.' and not seen[qy * g.w + qx] then
                  seen[qy * g.w + qx] = true; stack[#stack + 1] = { qx, qy }
                end
              end
            end
          end
        end
      end
    end
  end
  if n ~= 1 then print('SOLTA ' .. tag .. ': ' .. n .. ' pedaços'); S.problems = S.problems + 1 end
end

-- layers: { { name=, frames={grade,...}, png= (tira, opcional), hidden= } }, de baixo para cima.
function S.save(base, legend, layers, fps)
  local g0 = layers[1].frames[1]
  local w, h, n = g0.w, g0.h, #layers[1].frames
  local spr = Sprite(w, h, ColorMode.RGB)
  for _ = 2, n do spr:newEmptyFrame() end
  for i = 1, n do spr.frames[i].duration = 1 / (fps or 4) end
  local col = {}
  for ch, hex in pairs(legend) do col[ch] = pc(hex) end
  for i, ly in ipairs(layers) do
    local layer = i == 1 and spr.layers[1] or spr:newLayer()
    layer.name = ly.name
    local strip = Image(w * n, h, ColorMode.RGB)
    for f = 1, n do
      local img, g = Image(w, h, ColorMode.RGB), ly.frames[f]
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local ch = g[y][x]
          if ch ~= '.' then
            if col[ch] then
              img:putPixel(x, y, col[ch]); strip:putPixel((f - 1) * w + x, y, col[ch])
            else
              print('SEM COR em ' .. base .. ': ' .. ch); S.problems = S.problems + 1
            end
          end
        end
      end
      spr:newCel(layer, f, img, Point(0, 0))
    end
    if ly.png then strip:saveAs(ly.png) end
    layer.isVisible = not ly.hidden
  end
  spr:saveAs(base .. '.aseprite')
  spr:close()
  print('ok ' .. base .. ' ' .. w .. 'x' .. h .. ' x' .. n)
end

-- Folha de conferência: chão em bandas, [items] = { { g=, x=, y=, leg=, glow= } } de dia à esquerda e de noite à
-- direita (tom da noite por cima de tudo, depois o _glow sem tom), ampliada [k] vezes por vizinho mais próximo.
-- bands: { { y0, y1, x0, x1, base, dark, light } } em coordenadas da metade.
function S.folha(path, hw, h, bands, items, k)
  local img = Image(hw * 2, h, ColorMode.RGB)
  for half = 0, 1 do
    for _, b in ipairs(bands) do
      local base, dark, light = pc(b[5]), pc(b[6]), pc(b[7])
      for y = b[1], b[2] do
        for x = b[3], b[4] do
          local hsh = (x * 7 + y * 13 + (x * y) % 5) % 23
          img:putPixel(half * hw + x, y, hsh == 0 and dark or (hsh == 11 and light or base))
        end
      end
    end
    for _, it in ipairs(items) do
      for y = 0, it.g.h - 1 do
        for x = 0, it.g.w - 1 do
          local ch = it.g[y][x]
          if ch ~= '.' then img:putPixel(half * hw + it.x + x, it.y + y, pc(it.leg[ch])) end
        end
      end
    end
  end
  -- Noite: #141033 a 58% (docs/art/estilo-mapa.md, curva de luz).
  local a = 0.58
  for y = 0, h - 1 do
    for x = hw, hw * 2 - 1 do
      local p = img:getPixel(x, y)
      local function m(v, n) return math.floor(v * (1 - a) + n * a + 0.5) end
      img:putPixel(x, y, app.pixelColor.rgba(m(app.pixelColor.rgbaR(p), 0x14), m(app.pixelColor.rgbaG(p), 0x10), m(app.pixelColor.rgbaB(p), 0x33), 255))
    end
  end
  for _, it in ipairs(items) do
    if it.glow then
      for y = 0, it.glow.h - 1 do
        for x = 0, it.glow.w - 1 do
          local ch = it.glow[y][x]
          if ch ~= '.' then img:putPixel(hw + it.x + x, it.y + y, pc(it.leg[ch])) end
        end
      end
    end
  end
  local big = Image(hw * 2 * k, h * k, ColorMode.RGB)
  for y = 0, h * k - 1 do
    for x = 0, hw * 2 * k - 1 do big:putPixel(x, y, img:getPixel(x // k, y // k)) end
  end
  big:saveAs(path)
  print('ok ' .. path .. ' ' .. hw * 2 * k .. 'x' .. h * k)
end

return S
