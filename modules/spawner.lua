local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Util = Loader.load("core.util")

local Spawner = {}

local NPC_PATTERN = "INV_NPC_"

Spawner.QUANTITIES = { 1, 3, 5, 10 }
Spawner.npcs = {}
Spawner.objects = {}

local function byLabel(a, b)
    return a.label < b.label
end

local function entryFor(row)
    return { id = row.name, label = Util.humanize(row.name), category = row.category, rro = row.rro }
end

local function readInventory()
    Game.RefreshInventory()

    local npcs, objects = {}, {}
    for _, category in ipairs(Game.GetInventoryCategories()) do
        for _, row in ipairs(Game.GetInventoryItems(category)) do
            local entry = entryFor(row)
            objects[#objects + 1] = entry
            if row.name:find(NPC_PATTERN, 1, true) then npcs[#npcs + 1] = entry end
        end
    end
    table.sort(npcs, byLabel)
    table.sort(objects, byLabel)
    return npcs, objects
end

--- Reads the world's placeable inventory and splits it into NPCs and every object.
--- Needs a loaded world: the engine has no inventory on the main menu.
function Spawner.scan()
    local ok, npcs, objects = Native.run("Game inventory scan", readInventory)
    if not ok then return false end

    Spawner.npcs, Spawner.objects = npcs, objects
    State.setStatus(string.format("Scanned %d objects, %d of them NPCs", #objects, #npcs), "success")
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
