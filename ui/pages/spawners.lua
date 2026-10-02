local Loader = ...
local State = Loader.load("core.state")
local Items = Loader.load("ui.items")
local List = Loader.load("ui.pages.list")
local Spawner = Loader.load("modules.spawner")
local Weapons = Loader.load("modules.weapons")

local NOT_SCANNED_HINT = "Load a world, then use Scan world inventory"

local QUANTITY_LABELS = {}
for index, count in ipairs(Spawner.QUANTITIES) do QUANTITY_LABELS[index] = count .. "x" end

local function quantityIndex()
    for index, count in ipairs(Spawner.QUANTITIES) do
        if count == State.spawnCount then return index end
    end
    return 1
end

local function spawnItem(entry)
    return Items.action(entry.label, function() Spawner.spawn(entry) end, "Spawns " .. entry.id .. " in front of you",
        entry.category)
end

local function inventoryPage(title, source)
    return List.page(title, source, {
        fields = { "label", "id", "category" },
        toItem = spawnItem,
        emptyLabel = "Nothing scanned yet",
        emptyHint = NOT_SCANNED_HINT,
    })
end

local npcPage = inventoryPage("NPCs & Enemies", function() return Spawner.npcs end)
local objectPage = inventoryPage("Objects & Vehicles", function() return Spawner.objects end)

local weaponItems = nil

local function buildWeapons()
    local list = { Items.action("Holster current tool", Weapons.unequip, "Puts away whatever tool you hold") }
    local groups = Weapons.getGroups()
    if #groups == 0 then
        list[#list + 1] = Items.info("No weapon catalog", nil, "This CrabeLoader build has no weapon catalog")
    end
    for _, group in ipairs(groups) do
        list[#list + 1] = Items.section(group.title)
        for _, item in ipairs(group.items) do
            list[#list + 1] = Items.action(item.label, function() Weapons.equip(item) end, "Equips " .. item.label)
        end
    end
    return list
end

local weaponsPage = {
    title = "Weapons & Tools",
    items = function()
        weaponItems = weaponItems or buildWeapons()
        return weaponItems
    end,
}

local function countOf(rows)
    return function() return (#rows() > 0) and tostring(#rows()) or nil end
end

local ITEMS = {
    Items.action("Scan world inventory", Spawner.scan, "Reads everything this world can place; needs a loaded world"),
    Items.choice("Quantity", QUANTITY_LABELS, quantityIndex, function(index) State.spawnCount = Spawner.QUANTITIES[index] end,
        "How many copies each spawn places"),
    Items.submenu("NPCs & Enemies", npcPage, "Characters and enemies from the scan",
        countOf(function() return Spawner.npcs end)),
    Items.submenu("Objects & Vehicles", objectPage, "Every placeable object from the scan",
        countOf(function() return Spawner.objects end)),
    Items.submenu("Weapons & Tools", weaponsPage, "Equip any weapon or tool"),
    Items.action("Clear placed objects", Spawner.clearPlaced, "Removes the objects and ghosts the editor placed"),
}

return {
    title = "Spawners",
    items = function() return ITEMS end,
}
