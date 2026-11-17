local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local FreeCam = Loader.load("modules.freecam")
local Cheats = Loader.load("modules.cheats")
local Spawner = Loader.load("modules.spawner")
local Avatar = Loader.load("modules.avatar")

local Editor = {}

Editor.active = false
Editor.selectedAsset = nil
Editor.selectedLabel = "None"
Editor.placedObjects = {}
Editor.history = {}

-- Quests System
Editor.quests = {}
Editor.selectedQuestGiver = nil

local TOGGLE_DEBOUNCE = 0.4
local lastToggleClock = -1

local function inFrontEnd()
    local world = Native.poll(Game.CurrentWorld)
    return type(world) ~= "string" or world:lower() == "frontend"
end

local function getModsDir()
    return "mods"
end

local function sanitizeModName(name)
    if not name or name == "" then return "MyCustomWorld" end
    local sanitized = name:gsub("[^%w_%-]", "_")
    if sanitized == "" then return "MyCustomWorld" end
    return sanitized
end

--- Reports whether the editor mode is currently running.
function Editor.isActive()
    return Editor.active
end

--- Selects an asset to be placed.
function Editor.selectAsset(id, label)
    Editor.selectedAsset = id
    Editor.selectedLabel = label or id
    State.setStatus(string.format("Selected asset: %s", Editor.selectedLabel), "info")
end

--- Toggles the World Editor & Debug Mode (F1).
function Editor.toggle(mode)
    if mode == nil then
        if State.gameClock - lastToggleClock < TOGGLE_DEBOUNCE then return Editor.active end
        lastToggleClock = State.gameClock
    end
    if inFrontEnd() then
        State.setStatus("Load a world before entering Editor Mode", "warning")
        return false
    end

    local shouldEnable = not Editor.active
    if mode == "on" then shouldEnable = true
    elseif mode == "off" then shouldEnable = false end

    if shouldEnable and not Editor.active then
        Editor.active = true
        
        -- 1. Ensure Player is safe (GodMode)
        if Cheats and Cheats.setGodMode then
            Cheats.setGodMode(true)
        end

        -- 2. Activate Free Camera
        if not FreeCam.isActive() then
            FreeCam.toggle()
        end

        -- 3. Auto-scan world inventory if not scanned yet
        if #Spawner.objects == 0 then
            Spawner.scan()
        end

        -- 4. Select default asset if none selected
        if not Editor.selectedAsset and #Spawner.objects > 0 then
            Editor.selectedAsset = Spawner.objects[1].id
            Editor.selectedLabel = Spawner.objects[1].label
        end

        if Crabe and Crabe.Plugins and Crabe.Plugins.set then
            Crabe.Plugins.set("dev_toolkit.editormode", "1")
        end

        State.setStatus("WORLD EDITOR ACTIVE | F1: Exit | F5: Asset Palette | Place & Build", "success")
        return true

    elseif not shouldEnable and Editor.active then
        Editor.active = false

        -- Release Free Camera
        if FreeCam.isActive() then
            FreeCam.toggle()
        end
        if type(_G.System_UnlockAllControllers) == "function" then
            pcall(_G.System_UnlockAllControllers)
        end

        if Crabe and Crabe.Plugins and Crabe.Plugins.set then
            Crabe.Plugins.set("dev_toolkit.editormode", "0")
        end

        State.setStatus("World Editor closed", "info")
        return true
    end

    return true
end

