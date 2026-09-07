# CrabeMenu

A full-featured in-game mod menu for **Disney Infinity 3.0 (PC)**, running on **CrabeLoader**. 
Self-contained in one file: `mods/crabemenu.lua`.

---

## 🎮 Quick Start

1. **Deploy to game folder:**
   ```powershell
   .\deploy.ps1        # copies mods/crabemenu.lua to the game's mods\ directory
   ```
2. **Launch the game** and press **`F5`** to open/close the menu.
3. **Controls:**
   - **Arrow Keys** : Navigate rows & submenus
   - **Enter** : Activate / Toggle / Enter submenu
   - **Backspace** : Go back to previous menu
   - **Insert** : Open developer debug console & Lua prompt (separate ImGui overlay)

---

## 📂 Features & Categories

| Category | Features & Actions |
|---|---|
| **💰 Money** | Add/Remove Sparks (+50k, +1M, -50k, -1M), inspect Round Coins & Hex Coins (Power Discs). |
| **👤 Player** | Avatar status, Level Up (direct or skill-tree route), Set progression level (5/10/20), Life (Core health, alive check, checkpoint respawn, figure reset), Controls lock/unlock. |
| **🎭 Change character** | Instant swap across all **104 shipped characters** categorized by franchise (Disney, Marvel, Star Wars) with `loadout` and `legacy` application routes. |
| **🛡️ Cheats** | C++23 Code Caves: Invulnerability (God Mode with automatic entity lock), Movement speed multiplier (x1, x2, x5, x10), Live position hunt & memory probing. |
| **🌍 World** | Current world/zone info, destination counter, travel to any loaded destination level, return to Hub, load Main Menu, reset Toy Box / Play Set. |
| **📷 Camera** | Detached Editor camera modes (Object mode, Spark mode), camera target probe, Clean screenshot mode (HUD, DoF & Motion Blur toggles). |
| **🔓 Unlock** | Unlock any Play Set (Avengers, Asgard, Empire, Clone Wars, Inside Out, etc.), force progression unlocked mode. |
| **⚔️ Spawn** | Equip tools, weapons, jetpacks, hoverboards & lightsabers (Tron Disc, Boba Fett Jetpack, Green Lightsaber, Blaster, etc.). |
| **⚙️ Settings** | Video toggles (Bloom, SSAO, FXAA, Motion Blur, Depth of Field, Dynamic Resolution), Difficulty setting (0-3), HUD visibility toggle. |
| **💾 Save** | Save availability check, World autosave slot trigger, Profile save (progression & unlocks). |

---

## 🛠️ Architecture & Error Handling

- **No redundant `pcall`:** The loader's API raises clean, named errors when a native is unavailable (`Game.LoadLevel: UI_LaunchLevel is not available in this Lua state`), and `Crabe.Menu` automatically catches errors per handler, displays them in the menu status line, and logs them to `loader.log`.
- **Thread-safe Execution:** Handlers run safely on the game's Lua thread during frame ticks, avoiding cross-thread race conditions with DirectX render loops.
- **Extensibility:** Any new native or memory patch is added to `CrabeLoader` (`src/api/` or `src/cheats.cpp`) and exposed cleanly to `crabemenu.lua`.
