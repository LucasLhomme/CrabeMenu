local Loader = ...
local Items = Loader.load("ui.items")

local function optional(label, page, hint, ...)
    for _, module in ipairs({ ... }) do
        if not Loader.exists(module) then return nil end
    end
    return Items.submenu(label, Loader.load(page), hint)
end

local ITEMS = {}
for _, item in ipairs({
    Items.submenu("Player & Heroes", Loader.load("ui.pages.player"), "Change hero, level up, Sparks"),
    Items.submenu("Spawners", Loader.load("ui.pages.spawners"), "Spawn NPCs, objects, weapons and tools"),
    Items.submenu("Animations", Loader.load("ui.pages.animations"), "Play any of the game's choreographies on your hero"),
    Items.submenu("Cheats", Loader.load("ui.pages.cheats"), "God mode, game speed, Toy Box editor"),
    optional("Camera", "ui.pages.world", "Free camera and teleport", "modules.freecam") or false,
    optional("Multiplayer", "ui.pages.multiplayer", "Host or join a Toy Box session",
        "modules.multiplayer", "ui.pages.multiplayer") or false,
    Items.submenu("Mods", Loader.load("ui.pages.mods"), "Menus added by your other mods (Disney Infinity Complete, Radahn...)"),
    Items.submenu("Settings", Loader.load("ui.pages.settings"), "Menu side and size, overlay, video"),
}) do
    if item then ITEMS[#ITEMS + 1] = item end
end

return {
    title = "Main Menu",
    items = function() return ITEMS end,
}
