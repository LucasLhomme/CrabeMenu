local Loader = ...
local Theme = Loader.load("ui.theme")
local Animations = Loader.load("modules.animations")

local SEARCH_LENGTH = 64
local CATEGORIES_PER_ROW = 3

local category = "avatar"
local search = ""

local function drawSearchBar()
    search = ImGui.InputText("Search / custom name##AnimSearch", search, SEARCH_LENGTH)
    ImGui.SameLine()
    if Theme.button("Play typed name", 140) then Animations.play(search) end
    ImGui.SameLine()
    if Theme.button("Clear", 60) then search = "" end
end

local function drawCategories()
    for index, entry in ipairs(Animations.CATEGORIES) do
        local items = Animations.itemsByCategory[entry.id]
        local label = string.format("%s (%d)", entry.label, items and #items or 0)
        if category == entry.id then label = "> " .. label end

        if Theme.button(label, 0) then category = entry.id end
        if index % CATEGORIES_PER_ROW ~= 0 and index < #Animations.CATEGORIES then ImGui.SameLine() end
    end
end

local function describeItem(item)
    return string.format("%s  [%s]", item.label, item.id)
end

local function render()
    Theme.header("Animations & Emotes")
    drawSearchBar()
    ImGui.Spacing()
    drawCategories()
    ImGui.Separator()

    if Theme.button(Animations.hasScanned() and "Re-scan game assets" or "Scan game assets", 180) then
        Animations.scan()
    end
    local emptyText = Animations.hasScanned() and "No animation matches this category and search."
        or "Press Scan game assets to list the choreographies."
    Theme.selectList("AnimationsChild", Animations.getItems(category, search), describeItem, function(item)
        Animations.play(item.id)
    end, emptyText)
end

return { title = "Animations", render = render }
