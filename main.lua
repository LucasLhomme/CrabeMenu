Crabe = Crabe or {}
Crabe.Menu = Crabe.Menu or {}
Crabe.Cheats = Crabe.Cheats or {}
Crabe.GameSpeed = Crabe.GameSpeed or {}

-- God mode: two code caves share one data block with this script.
--   damage cave (apply-health-delta, esi = health component, [ebp+8] = delta):
--     records the last component that lost health; when enabled and esi is the
--     player, the new health becomes maxHealth ([esi+0Ch]) instead.
--   HUD cave (health meter fill, eax = component): writes every drawn component
--     into a 64-slot ring. The avatar meter is drawn every frame, an enemy meter
--     only while engaged, so the most frequent component is the player.
-- Health component layout: float health at +08h, float maxHealth at +0Ch.
local GOD_MAGIC = 0x474F4431
local GOD_OFF = { magic = 0x00, enabled = 0x04, player = 0x08, lastDamaged = 0x0C, ringIndex = 0x10, ring = 0x20 }
local GOD_RING = 64
local GOD_DAMAGE_PATTERN = "F3 0F 58 45 08 F3 0F 10 4E 0C 0F 2F C1 57 F3 0F 11 46 08"
local GOD_DAMAGE_SITE = 5
local GOD_HUD_PATTERN = "85 C0 0F 84 ?? ?? ?? ?? F3 0F 10 40 08 F3 0F 5E 40 0C 0F 2F C8"
local GOD_HUD_SITE = 8

local godBlock = nil
local godLocked = false
local godTicks = 0

local function le32(value)
    local b = {}
    for i = 1, 4 do
        b[i] = string.format("%02X", value % 256)
        value = math.floor(value / 256)
    end
    return table.concat(b, " ")
end

local function installGodCaves()
    if godBlock then return true end
    local block = Crabe.Memory.sharedBlock("crabemenu.godmode", GOD_OFF.ring + GOD_RING * 4)
    if not block then
        print("[GodMode] shared block unavailable (loader too old?)")
        return false
    end
    if Crabe.Memory.readU32(block + GOD_OFF.magic) == GOD_MAGIC then
        godBlock = block
        return true
    end

    local damage = Crabe.Memory.patternScan(GOD_DAMAGE_PATTERN)
    local hud = Crabe.Memory.patternScan(GOD_HUD_PATTERN)
    if not damage or not hud then
        print(string.format("[GodMode] sites not found (damage=%s, hud=%s)", tostring(damage), tostring(hud)))
        return false
    end

    local damageBody = table.concat({
        "F6 45 0B 80",
        "74 06",
        "89 35 " .. le32(block + GOD_OFF.lastDamaged),
        "80 3D " .. le32(block + GOD_OFF.enabled) .. " 00",
        "74 0D",
        "3B 35 " .. le32(block + GOD_OFF.player),
        "75 05",
        "F3 0F 10 46 0C",
    }, " ")
    local hudBody = table.concat({
        "51",
        "8B 0D " .. le32(block + GOD_OFF.ringIndex),
        "83 E1 3F",
        "89 04 8D " .. le32(block + GOD_OFF.ring),
        "41",
        "89 0D " .. le32(block + GOD_OFF.ringIndex),
        "59",
    }, " ")

    if not Crabe.Memory.installCodeCave(damage + GOD_DAMAGE_SITE, damageBody, 5) then
        print("[GodMode] damage cave install failed")
        return false
    end
    if not Crabe.Memory.installCodeCave(hud + GOD_HUD_SITE, hudBody, 5) then
        print("[GodMode] HUD cave install failed")
    end
    Crabe.Memory.writeU32(block + GOD_OFF.magic, GOD_MAGIC)
    godBlock = block
    print(string.format("[GodMode] caves installed (damage 0x%X, hud 0x%X, block 0x%X)",
        damage + GOD_DAMAGE_SITE, hud + GOD_HUD_SITE, block))
    return true
end

local function isHealthComponent(address)
    if not address or address == 0 then return false end
    local maxHealth = Crabe.Memory.readFloat(address + 0x0C)
    return maxHealth ~= nil and maxHealth > 0 and maxHealth < 1e7
end

