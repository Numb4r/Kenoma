---
name: game-workbench
description: Builds a local workbench website for the game in this repository, so the owner can browse everything in the game by tab, follow the build (tasks, queue, screenshots, videos) and leave a note on any specific item that goes into the build loop. Use when the user asks for the workbench (for example "run our workbench skill", "workbench", "update the workbench") or a prompt section names it.
---

# Game Workbench

A workbench turns a long game build into a conversation. The owner opens one page and can see what is being worked on, what is queued, and every item, character, place and system in the game. On anything they look at, they can leave a quick note ("this sword needs its own look"), and that note lands at the top of the build queue.

The templates in `assets/workbench/` are the finished product. Do not rebuild the page from scratch. Your job is to fill it with this game's real content, match it to this game's look, and keep it current.

## What "done" means

Open the page and check it the way the owner will:

- Every kind of thing the game contains has a tab, with real pictures taken from the game itself.
- Search, sort and filters work, and clicking anything opens a drawer with its details and a note box.
- A note sent from the page arrives in `workbench/notes.json`.
- Right now, Video and GIFs, Latest screenshots and Shipped all show real data.

An empty tab, a black picture or a placeholder is not done. Say plainly what is missing.

## Step 1: Understand the game

Find out how the game runs and how to drive it, and list everything it contains. Read the code and data rather than guessing: item tables, unit lists, levels, characters, enemies, quests, skills, tracks, recipes. Read the project's existing test and capture scripts first, because they usually already know how to start the game, skip menus and reach a good camera. That saves more time than anything else here. The tabs come from what this game actually has, so a racing game gets Cars, Tracks and Upgrades, a city builder gets Buildings, Citizens and Disasters, and an RPG gets Weapons, Armour, People, Locations and Quests.

## Step 2: Install the templates

Copy `assets/workbench/` into the game project as `workbench/`, assuming it sits at the project root. Rename `config.example.json` to `config.json`, and add the lines in `gitignore.txt` to the project's `.gitignore` (they are written for that location). Put your capture scripts in `workbench/capture/`.

Fill in `config.json`. Every path is relative to `workbench/`, so the project's `shots` folder is `../shots`. Restart `server.py` after changing this file, because it is read once at startup.

| Key | Meaning |
|---|---|
| `game` | Name shown in the rail |
| `port` | Local port; pick a free one if another workbench is running |
| `repo` | Path from `workbench/` to the git repository |
| `gitPaths` | Git paths that count as game changes. The default leaves `workbench/` out, so editing the workbench doesn't show as an unshipped game change |
| `buildFile` | The built game file, for "latest build" age. Blank if none |
| `shotDirs` | Folders the tests write screenshots to; the newest appear live |
| `clipDir` | Folder for `.webm`, `.mp4` and `.gif` clips |
| `catalogDir` | Folder holding `catalog.json` and its pictures |
| `running` | Regex matched against running processes, shown as "Running now". The first group is the label. It sees the whole machine, so make it specific to this project |
| `theme` | Colours and display font |

Set `theme` from the game's own menus, so the workbench feels like part of the game. Any Google Font works through `fontUrl`; name it in `display` for headings and `body` for text.

The defaults are for a dark theme. A light theme needs more keys, or text will vanish:

| Key | Sets |
|---|---|
| `scheme` | `"light"` or `"dark"`, for form controls and scrollbars |
| `active` | Text on the selected tab |
| `soft` | Secondary text, such as tabs and chips |
| `flavour` | Description text |
| `track` | Bar backgrounds |
| `well` | Background behind item pictures (a colour or gradient) |
| `sendHover` | Send button hover |
| `ok`, `bad`, `fresh` | Done, problem and new colours |
| `r0` to `r3` | Rarity name colours |

`gold` is used for both text and button fills, so choose a colour that reads as text on `bg`. Look at the page after theming, on every tab, and check for washed-out labels.

## Step 3: Build the catalogue

Read `references/catalogue.md`. It defines `catalog.json` and how to get real pictures out of a running game. This step is most of the work and most of the quality.

## Step 4: Record the build

Fill these so the page is alive from the first open:

- `tasks.json`: `owner` (their rating out of 10, or null), `doing` (`[{"t": "...", "why": "..."}]`), and `queue`, `done` and `stuck` as lists of plain strings. Keep `done` newest first, because the page shows the first eight.
- `numbers.json`: `[{"title": "One raider", "columns": ["Measure", "Before", "Now"], "rows": [["Swings to kill", "8", "6"]]}]`. Only numbers you actually measured. Leave it `[]` if there are none, and the tab hides itself.
- `clipDir`: short real clips of the game. See "Capturing footage" in `references/catalogue.md`.

## Step 5: Run it and check it

Start the server from a background shell, then open the page. If you're working through subagents, start it from the main session, because a server started by a subagent can stop when that subagent finishes.

```bash
python3 workbench/server.py
```

Drive the page in a real browser. Click every tab, sort, filter, open a drawer and send a test note, then delete that note. Run the check in "What done means" and fix what fails.

## Step 6: Keep it live

From now on, the workbench is part of how you work:

- At the top of every round, read `workbench/notes.json`. For each note with status `new`: set `status` to `seen`, and put it at the top of the queue in `tasks.json`. The owner's notes outrank your own plan.
- Update `tasks.json` at every step, not at the end. The page refreshes every few seconds, so stale tasks mean the owner is watching something false.
- When a note is finished, set `status` to `done` and write a short `reply`. The owner sees it under their note.
- Refresh clips and the catalogue whenever the visuals change.



## Things that went wrong before

- Rebuilding the sidebar on every poll caused lost clicks. The templates already key the sidebar and views, so keep that when editing them.
- Catalogue pictures came out black because a "hide the interface" rule also hid the canvas. Check a sample of pictures by eye before calling the catalogue done.
- Other tests running on the same machine can exhaust memory. Run one headless browser at a time, and check free memory before long captures.
- Automated blank-picture checks passed a whole set of shots of empty grass with no town in them. Only looking at them caught it.
- Check that the game really reached the state you meant to capture. One capture showed a town of 18 buildings because an autopilot was off, and only the numbers revealed it.

## In this repository (Kenoma)

- Installed only in this repository (`.claude/skills/game-workbench/`), never in `~/.claude/skills`.
- No hosting and no independent screenshot grades: Vercel, `deploy.py`, `push.py`, `references/hosting.md` and `grades.json` were removed, and the Ratings tab is hidden. Stills cannot judge motion or walking in the street, and a public blob would expose where the owner walks.
- Access from the phone and the other machine is through Tailscale (`tailscale serve`, tailnet only, never `funnel`), with `server.py` on localhost. See `docs/workbench.md`, which also has the notes rule for this project.
