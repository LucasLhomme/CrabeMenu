local Loader = ...
local Items = Loader.load("ui.items")
local List = Loader.load("ui.pages.list")
local Animations = Loader.load("modules.animations")

local typedName = ""

local function playItem(entry)
    return Items.action(entry.label, function() Animations.play(entry.id) end, "Plays " .. entry.id)
end

local pages = {}

local function categoryPage(category)
    pages[category.id] = pages[category.id] or List.page(category.label, function()
        return Animations.getCategory(category.id)
    end, {
        fields = { "id", "label" },
        toItem = playItem,
        emptyLabel = "No animation listed",
        emptyHint = "This CrabeLoader has no choreography catalog (Game.ListChoreographies)",
    })
    return pages[category.id]
end

local function countFor(category)
    return function()
        local list = Animations.getCategory(category.id)
        return list and tostring(#list) or nil
    end
end

local ITEMS = {
    Items.input("Play by name", function() return typedName end, function(text)
        typedName = text
        Animations.play(text)
    end, "Type a choreography name, such as rr_starbasic, and press Enter"),
    Items.section("Categories"),
}
for _, category in ipairs(Animations.CATEGORIES) do
    ITEMS[#ITEMS + 1] = Items.submenu(category.label, function() return categoryPage(category) end,
        "Browse " .. category.label:lower(), countFor(category))
end

local UNAVAILABLE = {
    Items.info("Animations unavailable", nil, "Update CrabeLoader: this build has no choreography catalog"),
}

return {
    title = "Animations",
    items = function() return Animations.isAvailable() and ITEMS or UNAVAILABLE end,
}