local function pickPlayerComponent()
    local counts, best, bestCount = {}, nil, 0
    for i = 0, GOD_RING - 1 do
        local p = Crabe.Memory.readU32(godBlock + GOD_OFF.ring + i * 4)
        if p and p ~= 0 then
            local c = (counts[p] or 0) + 1
            counts[p] = c
            if c > bestCount then best, bestCount = p, c end
        end
    end
    if best and isHealthComponent(best) then return best end
    return nil
end

local function refillPlayer()
    local p = Crabe.Memory.readU32(godBlock + GOD_OFF.player)
    if isHealthComponent(p) then
        Crabe.Memory.writeFloat(p + 0x08, Crabe.Memory.readFloat(p + 0x0C))
    end
end

Game.onTick(function()
    if not godBlock then return end
    godTicks = godTicks + 1
    if godTicks % 15 ~= 0 then return end
    if not godLocked then
        local p = pickPlayerComponent()
        if p and p ~= Crabe.Memory.readU32(godBlock + GOD_OFF.player) then
            Crabe.Memory.writeU32(godBlock + GOD_OFF.player, p)
        end
    end
    if Crabe.Memory.readU32(godBlock + GOD_OFF.enabled) ~= 0 then
        refillPlayer()
    end
end)

--- Sets god mode invulnerability state.
function Crabe.Cheats.setGodMode(enabled)
    if not installGodCaves() then return false end
    Crabe.Memory.writeU32(godBlock + GOD_OFF.enabled, enabled and 1 or 0)
    if enabled then refillPlayer() end
    return enabled
end

--- Returns whether god mode is currently enabled.
function Crabe.Cheats.isGodMode()
    return godBlock ~= nil and Crabe.Memory.readU32(godBlock + GOD_OFF.enabled) ~= 0
end

--- Pins god mode to the last component that lost health; returns its address (0 if none yet).
function Crabe.Cheats.lockToLastDamaged()
    if not installGodCaves() then return 0 end
    local last = Crabe.Memory.readU32(godBlock + GOD_OFF.lastDamaged) or 0
    if last ~= 0 then
        Crabe.Memory.writeU32(godBlock + GOD_OFF.player, last)
        godLocked = true
    end
    return last
end

--- Returns to automatic player detection after lockToLastDamaged.
function Crabe.Cheats.unlockGodTarget()
    godLocked = false
end

if Crabe.Memory.sharedBlock then
    local block = Crabe.Memory.sharedBlock("crabemenu.godmode", GOD_OFF.ring + GOD_RING * 4)
    if block and Crabe.Memory.readU32(block + GOD_OFF.magic) == GOD_MAGIC then
        godBlock = block
        Crabe.Memory.writeU32(block + GOD_OFF.enabled, 0)
    end
end

local simulationSpeeds = { 0.25, 0.5, 1.0, 1.5, 2.0, 5.0 }
local currentSpeedIdx = 3

