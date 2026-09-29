# Prompts de arte

Prompts para gerar referências visuais, alinhados com a Direção de arte do GDD (cores com significado, formas por camada, Os Que Escutam e o Aklo). O GPT acerta a arte e o Nano Banana acerta a grade de pixels, então o fluxo recomendado é gerar no GPT e pixelizar por script (reduzir 3x com média, quantizar para cerca de 24 cores preservando as cores de magia, ampliar 3x por vizinho mais próximo). O esmaecimento de prédios é efeito do motor e não entra nos prompts, porque os modelos inventam personagens duplicados ao tentar desenhá-lo. O pré-prompt vai sempre no início, seguido do prompt da tela ou da criatura. Gere primeiro o Mapa e a Linha Soot, e use as melhores imagens como referência nos prompts seguintes com "match the style of the attached image".

## Pré-prompt

```
ART DIRECTION "VÉU" — follow every rule strictly.
MEDIUM: 2D pixel art on a true pixel grid. 16px map tiles, 48px creature sprites. 1px outlines in dark plum #1a1424, never pure black. No anti-aliasing, no blur, no gradients, no soft shading. Max 24 colors. Flat color fills with at most 2 shade steps per material, crisp 1px outlines on buildings and props. Small props are allowed and readable at phone size: trees, benches, street lamps. Every edge sits on a visible pixel grid, as if drawn at 360x780 and upscaled 3x with nearest neighbor.
CAMERA: dimetric isometric-style 3/4 view at a fixed pitch, streets running diagonally, orthographic, no perspective. The camera may be rotated around the vertical axis. Characters, creatures and effects are flat 2D sprites that always stand upright facing the screen. Buildings are simple extruded blocks whose visible walls depend on the rotation.
CITY: ordinary Brazilian mid-size city, calm and plain. Desaturated cool colors only: #2b2f3d, #3d4254, #5a6072, #8a8fa3, muted green #3f5a48, muted blue #34506b. Buildings are simple low blocks, at most 2 tiles tall, flat roofs, no signs, no text, no logos, no cars, no people. The city has NOTHING magical unless the prompt explicitly asks for it. Lighting: night falling, dark indigo ambient light, most windows dark, street lamps off or very dim. All buildings in grey-indigo tones only, no green, blue or other painted walls. The player and creatures always stand at street level, never on rooftops.
MAGIC: the only saturated colors in the image, each with a fixed meaning. Violet #9b7bff is the Veil: seams, rifts, sigils. Cyan #5fd3c6 is the signal: the phone, static and the gaze of something watching; use it sparingly. Ember orange #ff7a45 is Essence and life: sparks, distillation, crafting. Glow is a 2-step dithered pixel halo.
CREATURES: fragments of dead gods that broke while crossing the Veil. Every creature has glowing violet crack seams where parts are missing, like cracks in porcelain. Lower tiers have more seams, higher tiers fewer. A creature keeps its type color as its main body color (fire = ember orange and soot grey, water = blue, plant = green); violet appears only as seams and a thin outer glow, never as the body color. Strangeness grows with tier: sparks and Echoes are small, cute and readable, simple animal or object shapes with clear eyes; Spirits have one or two parts in the wrong number; Greater Entities and Archetypes use radial or three-fold symmetry, missing or misplaced faces and impossible geometry, inspired by Ediacaran fossils (Dickinsonia, Charnia, Tribrachidium) and by "errors in reality" like Pokémon Ultra Beasts.
UI: minimal, Pokémon GO-like cleanliness. Map screens show only three elements: a large round button at bottom center showing a cracked glowing smartphone with a single violet rune on its screen and no app icons, a small circular player portrait at bottom left with the level number in a small badge and a thin XP bar, a small round nearby tracker at bottom right showing three tiny creature silhouettes in their type colors. The map screen contains no words at all, the level number is the only text. No compass unless the prompt says the camera is rotated. Every menu lives inside the Conjurador's magic-touched smartphone: dark plum body, cracked corner leaking violet light, faint horizontal glitch lines, pixel app icons. Chunky pixel font. Interface text in Brazilian Portuguese; creature names are English proper names written in capitals.
NEVER: photorealism, 3D render, bloom, painterly style, anime or chibi style, pure black outlines, colorful city, extra HUD panels, floating text boxes on the map, any words or labels on the map screen, English interface text, real-world app logos, more than one aura circle, colored building walls, characters standing on roofs, a visible body for the entities that watch through the phone.
```

