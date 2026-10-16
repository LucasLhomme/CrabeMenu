# CrabeMenu

In-game mod menu for **Disney Infinity 3.0 (PC)**, running on **CrabeLoader**.
It is a mod of its own: `mod.json` + `main.lua`, deployed to the game's `mods\crabemenu\` folder.
All game access goes through the stable `Crabe.*` and `Game.*` APIs.

## Use

```powershell
.\deploy.ps1          # copies the menu to mods\crabemenu\ and removes the legacy crabemenu.lua
.\deploy.ps1 -Full    # also syncs dinput8.dll (and restores the game's bink2w32.dll left by a 1.0 install), window_mode.lua, the hero pack, and removes obsolete game folders
```

The menu is a single list in the Disney Infinity colours: a banner, a breadcrumb with an `X / N` counter,
one highlighted row, and a help line at the bottom. It needs a CrabeLoader that provides `ImGui.DrawText`
(screen-space drawing) and `Crabe.Input.padState` (controller input); `loader.log` says so when the DLL is too old.

| Keyboard | Controller | Action |
|---|---|---|
| `F5` | `RB` + D-pad left | Open / close the menu |
| Up / Down | D-pad or left stick | Move (wraps; hold to repeat) |
| Left / Right | D-pad or left stick | Change a `< value >` or flip a switch |
| `Enter` | `A` | Select, open a sub-menu, or edit a text field |
| `Esc` / `Backspace` | `B` | Back; closes the menu on the main page |
| `Page Up` / `Page Down` | `LT` / `RT` | Jump 8 rows |
| `Home` / `End` | | First / last row |
| `F6` | | Toggle the runtime overlay |
| `F4` | | CrabeLoader hot reload |
| `Insert` | | CrabeLoader console |

While the menu is open the game does not see the navigation keys or the controller. Text fields (search, host IP,
animation name) are typed on the keyboard; the search lists narrow as you type. Menu side, menu size and the overlay
choice are saved to `crabemenu_settings.json`.

Every key above is rebindable in **Settings > Keybinds** and stored in `crabemenu_keybinds.json` next to it, one list of
key names per action (`"menuToggle": ["F5"]`, `"back": ["BACKSPACE", "ESCAPE"]`). Names are `F1`-`F12`, `A`-`Z`, `0`-`9`,
`UP`, `ENTER`, `PAGEUP`, `NUMPAD0`... or a hex code like `0x75`; a name the file gets wrong falls back to the default.

## Pages

