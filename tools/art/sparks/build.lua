-- Fagulhas (0.25.1): uma por tipo, 4 quadros de 12x12 em laço (repouso, aceso, pico, aceso), forma própria por tipo.
-- Camadas: base (com contorno) e glow (o que brilha de noite). Rodar: aseprite -b --script build.lua
-- Letras: d escuro, m cor do tipo, l claro (os três de tools/art/ui/types/palette.lua, 0.26.0), w miolo. No repouso
-- '1' é m e '2' é l; no quadro aceso '1' vira l e '2' vira w. O pico é desenho próprio.
local S = dofile('/home/yuri/Documentos/kenoma/tools/art/traffic/_strip.lua')
local L = S.L
local DIR = L.ROOT .. 'sparks/'
local O = '#1A1424'
local PAL = {}
for _, c in ipairs(dofile(L.ROOT .. 'ui/types/palette.lua')) do PAL[c.id] = c end

local TYPES = {
  { 'fire', w = '#FFF0B0', lum = true,  -- chama
    a = { '..........', '.....m....', '....mm....', '....mmm...', '...mm1m.m.', '..mm1l1mm.', '..m1l2l1m.', '..m1l22lm.', '...mm11m..', '..........' },
    c = { '..........', '....m.....', '....mm....', '...mmlm...', '...mllm.m.', '..mmlwlmm.', '..mllwwlm.', '..mlwwwlm.', '...mllmm..', '..........' } },
  { 'water', w = '#FFFFFF',  -- gota
    a = { '..........', '....m.....', '....m.....', '...mmm....', '...m1mm...', '..m2mmmd..', '..m1mmmd..', '..mmmmdd..', '...mddd...', '..........' },
    c = { '..........', '....m.....', '...mmm....', '...mlmm...', '..mlwmmm..', '..mwlmmmd.', '..mlmmmmd.', '..mmmmmdd.', '...mmddd..', '..........' } },
  { 'plant', w = '#F0FFD0',  -- folha
    a = { '..........', '.....mmm..', '...mm11m..', '..mm1lmm..', '..m1lmmm..', '..mlmmmd..', '..mmmmdd..', '.dmmddd...', '.d........', '..........' },
    c = { '..........', '....mmmmm.', '...mmllwm.', '..mmllwmm.', '..mllwmmm.', '..mlwmmmd.', '..mwmmmdd.', '.dmmmddd..', '.d........', '..........' } },
  { 'electric', w = '#FFFFFF', lum = true,  -- faísca
    a = { '..........', '.....m1m..', '....m1m...', '...m1m....', '..m1111m..', '....m1m...', '...m1m....', '..m1m.....', '..mm......', '..........' },
    c = { '..........', '.m...mwm..', '..m.mwm...', '...mwm....', '..mwwwwm..', '....mwm.m.', '...mwm.m..', '..mwm.....', '..mm......', '..........' } },
  { 'earth', w = '#FFF0D0',  -- pedrinha
    a = { '..........', '..........', '...mmmm...', '..m11mmd..', '.mm1mmmdd.', '.mmmmmddd.', '.mmmmdddd.', '..mddddd..', '..........', '..........' },
    c = { '..........', '...mmmm...', '..mllmmd..', '.mmlwmmdd.', '.mmlmmmdd.', '.mmmmmddd.', '..mmdddd..', '...dd.m...', '..........', '..........' } },
  { 'metal', w = '#FFFFFF',  -- lasca
    a = { '..........', '......mm..', '.....m2m..', '....m2md..', '...m1md...', '..m1mdd...', '..mmdd....', '.mddd.....', '.dd.......', '..........' },
    c = { '..........', '......lw..', '.....mwl..', '....mwmd..', '...mwmd.l.', '..mwmdd...', '..mlmd....', '.mmdd.....', '.dd.......', '..........' } },
  { 'light', w = '#FFFFFF', lum = true,  -- raio de luz
    a = { '..........', '....m.....', '....m.....', '...m1m....', '.mm121mm..', '...m1m....', '....m.....', '....m.....', '..........', '..........' },
    c = { '..........', '....l.....', '..m.l.m...', '...lwl....', '.llwwwll..', '...lwl....', '..m.l.m...', '....l.....', '..........', '..........' } },
  { 'shadow', w = '#F0DCF2', lum = true,  -- fiapo de sombra (a borda ameixa acende)
    a = { '..........', '...mmmm...', '..mddddm..', '..md..1dm.', '..mm..mdm.', '.....mdm..', '....mdm...', '...mdm....', '...mm.....', '..........' },
    c = { '..........', '..mmmm....', '.mddddm...', '.ml..ldm..', '.mm...mdm.', '......mdm.', '.....mlm..', '....mdm...', '....mm....', '..........' } },
  { 'spectral', w = '#FFFFFF', lum = true,  -- chama fria, oca
    a = { '..........', '....m.....', '....mm....', '...mmm.m..', '..mm1mmm..', '..m1dd1m..', '..m1dd1m..', '..mm11mm..', '...mmmm...', '..........' },
    c = { '..........', '...m......', '...mm..m..', '..mmlm.m..', '..mllmmm..', '..mlddlm..', '..mlddwm..', '..mmllmm..', '...mmmm...', '..........' } },
  { 'digital', w = '#FFFFFF', lum = true,  -- pixel
    a = { '..........', '..........', '..mmmmm...', '..m111m...', '..m121m...', '..m111mmm.', '..mmmmmdm.', '......mmm.', '..........', '..........' },
    c = { '..........', '..........', '..mmmmm...', '..mlllm.m.', '..mlwlmm..', '.mmlllmmm.', '..mmmmmlm.', '......mmm.', '..........', '..........' } },
  { 'fae', w = '#FFFFFF', lum = true,  -- pó de fada
    a = { '..........', '......m...', '.....m2m..', '......m...', '...m......', '..m1m.....', '...m...m..', '.....m....', '..........', '..........' },
    c = { '..........', '......l...', '.....lwl..', '...m..l...', '..mlm.....', '...m..m...', '.....mlm..', '......m...', '..........', '..........' } },
  { 'draconic', w = '#FFD8C8',  -- escama
    a = { '..........', '...mmmm...', '..m1111m..', '..m1mm1m..', '..mmmmmm..', '..dmmmmd..', '..ddmmdd..', '...dddd...', '....dd....', '..........' },
    c = { '..........', '...mmmm...', '..mllllm..', '..mlwwlm..', '..mlmmlm..', '..dmllmd..', '..ddmmdd..', '...dddd...', '....dd....', '..........' } },
}

