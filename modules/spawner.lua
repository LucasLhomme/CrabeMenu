local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Util = Loader.load("core.util")

local Spawner = {}

local NPC_PATTERN = "INV_NPC_"

Spawner.QUANTITIES = { 1, 3, 5, 10 }
Spawner.npcs = {}
Spawner.objects = {}
Spawner.modded = {}

local modNames = {}

local function byLabel(a, b)
    return a.label < b.label
end

-- A mod's display name: the "name" of its mod.json without the parenthesised
-- blurb ("Radahn (Promised Consort Radahn, enemy)" -> "Radahn"), else its folder.
local function modDisplayName(folder)
    if modNames[folder] then return modNames[folder] end
    local name = folder
    local file = io.open("mods/" .. folder .. "/mod.json", "r")
    if file then
        local manifest = file:read("*a")
        file:close()
        local declared = manifest:match('"name"%s*:%s*"([^"]+)"')
        if declared then
            declared = declared:gsub("%s*%b()", ""):match("^%s*(.-)%s*$")
            if declared ~= "" then name = declared end
        end
    end
    modNames[folder] = name
    return name
end

-- Which mod replaces each asset, keyed by lowercase file name without its
-- extension. A reskin keeps the game's item and only shadows its files
-- (Radahn is INV_NPC_TCW_NiktoThug_Bruiser wearing a new
-- characters/tcw_enemies/tcw_niktothug_bruiser.zip), so the VFS is the only
-- place that knows the item is modded. Empty on a loader without Crabe.Vfs.list.
local function overriddenAssets()
    local byName = {}
    if not (Crabe.Vfs and Crabe.Vfs.list) then return byName end
    for _, override in ipairs(Crabe.Vfs.list()) do
        local base = override.path:match("([^/]+)%.[^./]+$")
        if base then byName[base] = modDisplayName(override.mod) end
    end
    return byName
end

-- The mod that reskins an inventory row: its asset is named after the RRO
-- object, or after the item without its INV_/NPC_ prefix.
local function modFor(row, overridden)
    local candidates = { (row.name:gsub("^INV_", ""):gsub("^NPC_", "")) }
    if type(row.rro) == "string" then candidates[#candidates + 1] = row.rro end
    for _, candidate in ipairs(candidates) do
        local mod = overridden[candidate:lower()]
        if mod then return mod end
    end
    return nil
end

local function entryFor(row, overridden)
    local mod = modFor(row, overridden)
    local label = Util.humanize(row.name)
    if mod then label = label .. "  [" .. mod .. "]" end
    return { id = row.name, label = label, category = row.category, rro = row.rro, mod = mod }
end

local function readInventory()
    Game.RefreshInventory()

    local overridden = overriddenAssets()
    local npcs, objects, modded = {}, {}, {}
    for _, category in ipairs(Game.GetInventoryCategories()) do
        for _, row in ipairs(Game.GetInventoryItems(category)) do
            local entry = entryFor(row, overridden)
            objects[#objects + 1] = entry
            if row.name:find(NPC_PATTERN, 1, true) then npcs[#npcs + 1] = entry end
            if entry.mod then modded[#modded + 1] = entry end
        end
    end
    table.sort(npcs, byLabel)
    table.sort(objects, byLabel)
    table.sort(modded, byLabel)
    return npcs, objects, modded
end

--- Reads the world's placeable inventory and splits it into NPCs and every object.
--- Needs a loaded world: the engine has no inventory on the main menu.
function Spawner.scan()
    local ok, npcs, objects, modded = Native.run("Game inventory scan", readInventory)
    if not ok then return false end

    Spawner.npcs, Spawner.objects, Spawner.modded = npcs, objects, modded
    State.setStatus(string.format("Scanned %d objects, %d of them NPCs, %d modded", #objects, #npcs, #modded),
        "success")
    return true
end

--- Spawns an inventory entry the given number of times in front of the player.
function Spawner.spawn(entry, count)
    count = count or State.spawnCount
    local ok, placed = Native.run("Game.SpawnItemMany", Game.SpawnItemMany, entry.id, count)
    if not ok then return false end

    State.setStatus(string.format("Spawned %dx %s", tonumber(placed) or count, entry.label), "success")
    return true
end

--- Removes the objects and ghosts the editor placed.
function Spawner.clearPlaced()
    if not Native.run("Game.ClearEditorObjects", Game.ClearEditorObjects, true) then return false end
    State.setStatus("Placed objects and ghosts removed", "info")
    return true
end

return Spawner
