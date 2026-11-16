# Building the catalogue

The catalogue is why the workbench is worth opening. It shows the owner their own game as a browsable whole, so it has to come from the game's real data and real rendering. Inventing entries, or drawing pictures that don't come from the game, breaks the point of it: the owner is judging the game itself.

## catalog.json

Write `workbench/catalog/catalog.json`, with pictures in folders beside it. The page builds its tabs, filters and sort options from this file, so no page code changes per game.

```json
{
  "made": "2026-11-02T15:00:00Z",
  "sections": [
    {
      "id": "weapons",
      "group": "Items",
      "label": "Weapons",
      "title": "Weapons and shields",
      "lede": "Every blade and board in the game.",
      "layout": "grid",
      "filter": "Slot",
      "rows": [
        {
          "id": "iron-sword",
          "name": "Iron Sword",
          "sub": "Common weapon",
          "img": "items/iron-sword.png",
          "r": 0,
          "text": "A line of description or flavour.",
          "quote": "A spoken greeting, for characters.",
          "tags": ["+5 damage", "Two-handed"],
          "list": [{ "name": "Perk name", "text": "What it does" }],
          "fields": { "Slot": "Weapon", "Attack": 12, "Weight": 3, "Value": 40 }
        }
      ]
    }
  ]
}
```

Section keys:

- `id` must be unique and must not be one of `now`, `inbox`, `ratings`, `media`, `shots`, `shipped`, `numbers`.
- `group` is the rail heading. Sections with the same group sit together: Items, People, World, Combat, Systems, or whatever fits the game. Don't use `Build` or `Numbers`, because those are the page's own.
- `keepOrder`: set to `true` when the order means something, such as seasons, ranks, levels or story order. The tab then starts in your order and its filter chips keep it too. Otherwise tabs start A to Z.
- `layout`: `grid` for square object pictures (items, icons), `wide` for 16:9 scenes (people in place, locations), `list` for things with no picture (quests, skills, factions).
- `filter` names a field. Its values become filter chips.

Row keys: only `id` and `name` are required.

- `fields` appears in the drawer and on `list` rows. Numeric fields automatically become sort options, both high to low and low to high, so store numbers as numbers rather than `"12 gold"`.
- `r` is a rarity tier from 0 to 3. It colours the name, and adds a rarity sort.
- `img` is a path relative to `catalog/`.

Give every row a stable `id`. Notes attach to `sectionId:rowId`, so changing ids orphans the owner's notes. Generated content is the hard case: base the id on something that survives a rerun, such as a name or seed. If a capture would change the ids, keep the old rows rather than losing notes.

## Pulling the data

Prefer reading the game's own tables at runtime, because that captures generated and merged content that static files miss. Load the game in a headless browser, wait until it is ready, and read the data out. For engines without a browser build, parse the data files or add a small debug export that writes JSON.

Be complete. If the game rolls random loot, generate many rolls and de-duplicate. If an entry has no display name, fix the name rather than showing an internal id. Title-case shouted names. When content is procedural and endless, such as generated residents, show a representative sample and say so in the section's `lede`.

## Getting real pictures

Render each thing the way the player sees it, then save a file per row.

- **Items and objects:** use the game's own icon renderer if there is one, at the size it was built for. Scale up afterwards, because a renderer made for 40-pixel icons can break at 160. Otherwise render each model alone against a plain background with a fixed camera. 240 to 512 pixels is plenty.
- **People:** in a walkable 3D world, move the camera to each character, stand a couple of metres in front, face them, and shoot. A character in place reads better than a floating model. In top-down and 2D games, use the game's portrait or sprite.
- **Places:** go to a good viewpoint at each location in daylight, wait for streaming to finish, and shoot. Shoot twice if the first frame is still loading. Top-down games should frame the area with their own camera controls.
- **Things with no single picture**, such as goals, ranks and factions, use the `list` layout. Don't invent art for them.
- **Enemies:** spawn each in the open in a safe spot and clear it before the next. Some can't be spawned, and it's fine to say so with no picture.

Hide the interface for these shots, and hide only the interface. A rule like `body > * { display: none }` also hides the game canvas and gives you black pictures; exclude the canvas and anything containing it.

Force daytime and clear weather, stop random encounters, and make the player invulnerable while capturing, so nothing interrupts the run. Do this only in the capture script, never in the game itself.

Afterwards, look at a contact sheet of a sample from each section. Count how many pictures are black, blank or show the wrong thing, and redo those. Ask of each one: does it show the thing it's named after? An automated blank check can't answer that. Spotting bad pictures yourself is much cheaper than the owner finding them.

Limit pictures per section if a capture would run long. Twenty good pictures beat two hundred unchecked ones. Say what you left out.

## Capturing footage

Record short real clips into `clipDir`: walking through the main area, a conversation, a fight, day and night. Five clips of about 10 seconds is a good start.

A browser game can record its own canvas with `MediaRecorder` to `.webm`, with no extra tools. If the game draws on more than one canvas, such as sky behind a world layer, composite them first or the clip will miss a layer. For smooth footage from a heavy game, check whether it can be stepped one frame at a time. Step, screenshot, step, screenshot, then encode the frames. That produces clean 30fps video however slowly the game renders.

Look at the frames before you trust them. Scripted walks often end up pressed against a wall, and an effect you meant to show may not be visible. Rename a clip rather than claim something it doesn't show.

Clips are large. Either add `workbench/clips/` and `workbench/catalog/` to `.gitignore`, or tell the owner they will be committed.