--- Cycles through simulation speeds.
function Crabe.GameSpeed.cycle()
    currentSpeedIdx = (currentSpeedIdx % #simulationSpeeds) + 1
    return simulationSpeeds[currentSpeedIdx]
end

--- Resets simulation speed to normal.
function Crabe.GameSpeed.reset()
    currentSpeedIdx = 3
    return 1.0
end


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
-- 2. Free camera (the engine's own) & leaving the world
-- ---------------------------------------------------------------------------

-- Hot reload keeps the menu tree, and this category used to be called
-- "Freecam & NoClip": take that entry over in place and drop any duplicate,
-- so no stale button from the old name stays on screen.
do
    local items = Crabe.Menu.root.items
    local old
    for _, item in ipairs(items) do
        if item.label == "Freecam & NoClip" and item.submenu then old = item end
    end
    if old then
        for i = #items, 1, -1 do
            if items[i].label == "Freecam & World" then table.remove(items, i) end
        end
        old.label = "Freecam & World"
        old.submenu.title = "FREECAM & WORLD"
        old.submenu.items = {}
        Crabe.Menu.stack = { { menu = Crabe.Menu.root, index = 1 } }
    end
end

local freeCamItem = {
    label = "Free Camera (Engine)",
    toggle = true,
    state = false,
}

-- The menu flips `state` before calling; it is set back to what the engine
-- actually did, so a refused start does not leave the entry showing [ON].
function freeCamItem.onToggle(on)
    if not on then
        Crabe.Camera.StopFreeCam()
        return "Free camera OFF"
    end

    freeCamItem.state = false
    freeCamItem.state = Crabe.Camera.StartFreeCam()
    if not freeCamItem.state then
        return "No camera to switch here (load a world first)"
    end
    return "Free camera ON -- left stick: fly | right stick: look | R1/R2: up/down"
end

Crabe.Menu.registerInCategory("Freecam & World", freeCamItem)

-- One press can reach a handler several times in a row, and each of these
-- starts a level transition: a second request inside this window is dropped.
local LEAVE_COOLDOWN = 5.0
local lastLeave = nil

local function clock()
    return (type(os) == "table" and type(os.clock) == "function") and os.clock() or nil
end

local function leaveAllowed()
    local now = clock()
    if lastLeave and (now == nil or now - lastLeave < LEAVE_COOLDOWN) then return false end
    lastLeave = now or 0
    return true
end

-- The pause menu's own Quit (pausemenu.lua PauseExit) without its popup: the
-- game autosaves, then returns to the main menu by itself.
Crabe.Menu.registerInCategory("Freecam & World", {
    label = "Go to Main Menu",
    action = function()
        local world = Game.CurrentWorld()
        if type(world) == "string" and string.lower(world) == "frontend" then
            return "Already in the main menu"
        end
        if not leaveAllowed() then return nil end
        if Crabe.Camera.IsFreeCamActive() then
            Crabe.Camera.StopFreeCam()
            freeCamItem.state = false
        end
        Crabe.native("Pause_ExitGame", "Go to Main Menu")()
        return "Going to the main menu..."
    end,
})

-- UI_ReturnToHub takes the player number, as pausemenu.lua passes it.
Crabe.Menu.registerInCategory("Freecam & World", {
    label = "Return to Hub World",
    action = function()
        if not leaveAllowed() then return nil end
        Crabe.native("UI_ReturnToHub", "Return to Hub World")(Crabe.hostPlayer())
        return "Returning to the hub..."
    end,
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

local isMenuOpen = false
local menuCursor = 1
local menuScrollTo = false
local lastFrame = nil

-- Arrows, Enter, Backspace, PageUp/Down, Home/End, Esc. The game keeps re-centring
-- the mouse every frame, so the pointer cannot be trusted to sit on a row.
local NAV_KEYS = { 0x26, 0x28, 0x25, 0x27, 0x0D, 0x08, 0x21, 0x22, 0x24, 0x23, 0x1B }

--- Returns the menu currently on top of the navigation stack.
local function currentMenu()
    local stack = Crabe.Menu and Crabe.Menu.stack
    local frame = stack and stack[#stack]
    return frame and frame.menu or nil
end

--- Builds the display label of one entry, suffixed with its state.
local function entryLabel(item)
    local suffix = ""
    if item.submenu then
        suffix = "  >"
    elseif item.toggle then
        suffix = item.state and "  [ON]" or "  [OFF]"
    elseif item.cycle then
        suffix = "  [" .. tostring(item.cycle[item.index or 1]) .. "]"
    end
    return tostring(item.label) .. suffix
end

--- Moves the highlighted row, wrapping around both ends.
local function moveCursor(delta, count)
    if count < 1 then return end
    menuCursor = (menuCursor - 1 + delta) % count + 1
    menuScrollTo = true
end

--- Opens or closes the menu, taking the navigation keys away from the game
--- while it is up so that arrows do not also steer the player.
local function setMenuOpen(open)
    isMenuOpen = open
    if open then
        menuScrollTo = true
    end
    if Crabe.Input and Crabe.Input.captureKeys then
        Crabe.Input.captureKeys(open and NAV_KEYS or nil)
    end
end

--- Applies one navigation key press to the menu.
-- Keys that act (select, back, close) run once per press; only the cursor
-- keys follow Windows' auto-repeat, so holding Enter cannot fire an action
-- ten times or launch the same level over and over.
local REPEATABLE_KEYS = { [0x26] = true, [0x28] = true, [0x21] = true, [0x22] = true }

local function onNavKey(vk, isRepeat)
    if not isMenuOpen or not Crabe.Menu then return end
    if isRepeat and not REPEATABLE_KEYS[vk] then return end

    local menu = currentMenu()
    local count = (menu and menu.items) and #menu.items or 0
    if count < 1 then return end

    if menuCursor > count then menuCursor = count end

    local stack = Crabe.Menu.stack
    local frame = stack and stack[#stack]

    if vk == 0x28 then
        moveCursor(1, count)
        if frame then frame.index = menuCursor end
    elseif vk == 0x26 then
        moveCursor(-1, count)
        if frame then frame.index = menuCursor end
    elseif vk == 0x22 then
        moveCursor(5, count)
        if frame then frame.index = menuCursor end
    elseif vk == 0x21 then
        moveCursor(-5, count)
        if frame then frame.index = menuCursor end
    elseif vk == 0x24 then
        menuCursor, menuScrollTo = 1, true
        if frame then frame.index = menuCursor end
    elseif vk == 0x23 then
        menuCursor, menuScrollTo = count, true
        if frame then frame.index = menuCursor end
    elseif vk == 0x0D or vk == 0x27 then
        Crabe.Menu._activate(menuCursor)
    elseif vk == 0x08 or vk == 0x25 then
        Crabe.Menu._back()
    elseif vk == 0x1B then
        if stack and #stack > 1 then
            Crabe.Menu._back()
        else
            setMenuOpen(false)
        end
    end
end

if Crabe and Crabe.Events and Crabe.Events.on then
    Crabe.Events.on("keyDown", function(vk, isRepeat)
        if vk == 0x74 then
            if not isRepeat then setMenuOpen(not isMenuOpen) end
        else
            onNavKey(vk, isRepeat)
        end
    end)
end

--- Renders the complete CrabeMenu ImGui interface.
local function renderImGuiMenu()
    if not isMenuOpen or not ImGui then return end

    if ImGui.SetNextWindowSize then
        ImGui.SetNextWindowSize(380, 440, 4)
    end

    -- ImGuiWindowFlags_NoInputs = 197120 (NoMouseInputs 512 | NoNavInputs 65536 | NoNavFocus 131072)
    -- Guarantees pure keyboard/gamepad navigation with zero mouse-hover or nav-focus side effects.
    local WINDOW_FLAGS = 197120
    local visible, open = ImGui.Begin("Crabe Menu", true, WINDOW_FLAGS)
    if open == false then
        setMenuOpen(false)
        ImGui.End()
        return
    end

    if not visible then
        ImGui.End()
        return
    end

    local menu = currentMenu()
    if not menu or not menu.items or #menu.items == 0 then
        ImGui.TextDisabled("No mod has registered a menu entry.")
        ImGui.TextDisabled("Mods declare them with Crabe.Menu.register{...}.")
        ImGui.End()
        return
    end

    local stack = Crabe.Menu and Crabe.Menu.stack
    local title = tostring(menu.title or "CRABE MENU")
    if stack and #stack > 1 then
        title = "< " .. title
    end
    ImGui.Text(title)
    ImGui.Separator()

    local count = #menu.items
    local frame = stack and stack[#stack]
    if frame ~= lastFrame then
        lastFrame = frame
        menuCursor = (frame and frame.index) or 1
        menuScrollTo = true
    end
    if menuCursor > count then menuCursor = count end
    if menuCursor < 1 then menuCursor = 1 end

    ImGui.BeginChild("MenuScroll", 0, -56, false, WINDOW_FLAGS)
    for i, item in ipairs(menu.items) do
        local isCurrent = (i == menuCursor)
        local prefix = isCurrent and "> " or "  "
        local displayLabel = prefix .. entryLabel(item) .. "##item_" .. tostring(i)
        ImGui.Selectable(displayLabel, isCurrent)
        if isCurrent and menuScrollTo then
            ImGui.SetScrollHereY(0.5)
        end
    end
    menuScrollTo = false
    ImGui.EndChild()

    ImGui.Separator()

    local status = Crabe.Menu and Crabe.Menu.status
    if status and status ~= "" then
        if ImGui.TextColored then
            ImGui.TextColored(0.3, 0.9, 0.4, 1.0, tostring(status))
        else
            ImGui.Text(tostring(status))
        end
    else
        ImGui.TextDisabled("Fleches: Nav  |  Entree: OK  |  Retour: Precedent")
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
        onUpdate = function(dt)
            if isGodModeActive then
                local p = (type(Game) == "table" and type(Game.GetLocalPlayer) == "function") and Game.GetLocalPlayer()
                if p and type(Game.SetPlayerHealth) == "function" then
                    pcall(Game.SetPlayerHealth, p, 9999.0)
                end
            end
        end,
        onDraw = function()
            renderImGuiMenu()
        end,
        onShutdown = function()
            setMenuOpen(false)
        end
    })
end


