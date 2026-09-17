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

-- ---------------------------------------------------------------------------
-- 7. Steam Multiplayer (P2P Lobbies & Friends)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "Steam Persona Status",
    action = function()
        if not Crabe.Multiplayer or not Crabe.Multiplayer.Steam then
            return "Error: Steam subsystem not loaded in CrabeLoader."
        end
        local okAvail, avail = pcall(Crabe.Multiplayer.Steam.isAvailable)
        if not okAvail or not avail then
            return "Steam Status: Offline / Game not running through Steam client."
        end
        local okName, name = pcall(Crabe.Multiplayer.Steam.getPersonaName)
        local okFriends, friends = pcall(Crabe.Multiplayer.Steam.getFriendCount)
        local displayName = (okName and name and #tostring(name) > 0) and tostring(name) or "Player"
        local friendCount = (okFriends and tonumber(friends)) and tonumber(friends) or 0
        return string.format("Steam Online: '%s' | %d friends online", displayName, friendCount)
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "Create Steam Lobby (Friends Only)",
    action = function()
        if not Crabe.Multiplayer or not Crabe.Multiplayer.Steam then
            return "Error: Multiplayer API unavailable."
        end
        local okAvail, avail = pcall(Crabe.Multiplayer.Steam.isAvailable)
        if not okAvail or not avail then
            return "Error: Steam is offline. Please launch via Steam client."
        end
        local okLobby, created = pcall(Crabe.Multiplayer.Steam.createLobby, true, 4)
        if okLobby and created then
            return "Lobby created successfully! Ready for friends."
        else
            return "Notice: Valve disables Steam Lobbies for DI3 Gold Edition (AppID 541670). Use Multiplayer P2P Direct Connect!"
        end
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "Invite Friends (Steam Overlay)",
    action = function()
        if not Crabe.Multiplayer or not Crabe.Multiplayer.Steam then
            return "Error: Multiplayer API unavailable."
        end
        local okAvail, avail = pcall(Crabe.Multiplayer.Steam.isAvailable)
        if not okAvail or not avail then
            return "Error: Steam is offline. Please launch via Steam client."
        end
        local okInvite, opened = pcall(Crabe.Multiplayer.Steam.openInviteOverlay)
        if okInvite and opened then
            return "Opened Steam Overlay! Send invites to friends."
        else
            return "Error: Overlay not available. Press Shift+Tab manually."
        end
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "Steam Lobby Status",
    action = function()
        if not Crabe.Multiplayer or not Crabe.Multiplayer.Steam then
            return "Error: Multiplayer API unavailable."
        end
        local okSt, st = pcall(Crabe.Multiplayer.Steam.getLobbyStatus)
        if not okSt or not st or not st.inLobby then
            return "Not currently in a Steam lobby."
        end
        return string.format("In Lobby (%s) | %d/%d players (LobbyID: %s)",
            st.isHost and "Host" or "Guest", st.memberCount or 1, st.memberLimit or 4, tostring(st.lobbyId or 0))
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "Leave Steam Lobby",
    action = function()
        if not Crabe.Multiplayer or not Crabe.Multiplayer.Steam then
            return "Error: Multiplayer API unavailable."
        end
        local ok = pcall(Crabe.Multiplayer.Steam.leaveLobby)
        if ok then
            return "Left Steam lobby."
        else
            return "Error: Failed to leave lobby."
        end
    end,
})

-- ---------------------------------------------------------------------------
-- 8. P2P Direct Multiplayer (Net-Z StandAloneLoop & Central Server)
-- ---------------------------------------------------------------------------

local function getSessionModule()
    if _G.DisneyInfinityMP and _G.DisneyInfinityMP.Session then
        return _G.DisneyInfinityMP.Session
    end
    local okEntry, dimp = pcall(require, "disneyinfinitymp")
    if okEntry and dimp and dimp.Session then
        return dimp.Session
    end
    local ok1, sess1 = pcall(require, "modules.session")
    if ok1 and sess1 then return sess1 end
    local ok2, sess2 = pcall(require, "disneyinfinitymp.modules.session")
    if ok2 and sess2 then return sess2 end
    return nil
