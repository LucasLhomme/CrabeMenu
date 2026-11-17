local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local PosableHeroes = {}

local Globals = getfenv(0)
local CATALOG_FILE = "assets/presentation/virtualreaderpc_data.lua"
local EVENTS_FILE = "assets/characters/biped/biped.animtreeproject"
local SPAWN_DISTANCE = 3
local STORE_KEY = "crabemenu.posable_heroes"
local PRUNE_INTERVAL = 2

PosableHeroes.ANGLES = {}
for degrees = 0, 345, 15 do PosableHeroes.ANGLES[#PosableHeroes.ANGLES + 1] = degrees end
PosableHeroes.SCALES = { 0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 5 }
PosableHeroes.STEPS = { 0.1, 0.25, 0.5, 1, 2, 5 }
PosableHeroes.FREEZE_DELAYS = { 0, 0.25, 0.5, 0.75, 1, 1.5, 2, 3 }
PosableHeroes.POSES = {
    { id = "Cinematic_Celebrate", label = "Victory pose" },
    { id = "CELEBRATE", label = "Celebrate" },
    { id = "CELEBRATE_SMALL", label = "Small celebration" },
    { id = "CELEBRATE_SMALL_MBA", label = "Fist pump" },
    { id = "IDLE_BREAK", label = "Idle break" },
}

local store = package.loaded[STORE_KEY]
if type(store) ~= "table" then
    store = { placed = {}, revision = 0 }
    package.loaded[STORE_KEY] = store
end
PosableHeroes.store = store
PosableHeroes.placed = store.placed
PosableHeroes.stepIndex = 3
PosableHeroes.freezeDelayIndex = 1

local clock, nextPrune = 0, PRUNE_INTERVAL

local characters, events

--- Reports whether this CrabeLoader can create actors and call the engine's script natives.
function PosableHeroes.isAvailable()
    return type(Game.CreateActor) == "function" and type(Crabe.callNative) == "function"
end

local function call(name, ...)
    local ok, result = Crabe.callNative(name, ...)
    if not ok then return Native.fail("Posable heroes: the engine refused " .. name) end
    return true, result
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

local function catalogRows()
    local rows = {}
    if Crabe.VirtualReader and Crabe.VirtualReader.getModdedCharacters then
        for _, row in ipairs(Native.poll(Crabe.VirtualReader.getModdedCharacters) or {}) do
            rows[#rows + 1] = { Name = row.Name, sku_id = row.sku_id, ProgressionTree = row.ProgressionTree, modded = true }
        end
    end
    local data = rawget(Globals, "VirtualReaderPC_Data")
    if type(data) == "table" and type(data.AvatarData) == "table" then
        for _, row in ipairs(data.AvatarData) do rows[#rows + 1] = row end
        return rows
    end

    local avatarData = (readFile(CATALOG_FILE) or ""):match("AvatarData%s*=%s*(%b{})") or "{}"
    for block in avatarData:sub(2, -2):gmatch("%b{}") do
        local name = block:match('Name%s*=%s*"([^"]+)"')
        if name then
            rows[#rows + 1] = {
                Name = name,
                sku_id = block:match('sku_id%s*=%s*"([^"]*)"'),
                ProgressionTree = block:match('ProgressionTree%s*=%s*"([^"]*)"'),
            }
        end
    end
    return rows
end

local function moddedDna()
    local paths = {}
    if not (Crabe.Vfs and Crabe.Vfs.list) then return paths end
    for _, override in ipairs(Crabe.Vfs.list("characters/")) do paths[override.path:lower()] = true end
    return paths
end

local function dnaPath(name, modded)
    local lower = name:lower()
    for _, path in ipairs({ "characters/" .. lower .. ".dnax", "characters/" .. lower .. "/" .. lower .. ".dnax" }) do
        if modded[path] then return path end
        local file = io.open("assets/" .. path, "rb")
        if file then
            file:close()
            return path
        end
    end
    return nil
end

local function displayNames()
    local names = {}
    for _, row in ipairs(Native.poll(Game.ListCharacters) or {}) do
        local sku = tonumber(row.sku)
        if sku then names[sku] = row.name end
    end
    return names
end

local function labelFor(row, names)
    local name = row.Name
    local label = names[tonumber(row.sku_id) or -1]
    if not label or label == name then label = name:gsub("^%u+_", ""):gsub("_", " "):gsub("(%l)(%u)", "%1 %2") end
    if name:find("_Premium$") and not label:find("Premium") then label = label .. " (Premium)" end
    if row.modded then label = label .. "  [Mod]" end
    return label
end

local function byLabel(a, b)
    return a.label < b.label
end

--- Lists the playable heroes whose DNA file the game or a mod ships, sorted by name.
--- Rows of the game's catalog without a progression tree are packs and coins; mod rows are always heroes.
function PosableHeroes.characters()
    if characters then return characters end
    characters = {}
    local modded, names, seen = moddedDna(), displayNames(), {}
    for _, row in ipairs(catalogRows()) do
        local name = type(row) == "table" and row.Name
        local hero = row.modded or (row.ProgressionTree or "") ~= ""
        local dna = type(name) == "string" and not seen[name] and hero and dnaPath(name, modded)
        if dna then
            seen[name] = true
            characters[#characters + 1] = { id = name, dna = dna, label = labelFor(row, names) }
        end
    end
    table.sort(characters, byLabel)
    return characters
end

--- Lists every animation event of the shared biped animation tree, read once from the game files.
function PosableHeroes.events()
    if events then return events end
    events = {}
    local seen = {}
    for name in (readFile(EVENTS_FILE) or ""):gmatch('<AnimTreeEvent name="([^"]+)"') do
        if not seen[name] then
            seen[name] = true
            events[#events + 1] = { id = name, label = name }
        end
    end
    table.sort(events, byLabel)
    return events
end


local function playerFrame()
    local handle = Native.poll(Game.GetAvatarHandle)
    local px, py, pz = Native.poll(Game.ActorPosition, handle or 0)
    if not px then return nil end
    local cx, _, cz = Native.poll(Crabe.Camera.GetPosition)
    local dx, dz = px - (cx or px), pz - (cz or pz - 1)
    local length = math.sqrt(dx * dx + dz * dz)
    if length < 0.001 then dx, dz, length = 0, 1, 1 end
    return px, py, pz, dx / length, dz / length
end

local function headingToward(fromX, fromZ, toX, toZ)
    return math.atan2(toX - fromX, toZ - fromZ)
end

local function nearestAngleIndex(heading)
    local degrees = math.deg(heading) % 360
    return math.floor(degrees / 15 + 0.5) % #PosableHeroes.ANGLES + 1
end

local function changed()
    store.revision = store.revision + 1
end

local function isAlive(hero)
    local ok, valid = Crabe.callNative("ActorIsValid", hero.handle)
    return ok and valid == 1
end

--- Spawns a playable hero in front of the player, facing them.
function PosableHeroes.spawn(entry)
    local px, py, pz, fx, fz = playerFrame()
    if not px then return Native.fail("Posable heroes: load a world with your hero first") end

    local x, z = px + fx * SPAWN_DISTANCE, pz + fz * SPAWN_DISTANCE
    local heading = headingToward(x, z, px, pz)
    local ok, handle = Native.run("Game.CreateActor", Game.CreateActor, "DNAFile=" .. entry.dna, x, py, z, heading)
    if not ok then return false end
    if not handle then return Native.fail("Posable heroes: the engine did not create " .. entry.label) end

    Native.poll(Game.SetActorState, handle, "Unkillable", true)
    Crabe.callNative("SendSuspendAIEvent", handle, 0)
    store.placed[#store.placed + 1] = {
        handle = handle,
        id = entry.id,
        label = entry.label,
        angleIndex = nearestAngleIndex(heading),
        scaleIndex = 4,
        frozen = false,
        collision = true,
    }
    changed()
    PosableHeroes.setAngle(store.placed[#store.placed], nearestAngleIndex(heading))
    State.setStatus("Spawned posable hero: " .. entry.label, "success")
    return true
end

local function position(hero)
    local x, y, z = Native.poll(Game.ActorPosition, hero.handle)
    if not x then Native.fail("Posable heroes: " .. hero.label .. " is gone (world changed?)") end
    return x, y, z
end

local function place(hero, x, y, z)
    return Native.run("Game.PlaceActor", Game.PlaceActor, hero.handle, x, y, z)
end

--- Moves a hero by the current step, along the camera's view: forward/back, left/right or up/down.
function PosableHeroes.move(hero, forward, right, up)
    local x, y, z = position(hero)
    if not x then return false end
    local _, _, _, fx, fz = playerFrame()
    fx, fz = fx or 0, fz or 1
    local step = PosableHeroes.STEPS[PosableHeroes.stepIndex]
    return place(hero, x + (fx * forward - fz * right) * step, y + up * step, z + (fz * forward + fx * right) * step)
end

--- Puts a hero back in front of the player, facing them.
function PosableHeroes.bringToPlayer(hero)
    local px, py, pz, fx, fz = playerFrame()
    if not px then return Native.fail("Posable heroes: your hero's position cannot be read") end
    local x, z = px + fx * SPAWN_DISTANCE, pz + fz * SPAWN_DISTANCE
    if not place(hero, x, py, z) then return false end
    return PosableHeroes.setAngle(hero, nearestAngleIndex(headingToward(x, z, px, pz)))
end

--- Puts a hero where the camera is, so the free camera can carry it anywhere.
function PosableHeroes.placeAtCamera(hero)
    local x, y, z = Native.poll(Crabe.Camera.GetPosition)
    if not x then return Native.fail("Posable heroes: the camera position cannot be read") end
    return place(hero, x, y, z)
end

local function crosshairHit()
    if not (Crabe.Plugins and Crabe.Plugins.get) then return nil end
    local raw = Native.poll(Crabe.Plugins.get, "dev_toolkit.telemetry") or ""
    if not raw:find('"rayHit"%s*:%s*true') then return nil end
    local x = tonumber(raw:match('"rayX"%s*:%s*([%-0-9%.]+)'))
    local y = tonumber(raw:match('"rayY"%s*:%s*([%-0-9%.]+)'))
    local z = tonumber(raw:match('"rayZ"%s*:%s*([%-0-9%.]+)'))
    if not (x and y and z) then return nil end
    return x, y, z
end

--- Puts a hero on the spot under the crosshair, as reported by the Dev Toolkit plugin.
function PosableHeroes.placeAtCrosshair(hero)
    local x, y, z = crosshairHit()
    if not x then return Native.fail("Posable heroes: no crosshair hit (needs the Dev Toolkit plugin, aim at the ground)") end
    return place(hero, x, y, z)
end

--- Turns a hero to one of the ANGLES, in degrees around the vertical axis.
function PosableHeroes.setAngle(hero, index)
    local x, y, z = position(hero)
    if not x then return false end
    local half = math.rad(PosableHeroes.ANGLES[index]) / 2
    if not call("KinematicStatePlaceWithPositionAndOrientation", hero.handle, x, y, z, math.cos(half), 0, -math.sin(half), 0) then
        return false
    end
    hero.angleIndex = index
    return true
end

--- Turns a hero toward the player.
function PosableHeroes.faceMe(hero)
    local x, _, z = position(hero)
    local px, _, pz = playerFrame()
    if not (x and px) then return false end
    return PosableHeroes.setAngle(hero, nearestAngleIndex(headingToward(x, z, px, pz)))
end

--- Resizes a hero to one of the SCALES.
function PosableHeroes.setScale(hero, index)
    if not call("ActorSetUniformScale", hero.handle, PosableHeroes.SCALES[index]) then return false end
    hero.scaleIndex = index
    return true
end

--- Reports whether a hero's pose is frozen.
function PosableHeroes.isFrozen(hero)
    return hero.frozen == true
end

--- Freezes a hero in its current pose, like a statue, or lets it move again.
--- The engine's suspend-AI event stops the animation tree only, so the hero keeps its place and collision.
function PosableHeroes.setFrozen(hero, frozen)
    if not call("SendSuspendAIEvent", hero.handle, frozen and 1 or 0) then return false end
    hero.frozen = frozen
    hero.freezeAt = nil
    return true
end

--- Plays an animation event, such as CELEBRATE, then freezes the hero after the chosen delay, if any.
--- A spawned hero only reacts once its animation tree was woken by a resume event, which spawn sends.
function PosableHeroes.playEvent(hero, event)
    if hero.frozen and not PosableHeroes.setFrozen(hero, false) then return false end
    if not call("SendAnimTreeEvent", hero.handle, event) then return false end
    local delay = PosableHeroes.FREEZE_DELAYS[PosableHeroes.freezeDelayIndex]
    if delay > 0 then
        hero.freezeAt = os.clock() + delay
        State.setStatus(string.format("%s: %s, freezing in %gs", hero.label, event, delay), "success")
    else
        State.setStatus(hero.label .. ": " .. event, "success")
    end
    return true
end

--- Turns a hero's collision on or off, so the player can walk through it.
function PosableHeroes.setCollision(hero, on)
    if not call(on and "ActorCollisionEnable" or "ActorCollisionDisable", hero.handle) then return false end
    hero.collision = on
    return true
end

--- Deletes a hero from the world and from the list.
function PosableHeroes.remove(hero)
    if isAlive(hero) then call("ActorMarkForDeathForced", hero.handle) end
    for index, placed in ipairs(store.placed) do
        if placed == hero then
            table.remove(store.placed, index)
            changed()
            break
        end
    end
    State.setStatus("Removed posable hero: " .. hero.label, "info")
    return true
end

--- Deletes every posable hero, including the ones spawned before a mod reload (F4).
function PosableHeroes.removeAll()
    local count = 0
    for index = #store.placed, 1, -1 do
        local hero = store.placed[index]
        if isAlive(hero) then
            Crabe.callNative("ActorMarkForDeathForced", hero.handle)
            count = count + 1
        end
        store.placed[index] = nil
    end
    changed()
    State.setStatus(string.format("Removed %d posable hero(es)", count), "info")
    return true
end

local function prune()
    for index = #store.placed, 1, -1 do
        if not isAlive(store.placed[index]) then
            table.remove(store.placed, index)
            changed()
        end
    end
end

--- Runs the delayed pose freezes and forgets heroes the world no longer has; call once per tick.
function PosableHeroes.onTick(dt)
    clock = clock + (dt or 0)
    if #store.placed == 0 or not PosableHeroes.isAvailable() then return end
    for _, hero in ipairs(store.placed) do
        if hero.freezeAt and os.clock() >= hero.freezeAt then
            hero.freezeAt = nil
            PosableHeroes.setFrozen(hero, true)
        end
    end
    if clock >= nextPrune then
        nextPrune = clock + PRUNE_INTERVAL
        prune()
    end
end

return PosableHeroes