--- Places the currently selected asset at absolute 3D world coordinates.
function Editor.placeCurrent()
    if inFrontEnd() then
        State.setStatus("Cannot place objects on the main menu", "warning")
        return false
    end

    if not Editor.selectedAsset then
        State.setStatus("No asset selected in editor palette", "warning")
        return false
    end

    local x, y, z = nil, nil, nil
    if State.lastRayHit and State.lastRayHit.x then
        x = tonumber(State.lastRayHit.x)
        y = tonumber(State.lastRayHit.y)
        z = tonumber(State.lastRayHit.z)
    end

    if not x and Crabe and Crabe.Plugins and Crabe.Plugins.get then
        local raw = Crabe.Plugins.get("dev_toolkit.telemetry")
        if raw and raw ~= "" then
            if raw:match('"rayHit"%s*:%s*true') then
                x = tonumber(raw:match('"rayX"%s*:%s*([%d%.%-]+)'))
                y = tonumber(raw:match('"rayY"%s*:%s*([%d%.%-]+)'))
                z = tonumber(raw:match('"rayZ"%s*:%s*([%d%.%-]+)'))
            end
            if not x then
                local cx = tonumber(raw:match('"camX"%s*:%s*([%d%.%-]+)'))
                local cy = tonumber(raw:match('"camY"%s*:%s*([%d%.%-]+)'))
                local cz = tonumber(raw:match('"camZ"%s*:%s*([%d%.%-]+)'))
                local dx = tonumber(raw:match('"camDx"%s*:%s*([%d%.%-]+)')) or 0
                local dy = tonumber(raw:match('"camDy"%s*:%s*([%d%.%-]+)')) or 0
                local dz = tonumber(raw:match('"camDz"%s*:%s*([%d%.%-]+)')) or 1
                if cx and cy and cz then
                    x = cx + dx * 5.0
                    y = cy + dy * 5.0
                    z = cz + dz * 5.0
                end
            end
        end
    end

    if not x then
        local handle = Avatar.handle()
        if handle then
            local px, py, pz = Native.poll(Game.ActorPosition, handle)
            x = tonumber(px) or 0
            y = tonumber(py) or 0
            z = tonumber(pz) or 0
        else
            x, y, z = 0, 0, 0
        end
    end

    local snap = tonumber(State.editorSnapGrid) or 0
    if snap > 0 then
        x = math.floor((x / snap) + 0.5) * snap
        y = math.floor((y / snap) + 0.5) * snap
        z = math.floor((z / snap) + 0.5) * snap
    end

    -- Use authentic Game.SpawnItemAt for precise (X, Y, Z) placement
    local ok = false
    if Game and Game.SpawnItemAt then
        ok = pcall(Game.SpawnItemAt, Editor.selectedAsset, x, y, z)
    end
    if not ok and Game and Game.SpawnItemMany then
        ok = Native.run("Game.SpawnItemMany", Game.SpawnItemMany, Editor.selectedAsset, 1)
    end

    if not ok then
        State.setStatus("Placement failed for " .. Editor.selectedLabel, "error")
        return false
    end

    local world = Native.poll(Game.CurrentWorld) or "UnknownWorld"
    local entry = {
        id = Editor.selectedAsset,
        label = Editor.selectedLabel,
        x = x,
        y = y,
        z = z,
        world = world,
        timestamp = os.time(),
    }

    table.insert(Editor.placedObjects, entry)
    table.insert(Editor.history, entry)

    State.setStatus(string.format("Placed %s at (%.1f, %.1f, %.1f) [Total: %d]", Editor.selectedLabel, x or 0, y or 0, z or 0, #Editor.placedObjects), "success")
    return true
end

--- Marks the last placed entity as a Quest Giver and attaches a quest to it.
function Editor.addQuestToLastPlaced(title, dialogText, objType, targetAsset)
    if #Editor.placedObjects == 0 then
        State.setStatus("Place an NPC or character first to assign a quest!", "warning")
        return false
    end

    local giver = Editor.placedObjects[#Editor.placedObjects]
    local questId = string.format("QUEST_%02d", #Editor.quests + 1)
    local qTitle = (title and title ~= "") and title or ("Mission de " .. giver.label)
    local qDialog = (dialogText and dialogText ~= "") and dialogText or "Aide-moi a accomplir cette quete !"
    local qType = objType or "talk"

    local quest = {
        id = questId,
        title = qTitle,
        giverId = giver.id,
        giverLabel = giver.label,
        giverPos = { x = giver.x, y = giver.y, z = giver.z },
        dialog = qDialog,
        type = qType,
        targetAsset = targetAsset or "",
        rewardXp = 250,
        rewardSparks = 100,
    }

    table.insert(Editor.quests, quest)
    State.setStatus(string.format("Quest '%s' created on %s!", qTitle, giver.label), "success")
    return true
end

--- Removes the last placed object from the session.
function Editor.undo()
    if #Editor.placedObjects == 0 then
        State.setStatus("No objects placed to undo", "warning")
        return false
    end

    table.remove(Editor.placedObjects)
    table.remove(Editor.history)
    State.setStatus(string.format("Last object removed (Remaining: %d)", #Editor.placedObjects), "info")
    return true
end

--- Clears all placed objects from the game and session.
function Editor.clearAll()
    Spawner.clearPlaced()
    Editor.placedObjects = {}
    Editor.history = {}
    Editor.quests = {}
    State.setStatus("All placed editor objects and quests cleared", "info")
    return true
end

--- Exports the placed world layout into a standalone CrabeLoader mod folder.
--- Generates mod.json, scene_layout.json, and fully autonomous runtime.lua with live Quest Watcher.
function Editor.exportMod(rawModName, authorName)
    if #Editor.placedObjects == 0 then
        State.setStatus("Cannot export: No objects have been placed yet!", "warning")
        return false
    end

    local modFolder = sanitizeModName(rawModName)
    local author = (authorName and authorName ~= "") and authorName or "Lucas (Crabe)"
    local targetDir = getModsDir() .. "/" .. modFolder

    os.execute(string.format('mkdir "%s" 2>nul', targetDir:gsub("/", "\\")))

    -- 1. Write mod.json (CrabeLoader manifest)
    local modJsonPath = targetDir .. "/mod.json"
    local fMod = io.open(modJsonPath, "w")
    if not fMod then
        State.setStatus("Failed to create " .. modJsonPath, "error")
        return false
    end

    local currentWorld = Native.poll(Game.CurrentWorld) or "all"
    fMod:write(string.format([[{
  "id": "%s",
  "name": "%s",
  "version": "1.0.0",
  "author": "%s",
  "description": "Full Playset / Custom World with Quests built with Disney Infinity 3.0 World Editor.",
  "targetWorld": "%s",
  "entry": "runtime.lua"
}
]], modFolder, modFolder, author, currentWorld))
    fMod:close()

    -- 2. Write scene_layout.json (entities + quests)
    local sceneJsonPath = targetDir .. "/scene_layout.json"
    local fScene = io.open(sceneJsonPath, "w")
    if not fScene then
        State.setStatus("Failed to create " .. sceneJsonPath, "error")
        return false
    end

    fScene:write("{\n  \"entities\": [\n")
    for i, obj in ipairs(Editor.placedObjects) do
        fScene:write(string.format(
            '    { "id": "%s", "label": "%s", "x": %.3f, "y": %.3f, "z": %.3f, "world": "%s" }%s\n',
            obj.id,
            obj.label:gsub('"', '\\"'),
            obj.x or 0,
            obj.y or 0,
            obj.z or 0,
            obj.world or "",
            (i < #Editor.placedObjects) and "," or ""
        ))
    end
    fScene:write("  ],\n  \"quests\": [\n")
    for i, q in ipairs(Editor.quests) do
        fScene:write(string.format(
            '    { "id": "%s", "title": "%s", "giverId": "%s", "giverLabel": "%s", "gx": %.3f, "gy": %.3f, "gz": %.3f, "dialog": "%s", "rewardXp": %d }%s\n',
            q.id,
            q.title:gsub('"', '\\"'),
            q.giverId,
            (q.giverLabel or ""):gsub('"', '\\"'),
            (q.giverPos and q.giverPos.x) or 0,
            (q.giverPos and q.giverPos.y) or 0,
            (q.giverPos and q.giverPos.z) or 0,
            q.dialog:gsub('"', '\\"'),
            q.rewardXp or 250,
            (i < #Editor.quests) and "," or ""
        ))
    end
    fScene:write("  ]\n}\n")
    fScene:close()

    -- 3. Write runtime.lua (Autonomous in-game loader & Proximity Quest Watcher)
    local runtimePath = targetDir .. "/runtime.lua"
    local fRun = io.open(runtimePath, "w")
    if not fRun then
        State.setStatus("Failed to create " .. runtimePath, "error")
        return false
    end

    local runtimeTemplate = [=[-- @MOD_FOLDER@ - Autonomous Playset & Live Quest Runtime
-- Generated automatically by Disney Infinity 3.0 World Editor

local function loadPlayset()
    local path = "mods/@MOD_FOLDER@/scene_layout.json"
    local file = io.open(path, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()

    local targetWorld = "@TARGET_WORLD@"
    local currWorld = (Game and Game.CurrentWorld) and Game.CurrentWorld() or ""

    if targetWorld ~= "all" and currWorld ~= "" and currWorld:lower() ~= targetWorld:lower() then
        return
    end

    -- 1. Spawn Entities at exact 3D coordinates
    local count = 0
    for id, x, y, z in content:gmatch('"id"%s*:%s*"([^"]+)".-"x"%s*:%s*([%-%d%.]+).-"y"%s*:%s*([%-%d%.]+).-"z"%s*:%s*([%-%d%.]+)') do
        local nx, ny, nz = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
        if Game and Game.SpawnItemAt then
            pcall(Game.SpawnItemAt, id, nx, ny, nz)
            count = count + 1
        elseif Game and Game.SpawnItemMany then
            pcall(Game.SpawnItemMany, id, 1)
            count = count + 1
        end
    end

    -- 2. Setup Proximity Quest Watcher
    local quests = {}
    for qid, qtitle, gx, gy, gz, qdialog in content:gmatch('"id"%s*:%s*"(QUEST_[^"]+)".-"title"%s*:%s*"([^"]+)".-"gx"%s*:%s*([%-%d%.]+).-"gy"%s*:%s*([%-%d%.]+).-"gz"%s*:%s*([%-%d%.]+).-"dialog"%s*:%s*"([^"]+)"') do
        table.insert(quests, {
            id = qid,
            title = qtitle,
            gx = tonumber(gx) or 0,
            gy = tonumber(gy) or 0,
            gz = tonumber(gz) or 0,
            dialog = qdialog,
            triggered = false,
        })
    end

    if #quests > 0 and Game and Game.onTick then
        local tickCount = 0
        Game.onTick(function()
            tickCount = tickCount + 1
            if tickCount % 30 ~= 0 then return end -- Check every ~0.5s

            local avatarHandle = (Game.GetAvatarHandle and Game.GetAvatarHandle()) or 0
            if avatarHandle == 0 then return end

            local px, py, pz = Game.ActorPosition(avatarHandle)
            if not px then return end

            for _, q in ipairs(quests) do
                if not q.triggered then
                    local dx, dz = px - q.gx, pz - q.gz
                    local dist = math.sqrt(dx * dx + dz * dz)
                    if dist < 4.0 then
                        q.triggered = true
                        if Game.ShowMessage then
                            Game.ShowMessage(q.title, q.dialog)
                        end
                        if Game.LevelUpAvatar then
                            pcall(Game.LevelUpAvatar)
                        end
                    end
                end
            end
        end)
    end

    if Game and Game.ShowMessage then
        Game.ShowMessage("@MOD_FOLDER@ Playset Loaded", string.format("%d entities and %d quests populated!", count, #quests))
    end
end

if Crabe and Crabe.Events and Crabe.Events.on then
    Crabe.Events.on("world_loaded", loadPlayset)
else
    loadPlayset()
end
]=]

    local runtimeCode = runtimeTemplate:gsub("@MOD_FOLDER@", modFolder):gsub("@TARGET_WORLD@", currentWorld)
    fRun:write(runtimeCode)
    fRun:close()

    State.setStatus(string.format("SUCCESS: Exported Playset '%s' (%d objects, %d quests) to mods/%s/ !", modFolder, #Editor.placedObjects, #Editor.quests, modFolder), "success")
    return true
end

return Editor