## Telas

### Mapa

```
Portrait phone screenshot, the map fills the entire screen. City block at dusk: grey streets, low plain buildings, a small park, a small lake. The player, a hooded young person holding a faintly glowing phone, stands in the center inside a single faint dashed violet aura circle drawn flat on the ground plane as an ellipse. The player stands on the open street, fully visible, with no building in front of them. There is exactly one player character in the image. At the player's feet sits their Familiar, a cat-sized hole in the air stitched shut with violet seams, with one violet eye. Inside the aura, at the same scale as the player, a SOOTLING: a small soot-grey creature with a glowing ember in its chest and at least three bright violet crack seams, clearly readable at phone size. Tiny ember-orange sparks on the ground. Only the three standard UI elements.
```

### Mapa rotacionado

Anexar a imagem gerada do Mapa como referência.

```
Use the attached image as the exact same scene: same streets, buildings, park, lake, player, Familiar, creature, sparks, palette and pixel style. Render it with the camera rotated 90 degrees clockwise around the vertical axis, keeping the same fixed 3/4 pitch and zoom. The ground layout rotates accordingly, and buildings now show the walls that were hidden before, while their roofs keep the same footprint. The player, the Familiar, the creature and the sparks stay upright, facing the screen, not rotated. The UI does not rotate: same three standard elements in the same screen positions, plus a small round compass at the top right with a violet needle pointing to the new north. Do not add or remove any object.
```

### Mapa perto de uma Fenda

```
Same map style and UI. At the top of the screen, a vertical violet rift tears the air above a street corner. Buildings within about 6 tiles of the rift are transformed: violet crack seams on walls, small chunks of roof floating upward, the street surface slowly turning into the landscape of another world. The effect fades with distance. Buildings farther away stay completely ordinary and grey. The player stands at the edge of the transformed area.
```

### Celular aberto

```
Portrait phone screenshot. The map behind is darkened. The Conjurador's smartphone slides up from the bottom and fills 80% of the screen, drawn in pixel art as a physical object: dark plum body, cracked top-right corner leaking violet light, faint glitch lines. Its screen shows a home screen with a 3-column grid of pixel app icons with labels: BOLSA, CÍRCULO, BESTIÁRIO, BANCADA, and two locked slots shown as violet cracks with no icon. A small notification dot on BESTIÁRIO. A small round close button below the phone.
```

### Bestiário

```
Same opened-phone framing. The phone screen shows the BESTIÁRIO app: title bar, filter chips TODOS, FOGO, PLANTA, ÁGUA, then a vertical list of rows, each with a small creature portrait in a rune frame, name, type and a tag CAPTURADO or VISTO. Entries: SOOTLING, FRONDLING, RILLET. Unknown entries are dark silhouettes with "???".
```

### Bancada

```
Same opened-phone framing. The phone screen shows the BANCADA app with two tabs, FABRICAR and DESTILAR. FABRICAR is open: a row of material slots with counts (Sucata, Giz, Ervas, Água pura, Ectoplasma as a small vial of pale violet mist, Essência de Fogo as a glowing ember-orange vial), then two recipe cards, "SELO SIMPLES" with ingredients Giz and Ectoplasma and a violet button "FABRICAR", and "TÔNICO DE FOCO" with Ervas and Água pura. A locked recipe card with "?".
```

### Círculo

```
Same opened-phone framing. The phone screen shows the CÍRCULO app: three large slots for the active team arranged in a triangle joined by faint violet lines, each with a creature sprite (SOOTLING, FRONDLING, RILLET), name, level and the map ability it grants. Below, a scrollable grid of stored creatures in small rune frames, and an ember-orange DESTILAR button.
```

### Bolsa