local function conv(rows, one, two)
  local out = {}
  for i, r in ipairs(rows) do out[i] = r:gsub('1', one):gsub('2', two) end
  return out
end

local function frame(rows, tag)
  local g = L.grid(12, 12)
  L.put(g, 1, 1, L.frame(rows, 10, 10, tag) and rows)
  L.outline(g, 'o')
  S.check(tag, g)
  return g
end

local items = {}
for i, t in ipairs(TYPES) do
  local name = 'spark_' .. t[1]
  local c = PAL[t[1]]
  local leg = { o = O, m = c.m, d = c.d, l = c.l, w = t.w }
  local rest = frame(conv(t.a, 'm', 'l'), name .. ' q1')
  local lit = frame(conv(t.a, 'l', 'w'), name .. ' q2')
  local peak = frame(t.c, name .. ' q3')
  local frames = { rest, lit, peak, lit }
  local glow = {}
  for f, g in ipairs(frames) do glow[f] = S.pick(g, t.lum and 'mlw' or 'lw') end
  S.save(DIR .. name, leg, {
    { name = 'base', frames = frames, png = DIR .. name .. '.png' },
    { name = 'glow', frames = glow, png = DIR .. name .. '_glow.png' },
  }, 5)
  -- Folha: os 4 quadros no asfalto, na grama e na calçada.
  for f = 1, 4 do
    for b = 0, 2 do
      items[#items + 1] = { g = frames[f], glow = glow[f], leg = leg, x = 2 + b * 50 + (f - 1) * 12, y = 1 + (i - 1) * 14 }
    end
  end
end

local H = #TYPES * 14 + 2
S.folha(DIR .. 'sparks_folha.png', 152, H, {
  { 0, H - 1, 0, 50, '#343949', '#2B2F3D', '#40465A' },
  { 0, H - 1, 51, 100, '#429658', '#2F7446', '#5FB26A' },
  { 0, H - 1, 101, 151, '#A3A7B3', '#8E92A0', '#B6BAC4' },
}, items, 4)
print('problemas: ' .. S.problems)
