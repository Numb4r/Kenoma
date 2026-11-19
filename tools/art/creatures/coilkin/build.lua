-- Coilkin (hum.spirit), arte final: o Espírito da família Hum, a partir do conceito aprovado. A mariposa tomada
-- pelos fios: abdômen em bobina de cobre, asas de trás só na armação de fio, três antenas (a do meio é um fio
-- desencapado), três olhos nas asas (dois numa, um na outra).
-- O ELEMENTO ERRADO (o que o Humoth não tem): o peito abriu. A bobina sobe por dentro do tórax e, no meio dela, onde
-- não devia haver nada, abre um quarto olho de LED: o letreiro tomou o corpo por dentro e olha de lá.
-- Costura do Véu: uma só, de 2 px, atravessando a asa direita (a de um olho só), onde a ponta foi cosida de volta.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/coilkin/build.lua')
local K = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_hum.lua')
local L, C = K.L, K.C
local floor, ceil = math.floor, math.ceil

-- Batida de asa, vista de cima: { comprimento, largura, graus para cima }.
local FLAP = { [0] = { 1, 1, 0 }, { 0.85, 0.95, 6 }, { 0.68, 0.9, 12 } }

local function draw(g, sg, k, o)
  local S = 36 * k
  local cx = S / 2 - 0.5
  local ph = (o.ph or 0) % 4
  local f = ({ [0] = 0, 1, 2, 1 })[ph]
  if o.pose == 'crouch' then f = 2 elseif o.pose == 'alert' then f = 0 end
  local ls, ws, up = FLAP[f][1], FLAP[f][2], FLAP[f][3]
  if o.pose == 'alert' then up = -5 end
  local th = math.max(1, floor(k + 0.5))
  local wings = {}
  for _, sd in ipairs({ -1, 1 }) do
    -- asas de trás: três fios de cobre e um resto de membrana
    local rx, ry = cx + sd * 2 * k, 18 * k
    local ends = { { cx + sd * 13 * ls * k, 22.5 * k }, { cx + sd * 10.5 * ls * k, 28 * k }, { cx + sd * 6 * ls * k, 31 * k } }
    C.poly(g, { { rx, ry }, { cx + sd * 9 * ls * k, 21 * k }, { cx + sd * 7.5 * ls * k, 25.5 * k } }, 'P')
    C.poly(g, { { rx, ry }, { cx + sd * 6 * ls * k, 20 * k }, { cx + sd * 5 * ls * k, 22.5 * k } }, 'Q')
    for n, e in ipairs(ends) do
      K.wire(g, { { rx, ry }, { (rx + e[1]) / 2, (ry + e[2]) / 2 + (2 - n * 0.5) * k }, e }, 'k', n == 2 and 'm' or 'q', k)
      L.rect(g, floor(e[1] + 0.5), floor(e[2] + 0.5), floor(e[1] + 0.5) + th - 1, floor(e[2] + 0.5) + th - 1, 'Y')
      -- a faísca que cai da ponta de cada fio
      local fall = (ph + n) % 4
      if fall > 0 or (o.hot or 0) > 0 then K.dot(sg, e[1] + sd * 1.5 * k, e[2] + (1 + fall * 0.7) * k, k, fall == 2 and 's' or 'S') end
    end
    local w = { x = cx + sd * 2.5 * k, y = 13.5 * k, ang = sd < 0 and (203 + up) or (-23 - up), len = 12.5 * ls * k,
      wid = 8 * ws * k, side = sd, pal = { 'E', 'F', 'G', 'P' }, band = 2, torn = 3 * k, rich = k > 1 }
    K.wing(g, w)
    wings[sd] = w
  end
  -- costura do Véu: 2 px, de borda a borda da asa direita
  K.veins(g, wings[1], { { 0.76, 0.02, 0.66, 0.98 } }, 2 * th, 'X')
  local eyes = { { wings[-1], 0.30 }, { wings[-1], 0.68 }, { wings[1], 0.40 } }
  for _, e in ipairs(eyes) do
    K.veins(g, e[1], { { e[2] - 0.03, 0.6, e[2] - 0.10, 0.98 }, { e[2] + 0.06, 0.6, e[2] + 0.14, 0.98 },
      { e[2], 0.4, e[2] + 0.08, 0.1 } }, k > 1 and 2 or 1)
  end
  for _, e in ipairs(eyes) do
    local x, y = K.wpt(e[1], e[2], 0.5)
    K.eye(g, x, y, 1.6 * k)
  end
  -- abdômen em bobina, com o fio da ponta balançando
  K.coil(g, cx, 18 * k, 31 * k, function(y) return (2.6 - 1.3 * (y - 18 * k) / (13 * k)) * k end, k)
  local sway = ({ [0] = 1.5, 0.8, 0, 0.8 })[ph]
  K.wire(g, { { cx, 31 * k }, { cx + sway * k, 32.2 * k }, { cx + (sway - 0.9) * k, 33 * k } }, 'k', 'm', k)
  -- tórax e cabeça de pelo; o cabo de borracha no pescoço
  K.fur(g, cx, 11 * k, 18 * k - 1, function(y) return ((y < 12 * k or y >= 17 * k) and 2.4 or 3.5) * k end, k)
  K.fur(g, cx, 9 * k, 11 * k - 1, function() return 1.8 * k end, k)
  K.wire(g, { { cx - 1.5 * k, 11 * k }, { cx + 1.5 * k, 11 * k } }, 'n', 'N', k)
  -- o peito aberto: a bobina por dentro e o quarto olho
  K.coil(g, cx, 12 * k, 17 * k - 1, function() return 2.5 * k end, k)
  K.eye(g, cx, 14.5 * k, 1.6 * k)
  -- antenas: duas de pluma, a terceira é um fio desencapado
  local lift = o.pose == 'alert' and 1 or 0
  for _, sd in ipairs({ -1, 1 }) do
    K.wire(g, { { cx + sd * 1.4 * k, 9.4 * k }, { cx + sd * 4 * k, 6.4 * k }, { cx + sd * 9 * k, (5 - lift * 0.8) * k } }, 'B', 'T', k)
    K.wire(g, { { cx + sd * 4 * k, 5.6 * k }, { cx + sd * 9 * k, (4.2 - lift * 0.2) * k } }, 'B', 'T', k)
  end
  local wig = ({ [0] = 0.4, 0, -0.4, 0 })[ph]
  K.wire(g, { { cx + 0.5, 9 * k }, { cx + 0.5 + wig * k, 6.5 * k }, { cx + 0.5 - wig * k, 4 * k } }, 'k', 'm', k)
  K.plus(sg, cx + 0.5 - wig * k, 2 * k - (k > 1 and 3 or 0), k)
end

K.run {
  name = 'coilkin', stage = 'espirito', W = 36, PW = 96, LEG = K.LEG, draw = draw, DARK = 'C',
  BODY_KEYS = { 'G', 'F', 'E', 'P', 'Q', 'C', 'D', 'R', 'B', 'T', 'K', 'c', 'M', 'n', 'N' },
  lean = function(y) return (y < 7 and 2) or (y < 15 and 1) or (y >= 30 and -1) or 0 end,
  -- o retrato é o desenho de 36 ampliado 2,5 vezes num quadro de 96 (sobram 3 px de cada lado)
  portrait = function(o)
    local g, sg = L.grid(90, 90), L.grid(90, 90)
    draw(g, sg, 2.5, o)
    return g, sg, 3, 3
  end,
  acc = {
    urban = { 15, 21 }, green = { 12, 8 }, water = { 14, 9 }, residential = { 14, 9 }, lit = { 14, 9 },
    sacred = { 14, 7 }, crimson = { 16, 20 },
  },
}
