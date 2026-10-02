# CrabeMenu

In-game mod menu for **Disney Infinity 3.0 (PC)**, running on **CrabeLoader**.
It is a mod of its own: `mod.json` + `main.lua`, deployed to the game's `mods\crabemenu\` folder.
All game access goes through the stable `Crabe.*` and `Game.*` APIs.

## Use

```powershell
.\deploy.ps1          # copies the menu to mods\crabemenu\ and removes the legacy crabemenu.lua
.\deploy.ps1 -Full    # also syncs bink2w32.dll, window_mode.lua, the hero pack, and removes obsolete game folders
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

## Pages

| Page | What it does |
|---|---|
| **Player & Heroes** | Swap character (Star Wars, Marvel, Disney, custom heroes), **any character in any playset**, level up, max level, refill health, Sparks |
| **Spawners** | Scan the world inventory, spawn NPCs and objects (searchable), a **Modded** list of the entries a mod reskins (tagged `[Mod name]`), equip weapons from the loader catalog, clear placed objects |
| **Animations** | The 7,784 choreographies of `Game.ListChoreographies()` by category, searchable, or play one by name |
| **Cheats** | God Mode (x86 code caves), game speed (needs `Crabe.GameSpeed`), Toy Box editor unlock |
| **World** | Go to the main menu (world select, the pause menu's Quit without its popup), return to the hub, travel to any of the 301 worlds of the game's zone list (searchable, grouped by playset; a world the game refuses is forced on a second press); free camera and teleport when `modules/freecam.lua` is present |
| **Mods** | The menus other mods declare through `Crabe.Menu` (Disney Infinity Complete warps, Radahn spawns, ...) |
| **Settings** | Menu side and size, overlay, video options, credits |

Multiplayer and the free camera are kept out of the repository (`.gitignore`); the menu shows their pages only
when their files are there. The animation list comes from CrabeLoader's catalog, so nothing scans the game folder
at run time (the old `io.popen` scan froze the game for seconds).

**Any character in any playset** is AaBysT's *Anyone Can Cook II* patch, native here: eleven barriers flipped by
signature (character validation, the four forced playset characters, brand lookup, avatar validity, playset matching,
the missing-figure popup, the grid's zone and lock filters), plus a Lua layer re-applied every tick. On by default;
the choice is saved in `crabemenu_settings.json`, and switching it off writes the original bytes back. Disney Infinity
Complete defers to this copy when CrabeMenu is installed.

A **Modded** spawner entry is one whose asset file a mod shadows in the VFS (needs a CrabeLoader with `Crabe.Vfs.list`).
A reskin keeps the game's item id, so the list shows the vanilla name followed by the mod's name.

Every action reports its real outcome in the footer. A failing native shows an error and is written to
`loader.log`; nothing is announced as done unless it was.

## Requirements and limits

- **Game speed** is only available when the loader provides `Crabe.GameSpeed`. The current loader source does not,
  so the section shows a notice until the clock hook is restored.
- **Spawners** need a loaded world: the engine has no inventory on the main menu.
- The Power Disc selector was removed: `Game.SetRoundCoins` / `SetHexCoins` take slot ids that are not documented,
  and the previous ids were placeholders.

## Layout

```text
mods/crabemenu/
├── mod.json
├── main.lua              entry point: loader bootstrap, lifecycle
├── core/
│   ├── loader.lua        module loader (cached per generation, runs modules in the mod's sandbox)
│   ├── config.lua        version, keys, key repeat, layout sizes, menu scales
│   ├── state.lua         shared state, footer status, key and controller capture
│   ├── input.lua         keyboard + controller actions with key repeat, text entry
│   ├── settings.lua      saves the menu side, size and overlay choice
│   ├── native.lua        the only place that catches errors (Native.run reports, Native.poll stays silent)
│   └── util.lua          search filter, name formatting, IPv4 check
├── modules/              behavior, no drawing
│   ├── player.lua  spawner.lua  weapons.lua  animations.lua  cheats.lua
│   └── speedhack.lua  world.lua  (freecam.lua, multiplayer.lua: optional, not in the repository)
└── ui/                   drawing, no game logic
    ├── theme.lua         palette and the scaled drawing helpers (ImGui.Draw*)
    ├── items.lua         row kinds: action, toggle, submenu, choice, input, info, section
    ├── menu.lua          page stack, navigation, prompt, rendering
    ├── overlay.lua       F6 runtime card
    └── pages/            one file per page; list.lua is the searchable list page
```

A page is `{ title = "...", items = function() return { Items.action(...), Items.toggle(...), ... } end }`.
Modules are loaded with `Loader.load("modules.player")` and receive the loader as `...`.
