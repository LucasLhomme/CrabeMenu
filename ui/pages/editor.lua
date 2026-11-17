local Loader = ...
local Items = Loader.load("ui.items")
local List = Loader.load("ui.pages.list")
local Editor = Loader.load("modules.editor")
local Spawner = Loader.load("modules.spawner")

local exportModName = "Moana_Playset"
local questTitle = "Sauver l'Ile de Motunui"
local questDialog = "Trouve la relique sacree pour sauver notre peuple !"

local function selectItem(entry)
    return Items.action(
        entry.label,
        function()
            Editor.selectAsset(entry.id, entry.label)
        end,
        "Selects " .. entry.id .. " as active brush",
        entry.category
    )
end

local function assetPickerPage(title, source)
    return List.page(title, source, {
        fields = { "label", "id", "category" },
        toItem = selectItem,
        emptyLabel = "No assets available",
        emptyHint = "Scan the world inventory first",
    })
end

local npcPalette = assetPickerPage("NPCs & Characters Palette", function() return Spawner.npcs end)
local objectPalette = assetPickerPage("Objects & Props Palette", function() return Spawner.objects end)

local function buildPlacedList()
    local list = {}
    if #Editor.placedObjects == 0 then
        list[#list + 1] = Items.info("Placed Entities", "0", "No objects placed in this session yet")
        return list
    end

    list[#list + 1] = Items.section(string.format("Placed Entities (%d)", #Editor.placedObjects))
    for i = #Editor.placedObjects, 1, -1 do
        local obj = Editor.placedObjects[i]
        local desc = string.format("Pos: %.1f, %.1f, %.1f", obj.x or 0, obj.y or 0, obj.z or 0)
        list[#list + 1] = Items.info(string.format("#%d %s", i, obj.label), desc, obj.id)
    end
    return list
end

local placedPage = {
    title = "Placed Entities List",
    items = function() return buildPlacedList() end,
}

local function getPlacedCountText()
    return string.format("%d placed", #Editor.placedObjects)
end

local function getQuestCountText()
    return string.format("%d quests", #Editor.quests)
end

local function getActiveBrushText()
    return Editor.selectedLabel or "None"
end

local function cycleSnapGrid()
    local cur = tonumber(State.editorSnapGrid) or 0
    if cur <= 0.0 then
        State.editorSnapGrid = 0.5
    elseif cur < 0.9 then
        State.editorSnapGrid = 1.0
    elseif cur < 1.9 then
        State.editorSnapGrid = 2.0
    else
        State.editorSnapGrid = 0.0
    end
end

local function getSnapGridText()
    local cur = tonumber(State.editorSnapGrid) or 0
    if cur <= 0.0 then return "Off" end
    return string.format("%.1fm", cur)
end

local function getCrosshairTargetText()
    if State.lastRayHit and State.lastRayHit.x then
        return string.format("%.1f, %.1f, %.1f (%.1fm)",
                             State.lastRayHit.x, State.lastRayHit.y, State.lastRayHit.z,
                             State.lastRayHit.dist or 0)
    end
    if Crabe and Crabe.Plugins and Crabe.Plugins.get then
        local raw = Crabe.Plugins.get("dev_toolkit.telemetry")
        if raw and raw ~= "" and raw:match('"rayHit"%s*:%s*true') then
            local rx = tonumber(raw:match('"rayX"%s*:%s*([%-0-9%.]+)')) or 0
            local ry = tonumber(raw:match('"rayY"%s*:%s*([%-0-9%.]+)')) or 0
            local rz = tonumber(raw:match('"rayZ"%s*:%s*([%-0-9%.]+)')) or 0
            local rd = tonumber(raw:match('"rayDist"%s*:%s*([%-0-9%.]+)')) or 0
            return string.format("%.1f, %.1f, %.1f (%.1fm)", rx, ry, rz, rd)
        end
    end
    return "No crosshair surface hit"
end

local function buildPage()
    local items = {
        Items.section("World Editor & Debug"),
        Items.toggle(
            "Editor Mode Active",
            function() return Editor.isActive() end,
            function(val) Editor.toggle(val and "on" or "off") end,
            "Toggles FreeCam, safe GodMode and in-game level editing controls"
        ),

        Items.section("Active Brush & Palette"),
        Items.info("Selected Asset", getActiveBrushText, "Object that will be placed under the crosshair"),
        Items.action("Scan World Assets", Spawner.scan, "Reads placeable props and characters from this map"),
        Items.submenu("Pick Character / NPC", npcPalette, "Choose an NPC or enemy to place"),
        Items.submenu("Pick Prop / Object", objectPalette, "Choose a prop, building or terrain item"),

        Items.section("Placement Actions"),
        Items.info("Crosshair 3D Target", getCrosshairTargetText, "Live world hit point under camera crosshair"),
        Items.action("Grid Snap", cycleSnapGrid, "Cycle world placement grid snapping (Off -> 0.5m -> 1.0m -> 2.0m)", getSnapGridText),
        Items.action("Place Object (Under Camera)", Editor.placeCurrent, "Spawns active asset at crosshair hit point without moving avatar"),
        Items.action("Undo Last Placement", Editor.undo, "Removes the most recent placed entity"),
        Items.action("Clear Placed Entities", Editor.clearAll, "Removes all editor objects from this session"),
        Items.submenu("View Placed Entities", placedPage, "Inspect all placed objects and their coordinates", getPlacedCountText),

        Items.section("Quest & Mission Designer"),
        Items.input(
            "Quest Title",
            function() return questTitle end,
            function(text) questTitle = (text and text ~= "") and text or "Nouvelle Mission" end,
            "Title of the mission shown on the HUD"
        ),
        Items.input(
            "NPC Dialog Text",
            function() return questDialog end,
            function(text) questDialog = (text and text ~= "") and text or "Bonjour héros !" end,
            "What the NPC says when you talk to them"
        ),
        Items.action(
            "Assign Quest to Last Placed NPC",
            function() Editor.addQuestToLastPlaced(questTitle, questDialog, "reach") end,
            "Makes the most recently placed NPC a Quest Giver with this dialog"
        ),
        Items.info("Configured Quests", getQuestCountText, "Quests that will be bundled into the exported Playset"),

        Items.section("Build & Export for CrabeLoader"),
        Items.input(
            "Playset Project Name",
            function() return exportModName end,
            function(text) exportModName = (text and text ~= "") and text or "Moana_Playset" end,
            "Folder name in mods/ for CrabeLoader"
        ),
        Items.action(
            "Export Full Playset Mod",
            function() Editor.exportMod(exportModName) end,
            "Generates mods/<name>/ with mod.json, layout, quests and auto-loader"
        ),
    }

    return items
end

return {
    title = "World Editor",
    items = buildPage,
}