```
Same opened-phone framing. The phone screen shows the BOLSA app: tabs MATERIAIS and ITENS, a grid of item icons with counts, including selos (violet circle with a triangle rune) and tônicos (small vials). A thin capacity bar at the top shows the bag is almost full. One item selected with a short description at the bottom.
```

### Sintonia

```
Portrait phone screen, full screen, no map UI, styled as a radio of the Veil. Upper half: a SOOTLING hovering, its violet seams pulsing. Middle: a horizontal waveform display with two waves, the creature's signal in cyan with sharp spikes and the player's tuning wave in violet, almost aligned. Lower half: a large circular dial the player drags with the thumb, marked with frequency ticks and small glyphs shaped like oscilloscope traces. A progress ring around the creature fills as the Veil dissolves. Small indicators for the equipped selo and time remaining. No attack buttons.
```

### Ritual

```
Portrait phone screen, full screen, background dimmed. A ritual circle drawn in violet chalk seen from above, with slots around it: two material slots with item icons, one world-condition slot showing a moon phase, two creature slots with small sprites, and one locked slot showing ???. A large spirit creature floats in the center. On top, a glowing sigil half-drawn by a finger, with a countdown ring. Text at the top: FASE DE PRESSÃO.
```

### Chat com o número desconhecido

```
Same opened-phone framing. The phone screen shows a plain messaging app. The contact name at the top is only a row of question marks, with no photo. Three short messages from the contact in grey bubbles, one reply from the player in a violet bubble. The last incoming message is partly corrupted: a few characters replaced by thin cyan glyphs shaped like oscilloscope traces. At the bottom edge of the screen, the player's Familiar peeks in, its outline breaking into violet static as if reacting to the messages.
```

### Os Que Escutam

```
Portrait phone screenshot of the normal map screen at night, but high Veil exposure is distorting it. Thin horizontal cyan scanlines, a few misaligned pixel blocks, and faint cyan static gathering at the edges of the screen. Inside the static, if you look closely, there are shapes that almost read as something enormous and patient, never fully drawn: only suggested by the pattern of the noise. The nearby tracker shows one silhouette that is clearly wrong. The UI is still readable. No creature body, no face, no eyes drawn outright.
```

## Concept art das criaturas

Adicionar depois do pré-prompt:

```
CONCEPT SHEET MODE: larger pixel illustrations at 128px per creature, same palette and outline rules, flat #1a1424 background, no text, no UI. Show each creature in front view and side view.
```

### Linha Soot (Fogo, fragmentos de Ialprg)

```
Evolution line of one fire family, left to right, growing in size and losing violet seams at each step. 1) EMBER MOTE, a single floating ember from a cigarette butt or hot asphalt, mostly made of violet cracks. 2) SOOTLING, a small soot-grey creature that lives in storm drains and exhausts, with a glowing ember in its chest, round eyes and three violet seams. 3) A Spirit form, a larger soot creature with two ember hearts instead of one and a trail of smoke that forms a second, lagging silhouette, one violet seam.
```

### Linha Frond (Planta, fragmentos de Peab)

```
Evolution line of one plant family, left to right, growing and losing violet seams. 1) SEED MOTE, a seed with a single sprout and a violet crack. 2) FRONDLING, a small fractal frond shaped like the Ediacaran fossil Charnia, walking on tiny roots, with two small eyes at the base, three violet seams. 3) A Spirit form, a frond creature with three root legs and one frond too many, each frond repeating the whole creature in miniature, one violet seam.
```

### Linha Rill (Água, fragmentos de Zumvi)

```
Evolution line of one water family, left to right, growing and losing violet seams. 1) DRIP MOTE, a tiny floating drop with a violet crack through it. 2) RILLET, a round water drop with large calm eyes whose surface reflects a sky that is not the one above it, three violet seams. 3) A Spirit form, a puddle-shaped creature with several reflections of different skies on its surface, and two sets of eyes that blink out of sync, one violet seam.
```

### Escala de estranheza

