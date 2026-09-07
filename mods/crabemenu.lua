-- ===========================================================================
-- CrabeMenu ? Master Mod Menu for Disney Infinity 3.0 (PC)
--
-- Controls: F5 to toggle, Arrow Keys to navigate, Enter / Right to select,
-- Backspace / Left to go back.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Model Changer & Combat Heroes (104 H?ros, Sabres & Combos)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Heroes", {
    label = "Avatar Status Summary",
    action = function() return Game.GetAvatarSummary() end,
})

local applyRoute = "loadout"

local function buildCharacterItems(franchise)
    local chars = Game.ListCharacters(franchise)
    local items = {}

    local PAGE_SIZE = 14
    local totalPages = math.ceil(#chars / PAGE_SIZE)

    for p = 1, totalPages do
        local pageItems = {}
        local startIdx = (p - 1) * PAGE_SIZE + 1
        local endIdx = math.min(p * PAGE_SIZE, #chars)

        for i = startIdx, endIdx do
            local c = chars[i]
            pageItems[#pageItems + 1] = {
                label = string.format("%-22s  [%d]", c.name, c.sku),
                action = function()
                    local before = Game.GetAvatarSku()
                    Game.SetCharacter(c.sku, applyRoute)
                    return string.format("Swapped to %s (SKU %d -> %d)", c.name, before or 0, c.sku)
                end,
            }
        end

        if totalPages == 1 then
            return pageItems
        else
            items[#items + 1] = {
                label = string.format("Page %d of %d (%d-%d)", p, totalPages, startIdx, endIdx),
                submenu = { title = string.format("%s - P%d", string.upper(franchise), p), items = pageItems },
            }
        end
    end
    return items
end

Crabe.Menu.registerInCategory("Heroes", {
    label = "Swap Character Model (104 Heroes)",
    submenu = {
        title = "HEROES & COMBAT",
        items = {
            {
                label = "Apply Method",
                cycle = { "loadout", "legacy" },
                index = 1,
                onCycle = function(v)
                    applyRoute = v
                    return "Apply method set to: " .. v
                end,
            },
            { label = "Star Wars (Jedi/Sith Sabers)", submenu = { title = "STAR WARS", items = buildCharacterItems("starwars") } },
            { label = "Marvel Superheroes", submenu = { title = "MARVEL", items = buildCharacterItems("marvel") } },
            { label = "Disney & Pixar Characters", submenu = { title = "DISNEY", items = buildCharacterItems("disney") } },
        }
    }
})

-- Progression Submenu
local progressionItems = {
    {
        label = "Level Up x1",
        action = function()
            local before = Game.GetAvatarLevel()
            local after = Game.LevelUpAvatar()
            return string.format("Level: %d -> %d", before, after)
        end,
    },
    {
        label = "Level Up x5",
        action = function()
            local before = Game.GetAvatarLevel()
            local after = before
            for _ = 1, 5 do after = Game.LevelUpAvatar() end
            return string.format("Level: %d -> %d", before, after)
        end,
    },
    {
        label = "Set Level 20 (Max)",
        action = function() Game.SetAvatarProgression(20) return "Progression maxed to Level 20!" end,
    },
}

Crabe.Menu.registerInCategory("Heroes", {
    label = "Progression & Level 20",
    submenu = { title = "PROGRESSION", items = progressionItems },
})

-- ---------------------------------------------------------------------------
-- 2. 6-DOF Free Camera & Flight Engine (C++23 Native Freecam)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "6-DOF Free Camera (Fly & Look)",
    toggle = true,
    state = false,
    onToggle = function(on)
        if Crabe.Freecam then
            Crabe.Freecam.setEnabled(on)
        end
        if on then
            return "Flight ON! W/A/S/D: Fly | Right-Click + Mouse: Look | Space/Ctrl: Up/Down | Shift: Turbo"
        else
            return "Flight OFF (Restored)"
        end
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Exit Editor (Return to Character)",
    action = function()
        local pid = type(Players_GetHostPlayerID) == "function" and Players_GetHostPlayerID() or 0
        if type(Place_StopPlaceMode) == "function" then
            pcall(Place_StopPlaceMode, pid, 0, false)
        end
        if type(Place_SetEditorState) == "function" then
            pcall(Place_SetEditorState, pid, "Editor::IdleMode")
        end
        if type(Game) == "table" and type(Game.UnlockControls) == "function" then
            pcall(Game.UnlockControls, pid)
        end
        return "Exited Editor -> Back to Human Character!"
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Toy Box Spark Mode (Editor)",
    action = function()
        if type(Place_SetEditorState) == "function" then
            local pid = type(Players_GetHostPlayerID) == "function" and Players_GetHostPlayerID() or 0
            Place_SetEditorState(pid, "Editor::SparkMode")
            return "Spark Editor Mode activated (use Exit Editor to return)"
        else
            return "Editor native unavailable in current screen"
        end
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Toy Box Object Mode (Editor)",
    action = function()
        if type(Place_SetEditorState) == "function" then
            local pid = type(Players_GetHostPlayerID) == "function" and Players_GetHostPlayerID() or 0
            Place_SetEditorState(pid, "Editor::ObjectMode")
            return "Object Editor Mode activated (use Exit Editor to return)"
        else
            return "Editor native unavailable in current screen"
        end
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Freecam Flight Speed",
    cycle = { "10 m/s (Explore)", "25 m/s (Fast)", "60 m/s (Supersonic)" },
    index = 2,
    onCycle = function(val, i)
        local speeds = { 10.0, 25.0, 60.0 }
        if Crabe.Freecam then
            Crabe.Freecam.setSpeed(speeds[i] or 25.0)
        end
        return "Flight speed set to " .. val
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Teleport Up +15m (Over Obstacles)",
    action = function()
        Crabe.Cheats.trackPosition()
        local ok = Crabe.Cheats.teleportUp(15.0)
        local x, y, z = Crabe.Cheats.position()
        return ok and string.format("Teleported Up +15m -> (%.1f, %.1f, %.1f)", x or 0, y or 0, z or 0)
                  or "Walk 1 step first to capture movement pointer"
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Teleport Up +50m (Sky High)",
    action = function()
        Crabe.Cheats.trackPosition()
        local ok = Crabe.Cheats.teleportUp(50.0)
        local x, y, z = Crabe.Cheats.position()
        return ok and string.format("Teleported Up +50m -> (%.1f, %.1f, %.1f)", x or 0, y or 0, z or 0)
                  or "Walk 1 step first to capture movement pointer"
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Teleport Forward +15m (Through Walls)",
    action = function()
        Crabe.Cheats.trackPosition()
        local ok = Crabe.Cheats.teleportForward(15.0)
        local x, y, z = Crabe.Cheats.position()
        return ok and string.format("Teleported Forward +15m -> (%.1f, %.1f, %.1f)", x or 0, y or 0, z or 0)
                  or "Walk 1 step first to capture movement pointer"
    end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Return to Hub World",
    action = function() Game.ReturnToHub() return "Returning to Hub..." end,
})

