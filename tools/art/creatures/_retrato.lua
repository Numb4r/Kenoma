-- Acabamento do retrato de 128 do Arquétipo, desenhado no tamanho do retrato (docs/art/estilo-criaturas.md,
-- "Retrato do Arquétipo"). As formas continuam as do draw da espécie (a mesma silhueta e o mesmo vão do 64); aqui
-- entra o que só cabe em 128, pixel a pixel, nunca em bloco de 2:
--   RT.vao      o vão com fundo: do violeta da borda ao quase preto, com o céu de lá (poeira em faixa e estrelas na
--               luz do tipo, cada uma piscando no seu passo); a borda respira
--   RT.relight  o corpo: a base do degrau sem o bloco da textura ampliada, o volume (luz de cima à esquerda), a luz
--               do tipo (clareia ou, no Soot, escurece), a textura do material e a borda recortada na luz do tipo,
--               na camada glow (por fora e em volta do vão)
--   RT.tear     a moldura: o busto acaba num rasgo a pelo menos m px da borda, sem peça solta
-- Uso, no build.lua da espécie:  local RT = dofile(KENOMA_ART .. 'creatures/_retrato.lua')(K)   (K: o kit, com L e hash)
--   RT.install(LEG, LIT) antes do run; no draw, no lugar do rasgo antigo: if o.bust then RT.finish(g, o, CFG) end
-- Caracteres que o install acrescenta (não usar para outra coisa): ! @ $ % (violeta do vão, glow) e = * (o fundo, corpo).
return function(K)
  local L = K.L
  local function hash(x, y, k)                                -- o do _hum.lua (o do _wisp.lua devolve fração)
    local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
    v = v ~ (v >> 13)
    return (v * 1274126177) & 0x7fffffff
  end
  local floor, sqrt, abs, max, min, sin, cos = math.floor, math.sqrt, math.abs, math.max, math.min, math.sin, math.cos
  local RT = {}
  RT.CHARS = '!@$%=*'
  local BAYER = { [0] = { [0] = 0, 8, 2, 10 }, { [0] = 12, 4, 14, 6 }, { [0] = 3, 11, 1, 9 }, { [0] = 15, 7, 13, 5 } }
  local function bay(x, y) return (BAYER[y % 4][x % 4] + 0.5) / 16 end
  local function has(s, c) return s:find(c, 1, true) ~= nil end

  function RT.install(LEG, LIT)
    LEG['!'] = '#9B7BFF'; LEG['@'] = '#5A45A8'; LEG['$'] = '#3B2D78'; LEG['%'] = '#261D4E'
    LEG['='] = '#1B1230'; LEG['*'] = '#0D0914'
    LIT['!'] = { '=', 'w' }; LIT['@'] = { '=', 'w' }; LIT['$'] = { '*', 'w' }; LIT['%'] = { '*', 'w' }
  end

  -- Distância (px, chanfro 1 / 1,4) até o ponto mais próximo em que seed(x, y) vale.
  function RT.dist(g, seed)
    local W, H, d = g.w, g.h, {}
    for y = 0, H - 1 do
      d[y] = {}
      for x = 0, W - 1 do d[y][x] = seed(x, y) and 0 or 1e9 end
    end
    local function rx(x, y, nx, ny, w)
      if nx >= 0 and ny >= 0 and nx < W and ny < H and d[ny][nx] + w < d[y][x] then d[y][x] = d[ny][nx] + w end
    end
    for y = 0, H - 1 do for x = 0, W - 1 do
      rx(x, y, x - 1, y, 1); rx(x, y, x, y - 1, 1); rx(x, y, x - 1, y - 1, 1.4); rx(x, y, x + 1, y - 1, 1.4)
    end end
    for y = H - 1, 0, -1 do for x = W - 1, 0, -1 do
      rx(x, y, x + 1, y, 1); rx(x, y, x, y + 1, 1); rx(x, y, x + 1, y + 1, 1.4); rx(x, y, x - 1, y + 1, 1.4)
    end end
    return d
  end

  -- A região do vão: nasce dos caracteres de seed e se espalha por set e keep.
  local function region(g, cfg)
    local reg, st, all = {}, {}, cfg.set .. (cfg.keep or '') .. RT.CHARS
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if has(cfg.seed, g[y][x]) then reg[y * g.w + x] = true; st[#st + 1] = { x, y } end
    end end
    while #st > 0 do
      local q = table.remove(st)
      for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nx, ny = q[1] + dd[1], q[2] + dd[2]
        local c = L.get(g, nx, ny)
        if c ~= '.' and not reg[ny * g.w + nx] and has(all, c) then reg[ny * g.w + nx] = true; st[#st + 1] = { nx, ny } end
      end
    end
    return reg
  end

  -- cfg = { seed = violetas que só o vão tem, set = o que é reescrito (fundo, xadrez, borda), keep = o que vive lá
  --   dentro e fica, depth = px da borda ao fundo, star = { fraca, forte } (luz do tipo), sky = ângulo da faixa,
  --   t = function(x, y) -> 0 (borda) .. 1 (fundo), para o vão que já tem perspectiva própria }
  function RT.vao(g, ph, cfg)
    local reg = region(g, cfg)
    local d = RT.dist(g, function(x, y) return not reg[y * g.w + x] end)
    local br = ({ [0] = 0, 0.9, 1.8, 0.9 })[ph % 4]              -- a borda respira
    local depth = cfg.depth or 12
    local a = math.rad(cfg.sky or 35)
    local ca, sa = cos(a), sin(a)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if reg[y * g.w + x] and has(cfg.set, g[y][x]) then
        local dd = d[y][x]
        local t = cfg.t and cfg.t(x, y) or min(1, max(0, (dd - 1.5 - br) / depth))
        local lv = t * 5.3 + (bay(x, y) - 0.5) * 1.15
        local ch
        if not cfg.t and dd <= 1.5 + br * 0.6 then ch = '!'
        elseif lv < 0.5 then ch = '!' elseif lv < 1.5 then ch = '@' elseif lv < 2.5 then ch = '$'
        elseif lv < 3.5 then ch = '%' elseif lv < 4.4 then ch = '=' else ch = '*' end
        if t > 0.42 then
          -- o céu de lá: uma faixa de poeira atravessa o fundo e desliza; as estrelas piscam cada uma no seu passo
          local across, along = -x * sa + y * ca, x * ca + y * sa
          local band = abs((across + ph * 1.5 + 5 * sin(along / 9)) % 30 - 15)
          if band < 3.4 and hash(x, y, 31) % 3 == 0 then ch = band < 1.3 and '$' or '%' end
          local h = hash(x, y, 47)
          if h % 41 == 0 then
            local tw = ((h // 41) + ph) % 4
            if tw == 0 then ch = cfg.star[2] elseif tw == 1 then ch = cfg.star[1] elseif tw == 2 then ch = '$' end
          end
        end
        g[y][x] = ch
      end
    end end
    return reg
  end

  -- Texturas do material, no pixel: devolvem um desvio do degrau (-amp .. amp).
  RT.tex = {}
  function RT.tex.fur(dx, dy, amp, len)                         -- fios ao longo de (dx, dy)
    local n = sqrt(dx * dx + dy * dy); dx, dy = dx / n, dy / n
    return function(x, y)
      local u, v = x * dx + y * dy, floor(-x * dy + y * dx + 0.5)
      return ((hash(floor((u + hash(v, 0, 5) % 7) / (len or 4)), v, 9) % 100) / 100 - 0.5) * 2 * (amp or 0.3)
    end
  end
  function RT.tex.pit(amp, n)                                   -- ferro, concreto: poros e grãos
    return function(x, y)
      local h = hash(x, y, 13) % (n or 7)
      return h == 0 and -(amp or 0.35) or (h == 1 and (amp or 0.35) * 0.6 or 0)
    end
  end
  function RT.tex.stone(amp)                                    -- pedra e osso: poros raros e trincas compridas
    return function(x, y)
      if abs((x * 0.35 + y + 5 * sin(x / 11)) % 19) < 1 and hash(x // 9, y // 9, 3) % 3 ~= 0 then return -(amp or 0.35) end
      local h = hash(x, y, 13) % 11
      return h == 0 and -(amp or 0.35) or (h == 1 and (amp or 0.35) * 0.5 or 0)
    end
  end
  function RT.tex.weave(amp)                                    -- pano: trama
    return function(x, y)                                       -- sarja: o fio escuro corre em diagonal
      if (x + 2 * y) % 5 == 0 then return -(amp or 0.2) end
      return (x - 2 * y) % 7 == 0 and (amp or 0.2) or 0
    end
  end
  function RT.tex.scale(p, amp)                                 -- escama: fileiras alternadas, a aresta de baixo escura
    return function(x, y)
      local row = floor(y / p)
      local xx = (x + (row % 2) * p / 2) % p
      local e = (y % p) - (p - 1) + abs(xx - p / 2) * 0.9
      return e >= 0 and -(amp or 0.35) or ((y % p) == 0 and (amp or 0.35) * 0.6 or 0)
    end
  end

  -- cfg = { ramps = { { 'escuro..claro', textura } }, lights = caracteres da luz do tipo, sign = 1 | -1 (o Soot
  --   escurece perto da brasa), lw = peso da luz, R = alcance em px, blur = raio da base, rim = { perto, longe }
  --   (glow, a luz do tipo), rimLights = de onde vem a luz da borda (padrão: lights) }; reg: a região do vão.
  function RT.relight(g, cfg, reg)
    local W, H = g.w, g.h
    local rampOf, lvOf = {}, {}
    for _, r in ipairs(cfg.ramps) do
      for i = 1, #r[1] do local c = r[1]:sub(i, i); rampOf[c] = r; lvOf[c] = i end
    end
    local de = RT.dist(g, function(x, y) return g[y][x] == '.' end)
    local dl = RT.dist(g, function(x, y) return has(cfg.lights, g[y][x]) end)
    local dr = cfg.rimLights and RT.dist(g, function(x, y) return has(cfg.rimLights, g[y][x]) end) or dl
    local dv = reg and RT.dist(g, function(x, y) return reg[y * W + x] == true end)
    local R, b = cfg.R or 12, cfg.blur or 2
    local function dv6(x, y)
      if x < 0 or y < 0 or x >= W or y >= H then return 6 end
      return min(de[y][x], 6)
    end
    local out = {}
    for y = 0, H - 1 do
      out[y] = {}
      for x = 0, W - 1 do
        local c = g[y][x]
        local r = rampOf[c]
        if r then
          local n = #r[1]
          local s, m = 0, 0
          for j = -b, b do for i = -b, b do
            local q = L.get(g, x + i, y + j)
            if rampOf[q] == r then s = s + lvOf[q]; m = m + 1 end
          end end
          local base = (s / m - 1) / (n - 1)
          local gx, gy = dv6(x + 1, y) - dv6(x - 1, y), dv6(x, y + 1) - dv6(x, y - 1)
          local gl = sqrt(gx * gx + gy * gy)
          local form = gl > 0 and (gx * 0.6 + gy * 0.8) / gl * max(0, 1 - (de[y][x] - 1) / 6) or 0
          local lt = max(0, 1 - dl[y][x] / R) * (cfg.sign or 1)
          local v = base + 0.3 * form + (cfg.lw or 0.3) * lt + (r[2] and r[2](x, y) or 0) + (bay(x, y) - 0.5) * 0.5 / (n - 1)
          local i = floor(max(0, min(1, v)) * (n - 1) + 0.5) + 1
          c = r[1]:sub(i, i)
          -- a borda recortada pela luz do tipo: por fora, perto da luz; e em volta do vão
          if cfg.rim then
            local near = dr[y][x]
            local rr = cfg.rimR or R
            if de[y][x] <= 1.45 and near <= rr and hash(x // 3, y // 3, 23) % 4 ~= 0 then
              c = near <= rr * 0.45 and cfg.rim[1] or cfg.rim[2]
            elseif dv and cfg.rimVao ~= false and dv[y][x] <= 1.45 and hash(x, y, 29) % 3 ~= 0 then c = cfg.rim[2] end
          end
        end
        out[y][x] = c
      end
    end
    for y = 0, H - 1 do for x = 0, W - 1 do g[y][x] = out[y][x] end end
  end

  -- O rasgo da moldura: nada a menos de m px da borda; o corte ondula até 5 px para dentro, no pixel.
  function RT.tear(g, m)
    local function n1(i, s)
      local a, b = hash(i // 6, s, 3) % 100, hash(i // 6 + 1, s, 3) % 100
      return (a + (b - a) * (i % 6) / 6) / 100
    end
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] ~= '.' then
        local l, r, t, bt = x, g.w - 1 - x, y, g.h - 1 - y
        local e = min(l, r, t, bt)
        local along = (e == l or e == r) and y or x
        local side = e == l and 1 or (e == r and 2 or (e == t and 3 or 4))
        if e < m + 4 * n1(along, side) + hash(along, side, 5) % 2 then g[y][x] = '.' end
      end
    end end
    -- só a peça maior fica
    local seen, best, comps = {}, nil, {}
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] ~= '.' and not seen[y * g.w + x] then
        local comp, st = {}, { { x, y } }
        seen[y * g.w + x] = true
        while #st > 0 do
          local q = table.remove(st)
          comp[#comp + 1] = q
          for dy = -1, 1 do for dx = -1, 1 do
            local nx, ny = q[1] + dx, q[2] + dy
            if L.get(g, nx, ny) ~= '.' and not seen[ny * g.w + nx] then seen[ny * g.w + nx] = true; st[#st + 1] = { nx, ny } end
          end end
        end
        comps[#comps + 1] = comp
        if not best or #comp > #best then best = comp end
      end
    end end
    for _, comp in ipairs(comps) do
      if comp ~= best then for _, q in ipairs(comp) do g[q[2]][q[1]] = '.' end end
    end
  end

  -- cfg = { vao = { ... }, light = { ... }, margin = px }
  function RT.finish(g, o, cfg)
    local ph = (o.ph or 0) % 4
    local reg = RT.vao(g, ph, cfg.vao)
    RT.relight(g, cfg.light, reg)
    if cfg.margin ~= false then RT.tear(g, cfg.margin or 5) end
  end

  return RT
end