```
One plant family shown across five tiers, left to right, to demonstrate the rule that strangeness grows with tier. 1) FRONDLING, small and cute. 2) Spirit, one part in the wrong number. 3) Greater Entity, a tall three-fold symmetric frond tree like the Ediacaran Tribrachidium, with no face. 4) Archetype, a huge quilted oval body like Dickinsonia, lying flat on the street, breathing, with a single misplaced eye on its edge. 5) God silhouette, almost abstract, an enormous branching pattern of light and oak bark with violet seams, too large to fit the frame.
```

### Familiar

```
The Conjurador's Familiar, a splinter of the god that became the Veil. A cat-sized creature that looks like a hole cut out of the air, showing a dark violet void inside, its edges stitched shut with glowing violet seams, with one large violet eye. It has no mouth. Show four versions side by side: base form; Selador form wrapped in thin violet rune bands; Tecnomante form with thin cyan circuit lines creeping over its edges, looking slightly uneasy; Xamã Urbano form wearing a small ember-orange charm of leaf and bone.
```

### Soberano Oquor, arte-chave

```
Key art, 16:9, same pixel rules. An ordinary grey city block at night seen in top-down 3/4 view. A huge violet rift opens above an intersection and OQUOR, the first Sovereign, is walking out of it: a colossal tree that walks on its branches with its roots up in the air, planting glowing seeds straight into the asphalt, which cracks and sprouts behind it. Violet seams run through its bark. Nearby buildings are covered in sudden growth and floating debris, the rest of the city untouched. A tiny hooded figure with a glowing phone stands in the street below for scale.
```

### Glifos de Aklo

```
Sheet of 24 pixel-art glyphs of an invented alien script, drawn in cyan #5fd3c6 on flat #1a1424. Each glyph looks like a short oscilloscope trace or radio waveform bent into a symbol: spikes, sine fragments, sudden flat lines, interference patterns. 1-2px strokes, consistent height, no resemblance to any real alphabet.
```

## Marca e capa

Estes prompts não usam o pré-prompt, porque a marca precisa funcionar fora do pixel art (pitch, loja, redes). A ideia central da marca é o O de KENOMA como o dial da sintonia: um círculo com 30 marcas, uma por deus dos Trinta, e uma delas faltando no lugar do Décimo, que virou o Véu. Uma rachadura violeta atravessa o nome, como as costuras das criaturas. Modelos de imagem ainda erram texto com frequência: gere várias vezes, confira a grafia e, para a capa, prefira gerar sem texto e aplicar o logo por cima.

### Logo, versão principal

```
Game logo for "KENOMA: VEILBREAKERS", a dark urban-fantasy mobile game about capturing fragments of dead gods through cracks in reality. Flat vector logo on a solid very dark plum background #1a1424, centered, generous empty space around it.
WORDMARK: "KENOMA" in tall, sharp, slightly condensed custom capital letters with an occult feel, like engraved sigils, off-white #ece6ff. The letter O is replaced by a circular radio tuning dial: a thin ring with exactly 30 small tick marks evenly spaced, one tick missing at the top, and a single thin needle. A thin jagged crack runs horizontally through the whole word, slightly offsetting the top and bottom halves of the letters, and glowing violet #9b7bff light leaks from inside the crack.
SUBTITLE: "VEILBREAKERS" below, much smaller, widely letter-spaced thin capitals in cyan #5fd3c6.
AROUND THE LOGO, subtle and sparse: a few tiny floating glyphs that look like oscilloscope traces in faint cyan, a few tiny ember-orange #ff7a45 sparks drifting upward, thin violet stitch marks at the ends of the crack.
Style: clean, minimal, high contrast, readable at small sizes. No 3D, no bevel, no gradients except the soft glow of the crack, no extra words, no mascot.
```

### Logo, versão pixel art

Para a tela de título do jogo. Anexar a versão principal como referência.

```
Recreate the attached logo as true pixel art for a game title screen, as if drawn at 320x120 and upscaled with nearest neighbor. Keep the exact same composition: "KENOMA" with the O as a tuning dial of 30 ticks with one missing, the horizontal violet crack through the word, and "VEILBREAKERS" small in cyan below. 1px outlines in #1a1424, flat colors, max 12 colors, 2-step dithered glow on the crack, no anti-aliasing, background #1a1424.
```

