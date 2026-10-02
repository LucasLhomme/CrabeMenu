local Loader = ...
local State = Loader.load("core.state")
local Util = Loader.load("core.util")
local Theme = Loader.load("ui.theme")
local Spawner = Loader.load("modules.spawner")
local Weapons = Loader.load("modules.weapons")

local SECTIONS = {
    { key = "npcs", title = "NPCs & Enemies" },
    { key = "weapons", title = "Weapons & Tools" },
    { key = "objects", title = "Objects & Vehicles" },
}

local SEARCH_LENGTH = 64
local NOT_SCANNED = "Nothing scanned yet. Load a world, then press Scan world inventory."

local section = "npcs"
local searches = { npcs = "", objects = "" }
local filters = {
    npcs = Util.newFilter({ "label", "id", "category" }),
    objects = Util.newFilter({ "label", "id", "category" }),
}

local function describeEntry(entry)
    return string.format("%s  [%s]", entry.label, entry.category)
end

local function drawInventory(key, rows)
    local text = ImGui.InputText("Search##" .. key, searches[key], SEARCH_LENGTH)
    searches[key] = text

    local visible = filters[key](rows, text)
    Theme.textMuted(string.format("%d of %d entries", #visible, #rows))
    Theme.selectList(key .. "List", visible, describeEntry, Spawner.spawn, NOT_SCANNED)
end

local function drawWeapons()
    if Theme.button("Holster current tool", 220) then Weapons.unequip() end

    ImGui.BeginChild("WeaponsChild", 0, 240, true)
    local groups = Weapons.getGroups()
    if #groups == 0 then ImGui.TextDisabled("This CrabeLoader build has no weapon catalog.") end
    for _, group in ipairs(groups) do
        Theme.textGold(group.title)
        for _, item in ipairs(group.items) do
            if ImGui.Selectable("Equip " .. item.label .. "##" .. item.id, false) then Weapons.equip(item) end
        end
        ImGui.Spacing()
    end
    ImGui.EndChild()
end

local function drawQuantity()
    ImGui.Text("Quantity:")
    for _, count in ipairs(Spawner.QUANTITIES) do
        ImGui.SameLine()
        local label = (State.spawnCount == count) and ("[" .. count .. "x]") or (count .. "x")
        if Theme.button(label, 50) then State.spawnCount = count end
    end
end

local function render()
    Theme.header("Spawners")

    if Theme.button("Scan world inventory", 200) then Spawner.scan() end
    ImGui.SameLine()
    if Theme.button("Clear placed objects", 200) then Spawner.clearPlaced() end

    ImGui.Spacing()
    for index, entry in ipairs(SECTIONS) do
        if index > 1 then ImGui.SameLine() end
        if Theme.button((section == entry.key and "> " or "") .. entry.title, 170) then section = entry.key end
    end

    ImGui.Separator()
    drawQuantity()
    ImGui.Spacing()

    if section == "npcs" then
        drawInventory("npcs", Spawner.npcs)
    elseif section == "objects" then
        drawInventory("objects", Spawner.objects)
    else
        drawWeapons()
    end
end

return { title = "Spawners", render = render }
