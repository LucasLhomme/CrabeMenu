local Loader = ...
local Items = Loader.load("ui.items")
local Menu = Loader.load("ui.menu")
local WorldModule = Loader.load("modules.world")
local List = Loader.load("ui.pages.list")
local CATALOG = Loader.load("modules.world_catalog")
local SKIES = Loader.load("modules.sky_catalog")

-- Leaving a world closes the menu: it would otherwise keep the keys and the
-- pad away from the game through the loading screen and the world select.
local function leave(run)
    return function()
        if run() then Menu.setOpen(false) end
    end
end

local function worldItem(row)
    return Items.action(row.name, leave(function() return WorldModule.travelTo(row.name) end),
        "Loads " .. row.name .. "; a world the game refuses needs a second press", row.group)
end

local function worldPage(title, rows)
    return List.page(title, function() return rows end, {
        fields = { "name", "group" },
        toItem = worldItem,
        emptyLabel = "No world here",
    })
end

local allRows = {}
local travelItems = {}
for _, group in ipairs(CATALOG) do
    local rows = {}
    for _, name in ipairs(group.worlds) do
        local row = { name = name, group = group.title }
        rows[#rows + 1] = row
        allRows[#allRows + 1] = row
    end
    travelItems[#travelItems + 1] = Items.submenu(group.title, worldPage(group.title, rows),
        "Every " .. group.title .. " world", tostring(#rows))
end
table.insert(travelItems, 1, Items.submenu("Search every world", worldPage("All worlds", allRows),
    "Type part of a name, e.g. hoth or hub", tostring(#allRows)))

local travelPage = {
    title = "Travel to a world",
    items = function() return travelItems end,
}

local function skyItem(row)
    return Items.action(row.name, function() WorldModule.loadSky(row.name) end,
        "Loads the realm " .. row.name .. " as the sky and lighting; it stays until the world reloads", row.group)
end

local function skyPage(title, rows)
    return List.page(title, function() return rows end, {
        fields = { "name", "group" },
        toItem = skyItem,
        emptyLabel = "No sky here",
    })
end

local allSkies = {}
local skyItems = {}
for _, group in ipairs(SKIES) do
    local rows = {}
    for _, name in ipairs(group.realms) do
        local row = { name = name, group = group.title }
        rows[#rows + 1] = row
        allSkies[#allSkies + 1] = row
    end
    skyItems[#skyItems + 1] = Items.submenu(group.title, skyPage(group.title, rows),
        "Every " .. group.title:lower() .. " realm", tostring(#rows))
end
table.insert(skyItems, 1, Items.submenu("Search every sky", skyPage("All skies", allSkies),
    "Type part of a name, e.g. night, sunset or storm", tostring(#allSkies)))

local skyPickerPage = {
    title = "Skybox",
    items = function() return skyItems end,
}

local ITEMS = {
    Items.action("Go to main menu", leave(WorldModule.goToMainMenu),
        "Back to the world select; the game saves first, like Quit in the pause menu"),
    Items.action("Return to hub", leave(WorldModule.returnToHub), "Back to this playset's or Toy Box's hub"),
    Items.submenu("Travel to a world", travelPage, "Any base-game world: Toy Box, Speedway and the four playsets",
        tostring(#allRows)),
    Items.submenu("Skybox", skyPickerPage, "Swap the sky and lighting of this world for any realm the game ships",
        tostring(#allSkies)),
}

-- The free camera ships outside the repository; its rows exist only with it.
if Loader.exists("modules.freecam") then
    local FreeCam = Loader.load("modules.freecam")
    local function setFreeCam(on)
        if on ~= FreeCam.isActive() then FreeCam.toggle() end
    end
    ITEMS[#ITEMS + 1] = Items.section("Camera")
    ITEMS[#ITEMS + 1] = Items.toggle("Free camera", FreeCam.isActive, setFreeCam,
        "Fly the camera anywhere; close the menu to steer it")
    ITEMS[#ITEMS + 1] = Items.action("Teleport hero to camera", FreeCam.teleportPlayerToCamera,
        "Drops your hero where the free camera is")
end

return {
    title = "World",
    items = function() return ITEMS end,
}