### Emblema e ícone do app

```
App icon, square with rounded corners, flat vector, background very dark plum #1a1424. In the center, the KENOMA dial alone: a thin off-white ring with exactly 30 small tick marks, one tick missing at the top, a single needle pointing to the gap. A thin jagged violet #9b7bff crack runs diagonally across the whole icon, glowing softly, and the dial is slightly offset on each side of the crack. One tiny cyan #5fd3c6 point of light inside the gap where the missing tick should be. No text. Bold, simple, readable at 48x48 pixels.
```

### Capa vertical

Formato 2:3, para loja, pôster e página do pitch. Deixar o terço de cima livre para aplicar o logo.

```
Vertical key art, 2:3, high-detail pixel art illustration in the style of HD-2D games like Octopath Traveler, true pixel grid, 1px dark plum outlines #1a1424, never pure black. A calm ordinary Brazilian mid-size city street at night, low buildings, a lamp post, overhead wires, everything in desaturated cool grey-indigo tones. Seen from behind, in the lower third, a lone hooded young person stands in the middle of the street holding up a smartphone; its screen glows with a small violet dial. At their feet sits a cat-sized creature that looks like a hole cut in the air, stitched with violet seams, with one violet eye.
Above the city, the night sky is split by an enormous jagged violet #9b7bff crack. Inside the crack, colossal abstract silhouettes of dying gods are falling and shattering, their shapes inspired by Ediacaran fossils: fractal fronds, three-fold symmetric forms, quilted ovals. Their fragments rain down over the city as small glowing creatures with violet seams: a soot creature with an ember in its chest, a small walking frond, a water drop reflecting another sky. Tiny ember-orange #ff7a45 sparks drift up from the street.
In the corners of the image the sky dissolves into faint cyan #5fd3c6 static, and inside that static there is the barely suggested shape of something enormous and patient, never fully drawn.
The top third of the image is darker sky with space for a logo. No text, no letters, no logos, no UI.
```

### Capa horizontal

Formato 16:9, para a abertura e o encerramento do vídeo. Mesmo prompt da capa vertical com as mudanças abaixo, anexando a capa vertical como referência.

```
Use the attached image as style and content reference. Recompose it as a wide 16:9 key art: the hooded figure and the Familiar on the left third, the long street receding to the right, the violet crack running diagonally across the whole sky with the falling gods on the right, cyan static in the upper corners. Keep a clear dark area in the center-top for a logo. Same palette, same pixel rules, no text.
```

## Vídeo de apresentação

Dois clipes de 8 s com áudio, pensados para o Veo 3. A parte 2 continua a parte 1 usando o último quadro dela como primeiro quadro (Extend ou Frames to Video no Flow). O logo não é gerado pelo modelo, porque vídeo erra texto: o final deixa o espaço limpo e o logo entra na edição, ou vai como quadro final no Frames to Video. A música pode vir do próprio Veo, mas uma trilha gerada separada para os 16 s fica mais coesa entre os dois clipes.

### Parte 1 · O chamado

