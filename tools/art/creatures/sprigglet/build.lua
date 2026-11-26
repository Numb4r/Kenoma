-- Sprigglet (sprig.eco), arte final: o Eco da família Sprig, a partir do conceito aprovado (a forma está no
-- _sprig.lua, com pose). A maritaca em proporção natural, pairando: verde-oliva, cabeça mais escura, mancha azul na
-- garganta, crisso vermelho, bico cor de chifre. O único erro é que as duas asas são folhas secas, com a nervura
-- central acesa.
-- Costuras do Véu: três, curtas e de 1 px, na pena do corpo e da cabeça, só no glow.
-- Camadas: corpo; leds = o brilho do olho e a ponta das nervuras (piscam); glow = as nervuras, o olho, as costuras e
-- o pólen solto.
-- Animação (laço de 8 quadros: duas batidas de asa, uma virada de cabeça, uma respiração): a asa de cá sobe, desce
-- para trás do corpo e volta encurtada; a de lá acompanha e some atrás da cabeça; o rabo compensa; o corpo sobe na
-- batida. No meio do laço a cabeça abaixa o bico e volta. Na deriva e na fuga o corpo inteiro inclina para a frente
-- (na fuga, mais, com a batida curta). No alerta as asas abrem em V e a cabeça ergue; na antecipação as asas fecham
-- sobre o corpo e a cabeça encolhe.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/sprigglet/build.lua')
local Sp = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_sprig.lua')
local L = Sp.L

-- a batida, em 4 tempos: no alto, descendo, embaixo (atrás do corpo), voltando (encurtada, de quina)
local WN = { [0] = { 0, 1, 1 }, { -27, 0.9, 1 }, { -83, 0.8, 1 }, { -45, 0.7, 0.75 } }      -- asa de cá: graus, comprimento, largura
local WF = { [0] = { 0, 1 }, { 18, 0.9 }, { 43, 0.6 }, { 23, 0.7 } }                      -- asa de lá
local TAIL = { [0] = 0, -6, -12, -5 }
local DASH = { [0] = { -30, 0.85 }, { -80, 0.8 } }                                        -- na fuga, batida curta
local HD = { [0] = 0, 0, 0, 12, 24, 24, 12, 0 }                                           -- a cabeça abaixa o bico e volta

local function draw(g, sg, k, o)
  local NL = o.portrait and 4 or 8
  local ph = (o.ph or 0) % NL
  local w = ph % 4
  local a
  if o.pose == 'alert' then a = { wn = -15, wf = 13, hd = -14, hy = -0.4, tail = 8 }
  elseif o.pose == 'crouch' then a = { wn = -72, ln = 0.7, wwn = 0.8, wf = 40, lf = 0.5, hd = 12, hx = -0.6, hy = 0.9, br = -1, tail = 6 }
  elseif o.pose == 'half' then a = { wn = -38, ln = 0.8, wf = 28, lf = 0.7, hd = 6 }
  elseif o.portrait then                                         -- pairando devagar: a asa abre e fecha pouco
    a = { wn = ({ [0] = 0, -6, -11, -5 })[ph], wf = ({ [0] = 0, 4, 8, 3 })[ph], hd = ({ [0] = 0, 0, 7, 7 })[ph],
      br = ({ [0] = 0, 0.5, 1, 0.5 })[ph], tail = ({ [0] = 0, -3, -5, -2 })[ph] }
  elseif o.dash then
    a = { wn = DASH[ph % 2][1], ln = DASH[ph % 2][2], wf = 30, lf = 0.6, tilt = 10, hx = -1, tail = 0 }
  else
    a = { wn = WN[w][1], ln = WN[w][2], wwn = WN[w][3], wf = WF[w][1], lf = WF[w][2], tail = TAIL[w],
      hd = HD[ph], hy = HD[ph] / 40, br = (1 - math.cos(ph / NL * 2 * math.pi)) / 2,
      tilt = o.lean and 8 or 0, hx = o.lean and -0.8 or 0 }                 -- inclinada, a cabeça recua (o bico não sai do quadro)
  end
  local src = Sp.C.eco(k, g.w, a)
  Sp.place(g, sg, src, { k = k, ph = w, NL = 4, piv = 24, dark = o.dark,
    hot = (not o.pose and w == 2) and 1 or 0 })
end

Sp.run {
  name = 'sprigglet', stage = 'eco', W = 28, PW = 96, draw = draw,
  nloop = 8, dy = { 0, 0, -1, -1, 0, 0, -1, -1 },
  over = {
    flee = function(_, os) for i = 2, #os do os[i].dash = true end return os end,
    spawn = function(_, os) os[5].pose = 'half'; return os end,
  },
  -- o retrato é o mesmo desenho feito em 96, com a textura no pixel
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 96 / 28, o)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 12, 17 }, green = { 9, 19 }, water = { 11, 16 }, residential = { 11, 17 }, lit = { 11, 18 },
    sacred = { 16, 6 }, crimson = { 14, 16 },
  },
}