Crabe.Menu.registerInCategory("Freecam & NoClip", {
    label = "Load Main Menu",
    action = function() Game.LoadMainMenu() return "Loading Main Menu..." end,
})

-- ---------------------------------------------------------------------------
-- 3. God Mode & Player Cheats (Invuln?rabilit? C++ & Sant?)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Cheats", {
    label = "God Mode (Invulnerability)",
    toggle = true,
    state = false,
    onToggle = function(on)
        Crabe.Cheats.setGodMode(on)
        return on and "God mode ON (C++ Cave active)" or "God mode OFF"
    end,
})

Crabe.Menu.registerInCategory("Cheats", {
    label = "Lock To Last Damaged Entity",
    action = function()
        local address = Crabe.Cheats.lockToLastDamaged()
        return address ~= 0 and string.format("Protected entity: 0x%X", address)
                             or "No entity has taken damage yet"
    end,
})

Crabe.Menu.registerInCategory("Cheats", {
    label = "Checkpoint Respawn",
    action = function() Game.CheckpointRespawn() return "Respawned at checkpoint" end,
})

Crabe.Menu.registerInCategory("Cheats", {
    label = "Reset Figure Memory",
    action = function() Game.ResetFigure() return "Figure memory reset" end,
})

-- ---------------------------------------------------------------------------
-- 4. Simulation & Time Control (Ralenti Matrix & Vitesse)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Time", {
    label = "Game Simulation Speed",
    action = function()
        local value = Crabe.GameSpeed.cycle()
        return value == 1 and "Game speed back to normal (x1.00)"
                           or string.format("Game speed x%.2f (Slow-Mo / Turbo)", value)
    end,
})