```
8-second cinematic game trailer shot, 16:9.
STYLE: pixel art animation on a crisp true pixel grid with nearest-neighbor pixels, but buttery smooth 60fps motion. Sprites glide with sub-pixel smoothness, bob and squash slightly, and soft shader effects are layered over the pixel art like in Vampire Survivors and Hyper Light Drifter: dense particle bursts, white hit flashes, drifting embers, soft additive glow and light trails. Top-down 3/4 camera over an ordinary Brazilian mid-size city street at night. The city is desaturated cool grey-indigo (#2b2f3d, #3d4254, #5a6072), plain low buildings, overhead power lines, no signs, no cars, no people. The only saturated colors are violet #9b7bff, cyan #5fd3c6 and ember orange #ff7a45. Dark plum outlines, never pure black. No on-screen text, no UI, no logos.
ACTION:
0-2s: slow push-in over the quiet street. A lone hooded young person walks with a phone in hand. A faint dashed violet aura ellipse pulses on the ground around them with each step.
2-4s: the phone flickers. A thin jagged violet crack zips open across the sky with a bright flash. Tiny glowing fragments rain down like embers, each trailing violet light. One lands inside the aura and unfolds into a small cute soot-grey creature with a glowing ember in its chest and violet crack seams on its body; it blinks at the player.
4-7s: the camera snaps close onto the phone screen, which looks like an old radio: a spiky cyan waveform and a smooth violet waveform, and a circular dial turned by a thumb. The waves wobble, then lock into alignment while a ring fills around the creature.
7-8s: white flash. The creature dissolves into a spiral of violet sigil light that is pulled into the phone, with a burst of ember sparks.
SOUND DESIGN: quiet night ambience, distant traffic, electric hum of power lines, soft footsteps. Phone static crackle when it flickers. The sky crack opens with a reversed cymbal swell and a glassy tearing sound. Falling fragments sound like tiny glass wind chimes. Radio tuning sweeps and detuned tones that slowly converge into one clean pure tone as the waves align. The seal is a deep sub-bass hit followed by a bright crystalline chime.
MUSIC: starts almost silent with a low drone. At 2s a slow dark chiptune arpeggio in a minor key fades in, about 100 BPM, with a distant wordless mourning choir underneath. The music swells into the seal hit at 7s.
```

### Parte 2 · Os Trinta caem

Usar o último quadro da parte 1 como primeiro quadro.

```
Continue the shot seamlessly, same style, palette, pixel rules and camera language as the previous clip. 8 seconds, 16:9. No on-screen text, no UI, no logos.
ACTION:
0-3s: the camera pulls up and back high above the neighborhood. The violet crack in the sky widens. Inside it, colossal abstract silhouettes of dying gods fall slowly and shatter: fractal fronds, three-fold symmetric shapes, quilted oval bodies, all edged in violet light. Their fragments drift down over the whole city as dozens of small cute glowing creatures with violet seams, like a gentle swarm: soot creatures with ember hearts, little walking fronds, water drops reflecting another sky. Buildings near the crack sprout glowing violet seams and small chunks of roof float upward. The hooded figure is a tiny silhouette in the street below, phone glowing.
3-5s: the edges of the frame dissolve into cyan static. Inside the noise there is the barely suggested shape of something enormous and patient, watching, never clearly drawn. For a single frame the phone screen in the figure's hand turns cyan.
5-5.5s: hard cut to black.
5.5-8s: on a dark plum background #1a1424, a thin off-white ring draws itself in the center of the screen, then exactly 30 small tick marks light up around it one by one, fast, with one tick missing at the top. A thin violet crack slices horizontally through the ring with a flash and leaves a soft violet glow. The rest of the frame stays clean and empty.
SOUND DESIGN: the swarm sounds like hundreds of soft glass chimes. When the static appears, the music cuts out and there is only hissing radio static and a slow, heavy, heartbeat-like low pulse, with a faint whisper-like texture in the noise. Total silence on the black cut. Then 30 quick soft radio clicks accelerating as the ticks light up, and the crack is a sharp glassy snap.
MUSIC: the chiptune arpeggio and the mourning choir return at full strength during the falling gods, drop out completely during the static, and come back at the end as one sustained choir chord over a single clean tuned radio tone that rings out and fades.
```

### Trilha separada

Para gerar música de 16 s num gerador de música e usar os dois clipes só com os efeitos sonoros.

```
Instrumental game trailer cue, exactly 16 seconds, 100 BPM, minor key. Dark gothic chiptune in the spirit of Vampire Survivors mixed with a slow wordless mourning choir and analog radio textures. 0-2s: low drone and radio static. 2-7s: slow chiptune arpeggio enters, choir underneath, building. 7s: big sub-bass hit and crystalline chime. 7-11s: full arpeggio and choir, epic but sad. 11-13s: everything drops out except hissing static and a slow heartbeat pulse. 13-13.5s: silence. 13.5-16s: accelerating soft clicks, then one sustained choir chord over a single pure sine tone, ringing out.
```