end

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "[P1 - HOST] Démarrer Hébergement ToyBox (Port 3074 UDP)",
    action = function()
        local Session = getSessionModule()
        if not Session then
            return "Erreur: module DisneyInfinityMP.Session non disponible."
        end
        local ok = Session.hostToyBox()
        if ok then
            return "Hébergement lancé sur port 3074 UDP ! Chargement/rechargement du monde..."
        else
            return "Erreur: échec du lancement de l'hébergement ToyBox."
        end
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "[P2 - CLIENT] Connexion Directe LocalHost (127.0.0.1:3074)",
    action = function()
        local Session = getSessionModule()
        if not Session then
            return "Erreur: module DisneyInfinityMP.Session non disponible."
        end
        local ok = Session.directConnect("127.0.0.1", 3074, "Host1")
        if ok then
            return "Connexion directe à 127.0.0.1:3074 lancée ! Chargement du niveau..."
        else
            return "Erreur: échec de la connexion à 127.0.0.1:3074."
        end
    end,
})

local customLanIp = "192.168.1.100"
local lanSubnet = "192.168.1."
local lanHostNum = 100

local function getCustomLanIp()
    local f = io.open("mods/target_ip.txt", "r") or io.open("target_ip.txt", "r")
    if f then
        local line = f:read("*l") or f:read("*a")
        f:close()
        if line then
            local parsed = line:match("(%d+%.%d+%.%d+%.%d+)")
            if parsed then
                customLanIp = parsed
                local sub, num = parsed:match("^(%d+%.%d+%.%d+%.)(%d+)$")
                if sub and num then
                    lanSubnet = sub
                    lanHostNum = tonumber(num) or 100
                end
            end
        end
    end
    return customLanIp
end
getCustomLanIp()

local function buildLanSubmenu()
    local curIp = customLanIp
    local items = {}

    table.insert(items, {
        label = "-> Connexion Directe à " .. curIp .. ":3074",
        action = function()
            local Session = getSessionModule()
            if not Session then
                return "Erreur: module DisneyInfinityMP.Session indisponible."
            end
            local ok = Session.directConnect(curIp, 3074, "HostLAN")
            if ok then
                return string.format("Connexion directe à %s:3074 lancée ! Chargement...", curIp)
            else
                return string.format("Erreur: échec de la connexion à %s:3074.", curIp)
            end
        end,
    })

    table.insert(items, {
        label = "IP Prédéfinies (Cycle rapide)",
        cycle = { "192.168.1.100", "192.168.1.50", "192.168.1.20", "192.168.1.10", "192.168.1.2", "192.168.0.100", "192.168.0.50", "10.0.0.2" },
        index = 1,
        onCycle = function(val)
            customLanIp = val
            local sub, num = val:match("^(%d+%.%d+%.%d+%.)(%d+)$")
            if sub and num then
                lanSubnet = sub
                lanHostNum = tonumber(num) or 100
            end
            return "IP cible définie: " .. val .. " (Réouvrir pour actualiser le libellé)"
        end,
    })

    table.insert(items, {
        label = "Sous-réseau (Préfixe)",
        cycle = { "192.168.1.", "192.168.0.", "10.0.0.", "172.16.0." },
        index = 1,
        onCycle = function(val)
            lanSubnet = val
            customLanIp = lanSubnet .. tostring(lanHostNum)
            return "Sous-réseau: " .. val .. " -> IP cible: " .. customLanIp
        end,
    })

    table.insert(items, {
        label = "Dernier octet: +10",
        action = function()
            lanHostNum = (lanHostNum + 10) % 255
            if lanHostNum == 0 then lanHostNum = 1 end
            customLanIp = lanSubnet .. tostring(lanHostNum)
            return "IP cible ajustée: " .. customLanIp
        end,
    })

    table.insert(items, {
        label = "Dernier octet: +1",
        action = function()
            lanHostNum = (lanHostNum + 1) % 255
            if lanHostNum == 0 then lanHostNum = 1 end
            customLanIp = lanSubnet .. tostring(lanHostNum)
            return "IP cible ajustée: " .. customLanIp
        end,
    })

    table.insert(items, {
        label = "Dernier octet: -1",
        action = function()
            lanHostNum = lanHostNum - 1
            if lanHostNum < 1 then lanHostNum = 254 end
            customLanIp = lanSubnet .. tostring(lanHostNum)
            return "IP cible ajustée: " .. customLanIp
        end,
    })

    table.insert(items, {
        label = "Lire depuis mods/target_ip.txt",
        action = function()
            local ip = getCustomLanIp()
            return "IP lue depuis fichier: " .. ip
        end,
    })

    table.insert(items, {
        label = "Sauvegarder dans mods/target_ip.txt",
        action = function()
            local f = io.open("mods/target_ip.txt", "w")
            if f then
                f:write(customLanIp)
                f:close()
                return "Sauvegardé: " .. customLanIp .. " dans mods/target_ip.txt"
            end
            return "Erreur d'écriture dans mods/target_ip.txt"
        end,
    })

    return items