Crabe.Menu.registerInCategory("Time", {
    label = "Reset Game Speed (x1.00)",
    action = function()
        Crabe.GameSpeed.reset()
        return "Game speed reset to normal (x1.00)"
    end,
})

-- ---------------------------------------------------------------------------
-- 5. Skydomes & DirectX 11 Visuals (M?t?o & Graphismes)
-- ---------------------------------------------------------------------------

local function buildThemesSubmenu()
    local themes = Game.ListThemes()
    local items = {}
    for _, t in ipairs(themes) do
        items[#items + 1] = {
            label = t.label,
            action = function()
                Game.SetTheme(t.id)
                return "Applied theme: " .. t.label
            end,
        }
    end
    return { title = "SKYDOME THEMES", items = items }
end

Crabe.Menu.registerInCategory("Visuals", {
    label = "Skydome & Skybox Themes",
    submenu = buildThemesSubmenu(),
})

local function safeToggle(label, suffix)
    Crabe.Menu.registerInCategory("Visuals", {
        label = label,
        toggle = true,
        state = false,
        onToggle = function(on)
            if Game.VideoToggles and Game.VideoToggles[suffix] then
                Game.VideoToggles[suffix].set(on)
            end
            pcall(Game.SaveSettings)
            return label .. (on and " enabled" or " disabled")
        end,
    })
end

safeToggle("Bloom Effect", "Bloom")
safeToggle("SSAO Ambient Occlusion", "SSAO")
safeToggle("FXAA Anti-Aliasing", "FXAA")
safeToggle("Motion Blur", "MotionBlur")
safeToggle("Depth of Field", "DepthOfField")

-- ---------------------------------------------------------------------------
-- 6. Economy & 100% Unlocks (Argent & Tous les Play Sets)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Economy", {
    label = "Total Sparks Balance",
    action = function() return "Total Sparks: " .. tostring(Game.GetSparks()) end,
})

Crabe.Menu.registerInCategory("Economy", {
    label = "+1,000,000 Sparks",
    action = function()
        Game.AddToInventory("Items.money", 1000000)
        return "Added 1M -> Total: " .. tostring(Game.GetSparks())
    end,
})

Crabe.Menu.registerInCategory("Economy", {
    label = "+10,000,000 Sparks (Max)",
    action = function()
        Game.AddToInventory("Items.money", 10000000)
        return "Added 10M -> Total: " .. tostring(Game.GetSparks())
    end,
})

local playsets = {
    { "Asgard", "Thor: Asgard" },
    { "Avengers", "The Avengers" },
    { "Brave", "Brave: Forest" },
    { "Empire", "Star Wars: Rise Against the Empire" },
    { "Guardians", "Guardians of the Galaxy" },
    { "InsideOut", "Inside Out: Imagination" },
    { "Kyln", "Escape from the Kyln" },
    { "PlaysetX", "The Force Awakens" },
    { "Speedway", "Toy Box Speedway" },
    { "SpiderMan", "Spider-Man Manhattan" },
    { "Stitch", "Stitch: Tropical Rescue" },
    { "Takeover", "Toy Box Takeover" },
    { "TheCloneWars", "Star Wars: Twilight of the Republic" },
}

local playsetItems = {}
for _, p in ipairs(playsets) do
    local key, label = p[1], p[2]
    playsetItems[#playsetItems + 1] = {
        label = label,
        action = function()
            Game.UnlockPlayset(key)
            return "Unlocked: " .. label
        end,
    }
end

Crabe.Menu.registerInCategory("Economy", {
    label = "Unlock All 13 Play Sets",
    submenu = { title = "PLAY SETS", items = playsetItems },
})

Crabe.Menu.registerInCategory("Economy", {
    label = "Force Unlocked Progression Data",
    toggle = true,
    state = false,
    onToggle = function(on)
        Game.ForceUnlockData(on)
        return on and "Progression force-unlocked" or "Progression lock restored"
    end,
})