| Page | What it does |
|---|---|
| **Player & Heroes** | Swap character (Star Wars, Marvel, Disney, custom heroes), **any character in any playset**, level up, **level down**, max level, refund skill points (free respec), raise the skill point total a level 20 hero earns (75, 100, 150 or 200; next launch), refill health, add or remove Sparks |
| **Spawners** | Scan the world inventory, spawn NPCs and objects (searchable), a **Modded** list of the entries a mod reskins (tagged `[Mod name]`), equip weapons from the loader catalog, clear placed objects |
| **Animations** | The 7,784 choreographies of `Game.ListChoreographies()` by category, searchable, or play one by name |
| **Cheats** | God Mode and **One shot kill** (x86 code caves), **No fall** (hits never knock the hero down; pair it with God Mode), **Stealth** (enemies stop targeting you), game speed (needs `Crabe.GameSpeed`), **Hero speed** (only your hero runs faster; needs `Game.SetActorSpeedScale`), Toy Box editor unlock |
| **World** | Go to the main menu (world select, the pause menu's Quit without its popup), return to the hub, travel to any of the 187 base-game worlds of the game's zone list, listed by their in-game English names (searchable by name or zone id, grouped by playset; a world the game refuses is forced on a second press; the 1.05/1.06 and unreleased worlds are left to Disney Infinity Complete); free camera and teleport hero to camera; a Play Set zone loads through the pause menu's load path, so the Play Set save is kept |
| **Speedrun** | Stopwatch with splits (also in the F6 overlay), three saved positions to teleport back to, reload the current world, and a separate **Speedrun HUD** panel (stopwatch, world, splits, position, hero speed; choose its corner and which lines it shows in Settings, down to the stopwatch alone). Default hotkeys: `F7` save position, `F8` teleport, `F9` start / pause, `F3` reload the world, `F11` HUD |
| **Mods** | The menus other mods declare through `Crabe.Menu` (Disney Infinity Complete warps, Radahn spawns, ...) |
| **Settings** | Menu side and size, **Keybinds** (every menu and speedrun key), runtime monitor lines, Speedrun HUD, video options, credits |

Multiplayer is kept out of the repository (`.gitignore`); the menu shows its page only when its files are there.
The animation list comes from CrabeLoader's catalog, so nothing scans the game folder
at run time (the old `io.popen` scan froze the game for seconds).

**Any character in any playset** is AaBysT's *Anyone Can Cook II* patch integrated natively:
- **Native layer**: ten barriers flipped by signature (character validation, the four forced playset characters, brand lookup, avatar validity, playset matching, the missing-figure popup, the grid's zone filter); the category filter is preserved so figures remain cleanly separated and sorted by franchise.
- **Data transplantation layer**: chunk patches (`Crabe.Hooks.patchChunk`) for `DataMap`, `ActorList`, and bitmasks across the 4 story playsets (The Clone Wars, Rise Against the Empire, The Force Awakens, Inside Out), plus dynamic loading of `munitions_toybox.lua` to fix infinite loading screens and missing character abilities/weapons/projectiles.
- **Lua layer**: re-applied every tick (brand lookup, character grid hardening, Finding Dory catalog tagging).
On by default; the choice is saved in `crabemenu_settings.json`, and switching it off writes the original bytes back.
Disney Infinity Complete defers to this copy when CrabeMenu is installed.

A **Modded** spawner entry is one whose asset file a mod shadows in the VFS (needs a CrabeLoader with `Crabe.Vfs.list`).
A reskin keeps the game's item id, so the list shows the vanilla name followed by the mod's name.

Every action reports its real outcome in the footer. A failing native shows an error and is written to
`loader.log`; nothing is announced as done unless it was.

## Requirements and limits

- **Game speed** is only available when the loader provides `Crabe.GameSpeed`. The current loader source does not,
  so the section shows a notice until the clock hook is restored.
- **Spawners** need a loaded world: the engine has no inventory on the main menu.
- **Needs CrabeLoader 1.1.0 or newer** for hero speed (`Game.SetActorSpeedScale`), level down (`Game.SetAvatarLevel`), the skill point
  refund, the Play Set save resume and the input fixes; older loaders show those rows as unavailable or fall back to the old behaviour.
- **Skill points at level 20** (75 by default, or 100, 150, 200) rewrites `mods/crabemenu/skilltrees/SkillPointsEarned.patch`, a chunk patch
  CrabeLoader reads at startup: the game reads its level table once, so the new total applies the next time it starts, to every hero.
- **Hero speed** scales the engine's movement multiplier; the engine rebuilds it when a world loads, so the menu sets it again by itself.
- **One shot kill** zeroes the health of every entity but the hero on its first damage, bosses and allies included, and needs the hero to be
  identified (take a hit, or use Lock To Damaged Target). **Stealth** and **No fall** set an ActorState on the hero, which the menu keeps in place.
- **Level down** keeps the experience, so the next experience gained can raise the hero again; skills that no longer fit are refunded first
  (the game allows two free refunds per figure).
- **World travel** from outside a Play Set resumes that Play Set's save at the place it was saved, then moves to the zone you picked.
  Starting a zone straight from the main menu would load it without any save, which replays cutscenes and relocks unlocked levels.
- The Power Disc selector was removed: `Game.SetRoundCoins` / `SetHexCoins` take slot ids that are not documented,
  and the previous ids were placeholders.

## Layout

```text
mods/crabemenu/
├── skilltrees/
│   └── SkillPointsEarned.patch   written from Settings; raises the level 20 skill point total
├── mod.json
├── main.lua              entry point: loader bootstrap, lifecycle
├── core/
│   ├── keybinds.lua      rebindable keys, read from and written to crabemenu_keybinds.json
│   ├── loader.lua        module loader (cached per generation, runs modules in the mod's sandbox)
│   ├── config.lua        version, keys, key repeat, layout sizes, menu scales
│   ├── state.lua         shared state, footer status, key and controller capture
│   ├── input.lua         keyboard + controller actions with key repeat, text entry
│   ├── settings.lua      saves the menu side, size and overlay choice
│   ├── native.lua        the only place that catches errors (Native.run reports, Native.poll stays silent)
│   └── util.lua          search filter, name formatting, IPv4 check
├── modules/              behavior, no drawing
│   ├── player.lua  spawner.lua  weapons.lua  animations.lua  cheats.lua
│   └── speedhack.lua  world.lua  freecam.lua  speedrun.lua  nofall.lua  stealth.lua  state_guard.lua  avatar.lua  skill_points.lua  (multiplayer.lua: optional, not in the repository)
└── ui/                   drawing, no game logic
    ├── theme.lua         palette and the scaled drawing helpers (ImGui.Draw*)
    ├── items.lua         row kinds: action, toggle, submenu, choice, input, info, section
    ├── menu.lua          page stack, navigation, prompt, rendering
    ├── overlay.lua       F6 runtime card
    ├── speedrun_hud.lua  speedrun panel: stopwatch, world, splits, position, hero speed
    └── pages/            one file per page; list.lua is the searchable list page
```

A page is `{ title = "...", items = function() return { Items.action(...), Items.toggle(...), ... } end }`.
Modules are loaded with `Loader.load("modules.player")` and receive the loader as `...`.

---

## The DIM2 Modding Ecosystem

CrabeMenu is part of the **DIM2** open-source modding suite for Disney Infinity 3.0:

| Project | Description | Link |
| :--- | :--- | :---: |
| **CrabeLoader** | Next-generation C++23 modloader, ASI bootstrap, and low-level engine hook framework. | [GitHub](https://github.com/LucasLhomme/CrabeLoader) |
| **DisneyInfinityPortal** | Physical Disney Infinity Base (Portal) support & figure progress gateway. | [GitHub](https://github.com/LucasLhomme/DisneyInfinityPortal) |
| **DisneyInfinityCreator** | Comprehensive character creation, model extraction, and modding toolkit. | [GitHub](https://github.com/LucasLhomme/DisneyInfinityCreator) |

---

## Support & Sponsor

If you enjoy CrabeMenu and want to support ongoing development:

☕ **[Buy Me a Coffee](https://buymeacoffee.com/crabecrabe)** (`buymeacoffee.com/crabecrabe`)