end

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "[P2 - CLIENT] Connexion Directe LAN (IP personnalisée)",
    submenu = {
        title = "CONNEXION DIRECTE LAN",
        build = buildLanSubmenu,
    },
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "[Central Server] Statut Serveur Central (Docker 127.0.0.1:3000)",
    action = function()
        local isOnline = false
        if Crabe and Crabe.Multiplayer and Crabe.Multiplayer.checkServerReachability then
            isOnline = Crabe.Multiplayer.checkServerReachability("127.0.0.1", 3000, 500)
        elseif Crabe and Crabe.Multiplayer and Crabe.Multiplayer.getStatus then
            local st = Crabe.Multiplayer.getStatus()
            isOnline = st.isServerOnline
        end

        if isOnline then
            return "Serveur Central Docker (127.0.0.1:3000) : EN LIGNE (Joignable) !"
        else
            return "Serveur Central Docker (127.0.0.1:3000) : HORS LIGNE (Non joignable)"
        end
    end,
})

Crabe.Menu.registerInCategory("Multiplayer", {
    label = "[Contrôles] Débloquer le Joueur & Pause (Unlock Controls)",
    action = function()
        if type(_G.Pause_UnPauseFromPausedScreenIfPaused) == "function" then
            pcall(_G.Pause_UnPauseFromPausedScreenIfPaused, 0)
        end
        if type(_G.UnlockAllControls) == "function" then
            pcall(_G.UnlockAllControls)
        end
        if type(_G.Players_UnlockAllControls) == "function" then
            pcall(_G.Players_UnlockAllControls, "ProcessSwitchLevel")
            pcall(_G.Players_UnlockAllControls, "LevelLoad")
            pcall(_G.Players_UnlockAllControls, "ScriptLock")
            pcall(_G.Players_UnlockAllControls, "SYSTEM_MENU")
        end
        if type(Game) == "table" and type(Game.UnlockAllControls) == "function" then
            pcall(Game.UnlockAllControls)
        end
        if type(Game) == "table" and type(Game.UnlockAllControllers) == "function" then
            pcall(Game.UnlockAllControllers)
        end
        return "Contrôles et pause débloqués ! Appuyez sur F5 pour fermer le menu."
    end,
})

-- ---------------------------------------------------------------------------
-- 6. Engine Memory Patches (Toy Box Editor Everywhere)
-- ---------------------------------------------------------------------------

Crabe.Menu.registerInCategory("Cheats", {
    label = "Unlock Toy Box Editor Everywhere (PlaySets)",
    action = function()
        if not (Crabe and Crabe.Memory and Crabe.Memory.patternScan and Crabe.Memory.patchBytes) then
            return "Crabe.Memory is not available"
        end
        local addr = Crabe.Memory.patternScan("0F B6 42 20 85 C0 74")
        if not addr then
            return "Pattern not found (already unlocked or incompatible build)"
        end
        local ok = Crabe.Memory.patchBytes(addr + 6, "90 90")
        return ok and "Toy Box Editor unlocked everywhere!" or "Failed to patch memory"
    end
})

