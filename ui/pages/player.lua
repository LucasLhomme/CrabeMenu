local Loader = ...
local State = Loader.load("core.state")
local Items = Loader.load("ui.items")
local PlayerModule = Loader.load("modules.player")
local Cheats = Loader.load("modules.cheats")

local ROUTES = { "loadout", "legacy" }
local ROUTE_LABELS = { "Loadout", "Legacy" }

local function routeIndex()
    return (State.applyRoute == "legacy") and 2 or 1
end

local function setRoute(index)
    State.applyRoute = ROUTES[index]
    State.setStatus("Character swap method: " .. ROUTE_LABELS[index], "info")
end

local function heroPage(group)
    return {
        title = group.title,
        items = function()
            local list = {}
            for _, hero in ipairs(group.characters) do
                local current = (State.avatarSku == hero.sku) and "Current" or nil
                list[#list + 1] = Items.action(hero.name, function() PlayerModule.swapCharacter(hero.sku, hero.name) end,
                    "Play as " .. hero.name .. "  (SKU " .. tostring(hero.sku) .. ")", current)
            end
            return list
        end,
    }
end

local heroesPage = {
    title = "Change Hero",
    items = function()
        local list = {
            Items.choice("Swap method", ROUTE_LABELS, routeIndex, setRoute,
                "Loadout swaps through the figure loadout; Legacy calls Players_ChangeAvatar"),
        }
        for _, group in ipairs(PlayerModule.getRoster()) do
            list[#list + 1] = Items.submenu(group.title, function() return heroPage(group) end,
                "Every " .. group.title .. " figure", tostring(#group.characters))
        end
        return list
    end,
}

local function sparks(amount, label)
    return Items.action(label, function() PlayerModule.addSparks(amount) end, "Adds " .. label:sub(2) .. " to your balance")
end

local ITEMS = {
    Items.info("Current hero", function() return State.avatarName end,
        function() return "SKU " .. tostring(State.avatarSku) end),
    Items.submenu("Change hero", heroesPage, "Swap to any figure, modded heroes included"),
    Items.section("Progression"),
    Items.action("Level up +1", PlayerModule.levelUp, "Raises the current hero by one level"),
    Items.action("Max level", PlayerModule.maxProgression, "Sets the current hero to level 20"),
    Items.action("Refill health", Cheats.refillHealth, "Fills your health bar back up"),
    Items.section("Sparks"),
    sparks(50000, "+50,000 Sparks"),
    sparks(1000000, "+1,000,000 Sparks"),
    sparks(10000000, "+10,000,000 Sparks"),
}

return {
    title = "Player & Heroes",
    items = function() return ITEMS end,
}
