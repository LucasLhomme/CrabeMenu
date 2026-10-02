local Loader = ...
local Items = Loader.load("ui.items")
local Menu = Loader.load("ui.menu")
local WorldModule = Loader.load("modules.world")

-- Leaving a world closes the menu: it would otherwise keep the keys and the
-- pad away from the game through the loading screen and the world select.
local function leave(run)
    return function()
        if run() then Menu.setOpen(false) end
    end
end

local ITEMS = {
    Items.action("Go to main menu", leave(WorldModule.goToMainMenu),
        "Back to the world select; the game saves first, like Quit in the pause menu"),
    Items.action("Return to hub", leave(WorldModule.returnToHub), "Back to this playset's or Toy Box's hub"),
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