-- ---------------------------------------------------------------------------
-- 7. ImGui In-Game Interface (Rendered via onDraw in DirectX 11)
-- ---------------------------------------------------------------------------

local isMenuOpen = false

if Crabe and Crabe.Input and Crabe.Input.bindKey then
    Crabe.Input.bindKey(0x74, function() -- VK_F5
        isMenuOpen = not isMenuOpen
    end)
elseif Crabe and Crabe.Events and Crabe.Events.on then
    Crabe.Events.on("keyDown", function(vk)
        if vk == 0x74 then
            isMenuOpen = not isMenuOpen
        end
    end)
end

local function renderImGuiMenu()
    if not isMenuOpen or not ImGui then return end

    if ImGui.SetNextWindowSize then
        ImGui.SetNextWindowSize(500, 560, 4) -- ImGuiCond_FirstUseEver = 4
    end

    local visible = ImGui.Begin("CrabeMenu - Disney Infinity 3.0 (F5)", true)
    if not visible then
        ImGui.End()
        return
    end

    if ImGui.BeginTabBar and ImGui.BeginTabBar("CrabeMenuTabs") then
        local root = Crabe.Menu and Crabe.Menu.root
        if root and root.items then
            for i, cat in ipairs(root.items) do
                local tabLabel = cat.label or ("Cat " .. i)
                if ImGui.BeginTabItem(tabLabel) then
                    if cat.submenu and cat.submenu.items then
                        for j, item in ipairs(cat.submenu.items) do
                            local itemLabel = item.label or ("Item " .. j)
                            if item.submenu then
                                if ImGui.Button("> " .. itemLabel) then
                                    if item.submenu.items and #item.submenu.items > 0 then
                                        Crabe.Menu.stack[#Crabe.Menu.stack + 1] = { menu = item.submenu, index = 1 }
                                    end
                                end
                            elseif item.toggle then
                                local text = itemLabel .. (item.state and " [ON]" or " [OFF]")
                                if ImGui.Button(text) then
                                    item.state = not item.state
                                    if item.onToggle then
                                        local res = item.onToggle(item.state)
                                        if res then Crabe.Menu.status = tostring(res) end
                                    end
                                end
                            elseif item.cycle then
                                local text = itemLabel .. " [" .. tostring(item.cycle[item.index or 1]) .. "]"
                                if ImGui.Button(text) then
                                    item.index = ((item.index or 1) % #item.cycle) + 1
                                    if item.onCycle then
                                        local res = item.onCycle(item.cycle[item.index], item.index)
                                        if res then Crabe.Menu.status = tostring(res) end
                                    end
                                end
                            else
                                if ImGui.Button(itemLabel) then
                                    if item.action then
                                        local res = item.action()
                                        if res then Crabe.Menu.status = tostring(res) end
                                    end
                                end
                            end
                        end
                    elseif cat.action then
                        if ImGui.Button(tabLabel) then
                            local res = cat.action()
                            if res then Crabe.Menu.status = tostring(res) end
                        end
                    end
                    ImGui.EndTabItem()
                end
            end
        end
        ImGui.EndTabBar()
    end

    if Crabe.Menu and Crabe.Menu.status and Crabe.Menu.status ~= "" then
        ImGui.Separator()
        if ImGui.TextColored then
            ImGui.TextColored(0.2, 0.8, 1.0, 1.0, Crabe.Menu.status)
        else
            ImGui.TextUnformatted(Crabe.Menu.status)
        end
    end

    ImGui.End()
end

if Crabe and Crabe.Mod and Crabe.Mod.register then
    Crabe.Mod.register({
        id = "crabemenu",
        name = "CrabeMenu",
        onInit = function()
            if Crabe and Crabe.write then
                Crabe.write("[CrabeMenu] Master mod initialized (press F5 to toggle in-game menu).")
            end
        end,
        onDraw = function()
            renderImGuiMenu()
        end
    })
end


